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
        let birthOrder: Int
        let isSelf: Bool?
    }
    
    struct RawRelationship: Codable {
        let type: String
        // 通用字段
        let fromPersonIndex: Int?
        let toPersonIndex: Int?
        // 父子关系专用字段
        let parentIndex: Int?
        let childIndex: Int?
        // 兄弟姐妹关系专用字段
        let person1Index: Int?
        let person2Index: Int?
        // 描述
        let description: String?
    }
    
    let family: RawFamily
    let persons: [RawPerson]
    let relationships: [RawRelationship]
}

struct ExampleData {
    // 添加固定的示例家谱 ID
    static let defaultFamilyId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    
    static func loadExampleData() -> (Family, [Person], [Relationship]) {
        print("🔄 开始加载示例数据...")
        
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
        
        print("📋 家谱信息: \(family.name)")
        
        var persons: [Person] = []
        var personIndexToId: [Int: UUID] = [:]
        
        // 创建人物
        print("👥 开始创建人物...")
        for (index, rawPerson) in rawData.persons.enumerated() {
            let personId = UUID()
            personIndexToId[index] = personId
            
            let person = Person(
                id: personId,
                familyId: familyId,
                firstName: rawPerson.firstName,
                lastName: rawPerson.lastName,
                gender: rawPerson.gender == "male" ? .male : (rawPerson.gender == "female" ? .female : .other),
                isSelf: rawPerson.isSelf ?? false
            ).with(birthDate: rawPerson.birthDate)
            
            persons.append(person)
            
            print("👤 创建人物: \(person.lastName)\(person.firstName), 性别: \(person.gender), ID: \(person.id), 是自己: \(person.isSelf)")
        }
        
        var relationships: [Relationship] = []
        
        // 创建关系
        print("🔗 开始创建关系...")
        for (index, rawRelation) in rawData.relationships.enumerated() {
            print("🔄 处理关系 #\(index): 类型 \(rawRelation.type)")
            
            switch rawRelation.type {
            case "spouse":
                guard let fromIndex = rawRelation.fromPersonIndex,
                      let toIndex = rawRelation.toPersonIndex,
                      let fromId = personIndexToId[fromIndex],
                      let toId = personIndexToId[toIndex] else {
                    print("⚠️ 配偶关系数据不完整")
                    continue
                }
                
                // 创建双向配偶关系
                let relationship1 = Relationship(
                    type: .spouse,
                    fromPerson: fromId,
                    toPerson: toId
                )
                relationships.append(relationship1)
                
                let relationship2 = Relationship(
                    type: .spouse,
                    fromPerson: toId,
                    toPerson: fromId
                )
                relationships.append(relationship2)
                
                print("✅ 创建配偶关系: \(persons[fromIndex].name) <-> \(persons[toIndex].name)")
                
            // 创建父子关系的代码部分
            case "parent-child":
                guard let parentIndex = rawRelation.parentIndex,
                      let childIndex = rawRelation.childIndex,
                      let parentId = personIndexToId[parentIndex],
                      let childId = personIndexToId[childIndex] else {
                    print("⚠️ 父子关系数据不完整")
                    continue
                }
                
                let parent = persons[parentIndex]
                
                // 创建父母指向子女的关系
                let parentToChildRel = Relationship(
                    type: .child,
                    fromPerson: parentId,
                    toPerson: childId
                )
                relationships.append(parentToChildRel)
                
                // 创建子女指向父母的关系
                let parentType: RelationType = parent.gender == .male ? .father : .mother
                let childToParentRel = Relationship(
                    type: parentType,
                    fromPerson: childId,
                    toPerson: parentId
                )
                relationships.append(childToParentRel)
                
                print("✅ 创建父子关系: \(parent.name) -> \(persons[childIndex].name) (\(parentType))")
                
            case "sibling":
                guard let person1Index = rawRelation.person1Index,
                      let person2Index = rawRelation.person2Index,
                      let person1Id = personIndexToId[person1Index],
                      let person2Id = personIndexToId[person2Index] else {
                    print("⚠️ 兄弟姐妹关系数据不完整")
                    continue
                }
                
                let person1 = persons[person1Index]
                let person2 = persons[person2Index]
                
                // 确定兄弟姐妹关系类型
                let siblingType1: RelationType
                let siblingType2: RelationType
                
                if person1.gender == .male {
                    siblingType1 = .brother
                } else {
                    siblingType1 = .sister
                }
                
                if person2.gender == .male {
                    siblingType2 = .brother
                } else {
                    siblingType2 = .sister
                }
                
                // 创建双向兄弟姐妹关系
                let relationship1 = Relationship(
                    type: siblingType1,
                    fromPerson: person2Id,
                    toPerson: person1Id
                )
                relationships.append(relationship1)
                
                let relationship2 = Relationship(
                    type: siblingType2,
                    fromPerson: person1Id,
                    toPerson: person2Id
                )
                relationships.append(relationship2)
                
                print("✅ 创建兄弟姐妹关系: \(person1.name) <-> \(person2.name)")
                
            default:
                print("⚠️ 未知关系类型: \(rawRelation.type)")
            }
        }
        
        // 自动推导兄弟姐妹关系
        print("🔄 开始自动推导兄弟姐妹关系...")
        let derivedSiblingRelations = deriveImplicitSiblingRelationships(persons: persons, relationships: relationships)
        relationships.append(contentsOf: derivedSiblingRelations)
        
        print("📊 关系统计: 总计 \(relationships.count) 条关系")
        
        return (family, persons, relationships)
    }
    
    // 自动推导隐含的兄弟姐妹关系
    private static func deriveImplicitSiblingRelationships(persons: [Person], relationships: [Relationship]) -> [Relationship] {
        print("🔍 开始推导隐含的兄弟姐妹关系...")
        
        var newRelationships: [Relationship] = []
        var parentToChildren: [UUID: Set<UUID>] = [:]
        
        // 构建父母到子女的映射
        for relationship in relationships where relationship.type == .child {
            let parentId = relationship.fromPerson
            let childId = relationship.toPerson
            
            if parentToChildren[parentId] == nil {
                parentToChildren[parentId] = []
            }
            parentToChildren[parentId]?.insert(childId)
        }
        
        // 检查每个父母的所有子女，创建兄弟姐妹关系
        for (_, children) in parentToChildren {
            let childrenArray = Array(children)
            
            for i in 0..<childrenArray.count {
                for j in (i+1)..<childrenArray.count {
                    let child1Id = childrenArray[i]
                    let child2Id = childrenArray[j]
                    
                    // 检查是否已经存在兄弟姐妹关系
                    let alreadyExists = relationships.contains { rel in
                        (rel.type == .brother || rel.type == .sister) &&
                        ((rel.fromPerson == child1Id && rel.toPerson == child2Id) ||
                         (rel.fromPerson == child2Id && rel.toPerson == child1Id))
                    }
                    
                    if !alreadyExists {
                        guard let child1 = persons.first(where: { $0.id == child1Id }),
                              let child2 = persons.first(where: { $0.id == child2Id }) else {
                            continue
                        }
                        
                        // 确定兄弟姐妹关系类型
                        let siblingType1: RelationType
                        let siblingType2: RelationType
                        
                        if child1.gender == .male {
                            siblingType1 = .brother
                        } else {
                            siblingType1 = .sister
                        }
                        
                        if child2.gender == .male {
                            siblingType2 = .brother
                        } else {
                            siblingType2 = .sister
                        }
                        
                        // 创建双向兄弟姐妹关系
                        let relationship1 = Relationship(
                            type: siblingType1,
                            fromPerson: child2Id,
                            toPerson: child1Id
                        )
                        newRelationships.append(relationship1)
                        
                        let relationship2 = Relationship(
                            type: siblingType2,
                            fromPerson: child1Id,
                            toPerson: child2Id
                        )
                        newRelationships.append(relationship2)
                        
                        print("✅ 自动推导兄弟姐妹关系: \(child1.name) <-> \(child2.name)")
                    }
                }
            }
        }
        
        print("📊 自动推导的兄弟姐妹关系数量: \(newRelationships.count)")
        return newRelationships
    }
    
    // 验证关系数据的完整性
    private static func validateRelationships(persons: [Person], relationships: [Relationship]) -> Bool {
        print("🔍 开始验证关系数据完整性...")
        
        var isValid = true
        
        // 检查每个关系的人物是否存在
        for (index, relationship) in relationships.enumerated() {
            let fromExists = persons.contains { $0.id == relationship.fromPerson }
            let toExists = persons.contains { $0.id == relationship.toPerson }
            
            if !fromExists || !toExists {
                print("⚠️ 关系 #\(index) 引用了不存在的人物: fromExists=\(fromExists), toExists=\(toExists)")
                isValid = false
            }
        }
        
        // 检查每个人是否有父母关系
        for person in persons where !person.isSelf {
            let hasFather = relationships.contains { 
                $0.type == .father && $0.fromPerson == person.id 
            }
            
            let hasMother = relationships.contains { 
                $0.type == .mother && $0.fromPerson == person.id 
            }
            
            if !hasFather && !hasMother {
                print("⚠️ 人物 \(person.name) 没有父母关系")
                // 这可能是合理的，所以不标记为错误
            }
        }
        
        print(isValid ? "✅ 关系数据验证通过" : "❌ 关系数据验证失败")
        return isValid
    }
}
