import Foundation

class AncestorRelationHandler: BaseRelationHandler {
    func findAncestorTitle(from source: Person, to target: Person) -> String? {
        print("🔍 AncestorRelationHandler 开始查找关系: \(source.name) -> \(target.name)")
        
        // 查找祖父母称谓
        if let grandparentTitle = findGrandparentTitle(from: source, to: target) {
            print("👴👵 找到祖父母关系: \(grandparentTitle)")
            return grandparentTitle
        }
        
        // 查找曾祖父母称谓
        if let greatGrandparentTitle = findGreatGrandparentTitle(from: source, to: target) {
            print("👴👵 找到曾祖父母关系: \(greatGrandparentTitle)")
            return greatGrandparentTitle
        }
        
        // 查找叔伯姑姨称谓
        if let uncleAuntTitle = findUncleAuntTitle(from: source, to: target) {
            print("👨‍👩‍👧 找到叔伯姑姨关系: \(uncleAuntTitle)")
            return uncleAuntTitle
        }
        
        print("❌ AncestorRelationHandler 未找到祖先关系")
        return nil
    }
    
    // 查找祖父母称谓
    private func findGrandparentTitle(from source: Person, to target: Person) -> String? {
        print("🔍 开始查找祖父母关系: \(source.name) -> \(target.name)")
        
        // 使用直接关系查询
        let grandparents = getGrandparents(source.id)
        
        print("📊 找到祖父母数量: \(grandparents.count)")
        for (index, gp) in grandparents.enumerated() {
            print("  #\(index): \(gp.name) (ID=\(gp.id))")
        }
        
        if grandparents.contains(where: { $0.id == target.id }) {
            print("✅ 确认 \(target.name) 是 \(source.name) 的祖父母")
            
            // 确定是父系还是母系
            if let father = getFather(source.id) {
                print("👨 找到父亲: \(father.name)")
                
                if let fatherFather = getFather(father.id), fatherFather.id == target.id {
                    print("👴 确认是父系祖父")
                    return RelationshipTitleMapper.getPaternalGrandparentTitle(gender: .male)
                }
                
                if let fatherMother = getMother(father.id), fatherMother.id == target.id {
                    print("👵 确认是父系祖母")
                    return RelationshipTitleMapper.getPaternalGrandparentTitle(gender: .female)
                }
            } else {
                print("❌ 未找到父亲")
            }
            
            if let mother = getMother(source.id) {
                print("👩 找到母亲: \(mother.name)")
                
                if let motherFather = getFather(mother.id), motherFather.id == target.id {
                    print("👴 确认是母系祖父")
                    return RelationshipTitleMapper.getMaternalGrandparentTitle(gender: .male)
                }
                
                if let motherMother = getMother(mother.id), motherMother.id == target.id {
                    print("👵 确认是母系祖母")
                    return RelationshipTitleMapper.getMaternalGrandparentTitle(gender: .female)
                }
            } else {
                print("❌ 未找到母亲")
            }
        } else {
            print("❌ \(target.name) 不是 \(source.name) 的祖父母")
        }
        
        return nil
    }
    
    // 查找曾祖父母称谓
    private func findGreatGrandparentTitle(from source: Person, to target: Person) -> String? {
        // 父系曾祖父
        if let father = getFather(source.id),
           let grandfather = getFather(father.id),
           let greatGrandfather = getFather(grandfather.id),
           greatGrandfather.id == target.id {
            return RelationshipTitleMapper.getPaternalGreatGrandparentTitle(gender: .male)
        }
        
        // 父系曾祖母
        if let father = getFather(source.id),
           let grandfather = getFather(father.id),
           let greatGrandmother = getMother(grandfather.id),
           greatGrandmother.id == target.id {
            return RelationshipTitleMapper.getPaternalGreatGrandparentTitle(gender: .female)
        }
        
        // 父系曾祖父（通过奶奶）
        if let father = getFather(source.id),
           let grandmother = getMother(father.id),
           let greatGrandfather = getFather(grandmother.id),
           greatGrandfather.id == target.id {
            return RelationshipTitleMapper.getPaternalGreatGrandparentTitle(gender: .male)
        }
        
        // 父系曾祖母（通过奶奶）
        if let father = getFather(source.id),
           let grandmother = getMother(father.id),
           let greatGrandmother = getMother(grandmother.id),
           greatGrandmother.id == target.id {
            return RelationshipTitleMapper.getPaternalGreatGrandparentTitle(gender: .female)
        }
        
        // 母系曾祖父
        if let mother = getMother(source.id),
           let grandfather = getFather(mother.id),
           let greatGrandfather = getFather(grandfather.id),
           greatGrandfather.id == target.id {
            return RelationshipTitleMapper.getMaternalGreatGrandparentTitle(gender: .male)
        }
        
        // 母系曾祖母
        if let mother = getMother(source.id),
           let grandfather = getFather(mother.id),
           let greatGrandmother = getMother(grandfather.id),
           greatGrandmother.id == target.id {
            return RelationshipTitleMapper.getMaternalGreatGrandparentTitle(gender: .female)
        }
        
        // 母系曾祖父（通过外婆）
        if let mother = getMother(source.id),
           let grandmother = getMother(mother.id),
           let greatGrandfather = getFather(grandmother.id),
           greatGrandfather.id == target.id {
            return RelationshipTitleMapper.getMaternalGreatGrandparentTitle(gender: .male)
        }
        
        // 母系曾祖母（通过外婆）
        if let mother = getMother(source.id),
           let grandmother = getMother(mother.id),
           let greatGrandmother = getMother(grandmother.id),
           greatGrandmother.id == target.id {
            return RelationshipTitleMapper.getMaternalGreatGrandparentTitle(gender: .female)
        }
        
        return nil
    }
    
    // 查找叔伯姑姨称谓
    private func findUncleAuntTitle(from source: Person, to target: Person) -> String? {
        // 获取所有叔伯姑姨
        let unclesAunts = getUnclesAunts(source.id)
        
        if unclesAunts.contains(where: { $0.id == target.id }) {
            // 确定是父系还是母系
            if let father = getFather(source.id) {
                let fatherSiblings = getSiblings(father.id)
                if fatherSiblings.contains(where: { $0.id == target.id }) {
                    // 父亲的兄弟姐妹
                    if target.gender == .male {
                        // 判断年龄关系
                        let isOlder = isOlder(target, than: father) ?? false
                        return RelationshipTitleMapper.getFatherBrotherTitle(isOlder: isOlder)
                    } else if target.gender == .female {
                        return RelationshipTitleMapper.getFatherSisterTitle()
                    }
                }
            }
            
            if let mother = getMother(source.id) {
                let motherSiblings = getSiblings(mother.id)
                if motherSiblings.contains(where: { $0.id == target.id }) {
                    // 母亲的兄弟姐妹
                    if target.gender == .male {
                        return RelationshipTitleMapper.getMotherBrotherTitle()
                    } else if target.gender == .female {
                        return RelationshipTitleMapper.getMotherSisterTitle()
                    }
                }
            }
        }
        
        return nil
    }
}
