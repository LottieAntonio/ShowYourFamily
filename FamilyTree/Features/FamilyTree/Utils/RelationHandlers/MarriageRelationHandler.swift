import Foundation

class MarriageRelationHandler: BaseRelationHandler {
    func findMarriageTitle(from source: Person, to target: Person) -> String? {
        // 添加安全检查
        guard source.id != target.id else { return nil }
        
        // 通过配偶找关系
        let spouseRelations = findRelations(from: source.id, ofType: .spouse)
        guard !spouseRelations.isEmpty else { return nil }
        
        for spouseRelation in spouseRelations {
            guard let spouseId = getOtherPerson(in: spouseRelation, from: source.id) else { continue }
            
            // 目标是配偶的父母
            let spouseParents = findRelations(from: spouseId, ofType: .father) +
                findRelations(from: spouseId, ofType: .mother)
            
            for parentRelation in spouseParents {
                guard let parentId = getOtherPerson(in: parentRelation, from: spouseId) else { continue }
                if parentId == target.id {
                    if source.gender == .male {
                        return target.gender == .male ? "岳父" : "岳母"
                    } else {
                        return target.gender == .male ? "公公" : "婆婆"
                    }
                }
            }
            
            // 目标是配偶的兄弟姐妹
            let spouseSiblings = findRelations(from: spouseId, ofType: .brother) +
                findRelations(from: spouseId, ofType: .sister)
            
            for siblingRelation in spouseSiblings {
                let siblingId = getOtherPerson(in: siblingRelation, from: spouseId)
                if siblingId == target.id {
                    if let isOlder = isOlder(target, than: source) {
                        if target.gender == .male {
                            return isOlder ? "大舅子" : "小舅子"
                        } else {
                            return isOlder ? "大姑子" : "小姑子"
                        }
                    }
                }
            }
        }
        
        return nil
    }
}