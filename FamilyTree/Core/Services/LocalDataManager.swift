import Foundation

class LocalDataManager {
    // 添加获取文档目录的方法
    private func getDocumentsDirectory() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw NSError(
                domain: "LocalDataManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取文档目录"]
            )
        }
        return documentsDirectory
    }
    
    // 添加同步加载方法
    func loadPersonsSync() throws -> [Person] {
        // 实现同步加载逻辑
        let fileURL = try getDocumentsDirectory().appendingPathComponent("persons.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Person].self, from: data)
    }
    
    func loadRelationshipsSync() throws -> [Relationship] {
        // 实现同步加载逻辑
        let fileURL = try getDocumentsDirectory().appendingPathComponent("relationships.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Relationship].self, from: data)
    }
    
    private let personsFileName = "persons.json"
    private let relationshipsFileName = "relationships.json"
    
    func loadPersons() async throws -> [Person] {
        do {
            return try FileManager.load([Person].self, from: personsFileName)
        } catch {
            return []
        }
    }
    
    func loadRelationships() async throws -> [Relationship] {
        do {
            return try FileManager.load([Relationship].self, from: relationshipsFileName)
        } catch {
            return []
        }
    }
    
    func savePerson(_ person: Person) async throws {
        do {
            var persons = try await loadPersons()
            if let index = persons.firstIndex(where: { $0.id == person.id }) {
                persons[index] = person
            } else {
                persons.append(person)
            }
            try FileManager.save(persons, to: personsFileName)
        } catch {
            throw error  // 确保错误被正确传递
        }
    }
    
    func saveRelationship(_ relationship: Relationship) async throws {
        var relationships = try await loadRelationships()
        if let index = relationships.firstIndex(where: { $0.id == relationship.id }) {
            relationships[index] = relationship
        } else {
            relationships.append(relationship)
        }
        try FileManager.save(relationships, to: relationshipsFileName)
    }
    
    func deletePerson(_ personId: UUID) async throws {
        var persons = try await loadPersons()
        persons.removeAll { $0.id == personId }
        try FileManager.save(persons, to: personsFileName)
    }
    
    func deleteRelationship(_ relationshipId: UUID) async throws {
        var relationships = try await loadRelationships()
        relationships.removeAll { $0.id == relationshipId }
        try FileManager.save(relationships, to: relationshipsFileName)
    }
}