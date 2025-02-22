import Foundation

class MarriageRelationHandler: BaseRelationHandler {
    func findMarriageTitle(from source: Person, to target: Person) -> String? {
        guard source.id != target.id else { return nil }
        
        // 1. 检查目标是否是兄弟姐妹的配偶
        let siblingRelations = findRelations(from: source.id, ofType: .brother) + 
                             findRelations(from: source.id, ofType: .sister)
        
        // 先获取所有兄弟姐妹的ID
        var siblingIds = Set<UUID>()
        for relation in siblingRelations {
            if let siblingId = getOtherPerson(in: relation, from: source.id) {
                siblingIds.insert(siblingId)
            }
        }
        
        // 检查目标是否是兄弟姐妹的配偶
        for siblingId in siblingIds {
            let spouses = relationships.filter { relation in
                (relation.fromPerson == siblingId || relation.toPerson == siblingId) &&
                relation.type == .spouse
            }
            
            for spouseRelation in spouses {
                if let spouseId = getOtherPerson(in: spouseRelation, from: siblingId),
                   spouseId == target.id {
                    let sibling = persons.first { $0.id == siblingId }
                    if let sibling = sibling,
                       let isOlder = isOlder(sibling, than: source) {
                        if sibling.gender == .male {
                            return isOlder ? "嫂子" : "弟妹"
                        } else {
                            return isOlder ? "姐夫" : "妹夫"
                        }
                    }
                }
            }
        }
        
        // 2. 检查配偶相关的称谓
        let spouseRelations = findRelations(from: source.id, ofType: .spouse)
        guard !spouseRelations.isEmpty else { return nil }
        
        for spouseRelation in spouseRelations {
            guard let spouseId = getOtherPerson(in: spouseRelation, from: source.id) else { continue }
            
            // 目标是配偶的父母，只检查亲生父母关系
            let spouseParents = relationships.filter { relation in
                (relation.fromPerson == target.id && relation.toPerson == spouseId && relation.type == .child) ||
                (relation.fromPerson == spouseId && relation.toPerson == target.id && 
                 (relation.type == .father || relation.type == .mother))
            }
            
            for parentRelation in spouseParents {
                if let parentId = getOtherPerson(in: parentRelation, from: spouseId),
                   parentId == target.id {
                    if source.gender == .male {
                        return target.gender == .male ? "岳父" : "岳母"
                    } else {
                        return target.gender == .male ? "公公" : "婆婆"
                    }
                }
            }
            
            // 目标是配偶的兄弟姐妹
            let spouseParentRelations = relationships.filter { relation in
                (relation.fromPerson == spouseId && relation.type == .child) ||
                (relation.toPerson == spouseId && (relation.type == .father || relation.type == .mother))
            }
            
            // 2. 通过父母找到所有子女（即配偶的兄弟姐妹）
            for parentRelation in spouseParentRelations {
                if let parentId = getOtherPerson(in: parentRelation, from: spouseId) {
                    let siblingInfo = getSiblingInfo([parentRelation])
                    
                    // 检查父方兄弟姐妹
                    for (_, children) in siblingInfo.fatherChildren {
                        for childId in children {
                            if childId != spouseId && childId == target.id {
                                if let isOlder = isOlder(target, than: source) {
                                    if source.gender == .male {
                                        if target.gender == .male {
                                            return isOlder ? "大舅子" : "小舅子"
                                        } else {
                                            return isOlder ? "大姨子" : "小姨子"
                                        }
                                    } else {
                                        if target.gender == .male {
                                            return isOlder ? "大叔子" : "小叔子"
                                        } else {
                                            return isOlder ? "大姑子" : "小姑子"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 检查母方兄弟姐妹
                    for (_, children) in siblingInfo.motherChildren {
                        for childId in children {
                            if childId != spouseId && childId == target.id {
                                print("✅ 找到匹配的兄弟姐妹！")
                                if let isOlder = isOlder(target, than: source) {
                                    if source.gender == .male {
                                        if target.gender == .male {
                                            return isOlder ? "大舅子" : "小舅子"
                                        } else {
                                            return isOlder ? "大姨子" : "小姨子"
                                        }
                                    } else {
                                        if target.gender == .male {
                                            return isOlder ? "大叔子" : "小叔子"
                                        } else {
                                            return isOlder ? "大姑子" : "小姑子"
                                        }
                                    }
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
