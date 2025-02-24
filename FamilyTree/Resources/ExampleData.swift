import Foundation

// 用于解析 JSON 的数据结构
private struct RawFamilyData: Codable {
    struct RawFamily: Codable {
        let name: String
        let description: String?
        let isDefault: Bool
    }
    
    struct RawPerson: Codable {
        let firstName: String
        let lastName: String
        let gender: String
        let birthDate: Date
    }
    
    struct RawRelationship: Codable {
        let type: String
        let fromPersonIndex: Int
        let toPersonIndex: Int
    }
    
    let family: RawFamily
    let persons: [RawPerson]
    let relationships: [RawRelationship]
}

struct ExampleData {
    // 添加固定的示例家谱 ID
    static let defaultFamilyId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    
    static func loadExampleData() -> (Family, [Person], [Relationship]) {
        guard let url = Bundle.main.url(forResource: "ExampleFamilyData", withExtension: "json") else {
            fatalError("无法加载示例数据")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("无法加载示例数据")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let rawData = try? decoder.decode(RawFamilyData.self, from: data) else {
            fatalError("无法解析示例数据")
        }
        
        let familyId = defaultFamilyId
        
        let family = Family(
            id: familyId,
            name: rawData.family.name,
            description: rawData.family.description,
            isDefault: rawData.family.isDefault
        )
        
        var persons: [Person] = []
        var personIndexToId: [Int: UUID] = [:]
        
        for (index, rawPerson) in rawData.persons.enumerated() {
            let personId = UUID()
            personIndexToId[index] = personId
            
            let person = Person(
                id: personId,
                familyId: familyId,
                firstName: rawPerson.firstName,
                lastName: rawPerson.lastName,
                gender: Person.Gender(rawValue: rawPerson.gender) ?? .other
            ).with(birthDate: rawPerson.birthDate)
            
            persons.append(person)
        }
        
        let relationships = rawData.relationships.map { rawRelation in
            Relationship(
                type: RelationType(rawValue: rawRelation.type) ?? .spouse,
                fromPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID(),
                toPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID()
            )
        }
        
        return (family, persons, relationships)
    }
}
