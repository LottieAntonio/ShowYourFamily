import Foundation

class DirectRelationHandler: BaseRelationHandler {
    func findDirectTitle(from source: Person, to target: Person) -> String? {
        // 1. 检查是否是兄弟姐妹关系
        let siblingInfo = getSiblingInfo([])  // 传空数组，让它检查所有关系
        let (isValid, isPaternal) = determineSiblingType(
            source: source.id,
            target: target.id,
            fatherChildren: siblingInfo.fatherChildren,
            motherChildren: siblingInfo.motherChildren
        )
        
        if isValid {
            if let isOlder = isOlder(target, than: source) {
                if isPaternal == true {  // 同父异母
                    return target.gender == .male ?
                        (isOlder ? "同父异母哥哥" : "同父异母弟弟") :
                        (isOlder ? "同父异母姐姐" : "同父异母妹妹")
                } else if isPaternal == false {  // 同母异父
                    return target.gender == .male ?
                        (isOlder ? "同母异父哥哥" : "同母异父弟弟") :
                        (isOlder ? "同母异父姐姐" : "同母异父妹妹")
                } else {  // 同父同母
                    return target.gender == .male ?
                        (isOlder ? "哥哥" : "弟弟") :
                        (isOlder ? "姐姐" : "妹妹")
                }
            }
            return target.gender == .male ? "兄弟" : "姐妹"
        }
        
        // 2. 处理其他直接关系
        let directRelations = relationships.filter { relation in
            (relation.fromPerson == source.id && relation.toPerson == target.id) ||
            (relation.fromPerson == target.id && relation.toPerson == source.id)
        }
        
        // 2. 处理直接关系
        for relation in directRelations {
            // 确保关系方向正确
            let type: RelationType
            if relation.fromPerson == source.id {
                // 源是关系的起点，保持原有关系
                type = relation.type
            } else {
                // 如果关系方向相反，需要转换类型
                type = {
                    if relation.type == .father || relation.type == .mother {
                        // 如果对方是我的父/母，那我是对方的子
                        return .child
                    } else if relation.type == .child {
                        // 如果对方是我的子，那我是对方的父/母
                        return source.gender == .male ? .father : .mother
                    } else if relation.type == .spouse {
                        return .spouse
                    } else {
                        return relation.type
                    }
                }()
            }
            
            switch type {
            case .father: return "父亲"
            case .mother: return "母亲"
            case .child: return target.gender == .male ? "儿子" : "女儿"
            case .spouse: return target.gender == .male ? "丈夫" : "妻子"
            case .brother, .sister: break  // 忽略直接的兄弟姐妹关系，因为已经在前面处理过了
            }

        }
        
        // 3. 检查子女的配偶
        let childRelations = findRelations(from: source.id, ofType: .child)
        
        for childRelation in childRelations {
            if let childId = getOtherPerson(in: childRelation, from: source.id) {
                let spouses = relationships.filter { relation in
                    (relation.fromPerson == childId || relation.toPerson == childId) &&
                    relation.type == .spouse
                }
                
                for spouseRelation in spouses {
                    if let spouseId = getOtherPerson(in: spouseRelation, from: childId),
                       spouseId == target.id {
                        return target.gender == .male ? "女婿" : "儿媳"
                    }
                }
            }
        }
    
        // 检查目标是否是父母的配偶
        let parents = findRelations(from: source.id, ofType: .father) + 
                     findRelations(from: source.id, ofType: .mother)
        
        for parentRelation in parents {
            if let parentId = getOtherPerson(in: parentRelation, from: source.id) {
                // 查找父母的所有配偶
                let parentSpouses = relationships.filter { relation in
                    (relation.fromPerson == parentId || relation.toPerson == parentId) &&
                    relation.type == .spouse
                }
                
                for spouseRelation in parentSpouses {
                    if let spouseId = getOtherPerson(in: spouseRelation, from: parentId),
                       spouseId == target.id {
                        // 是父亲的配偶
                        if parentRelation.type == .father {
                            return "爸爸的配偶之一，可以叫阿姨"
                        }
                        // 是母亲的配偶
                        else if parentRelation.type == .mother {
                            return "妈妈的配偶之一，可以叫叔叔"
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func determineSiblingType(source: UUID, target: UUID, fatherChildren: [UUID: Set<UUID>], motherChildren: [UUID: Set<UUID>]) -> (isValid: Bool, isPaternal: Bool?) {
        let people = Set([source, target])
        
        // 检查是否存在共同的父亲和母亲
        let commonFathers = fatherChildren.filter { $0.value.isSuperset(of: people) }
        let commonMothers = motherChildren.filter { $0.value.isSuperset(of: people) }
        
        if commonFathers.count == 1 && commonMothers.count == 1 {
            // 同父同母
            return (true, nil)
        } else if commonFathers.count == 1 {
            // 同父异母
            return (true, true)
        } else if commonMothers.count == 1 {
            // 同母异父
            return (true, false)
        }
        
        return (false, nil)
    }
}

