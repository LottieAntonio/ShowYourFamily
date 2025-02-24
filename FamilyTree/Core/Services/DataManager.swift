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
    func getAllRelationships() async throws -> [Relationship]
    func deleteRelationship(_ id: UUID) async throws
    func savePersons(_ persons: [Person]) async throws
    
    // 家谱相关方法
    func loadPersons(familyId: UUID) async throws -> [Person]
    func loadRelationships(familyId: UUID) async throws -> [Relationship]
    func loadFamilies() async throws -> [Family]  // 添加这个
    func saveFamily(_ family: Family) async throws  // 添加这个
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
            let loadedPersons = try localDataManager.loadPersonsSync()
            let loadedRelationships = try localDataManager.loadRelationshipsSync()
            
            persons = Dictionary(uniqueKeysWithValues: loadedPersons.map { ($0.id, $0) })
            relationships = Dictionary(uniqueKeysWithValues: loadedRelationships.map { ($0.id, $0) })
        } catch {
            persons = [:]
            relationships = [:]
        }
    }
    
    func saveRelationship(_ relationship: Relationship) async throws {
        do {
            try await localDataManager.saveRelationship(relationship)
            await MainActor.run {
                relationships[relationship.id] = relationship
            }
        } catch {
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
    
    // 实现家谱相关方法
    func loadFamilies() async throws -> [Family] {
        return try await localDataManager.loadFamilies()
    }
    
    func saveFamily(_ family: Family) async throws {
        try await localDataManager.saveFamily(family)
    }
    
    // 实现新增的家谱相关方法
    func loadPersons(familyId: UUID) async throws -> [Person] {
        // 从内存中过滤指定家谱的人物
        return Array(persons.values)
            .filter { $0.familyId == familyId }
            .sorted { $0.id.uuidString > $1.id.uuidString }
    }
    
    func loadRelationships(familyId: UUID) async throws -> [Relationship] {
        // 获取指定家谱的所有人物 ID
        let familyPersonIds = Set(
            persons.values
                .filter { $0.familyId == familyId }
                .map { $0.id }
        )
        
        // 过滤出只涉及该家谱成员的关系
        return Array(relationships.values)
            .filter { relationship in
                familyPersonIds.contains(relationship.fromPerson) &&
                familyPersonIds.contains(relationship.toPerson)
            }
    }
    
    // 修改现有的保存方法，确保数据一致性
    func savePerson(_ person: Person) async throws {
        // 验证家谱 ID
        guard !person.familyId.uuidString.isEmpty else {
            throw DataError.invalidFamilyId
        }
        
        do {
            try await localDataManager.savePerson(person)
            
            await MainActor.run {
                persons[person.id] = person
            }
        } catch {
            throw error
        }
    }
}

// 添加错误类型
enum DataError: LocalizedError {
    case invalidFamilyId
    case personNotFound
    case relationshipNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidFamilyId:
            return "无效的家谱 ID"
        case .personNotFound:
            return "未找到指定的人物"
        case .relationshipNotFound:
            return "未找到指定的关系"
        }
    }
}
