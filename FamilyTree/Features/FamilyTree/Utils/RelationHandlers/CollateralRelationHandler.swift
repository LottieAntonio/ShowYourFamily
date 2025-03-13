import Foundation

class CollateralRelationHandler: BaseRelationHandler {
    func findCollateralTitle(from source: Person, to target: Person) -> String? {
        // 查找堂表兄弟姐妹称谓
        if let cousinTitle = findCousinTitle(from: source, to: target) {
            return cousinTitle
        }
        
        // 查找侄子女/外甥称谓
        if let nephewTitle = findNephewNieceTitle(from: source, to: target) {
            return nephewTitle
        }
        
        return nil
    }
    
    // 查找堂表兄弟姐妹称谓
    private func findCousinTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let cousins = getCousins(source.id)
        
        if cousins.contains(where: { $0.id == target.id }) {
            // 确定是堂还是表
            if let father = getFather(source.id) {
                let fatherBrothers = getSiblings(father.id).filter { $0.gender == .male }
                
                for uncle in fatherBrothers {
                    let uncleChildren = getChildren(uncle.id)
                    if uncleChildren.contains(where: { $0.id == target.id }) {
                        // 父亲的兄弟的子女 - 堂兄弟姐妹
                        let isOlder = isOlder(target, than: source) ?? false
                        return RelationshipTitleMapper.getPaternalCousinTitle(gender: target.gender, isOlder: isOlder)
                    }
                }
                
                let fatherSisters = getSiblings(father.id).filter { $0.gender == .female }
                
                for aunt in fatherSisters {
                    let auntChildren = getChildren(aunt.id)
                    if auntChildren.contains(where: { $0.id == target.id }) {
                        // 父亲的姐妹的子女 - 表兄弟姐妹
                        let isOlder = isOlder(target, than: source) ?? false
                        return RelationshipTitleMapper.getMaternalCousinTitle(gender: target.gender, isOlder: isOlder)
                    }
                }
            }
            
            if let mother = getMother(source.id) {
                let motherSiblings = getSiblings(mother.id)
                
                for uncleAunt in motherSiblings {
                    let uncleAuntChildren = getChildren(uncleAunt.id)
                    if uncleAuntChildren.contains(where: { $0.id == target.id }) {
                        // 母亲的兄弟姐妹的子女 - 表兄弟姐妹
                        let isOlder = isOlder(target, than: source) ?? false
                        return RelationshipTitleMapper.getMaternalCousinTitle(gender: target.gender, isOlder: isOlder)
                    }
                }
            }
            
            // 如果无法确定具体关系，返回默认称谓
            let isOlder = isOlder(target, than: source) ?? false
            return target.gender == .male ? 
                (isOlder ? "表哥" : "表弟") : 
                (isOlder ? "表姐" : "表妹")
        }
        
        return nil
    }
    
    // 查找侄子女/外甥称谓
    private func findNephewNieceTitle(from source: Person, to target: Person) -> String? {
        // 使用直接关系查询
        let nephewsNieces = getNephewsNieces(source.id)
        
        if nephewsNieces.contains(where: { $0.id == target.id }) {
            // 确定是通过兄弟还是姐妹
            let siblings = getSiblings(source.id)
            
            for sibling in siblings {
                let siblingChildren = getChildren(sibling.id)
                if siblingChildren.contains(where: { $0.id == target.id }) {
                    // 找到了中间的兄弟姐妹
                    if sibling.gender == .male {
                        // 兄弟的子女 - 侄子女
                        return RelationshipTitleMapper.getNephewNieceTitle(gender: target.gender)
                    } else {
                        // 姐妹的子女 - 外甥/外甥女
                        return RelationshipTitleMapper.getMaternalNephewNieceTitle(gender: target.gender)
                    }
                }
            }
            
            // 如果无法确定中间关系，返回默认称谓
            return target.gender == .male ? "侄子/外甥" : "侄女/外甥女"
        }
        
        return nil
    }
}


