import Foundation

class CollateralRelationHandler: BaseRelationHandler {
    func findCollateralTitle(from source: Person, to target: Person) -> String? {
        let path = findRelationPath(from: source.id, to: target.id)
        
        guard !path.isEmpty else { return nil }
        
        let commonAncestorPath = findCommonAncestor(in: path)
        let isPaternal = commonAncestorPath.first?.type == .father
        let generationDiff = calculateGenerationDifference(in: path)
        
        if generationDiff == 0 {
            if let isOlder = isOlder(target, than: source) {
                if target.gender == .male {
                    return isPaternal ? 
                        (isOlder ? "堂兄" : "堂弟") :
                        (isOlder ? "表兄" : "表弟")
                } else {
                    return isPaternal ?
                        (isOlder ? "堂姐" : "堂妹") :
                        (isOlder ? "表姐" : "表妹")
                }
            }
        } else if generationDiff == 1 {
            if isPaternal {
                if target.gender == .male {
                    if let father = getFather(of: source) {
                        let siblingInfo = getSiblingInfo([])
                        if validateSiblingRelation(source: father.id, target: target.id,
                                                 fatherChildren: siblingInfo.fatherChildren,
                                                 motherChildren: siblingInfo.motherChildren) {
                            if let isOlderThanFather = isOlder(target, than: father) {
                                return isOlderThanFather ? "伯父" : "叔父"
                            }
                            return "叔父"
                        }
                    }
                } else {
                    if let father = getFather(of: source) {
                        let siblingInfo = getSiblingInfo([])
                        if validateSiblingRelation(source: father.id, target: target.id,
                                                 fatherChildren: siblingInfo.fatherChildren,
                                                 motherChildren: siblingInfo.motherChildren) {
                            return "姑妈"
                        }
                    }
                }
            } else {
                if let mother = getMother(of: source) {
                    let siblingInfo = getSiblingInfo([])
                    if validateSiblingRelation(source: mother.id, target: target.id,
                                             fatherChildren: siblingInfo.fatherChildren,
                                             motherChildren: siblingInfo.motherChildren) {
                        return target.gender == .male ? "舅舅" : "姨妈"
                    }
                }
            }
        }
        
        return nil
    }
    
    // 添加获取母亲的辅助方法
    private func getMother(of person: Person) -> Person? {
        let motherRelation = relationships.first { relation in
            (relation.toPerson == person.id || relation.fromPerson == person.id) && 
            relation.type == .mother
        }
        
        if let relation = motherRelation {
            let motherId = relation.toPerson == person.id ? relation.fromPerson : relation.toPerson
            return persons.first(where: { $0.id == motherId })
        }
        return nil
    }
    
    private func findSiblingRelations(for personId: UUID) -> [Relationship] {
        return relationships.filter { relation in
            (relation.fromPerson == personId || relation.toPerson == personId) &&
            (relation.type == .brother || relation.type == .sister)
        }
    }
    
    private func findCommonAncestor(in path: [Relationship]) -> [Relationship] {
        var parentPath: [Relationship] = []
        var foundBranch = false
        var currentId: UUID?
        
        for relation in path {
            if currentId == nil {
                currentId = relation.fromPerson
            }
            
            if relation.type == .father || relation.type == .mother {
                if !foundBranch && relation.fromPerson == currentId {
                    parentPath.append(relation)
                    currentId = relation.toPerson
                }
            } else if relation.type == .brother || relation.type == .sister {
                foundBranch = true
            } else if relation.type == .child {
                foundBranch = true
            }
        }
        
        if parentPath.isEmpty {
            currentId = nil
            for relation in path.reversed() {
                if currentId == nil {
                    currentId = relation.toPerson
                }
                
                if (relation.type == .father || relation.type == .mother) && 
                   relation.toPerson == currentId {
                    parentPath.insert(relation, at: 0)
                    currentId = relation.fromPerson
                }
            }
        }
        
        return parentPath
    }
    
    private func calculateGenerationDifference(in path: [Relationship]) -> Int {
        var upCount = 0
        var downCount = 0
        var foundCommonAncestor = false
        var lastParentType: RelationType?
        var commonAncestorId: UUID?
        
        for relation in path {
            if relation.type == .father || relation.type == .mother {
                if !foundCommonAncestor {
                    upCount += 1
                    lastParentType = relation.type
                    commonAncestorId = relation.toPerson
                }
                
                if relation.toPerson == commonAncestorId {
                    foundCommonAncestor = true
                }
            } else if relation.type == .brother || relation.type == .sister {
                foundCommonAncestor = true
            }
        }
        
        if foundCommonAncestor {
            var targetPath = false
            for relation in path.reversed() {
                if relation.type == .father || relation.type == .mother {
                    if relation.toPerson == commonAncestorId {
                        targetPath = true
                        continue
                    }
                    if targetPath {
                        downCount += 1
                    }
                }
            }
        }
        
        return upCount - downCount
    }
    
    private func getFather(of person: Person) -> Person? {
        let fatherRelation = relationships.first { relation in
            (relation.toPerson == person.id || relation.fromPerson == person.id) && 
            relation.type == .father
        }
        
        if let relation = fatherRelation {
            let fatherId = relation.toPerson == person.id ? relation.fromPerson : relation.toPerson
            return persons.first(where: { $0.id == fatherId })
        }
        return nil
    }
}


