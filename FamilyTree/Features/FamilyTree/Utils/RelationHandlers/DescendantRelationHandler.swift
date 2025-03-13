import Foundation

class DescendantRelationHandler: BaseRelationHandler {
    func findDescendantTitle(from source: Person, to target: Person) -> String? {
        print("🔍 DescendantRelationHandler 开始查找关系: \(source.name) -> \(target.name)")
        
        // 查找孙子女称谓
        if let grandchildTitle = findGrandchildTitle(from: source, to: target) {
            print("👶 找到孙辈关系: \(grandchildTitle)")
            return grandchildTitle
        }
        
        // 查找曾孙子女称谓
        if let greatGrandchildTitle = findGreatGrandchildTitle(from: source, to: target) {
            print("👶 找到曾孙辈关系: \(greatGrandchildTitle)")
            return greatGrandchildTitle
        }
        
        print("❌ DescendantRelationHandler 未找到后代关系")
        return nil
    }
    
    // 查找孙子女称谓
    private func findGrandchildTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let grandchildren = getGrandchildren(source.id)
        
        // 打印调试信息
        print("🔍 检查 \(target.name) 是否是 \(source.name) 的孙辈，找到孙辈数量: \(grandchildren.count)")
        for grandchild in grandchildren {
            print("👶 孙辈: \(grandchild.name)")
        }
        
        if grandchildren.contains(where: { $0.id == target.id }) {
            print("✅ 确认 \(target.name) 是 \(source.name) 的孙辈")
            
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
        } else {
            print("❌ \(target.name) 不是 \(source.name) 的孙辈")
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
                print("✅ 确认 \(target.name) 是 \(source.name) 的曾孙辈")
                // 确定是否通过女儿
                let isMaternal = child.gender == .female
                return RelationshipTitleMapper.getGreatGrandchildTitle(gender: target.gender, isMaternal: isMaternal)
            }
        }
        
        return nil
    }
}
