import Foundation

class BaseRelationHandler {
    let relationships: [Relationship]
    let persons: [Person]
    
    init(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
    }
    
    // 查找两个人之间的关系路径
    // 修改 findRelationPath 方法中的验证逻辑
    func findRelationPath(from source: UUID, to target: UUID) -> [Relationship] {
        guard source != target else { return [] }
        
        var visited = Set<UUID>()
        var queue = [(source, [Relationship]())]
        visited.insert(source)
        var shortestPath: [Relationship]?
        var shortestLength = Int.max
        var allPaths: [[Relationship]] = []
        
        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            
            if current == target {
                if validatePath(path) {
                    allPaths.append(path)
                    if path.count < shortestLength {
                        shortestPath = path
                        shortestLength = path.count
                    }
                }
                continue  // 不要立即返回，继续搜索其他路径
            }
            
            if path.count >= shortestLength {
                continue
            }
            
            let possibleRelations = relationships.filter { relation in
                relation.fromPerson == current || relation.toPerson == current
            }
            
            // 移除关系排序，平等对待所有关系类型
            for relation in possibleRelations {
                let nextPerson = relation.fromPerson == current ? relation.toPerson : relation.fromPerson
                
                if !visited.contains(nextPerson) {
                    visited.insert(nextPerson)
                    queue.append((nextPerson, path + [relation]))  // 所有关系都添加到队列尾部
                }
            }
        }
        
        return shortestPath ?? []
    }
    
    private func validatePath(_ path: [Relationship]) -> Bool {
        let relationTypes = Set(path.map { $0.type })
        
        if relationTypes.allSatisfy({ $0 == .father || $0 == .mother }) {
            let ancestors = getAncestorInfo(path)
            var currentId: UUID?
            for (person, _) in ancestors {
                if currentId == nil {
                    currentId = person
                } else if person != currentId {
                    return false
                }
                currentId = person
            }
            return true
        }
        
        if (relationTypes.contains(.father) || relationTypes.contains(.mother)) &&
            (relationTypes.contains(.brother) || relationTypes.contains(.sister)) {
            let relatives = getUncleAuntInfo(path)
            
            if relatives.isEmpty {
                return false
            }
            
            // 检查第一个关系是否是父母
            guard let firstRelative = relatives.first,
                  firstRelative.type == .father || firstRelative.type == .mother else {
                return false
            }
            
            // 检查是否包含至少一个兄弟姐妹
            let hasSibling = relatives.contains { relative in
                relative.type == .brother || relative.type == .sister
            }
            
            return hasSibling
        
            var currentId: UUID?
            for (person, type) in relatives {
                if currentId == nil {
                    if type != .father && type != .mother {
                        return false
                    }
                    currentId = person
                    continue
                }
                
                if person != currentId {
                    return false
                }
                
                if type == .brother || type == .sister {
                    return true
                }
                
                currentId = person
            }
            
            return false
        }
        
        if relationTypes.contains(.brother) || relationTypes.contains(.sister) {
            // 检查路径的连续性
            var currentId: UUID?
            for relation in path {
                if currentId == nil {
                    currentId = relation.fromPerson
                    continue
                }
                
                if relation.fromPerson != currentId && relation.toPerson != currentId {
                    return false
                }
                
                currentId = relation.fromPerson == currentId ? relation.toPerson : relation.fromPerson
            }
            
            // 验证兄弟姐妹关系
            let siblingInfo = getSiblingInfo([])
            for i in 0..<path.count {
                if path[i].type == .brother || path[i].type == .sister {
                    let source = path[i].fromPerson
                    let target = path[i].toPerson
                    if !validateSiblingRelation(source: source, target: target,
                                              fatherChildren: siblingInfo.fatherChildren,
                                              motherChildren: siblingInfo.motherChildren) {
                        return false
                    }
                }
            }
            return true
        }
        
        if relationTypes.contains(.father) || relationTypes.contains(.mother) || relationTypes.contains(.child) {
            var currentId: UUID?
            for relation in path {
                if currentId == nil {
                    currentId = relation.fromPerson
                    continue
                }
                
                if relation.fromPerson != currentId && relation.toPerson != currentId {
                    return false
                }
                
                currentId = relation.fromPerson == currentId ? relation.toPerson : relation.fromPerson
            }
            return true
        }
        
        if relationTypes.contains(.spouse) {
            return true
        }
        
        return false
    }
    
    func validateSiblingRelation(source: UUID, target: UUID,
                                          fatherChildren: [UUID: Set<UUID>],
                                          motherChildren: [UUID: Set<UUID>]) -> Bool {
           let people = Set([source, target])
           
        // 检查是否存在共同的父亲或母亲
           for (_, children) in fatherChildren {
               if children.contains(source) && children.contains(target) {
                   return true
               }
           }
           
           for (_, children) in motherChildren {
               if children.contains(source) && children.contains(target) {
                   return true
               }
           }
           
           return false
       }
   
    private func validateAncestorPath(_ path: [Relationship]) -> Bool {
        // 检查是否所有关系都是父母关系
        guard path.allSatisfy({ $0.type == .father || $0.type == .mother }) else { return false }
        
        // 检查方向是否一致（应该都是向上追溯）
        var currentId: UUID?
        for relation in path {
            if currentId == nil {
                currentId = relation.toPerson
            } else if currentId != relation.toPerson {
                return false
            }
            currentId = relation.fromPerson
        }
        
        return true
    }
    
    private func isSiblingPath(_ path: [Relationship]) -> Bool {
        // 获取路径中的所有人
        var people = Set<UUID>()
        for relation in path {
            people.insert(relation.fromPerson)
            people.insert(relation.toPerson)
        }
        
        // 检查是否存在共同的父亲
        let fatherRelations = relationships.filter { relation in
            relation.type == .father && people.contains(relation.toPerson)
        }
        
        // 如果有共同的父亲，这是一个有效的兄弟姐妹路径
        let fathers = Set(fatherRelations.map { $0.fromPerson })
        if fathers.count == 1 {
            return true
        }
        
        return false
    }
    
    // 获取祖先路径信息
    func getAncestorInfo(_ path: [Relationship]) -> [(person: UUID, type: RelationType)] {
        var ancestors: [(person: UUID, type: RelationType)] = []
        var currentId: UUID?
        
        for relation in path {
            if currentId == nil {
                currentId = relation.fromPerson
                // 记录第一个祖先
                ancestors.append((relation.toPerson, relation.type))
            } else if relation.fromPerson == currentId {
                // 继续向上追溯
                currentId = relation.toPerson
                ancestors.append((relation.toPerson, relation.type))
            }
        }
        
        return ancestors
    }
    
    // 获取旁系亲属路径信息（叔伯姑舅姨）
    // 添加一个私有方法来处理父母关系的映射
    private func createParentMaps() -> (personsMap: [UUID: Person],
                                      childToParentMap: [UUID: [Relationship]],
                                      parentToChildMap: [UUID: [Relationship]]) {
        let personsMap = Dictionary(uniqueKeysWithValues: persons.map { ($0.id, $0) })
        
        // 预先筛选出所有父母关系
        let allParentRelations = relationships.filter { relation in
            relation.type == .father || relation.type == .mother
        }
        
        // 创建父母关系的快速查找映射
        let childToParentMap = Dictionary(grouping: allParentRelations) { relation in
            relation.fromPerson
        }
        
        let parentToChildMap = Dictionary(grouping: allParentRelations) { relation in
            relation.toPerson
        }
        
        return (personsMap, childToParentMap, parentToChildMap)
    }
    
    // 修改 getUncleAuntInfo 方法
    private func getUncleAuntInfo(_ path: [Relationship]) -> [(person: UUID, type: RelationType)] {
        var relatives = [(person: UUID, type: RelationType)]()
        let (personsMap, childToParentMap, parentToChildMap) = createParentMaps()
        
        let peopleInPath = Set(path.flatMap { [$0.fromPerson, $0.toPerson] })
        
        let parentRelations = relationships.filter { relation in
            guard peopleInPath.contains(relation.fromPerson) || peopleInPath.contains(relation.toPerson) else { return false }
            guard relation.type == .father || relation.type == .mother else { return false }
            
            if let person = personsMap[relation.toPerson] {
                return (relation.type == .mother && person.gender == .female) ||
                       (relation.type == .father && person.gender == .male)
            }
            return false
        }
        
        for parentRelation in parentRelations {
            guard let parent = personsMap[parentRelation.toPerson] else { continue }
            
            relatives.append((parentRelation.toPerson, parentRelation.type))
            
            if let grandParentRelations = childToParentMap[parentRelation.toPerson] {
                for grandParentRelation in grandParentRelations {
                    let grandParentId = grandParentRelation.toPerson
                    
                    if let uncleAunts = parentToChildMap[grandParentId] {
                        for uncleAunt in uncleAunts {
                            let uncleAuntId = uncleAunt.fromPerson
                            if uncleAuntId != parentRelation.toPerson,
                               let sibling = personsMap[uncleAuntId] {
                                let correctType: RelationType = sibling.gender == .male ? .brother : .sister
                                relatives.append((uncleAuntId, correctType))
                            }
                        }
                    }
                }
            }
        }
        
        return relatives
    }
    
  
    // 判断年龄大小
    func isOlder(_ person1: Person, than person2: Person) -> Bool? {
        guard let birth1 = person1.birthDate,
              let birth2 = person2.birthDate else {
            return nil
        }
        return birth1 < birth2
    }
    
    // 获取关系的另一端的人
    func getOtherPerson(in relation: Relationship, from personId: UUID) -> UUID? {  // 修改返回类型为可选
        guard relation.fromPerson == personId || relation.toPerson == personId else { return nil }
        return relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
    }
    
    // 获取特定类型的关系
    func findRelations(from personId: UUID, ofType type: RelationType) -> [Relationship] {
        guard !relationships.isEmpty else { return [] }
        return relationships.filter { relation in
            relation.type == type && 
            (relation.fromPerson == personId || relation.toPerson == personId)
        }
    }
    
    // 修改返回类型，返回父母的子女集合
    func getSiblingInfo(_ path: [Relationship]) -> (fatherChildren: [UUID: Set<UUID>], motherChildren: [UUID: Set<UUID>]) {
        let (personsMap, childToParentMap, parentToChildMap) = createParentMaps()
        var fatherChildren: [UUID: Set<UUID>] = [:]
        var motherChildren: [UUID: Set<UUID>] = [:]
        
        // 如果传入了父母关系，就找到这个父母的父母（祖父母）的所有子女
        if let parentRelation = path.first {
            let parentId = parentRelation.toPerson
            // 找到父母的父母（祖父母）
            if let grandParentRelations = childToParentMap[parentId] {
                for grandParentRelation in grandParentRelations {
                    let grandParentId = grandParentRelation.toPerson
                    guard let grandParent = personsMap[grandParentId] else { continue }
                    
                    // 找到祖父母的所有子女（即父母的兄弟姐妹）
                    if let parentSiblings = parentToChildMap[grandParentId] {
                        let children = Set(parentSiblings.map { $0.fromPerson })
                        if grandParent.gender == .male {
                            fatherChildren[grandParentId] = children
                        } else {
                            motherChildren[grandParentId] = children
                        }
                    }
                }
            }
        } else {
            // 如果没有传入父母关系，返回所有父母的子女集合
            for (parentId, relations) in parentToChildMap {
                guard let parent = personsMap[parentId] else { continue }
                let children = Set(relations.map { $0.fromPerson })
                if parent.gender == .male {
                    fatherChildren[parentId] = children
                } else {
                    motherChildren[parentId] = children
                }
            }
        }
        
        return (fatherChildren, motherChildren)
    }
   
}
