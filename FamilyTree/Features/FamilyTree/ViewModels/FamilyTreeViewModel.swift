import Foundation
import SwiftUI

@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var isLoading = false
    @Published var selectedPerson: Person?
    
    private var personsDict: [UUID: Person] = [:] // 添加字典缓存
    private var relationshipsDict: [UUID: Relationship] = [:] // 添加字典缓存
    let dataManager: DataManaging
    
    init(dataManager: DataManaging = DataManager.shared) {
        self.dataManager = dataManager
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
        if isLoading { return } // 防止重复加载
        
        isLoading = true
        do {
            async let loadedPersons = dataManager.getAllPersons()
            async let loadedRelationships = dataManager.getAllRelationships()
            
            // 并行加载数据
            let (persons, relationships) = try await (loadedPersons, loadedRelationships)
            
            await MainActor.run {
                // 更新字典缓存
                self.personsDict = Dictionary(uniqueKeysWithValues: persons.map { ($0.id, $0) })
                self.relationshipsDict = Dictionary(uniqueKeysWithValues: relationships.map { ($0.id, $0) })
                
                // 更新数组
                self.persons = Array(self.personsDict.values).sorted { $0.id.uuidString < $1.id.uuidString }
                self.relationships = Array(self.relationshipsDict.values)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            throw error
        }
    }
}