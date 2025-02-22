import Foundation

class CollateralRelationHandler: BaseRelationHandler {
    func findCollateralTitle(from source: Person, to target: Person) -> String? {
        let path = findRelationPath(from: source.id, to: target.id)
        guard !path.isEmpty else { return nil }
        
        // 检查是否存在亲生关系路径
        let hasBloodRelation = path.allSatisfy { relation in
            switch relation.type {
            case .father, .mother, .child, .brother, .sister:
                return true
            default:
                return false
            }
        }
        
        guard hasBloodRelation else { return nil }
        
        // 先检查是否是兄弟姐妹的子女
        let siblingInfo = getSiblingInfo([])
        let siblingRelations = findRelations(from: source.id, ofType: .brother) + 
                             findRelations(from: source.id, ofType: .sister)
        
        // 获取所有兄弟姐妹的ID
        var siblingIds = Set<UUID>()
        for relation in siblingRelations {
            if let siblingId = getOtherPerson(in: relation, from: source.id) {
                siblingIds.insert(siblingId)
            }
        }
        
        // 检查目标是否是兄弟姐妹的子女
        for (parentId, children) in siblingInfo.fatherChildren {
            if siblingIds.contains(parentId) && children.contains(target.id) {
                return findNephewTitle(from: source, to: target, isFromBrother: true)
            }
        }
        for (parentId, children) in siblingInfo.motherChildren {
            if siblingIds.contains(parentId) && children.contains(target.id) {
                return findNephewTitle(from: source, to: target, isFromBrother: false)
            }
        }
        
        // 如果不是侄子侄女，再判断其他关系
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
    

}


