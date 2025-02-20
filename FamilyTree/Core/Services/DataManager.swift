import Foundation
import Combine  // 添加 Combine 框架

protocol DataManaging {
    // 人员管理
    func savePerson(_ person: Person) async throws
    func getPerson(by id: UUID) async throws -> Person?
    func getAllPersons() async throws -> [Person]
    func deletePerson(_ id: UUID) async throws
    
    // 关系管理
    func saveRelationship(_ relationship: Relationship) async throws
    func getRelationships(for personId: UUID) async throws -> [Relationship]
    func getAllRelationships() async throws -> [Relationship]  // 添加新方法
    func deleteRelationship(_ id: UUID) async throws
    func savePersons(_ persons: [Person]) async throws  // 添加新方法
}

class DataManager: DataManaging, ObservableObject {  // 添加 ObservableObject 协议
    static let shared = DataManager()
    private let localDataManager = LocalDataManager()
    @Published private var persons: [UUID: Person] = [:]     // 添加 @Published
    @Published private var relationships: [UUID: Relationship] = [:]  // 添加 @Published
    
    private init() {
        loadDataSync()
    }
    
    private func loadDataSync() {
        do {
            // 同步加载所有数据
            let loadedPersons = try localDataManager.loadPersonsSync()
            let loadedRelationships = try localDataManager.loadRelationshipsSync()
            
            // 更新内存数据
            persons = Dictionary(uniqueKeysWithValues: loadedPersons.map { ($0.id, $0) })
            relationships = Dictionary(uniqueKeysWithValues: loadedRelationships.map { ($0.id, $0) })
            
            print("✅ 成功加载数据 - 人物: \(loadedPersons.count), 关系: \(loadedRelationships.count)")
        } catch {
            print("❌ 加载数据失败: \(error.localizedDescription)")
            // 确保字典被初始化为空
            persons = [:]
            relationships = [:]
        }
    }
    
    func savePerson(_ person: Person) async throws {
        do {
            // 先保存到本地
            try await localDataManager.savePerson(person)
            print("✅ 保存人物成功: \(person.firstName)\(person.lastName)")
            
            // 再更新内存
            await MainActor.run {
                persons[person.id] = person
            }
        } catch {
            print("❌ 保存人物失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    func saveRelationship(_ relationship: Relationship) async throws {
        do {
            // 先保存到本地
            try await localDataManager.saveRelationship(relationship)
            print("✅ 保存关系成功: \(relationship.id)")
            
            // 再更新内存
            await MainActor.run {
                relationships[relationship.id] = relationship
            }
        } catch {
            print("❌ 保存关系失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deletePerson(_ id: UUID) async throws {
        // 先从本地删除
        try await localDataManager.deletePerson(id)
        
        // 删除相关的关系
        let relatedRelationships = relationships.values.filter {
            $0.fromPerson == id || $0.toPerson == id
        }
        
        for relationship in relatedRelationships {
            try await localDataManager.deleteRelationship(relationship.id)
        }
        
        // 最后更新内存
        await MainActor.run {
            persons.removeValue(forKey: id)
            relationships = relationships.filter { relationship in
                relationship.value.fromPerson != id && relationship.value.toPerson != id
            }
        }
    }
    
    func savePersons(_ persons: [Person]) async throws {
        // 批量更新，避免频繁 IO
        await MainActor.run {
            let updates = Dictionary(uniqueKeysWithValues: persons.map { ($0.id, $0) })
            self.persons.merge(updates) { _, new in new }
        }
        
        // 使用 Task Group 并行处理保存操作
        try await withThrowingTaskGroup(of: Void.self) { group in
            for person in persons {
                group.addTask {
                    try await self.localDataManager.savePerson(person)
                }
            }
            try await group.waitForAll()
        }
    }
    
    func getPerson(by id: UUID) async throws -> Person? {
        return persons[id]
    }
    
    func getAllPersons() async throws -> [Person] {
        // 返回按照添加顺序排序的数组
        return Array(persons.values).sorted { $0.id.uuidString > $1.id.uuidString }
    }
    
   
    
    // MARK: - Relationship Management
    
    
    func getRelationships(for personId: UUID) async throws -> [Relationship] {
        return relationships.values.filter { relationship in
            relationship.fromPerson == personId || relationship.toPerson == personId
        }
    }
    
    // 添加新方法实现
    func getAllRelationships() async throws -> [Relationship] {
        return Array(relationships.values)
    }
    
    func deleteRelationship(_ id: UUID) async throws {
        relationships.removeValue(forKey: id)
        // 持久化删除
        try await localDataManager.deleteRelationship(id)
    }
}
