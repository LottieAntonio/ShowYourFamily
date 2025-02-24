import Foundation
import SwiftUI

@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var isLoading = false
    @Published var selectedPerson: Person?
    weak var familyManager: FamilyManagementViewModel?  // 改为 weak 可选引用
    
    private var personsDict: [UUID: Person] = [:]
    private var relationshipsDict: [UUID: Relationship] = [:]
    let dataManager: DataManaging
    
    init(dataManager: DataManaging) {
        self.dataManager = dataManager
    }
    
    // 修改便利初始化方法，不再使用可选的 familyManager
    convenience init(familyManager: FamilyManagementViewModel) {
        self.init(dataManager: familyManager.localDataManager)
        self.familyManager = familyManager
    }
    
    func savePerson(_ person: Person) async throws {
        do {
            try await dataManager.savePerson(person)
            await MainActor.run {
                // 使用字典优化查找
                personsDict[person.id] = person
                persons = Array(personsDict.values)
                // 设置新添加的人物为选中状态
                selectedPerson = person
            }
        } catch {
            print("保存人物失败：\(error)")
            throw error
        }
    }
    
    func deletePerson(_ person: Person) async throws {
        do {
            try await dataManager.deletePerson(person.id)
            await MainActor.run {
                // 使用字典优化删除操作
                personsDict.removeValue(forKey: person.id)
                persons = Array(personsDict.values)
                
                // 优化关系删除
                relationships.removeAll { relation in
                    if relation.fromPerson == person.id || relation.toPerson == person.id {
                        relationshipsDict.removeValue(forKey: relation.id)
                        return true
                    }
                    return false
                }
            }
        } catch {
            print("删除人物失败：\(error)")
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
    
    func loadData() async throws {
        guard let familyManager = familyManager,
              let currentFamily = familyManager.currentFamily else { return }
        
        // 只加载当前家谱的数据
        let persons = try await dataManager.loadPersons(familyId: currentFamily.id)
        let relationships = try await dataManager.loadRelationships(familyId: currentFamily.id)
        
        await MainActor.run {
            self.persons = persons
            self.relationships = relationships
            objectWillChange.send()
        }
    }
    
    // 添加家谱切换后的数据刷新方法
    func refreshAfterFamilySwitch() async {
        do {
            try await loadData()
            // 重置选中状态
            await MainActor.run {
                selectedPerson = nil
                objectWillChange.send()
            }
        } catch {
            print("切换家谱后刷新数据失败：\(error)")
        }
    }
}
