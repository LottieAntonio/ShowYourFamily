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

    // 添加新方法
    func deleteFamily(_ familyId: UUID) async throws
    func copyFamily(_ sourceId: UUID, withName name: String, description: String?) async throws -> Family
}

class DataManager: DataManaging {  // 添加 ObservableObject 协议
    static let shared = DataManager()
    private let localDataManager = LocalDataManager()
   
    
    private init() {
    }
    
     // 委托所有方法到 localDataManager
    func savePerson(_ person: Person) async throws {
        try await localDataManager.savePerson(person)
    }
    
    func getPerson(by id: UUID) async throws -> Person? {
        return try await localDataManager.getPerson(by: id)
    }
    
    func getAllPersons() async throws -> [Person] {
        return try await localDataManager.getAllPersons()
    }
    
    func deletePerson(_ id: UUID) async throws {
        try await localDataManager.deletePerson(id)
    }
    
    func saveRelationship(_ relationship: Relationship) async throws {
        try await localDataManager.saveRelationship(relationship)
    }
    
    func getRelationships(for personId: UUID) async throws -> [Relationship] {
        return try await localDataManager.getRelationships(for: personId)
    }
    
    func getAllRelationships() async throws -> [Relationship] {
        return try await localDataManager.getAllRelationships()
    }
    
    func deleteRelationship(_ id: UUID) async throws {
        try await localDataManager.deleteRelationship(id)
    }
    
    func savePersons(_ persons: [Person]) async throws {
        try await localDataManager.savePersons(persons)
    }
    
    func loadPersons(familyId: UUID) async throws -> [Person] {
        return try await localDataManager.loadPersons(familyId: familyId)
    }
    
    func loadRelationships(familyId: UUID) async throws -> [Relationship] {
        return try await localDataManager.loadRelationships(familyId: familyId)
    }
    
    func loadFamilies() async throws -> [Family] {
        return try await localDataManager.loadFamilies()
    }
    
    func saveFamily(_ family: Family) async throws {
        try await localDataManager.saveFamily(family)
    }
    
    func deleteFamily(_ familyId: UUID) async throws {
        try await localDataManager.deleteFamily(familyId)
    }
    
    func copyFamily(_ sourceId: UUID, withName name: String, description: String?) async throws -> Family {
        return try await localDataManager.copyFamily(sourceId, withName: name, description: description)
    }
}

// 添加错误类型
enum DataError: LocalizedError {
    case personNotFound
    case relationshipNotFound
    case familyNotFound
    case invalidData
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .personNotFound:
            return "未找到指定的人物"
        case .relationshipNotFound:
            return "未找到指定的关系"
        case .familyNotFound:
            return "未找到指定的家谱"
        case .invalidData:
            return "数据格式无效"
        case .saveFailed:
            return "保存数据失败"
        case .loadFailed:
            return "加载数据失败"
        }
    }
}
