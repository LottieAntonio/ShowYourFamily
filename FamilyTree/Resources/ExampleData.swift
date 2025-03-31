import Foundation
import UIKit

// 用于解析 JSON 的数据结构
private struct RawFamilyData: Codable {
    struct RawFamily: Codable {
        let name: String
        let description: String?
        let isDefault: Bool
        let badgeImageName: String?
    }
    
    // 修改 RawPerson 结构体，使用 String 类型接收日期，然后手动解析
    struct RawPerson: Codable {
        let firstName: String
        let lastName: String
        let gender: String
        let birthDate: String  // 改为 String 类型
        let birthOrder: Int
        let isSelf: Bool?
        let photoImageName: String?
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
            isDefault: rawData.family.isDefault,
            badgeImage: loadImage(named: rawData.family.badgeImageName)
        )
        
        var persons: [Person] = []
        var personIndexToId: [Int: UUID] = [:]
        
        // 创建人物
        for (index, rawPerson) in rawData.persons.enumerated() {
            let personId = UUID()
            personIndexToId[index] = personId
            
            // 创建基本 Person 对象
            var person = Person(
                id: personId,
                familyId: familyId,
                firstName: rawPerson.firstName,
                lastName: rawPerson.lastName,
                gender: rawPerson.gender == "male" ? .male : (rawPerson.gender == "female" ? .female : .other),
                isSelf: rawPerson.isSelf ?? false
            )
            
            // 手动解析日期
            let dateFormatter = ISO8601DateFormatter()
            if let birthDate = dateFormatter.date(from: rawPerson.birthDate) {
                // 使用 with 方法设置 birthDate
                person = person.with(birthDate: birthDate)
                print("成功解析日期: \(rawPerson.firstName) - \(rawPerson.birthDate) -> \(birthDate)")
                print("Person \(person.firstName) 的 birthDate 属性值: \(String(describing: person.birthDate))")
            } else {
                print("⚠️ 日期解析失败: \(rawPerson.firstName) - \(rawPerson.birthDate)")
                
                // 尝试修复常见的日期格式问题
                var fixedDateString = rawPerson.birthDate
                // 修复日期部分超过两位数的问题
                if fixedDateString.contains("-09-011T") {
                    fixedDateString = fixedDateString.replacingOccurrences(of: "-09-011T", with: "-09-01T")
                    print("尝试修复日期: \(fixedDateString)")
                    
                    if let fixedDate = dateFormatter.date(from: fixedDateString) {
                        person = person.with(birthDate: fixedDate)
                        print("修复后解析成功: \(rawPerson.firstName) - \(fixedDateString) -> \(fixedDate)")
                        
                        // 添加调试信息，确认修复后的日期已正确设置
                        print("Person \(person.firstName) 的修复后 birthDate 属性值: \(String(describing: person.birthDate))")
                    }
                }
            }
            
            // 加载照片（如果有）
            if let photoName = rawPerson.photoImageName {
                if let photoImage = loadImage(named: photoName) {
                    if let photoData = photoImage.pngData() {
                        // 修正参数顺序：birthDate 必须在 photo 之前
                        person = person.with(birthDate: person.birthDate, photo: photoData)
                    }
                }
            }
            
            // 再次确认 person 对象的 birthDate 是否正确
            print("最终 Person \(person.firstName) 的 birthDate: \(String(describing: person.birthDate))")
            
            persons.append(person)
        }
        
        var relationships: [Relationship] = []
        
        // 创建关系
        for (index, rawRelation) in rawData.relationships.enumerated() {
            
            switch rawRelation.type {
            case "spouse":
                guard let fromIndex = rawRelation.fromPersonIndex,
                      let toIndex = rawRelation.toPersonIndex,
                      let fromId = personIndexToId[fromIndex],
                      let toId = personIndexToId[toIndex] else {
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
                
                
            // 创建父子关系的代码部分
            case "parent-child":
                guard let parentIndex = rawRelation.parentIndex,
                      let childIndex = rawRelation.childIndex,
                      let parentId = personIndexToId[parentIndex],
                      let childId = personIndexToId[childIndex] else {
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
                
                
            case "sibling":
                guard let person1Index = rawRelation.person1Index,
                      let person2Index = rawRelation.person2Index,
                      let person1Id = personIndexToId[person1Index],
                      let person2Id = personIndexToId[person2Index] else {
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
                
                
                
            default:
                print("⚠️ 未知关系类型: \(rawRelation.type)")
            }
        }
        
        // 自动推导兄弟姐妹关系
        
        let derivedSiblingRelations = deriveImplicitSiblingRelationships(persons: persons, relationships: relationships)
        relationships.append(contentsOf: derivedSiblingRelations)
        
        
        
        return (family, persons, relationships)
    }
    
    // 添加一个辅助方法来加载图片
    private static func loadImage(named: String?) -> UIImage? {
        guard let imageName = named else { return nil }
        
        // 首先尝试从 Assets 加载
        if let image = UIImage(named: imageName) {
            return image
        }
        
        // 如果 Assets 中没有，尝试从 Bundle 加载
        if let path = Bundle.main.path(forResource: imageName, ofType: "jpg"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        
        if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        
        return nil
    }
    
    // 自动推导隐含的兄弟姐妹关系
    private static func deriveImplicitSiblingRelationships(persons: [Person], relationships: [Relationship]) -> [Relationship] {
        
        
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
                        
                        
                    }
                }
            }
        }
        
        
        return newRelationships
    }
    
    // 验证关系数据的完整性
    private static func validateRelationships(persons: [Person], relationships: [Relationship]) -> Bool {
        
        
        var isValid = true
        
        // 检查每个关系的人物是否存在
        for (index, relationship) in relationships.enumerated() {
            let fromExists = persons.contains { $0.id == relationship.fromPerson }
            let toExists = persons.contains { $0.id == relationship.toPerson }
            
            if !fromExists || !toExists {
                
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
            
           
        }
        
       
        return isValid
    }
}
