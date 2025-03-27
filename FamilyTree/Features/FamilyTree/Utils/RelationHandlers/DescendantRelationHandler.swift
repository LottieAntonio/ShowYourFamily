import Foundation

class DescendantRelationHandler: BaseRelationHandler {
    func findDescendantTitle(from source: Person, to target: Person) -> String? {
        
        // 查找孙子女称谓
        if let grandchildTitle = findGrandchildTitle(from: source, to: target) {
            return grandchildTitle
        }
        
        // 查找曾孙子女称谓
        if let greatGrandchildTitle = findGreatGrandchildTitle(from: source, to: target) {
            return greatGrandchildTitle
        }
        
        return nil
    }
    
    // 查找孙子女称谓
    private func findGrandchildTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let grandchildren = getGrandchildren(source.id)
        
        if grandchildren.contains(where: { $0.id == target.id }) {
            // 确定是通过儿子还是女儿
            let children = getChildren(source.id)
            
            for child in children {
                let childChildren = getChildren(child.id)
                if childChildren.contains(where: { $0.id == target.id }) {
                    // 找到了中间的子女
                    if child.gender == .male {
                        // 通过儿子的子女
                        return RelationshipTitleMapper.getPaternalGrandchildTitle(gender: target.gender)
                    } else {
                        // 通过女儿的子女
                        return RelationshipTitleMapper.getMaternalGrandchildTitle(gender: target.gender)
                    }
                }
            }
            
            // 如果无法确定中间关系，返回默认称谓
            return target.gender == .male ? "孙子" : "孙女"
        }
        
        return nil
    }
    
    // 查找曾孙子女称谓
    private func findGreatGrandchildTitle(from source: Person, to target: Person) -> String? {
        // 检查是否是曾孙辈
        let children = getChildren(source.id)
        
        for child in children {
            let grandchildren = getGrandchildren(child.id)
            if grandchildren.contains(where: { $0.id == target.id }) {
                // 确定是否通过女儿
                let isMaternal = child.gender == .female
                return RelationshipTitleMapper.getGreatGrandchildTitle(gender: target.gender, isMaternal: isMaternal)
            }
        }
        
        return nil
    }
}
