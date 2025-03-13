import Foundation

class MarriageRelationHandler: BaseRelationHandler {
    func findMarriageTitle(from source: Person, to target: Person) -> String? {
        // 查找配偶的父母称谓
        if let inLawTitle = findInLawTitle(from: source, to: target) {
            return inLawTitle
        }
        
        // 查找子女的配偶称谓
        if let childSpouseTitle = findChildSpouseTitle(from: source, to: target) {
            return childSpouseTitle
        }
        
        // 查找兄弟姐妹的配偶称谓
        if let siblingSpouseTitle = findSiblingSpouseTitle(from: source, to: target) {
            return siblingSpouseTitle
        }
        
        // 查找叔伯姑姨的配偶称谓
        if let uncleAuntSpouseTitle = findUncleAuntSpouseTitle(from: source, to: target) {
            return uncleAuntSpouseTitle
        }
        
        return nil
    }
    
    // 查找配偶的父母称谓
    private func findInLawTitle(from source: Person, to target: Person) -> String? {
        // 获取配偶
        let spouses = getSpouses(source.id)
        
        for spouse in spouses {
            // 检查配偶的父母
            if let spouseFather = getFather(spouse.id), spouseFather.id == target.id {
                return spouse.gender == .female ? 
                    RelationshipTitleMapper.getWifeParentTitle(gender: .male) : 
                    RelationshipTitleMapper.getHusbandParentTitle(gender: .male)
            }
            
            if let spouseMother = getMother(spouse.id), spouseMother.id == target.id {
                return spouse.gender == .female ? 
                    RelationshipTitleMapper.getWifeParentTitle(gender: .female) : 
                    RelationshipTitleMapper.getHusbandParentTitle(gender: .female)
            }
        }
        
        return nil
    }
    
    // 查找子女的配偶称谓
    private func findChildSpouseTitle(from source: Person, to target: Person) -> String? {
        // 获取子女
        let children = getChildren(source.id)
        
        for child in children {
            // 检查子女的配偶
            let childSpouses = getSpouses(child.id)
            if childSpouses.contains(where: { $0.id == target.id }) {
                return RelationshipTitleMapper.getChildSpouseTitle(gender: target.gender)
            }
        }
        
        return nil
    }
    
    // 查找兄弟姐妹的配偶称谓
    private func findSiblingSpouseTitle(from source: Person, to target: Person) -> String? {
        // 获取兄弟姐妹
        let siblings = getSiblings(source.id)
        
        for sibling in siblings {
            // 检查兄弟姐妹的配偶
            let siblingSpouses = getSpouses(sibling.id)
            if siblingSpouses.contains(where: { $0.id == target.id }) {
                if sibling.gender == .male {
                    // 兄弟的妻子
                    let isOlder = isOlder(sibling, than: source) ?? false
                    return RelationshipTitleMapper.getBrotherWifeTitle(isOlder: isOlder)
                } else {
                    // 姐妹的丈夫
                    let isOlder = isOlder(sibling, than: source) ?? false
                    return RelationshipTitleMapper.getSisterHusbandTitle(isOlder: isOlder)
                }
            }
        }
        
        return nil
    }
    
    // 查找叔伯姑姨的配偶称谓
    private func findUncleAuntSpouseTitle(from source: Person, to target: Person) -> String? {
        // 获取叔伯姑姨
        let unclesAunts = getUnclesAunts(source.id)
        
        for uncleAunt in unclesAunts {
            // 检查叔伯姑姨的配偶
            let spouses = getSpouses(uncleAunt.id)
            if spouses.contains(where: { $0.id == target.id }) {
                // 确定是父系还是母系
                if let father = getFather(source.id) {
                    let fatherSiblings = getSiblings(father.id)
                    if fatherSiblings.contains(where: { $0.id == uncleAunt.id }) {
                        // 父亲的兄弟姐妹的配偶
                        return RelationshipTitleMapper.getFatherSiblingSpouseTitle(siblingGender: uncleAunt.gender)
                    }
                }
                
                if let mother = getMother(source.id) {
                    let motherSiblings = getSiblings(mother.id)
                    if motherSiblings.contains(where: { $0.id == uncleAunt.id }) {
                        // 母亲的兄弟姐妹的配偶
                        return RelationshipTitleMapper.getMotherSiblingSpouseTitle(siblingGender: uncleAunt.gender)
                    }
                }
            }
        }
        
        return nil
    }
}
