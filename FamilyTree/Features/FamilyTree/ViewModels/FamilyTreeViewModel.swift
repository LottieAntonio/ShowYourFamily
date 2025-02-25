import Foundation
import SwiftUI

@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var isLoading = false
    @Published var selectedPerson: Person?
    weak var familyManager: FamilyManagementViewModel?  // 保持 weak 引用
    
    private var personsDict: [UUID: Person] = [:]
    private var relationshipsDict: [UUID: Relationship] = [:]
    let dataManager: DataManaging
    
    init(dataManager: DataManaging) {
        self.dataManager = dataManager
    }
    
    // 添加任务取消支持
    private var loadDataTask: Task<Void, Error>?
    
    deinit {
        loadDataTask?.cancel()
    }
    
    // 添加当前家谱 ID 追踪
    private var currentFamilyId: UUID?
    
    convenience init(familyManager: FamilyManagementViewModel) {
        self.init(dataManager: familyManager.localDataManager)
        self.familyManager = familyManager
        familyManager.setFamilyTreeViewModel(self)  // 添加这行，确保双向引用
        
        // 取消之前的加载任务
        loadDataTask?.cancel()
        
        // 创建新的加载任务
        loadDataTask = Task { @MainActor in
            if familyManager.currentFamily == nil,
               let firstFamily = familyManager.families.first {
                await familyManager.switchFamily(firstFamily)
            }
            
            if let currentFamily = familyManager.currentFamily {
                self.currentFamilyId = currentFamily.id
                try? await self.loadData()
            }
        }
    }
    
    func loadData() async throws {
        // 取消之前的任务
        loadDataTask?.cancel()
        
        guard let familyManager = familyManager else {
            print("⚠️ FamilyTreeViewModel 未设置 familyManager")
            throw FamilyError.noCurrentFamily
        }
        
        guard let currentFamily = familyManager.currentFamily else {
            print("⚠️ 未选择当前家谱")
            throw FamilyError.noCurrentFamily
        }
        
        print("🔄 开始加载家谱数据：\(currentFamily.name)")
        isLoading = true
        defer { isLoading = false }
        
        // 创建新的加载任务
        let task = Task { @MainActor in
            do {
                // 更新当前家谱 ID
                self.currentFamilyId = currentFamily.id
                
                // 清空现有数据
                self.persons = []
                self.relationships = []
                self.personsDict = [:]
                self.relationshipsDict = [:]
                
                let persons = try await dataManager.loadPersons(familyId: currentFamily.id)
                let relationships = try await dataManager.loadRelationships(familyId: currentFamily.id)
                
                if Task.isCancelled { return }
                
                self.persons = persons
                self.relationships = relationships
                self.personsDict = Dictionary(uniqueKeysWithValues: persons.map { ($0.id, $0) })
                self.relationshipsDict = Dictionary(uniqueKeysWithValues: relationships.map { ($0.id, $0) })
                print("✅ 加载完成[\(currentFamily.name)]：\(persons.count) 个成员，\(relationships.count) 个关系")
            } catch {
                print("❌ 加载数据失败：\(error.localizedDescription)")
                throw error
            }
        }
        
        loadDataTask = task
        try await task.value
    }
    
    func refreshAfterFamilySwitch() async {
        guard familyManager != nil else {
            print("⚠️ 刷新数据时未找到当前家谱")
            return
        }
        
        // 更新当前家谱 ID 并加载数据
        do {
            try await loadData()
        } catch {
            print("❌ 切换家谱后刷新数据失败：\(error)")
        }
    }
    
    func savePerson(_ person: Person) async throws {
        do {
            try await dataManager.savePerson(person)
            await MainActor.run {
                personsDict[person.id] = person
                persons = Array(personsDict.values)
                selectedPerson = person
            }
        } catch {
            throw error
        }
    }
    
    func deletePerson(_ person: Person) async throws {
        do {
            try await dataManager.deletePerson(person.id)
            await MainActor.run {
                personsDict.removeValue(forKey: person.id)
                persons = Array(personsDict.values)
                
                relationships.removeAll { relation in
                    if relation.fromPerson == person.id || relation.toPerson == person.id {
                        relationshipsDict.removeValue(forKey: relation.id)
                        return true
                    }
                    return false
                }
            }
        } catch {
            throw error
        }
    }
    
    func addRelationship(_ relationship: Relationship) async throws {
        do {
            try await dataManager.saveRelationship(relationship)
            await MainActor.run {
                relationshipsDict[relationship.id] = relationship
                relationships = Array(relationshipsDict.values)
            }
        } catch {
            print("保存关系失败：\(error)")
            throw error
        }
    }
    
    
}
