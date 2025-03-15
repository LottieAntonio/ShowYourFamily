import Foundation

/// 关系称谓映射器
/// 用于集中管理所有亲属称谓的映射规则
class RelationshipTitleMapper {
    
    // 使用 Person 中定义的 Gender 类型
    typealias Gender = Person.Gender
    
    // MARK: - 直系长辈称谓
    
    /// 父母称谓
    static func getParentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "爸爸"
        case .female:
            return "妈妈"
        case .other:
            return "父母"
        }
    }
    
    /// 祖父母称谓（父系）
    static func getPaternalGrandparentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "爷爷"
        case .female:
            return "奶奶"
        case .other:
            return "祖父母"
        }
    }
    
    /// 祖父母称谓（母系）
    static func getMaternalGrandparentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "外公"
        case .female:
            return "外婆"
        case .other:
            return "外祖父母"
        }
    }
    
    /// 曾祖父母称谓（父系）
    static func getPaternalGreatGrandparentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "曾祖父"
        case .female:
            return "曾祖母"
        case .other:
            return "曾祖父母"
        }
    }
    
    /// 曾祖父母称谓（母系）
    static func getMaternalGreatGrandparentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "外曾祖父"
        case .female:
            return "外曾祖母"
        case .other:
            return "外曾祖父母"
        }
    }
    
    // MARK: - 直系晚辈称谓
    
    /// 子女称谓
    static func getChildTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "儿子"
        case .female:
            return "女儿"
        case .other:
            return "子女"
        }
    }
    
    /// 孙子女称谓（父系）
    static func getPaternalGrandchildTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "孙子"
        case .female:
            return "孙女"
        case .other:
            return "孙辈"
        }
    }
    
    /// 孙子女称谓（母系）
    static func getMaternalGrandchildTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "外孙"
        case .female:
            return "外孙女"
        case .other:
            return "外孙辈"
        }
    }
    
    /// 曾孙子女称谓
    static func getGreatGrandchildTitle(gender: Gender, isMaternal: Bool = false) -> String {
        let prefix = isMaternal ? "外" : ""
        switch gender {
        case .male:
            return "\(prefix)曾孙"
        case .female:
            return "\(prefix)曾孙女"
        case .other:
            return "\(prefix)曾孙辈"
        }
    }
    
    // MARK: - 兄弟姐妹称谓
    
    /// 兄弟称谓
    static func getBrotherTitle(isOlder: Bool) -> String {
        return isOlder ? "哥哥" : "弟弟"
    }
    
    /// 姐妹称谓
    static func getSisterTitle(isOlder: Bool) -> String {
        return isOlder ? "姐姐" : "妹妹"
    }
    
    // MARK: - 旁系长辈称谓
    
    /// 叔伯称谓（父亲的兄弟）
    static func getFatherBrotherTitle(isOlder: Bool) -> String {
        return isOlder ? "伯父" : "叔叔"
    }
    
    /// 姑姑称谓（父亲的姐妹）
    static func getFatherSisterTitle() -> String {
        return "姑姑"
    }
    
    /// 舅舅称谓（母亲的兄弟）
    static func getMotherBrotherTitle() -> String {
        return "舅舅"
    }
    
    /// 姨妈称谓（母亲的姐妹）
    static func getMotherSisterTitle() -> String {
        return "姨妈"
    }
    
    /// 叔伯/姑姑配偶称谓
    static func getFatherSiblingSpouseTitle(siblingGender: Gender) -> String {
        switch siblingGender {
        case .male:
            return "婶婶"  // 叔叔的妻子
        case .female:
            return "姑父"  // 姑姑的丈夫
        case .other:
            return "姻亲"
        }
    }
    
    /// 舅舅/姨妈配偶称谓
    static func getMotherSiblingSpouseTitle(siblingGender: Gender) -> String {
        switch siblingGender {
        case .male:
            return "舅妈"  // 舅舅的妻子
        case .female:
            return "姨父"  // 姨妈的丈夫
        case .other:
            return "姻亲"
        }
    }
    
    // MARK: - 旁系晚辈称谓
    
    /// 侄子女称谓（兄弟的子女）
    static func getNephewNieceTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "侄子"
        case .female:
            return "侄女"
        case .other:
            return "侄辈"
        }
    }
    
    /// 外甥称谓（姐妹的子女）
    static func getMaternalNephewNieceTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "外甥"
        case .female:
            return "外甥女"
        case .other:
            return "外甥辈"
        }
    }
    
    // MARK: - 堂表亲称谓
    
    /// 堂兄弟姐妹称谓（父亲的兄弟的子女）
    static func getPaternalCousinTitle(gender: Gender, isOlder: Bool) -> String {
        let prefix = "堂"
        switch gender {
        case .male:
            return "\(prefix)\(isOlder ? "哥" : "弟")"
        case .female:
            return "\(prefix)\(isOlder ? "姐" : "妹")"
        case .other:
            return "\(prefix)兄弟姐妹"
        }
    }
    
    /// 表兄弟姐妹称谓（父亲的姐妹的子女或母亲的兄弟姐妹的子女）
    static func getMaternalCousinTitle(gender: Gender, isOlder: Bool) -> String {
        let prefix = "表"
        switch gender {
        case .male:
            return "\(prefix)\(isOlder ? "哥" : "弟")"
        case .female:
            return "\(prefix)\(isOlder ? "姐" : "妹")"
        case .other:
            return "\(prefix)兄弟姐妹"
        }
    }
    
    // MARK: - 姻亲称谓
    
    /// 配偶称谓
    static func getSpouseTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "丈夫"
        case .female:
            return "妻子"
        case .other:
            return "配偶"
        }
    }
    
    /// 岳父母称谓（妻子的父母）
    static func getWifeParentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "岳父"
        case .female:
            return "岳母"
        case .other:
            return "岳父母"
        }
    }
    
    /// 公婆称谓（丈夫的父母）
    static func getHusbandParentTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "公公"
        case .female:
            return "婆婆"
        case .other:
            return "公婆"
        }
    }
    
    /// 儿媳/女婿称谓
    static func getChildSpouseTitle(gender: Gender) -> String {
        switch gender {
        case .male:
            return "女婿"  // 女儿的丈夫
        case .female:
            return "儿媳"  // 儿子的妻子
        case .other:
            return "子女的配偶"
        }
    }
    
    /// 嫂子/弟媳称谓（兄弟的妻子）
    static func getBrotherWifeTitle(isOlder: Bool) -> String {
        return isOlder ? "嫂子" : "弟媳"
    }
    
    /// 姐夫/妹夫称谓（姐妹的丈夫）
    static func getSisterHusbandTitle(isOlder: Bool) -> String {
        return isOlder ? "姐夫" : "妹夫"
    }
    
    // MARK: - 复合关系称谓
    
    /// 获取简化的辈分称谓
    static func getSimplifiedGenerationTitle(generationDiff: Int, gender: Gender) -> String {
        
        if generationDiff > 0 {
            // 长辈
            if generationDiff == 1 {
                return gender == .male ? "叔伯辈" : "姑姨辈"
            } else if generationDiff == 2 {
                return gender == .male ? "祖父辈" : "祖母辈"
            } else if generationDiff >= 3 {
                return gender == .male ? "太祖辈" : "太祖母辈"
            }
        } else if generationDiff < 0 {
            // 晚辈
            let absDiff = abs(generationDiff)
            if absDiff == 1 {
                return gender == .male ? "侄辈" : "侄女辈"
            } else if absDiff == 2 {
                return gender == .male ? "孙辈" : "孙女辈"
            } else if absDiff >= 3 {
                return gender == .male ? "曾孙辈" : "曾孙女辈"
            }
        } else {
            // 同辈
            return "平辈亲戚"
        }
        
        return "亲戚"
    }
}
