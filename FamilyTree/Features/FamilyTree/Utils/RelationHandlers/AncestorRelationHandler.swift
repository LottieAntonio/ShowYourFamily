import Foundation

class AncestorRelationHandler: BaseRelationHandler {
    func findAncestorTitle(from source: Person, to target: Person) -> String? {
        let path = findRelationPath(from: source.id, to: target.id)
        guard !path.isEmpty else { 
            // 如果没有直接路径，尝试查找继祖父母关系
            return findGrandparentSpouseTitle(from: source, to: target)
        }
        
        var currentId = source.id
        var generation = 0
        var isPaternal = true
        var foundFirstParent = false
        
        for relation in path {
            if relation.fromPerson == currentId && (relation.type == .father || relation.type == .mother) {
                if !foundFirstParent {
                    foundFirstParent = true
                    isPaternal = relation.type == .father
                }
                currentId = relation.toPerson
                generation += 1
            }
            else if relation.toPerson == currentId && relation.type == .child {
                if !foundFirstParent {
                    foundFirstParent = true
                    isPaternal = true
                }
                currentId = relation.fromPerson
                generation += 1
            }
        }
        
        guard currentId == target.id else { return nil }
        
        switch generation {
        case 2:
            return target.gender == .male ? 
                (isPaternal ? "爷爷" : "外公") :
                (isPaternal ? "奶奶" : "外婆")
        case 3:
            if isPaternal {
                // 父亲这边的祖父母
                if let father = getFather(of: source),
                   let fatherParentRelation = findRelations(from: father.id, ofType: .father)
                        .first ?? findRelations(from: father.id, ofType: .mother).first,
                   let fatherParentId = getOtherPerson(in: fatherParentRelation, from: father.id),
                   fatherParentId == target.id {
                    // 父亲的父母（曾祖父母）
                    return target.gender == .male ? "曾祖父" : "曾祖母"
                } else {
                    // 父亲的外公外婆（曾外祖父母）
                    return target.gender == .male ? "曾外祖父" : "曾外祖母"
                }
            } else {
                // 母亲这边的祖父母
                if let mother = getMother(of: source),
                   let motherParentRelation = findRelations(from: mother.id, ofType: .father)
                        .first ?? findRelations(from: mother.id, ofType: .mother).first,
                   let motherParentId = getOtherPerson(in: motherParentRelation, from: mother.id),
                   motherParentId == target.id {
                    // 母亲的父母（外曾祖父母）
                    return target.gender == .male ? "外曾祖父" : "外曾祖母"
                } else {
                    // 母亲的外公外婆（外曾外祖父母）
                    return target.gender == .male ? "外曾外祖父" : "外曾外祖母"
                }
            }
        case 4:
            return target.gender == .male ? "高祖父" : "高祖母"
        default:
            if generation > 4 {
                let prefix = String(repeating: "高", count: generation - 3)
                return target.gender == .male ? "\(prefix)祖父" : "\(prefix)祖母"
            }
            return nil
        }
    }

    private func findGrandparentSpouseTitle(from source: Person, to target: Person) -> String? {
        let parents = findRelations(from: source.id, ofType: .father) + 
                     findRelations(from: source.id, ofType: .mother)
        
        for parentRelation in parents {
            if let parentId = getOtherPerson(in: parentRelation, from: source.id) {
                // 先获取亲生祖父母
                let grandparents = findRelations(from: parentId, ofType: .father) + 
                                 findRelations(from: parentId, ofType: .mother)
                
                for grandparentRelation in grandparents {
                    if let grandparentId = getOtherPerson(in: grandparentRelation, from: parentId) {
                        // 确保这个祖父母不是目标人物（避免将亲生祖父母判断为继祖父母）
                        guard grandparentId != target.id else { continue }
                        
                        // 只查找这个祖父母的配偶
                        let spouses = relationships.filter { relation in
                            (relation.fromPerson == grandparentId || relation.toPerson == grandparentId) &&
                            relation.type == .spouse
                        }
                        
                        for spouseRelation in spouses {
                            if let spouseId = getOtherPerson(in: spouseRelation, from: grandparentId),
                               spouseId == target.id {
                                let isPaternal = parentRelation.type == .father
                                
                                if isPaternal {
                                    return target.gender == .male ? "继祖父" : "继祖母"
                                } else {
                                    return target.gender == .male ? "继外祖父" : "继外祖母"
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
