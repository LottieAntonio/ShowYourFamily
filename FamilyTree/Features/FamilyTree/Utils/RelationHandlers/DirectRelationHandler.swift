import Foundation

class DirectRelationHandler: BaseRelationHandler {
    func findDirectTitle(from source: Person, to target: Person) -> String? {
        // 检查子女关系 - 调整顺序，先检查子女关系
        if let childTitle = findChildTitle(from: source, to: target) {
            return childTitle
        }
        
        // 检查父母关系
        if let parentTitle = findParentTitle(from: source, to: target) {
            return parentTitle
        }
        
        // 检查兄弟姐妹关系
        if let siblingTitle = findSiblingTitle(from: source, to: target) {
            return siblingTitle
        }
        
        // 检查配偶关系
        if let spouseTitle = findSpouseTitle(from: source, to: target) {
            return spouseTitle
        }
        
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
            ($0.fromPerson == source.id && $0.toPerson == target.id && $0.type == .child) ||
            ($0.fromPerson == target.id && $0.toPerson == source.id && $0.type == .child)
        }
        
        if let childRelation = childRelations.first {
            if childRelation.fromPerson == source.id && childRelation.toPerson == target.id {
                // 如果source是父母，target是子女，则不应该返回父母称谓
                return nil
            } else if childRelation.fromPerson == target.id && childRelation.toPerson == source.id {
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
        
        // 添加直接检查关系数据
        let childRelations = relationships.filter { 
            ($0.fromPerson == source.id && $0.toPerson == target.id && $0.type == .child) ||
            ($0.fromPerson == target.id && $0.toPerson == source.id && 
             ($0.type == .father || $0.type == .mother || $0.type == .parent))
        }
        
        if let childRelation = childRelations.first {
            // 确保关系方向正确
            if (childRelation.fromPerson == source.id && childRelation.type == .child) ||
               (childRelation.toPerson == source.id && 
                (childRelation.type == .father || childRelation.type == .mother || childRelation.type == .parent)) {
                return RelationshipTitleMapper.getChildTitle(gender: target.gender)
            }
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

