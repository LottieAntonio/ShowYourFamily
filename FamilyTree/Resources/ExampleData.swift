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
                gender: rawPerson.gender == "male" ? .male : (rawPerson.gender == "female" ? .female : .other),
                isSelf: index == 6
            ).with(birthDate: rawPerson.birthDate)
            
            persons.append(person)
        }
        
        var relationships: [Relationship] = []
        
        for rawRelation in rawData.relationships {
            if rawRelation.type == "child" {
                // 父母指向子女的关系（原始关系）
                let relationship = Relationship(
                    type: .child,
                    fromPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID(),
                    toPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID()
                )
                relationships.append(relationship)
                
                // 子女指向父母的反向关系
                // 根据父母（toPersonIndex）的性别来确定是父亲还是母亲
                let parent = persons[rawRelation.toPersonIndex]
                let parentType: RelationType = parent.gender == .male ? .father : .mother
                
                let reverseRelationship = Relationship(
                    type: parentType,
                    fromPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID(),
                    toPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID()
                )
                relationships.append(reverseRelationship)
            } else if rawRelation.type == "spouse" {
                // 配偶双向关系
                let relationship1 = Relationship(
                    type: .spouse,
                    fromPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID(),
                    toPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID()
                )
                let relationship2 = Relationship(
                    type: .spouse,
                    fromPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID(),
                    toPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID()
                )
                relationships.append(relationship1)
                relationships.append(relationship2)
            }
        }
        
        return (family, persons, relationships)
    }
}
