import Foundation
import SwiftUI

@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published var persons: [Person] = []
    @Published var relationships: [Relationship] = []
    @Published var isLoading = false
    @Published var selectedPerson: Person?  // 修改为公开访问
    
    func updateSelectedPerson(_ person: Person) {
        selectedPerson = person
    }
    
    let dataManager: DataManaging
    
    init(dataManager: DataManaging = DataManager.shared) {
        self.dataManager = dataManager
    }
    
    // 添加保存人物的方法
    func savePerson(_ person: Person) async throws {
        do {
            try await dataManager.savePerson(person)
            if let index = persons.firstIndex(where: { $0.id == person.id }) {
                persons[index] = person
            } else {
                persons.append(person)
            }
        } catch {
            print("保存人物失败：\(error)")
            throw error
        }
    }
    
    // 添加删除人物的方法
    func deletePerson(_ person: Person) async throws {
        do {
            try await dataManager.deletePerson(person.id)  // 修改这里，传入 person.id
            persons.removeAll { $0.id == person.id }
            // 同时删除相关的关系
            relationships.removeAll { $0.fromPerson == person.id || $0.toPerson == person.id }
        } catch {
            print("删除人物失败：\(error)")
            throw error
        }
    }
    
    func addRelationship(_ relationship: Relationship) async throws {
        // 修改为异步函数并添加错误处理
        do {
            try await dataManager.saveRelationship(relationship)
            relationships.append(relationship)
        } catch {
            print("保存关系失败：\(error)")
            throw error
        }
    }
    
    // 添加错误处理
    func loadData() async throws {
        isLoading = true
        do {
            // 强制从本地存储加载最新数据
            let loadedPersons = try await dataManager.getAllPersons()
            let loadedRelationships = try await dataManager.getAllRelationships()
            
            await MainActor.run {
                self.persons = loadedPersons.sorted { $0.id.uuidString < $1.id.uuidString }
                self.relationships = loadedRelationships
                self.isLoading = false
            }
        } catch {
            isLoading = false
            throw error
        }
    }
}