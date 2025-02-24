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
        print("\n=== ExampleData.loadExampleData 开始执行 ===")
        
        // 加载 JSON 文件
        guard let url = Bundle.main.url(forResource: "ExampleFamilyData", withExtension: "json") else {
            print("❌ 找不到示例数据文件")
            fatalError("无法加载示例数据")
        }
        print("📄 找到示例数据文件：\(url.lastPathComponent)")
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ 无法读取示例数据文件")
            fatalError("无法加载示例数据")
        }
        print("📥 成功读取数据：\(data.count) 字节")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let rawData = try? decoder.decode(RawFamilyData.self, from: data) else {
            print("❌ JSON 解析失败")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 JSON 内容：\(jsonString)")
            }
            fatalError("无法解析示例数据")
        }
        
        // 生成家谱
        // 使用固定的 UUID
        let familyId = defaultFamilyId
        
        let family = Family(
            id: familyId,
            name: rawData.family.name,
            description: rawData.family.description,
            isDefault: rawData.family.isDefault
        )
        print("👨‍👩‍👧‍👦 生成家谱：\(family.name)")
        
        // 生成人物
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
            print("👤 添加成员：\(person.firstName) \(person.lastName)")
        }
        print("✅ 成功生成 \(persons.count) 个成员")
        
        // 生成关系
        let relationships = rawData.relationships.map { rawRelation in
            let relationship = Relationship(
                type: RelationType(rawValue: rawRelation.type) ?? .spouse,
                fromPerson: personIndexToId[rawRelation.fromPersonIndex] ?? UUID(),
                toPerson: personIndexToId[rawRelation.toPersonIndex] ?? UUID()
            )
            print("🔗 添加关系：\(relationship.type.rawValue)")
            return relationship
        }
        print("✅ 成功生成 \(relationships.count) 个关系")
        
        print("=== ExampleData.loadExampleData 执行完成 ===\n")
        return (family, persons, relationships)
    }
}
