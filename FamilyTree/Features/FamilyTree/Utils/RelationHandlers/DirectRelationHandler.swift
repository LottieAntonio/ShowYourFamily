import Foundation

class DirectRelationHandler: BaseRelationHandler {
    func findDirectTitle(from source: Person, to target: Person) -> String? {
        // 添加调试日志
        print("🔎 DirectRelationHandler 开始查找关系: \(source.name) -> \(target.name)")
        
        // 检查父母关系
        if let parentTitle = findParentTitle(from: source, to: target) {
            print("👨‍👩‍👧 找到父母关系: \(parentTitle)")
            return parentTitle
        }
        
        // 检查子女关系
        if let childTitle = findChildTitle(from: source, to: target) {
            print("👶 找到子女关系: \(childTitle)")
            return childTitle
        }
        
        // 检查兄弟姐妹关系
        if let siblingTitle = findSiblingTitle(from: source, to: target) {
            print("👫 找到兄弟姐妹关系: \(siblingTitle)")
            return siblingTitle
        }
        
        // 检查配偶关系
        if let spouseTitle = findSpouseTitle(from: source, to: target) {
            print("💑 找到配偶关系: \(spouseTitle)")
            return spouseTitle
        }
        
        print("❌ DirectRelationHandler 未找到直接关系")
        return nil
    }
    
    // 查找父母称谓
    private func findParentTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询而非路径查找
        if let father = getFather(source.id), father.id == target.id {
            return RelationshipTitleMapper.getParentTitle(gender: .male)
        }
        
        if let mother = getMother(source.id), mother.id == target.id {
            return RelationshipTitleMapper.getParentTitle(gender: .female)
        }
        
        // 直接检查关系数据
        let parentRelations = relationships.filter { 
            ($0.fromPerson == target.id && $0.toPerson == source.id) && 
            ($0.type == .father || $0.type == .mother || $0.type == .parent)
        }
        
        if let parentRelation = parentRelations.first {
            if parentRelation.type == .father || 
               (parentRelation.type == .parent && target.gender == .male) {
                return RelationshipTitleMapper.getParentTitle(gender: .male)
            } else if parentRelation.type == .mother || 
                    (parentRelation.type == .parent && target.gender == .female) {
                return RelationshipTitleMapper.getParentTitle(gender: .female)
            }
        }
        
        // 检查子女关系的反向
        let childRelations = relationships.filter { 
            ($0.fromPerson == target.id && $0.toPerson == source.id && $0.type == .child) ||
            ($0.fromPerson == source.id && $0.toPerson == target.id && $0.type == .child)
        }
        
        if let childRelation = childRelations.first {
            if childRelation.fromPerson == target.id {
                // 对方是自己的父母
                return RelationshipTitleMapper.getParentTitle(gender: target.gender)
            }
        }
        
        return nil
    }
    
    // 查找子女称谓
    private func findChildTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let children = getChildren(source.id)
        if children.contains(where: { $0.id == target.id }) {
            return RelationshipTitleMapper.getChildTitle(gender: target.gender)
        }
        
        return nil
    }
    
    // 查找兄弟姐妹称谓
    private func findSiblingTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let siblings = getSiblings(source.id)
        if siblings.contains(where: { $0.id == target.id }) {
            // 确定是兄/弟还是姐/妹
            if target.gender == .male {
                // 判断年龄关系
                let isOlder = isOlder(target, than: source) ?? false
                return RelationshipTitleMapper.getBrotherTitle(isOlder: isOlder)
            } else if target.gender == .female {
                let isOlder = isOlder(target, than: source) ?? false
                return RelationshipTitleMapper.getSisterTitle(isOlder: isOlder)
            } else {
                return "兄弟姐妹"
            }
        }
        
        return nil
    }
    
    // 查找配偶称谓
    private func findSpouseTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let spouses = getSpouses(source.id)
        if spouses.contains(where: { $0.id == target.id }) {
            return RelationshipTitleMapper.getSpouseTitle(gender: target.gender)
        }
        
        return nil
    }
}

