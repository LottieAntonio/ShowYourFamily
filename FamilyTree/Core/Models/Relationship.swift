
/*
 * Relationship 模型
 * 作用：定义人物之间的关系
 * - 定义关系类型（父母、子女、配偶等）
 * - 管理关系的双向性
 * - 处理关系的时间属性
 */

import Foundation

// 先定义 RelationType
public enum RelationType: String, Codable, CaseIterable {
    case father
    case mother
    case spouse
    case child
    case brother
    case sister
    
    var displayName: String {
        switch self {
        case .father: return "父亲"
        case .mother: return "母亲"
        case .spouse: return "配偶"
        case .child: return "子女"
        case .brother: return "兄弟"
        case .sister: return "姐妹"
        }
    }
    
    var gender: Person.Gender? {
        switch self {
        case .father, .brother: return .male
        case .mother, .sister: return .female
        default: return nil
        }
    }
    
    public var opposite: RelationType {
        switch self {
        case .father, .mother:
            return .child
        case .spouse:
            return .spouse
        case .child:
            // 根据原始关系类型返回对应的父母类型
            if let parentType = parentType {
                return parentType
            }
            return .parent
        case .brother:
            return .brother
        case .sister:
            return .sister
        }
    }
    
    // 添加一个计算属性来确定父母类型
    private var parentType: RelationType? {
        switch self {
        case .child:
            return .father  // 默认返回父亲
        case .father:
            return .child
        case .mother:
            return .child
        case .brother:
            return .brother
        case .sister:
            return .sister
        default:
            return nil
        }
    }
    
    // 向后兼容
    public static var parent: RelationType {
        .father  // 默认返回父亲类型
    }
}

public struct Relationship: Identifiable, Codable, Hashable {
    public let id: UUID
    public var type: RelationType
    public var fromPerson: UUID
    public var toPerson: UUID
    public var startDate: Date?
    public var endDate: Date?
    
    public init(id: UUID = UUID(), type: RelationType, fromPerson: UUID, toPerson: UUID, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = id
        self.type = type
        self.fromPerson = fromPerson
        self.toPerson = toPerson
        self.startDate = startDate
        self.endDate = endDate
    }
    
    public func hash(into hasher: inout Hasher) {  // 添加 public
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(fromPerson)
        hasher.combine(toPerson)
        hasher.combine(startDate)
        hasher.combine(endDate)
    }
    
    public static func == (lhs: Relationship, rhs: Relationship) -> Bool {  // 添加 public
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.fromPerson == rhs.fromPerson &&
        lhs.toPerson == rhs.toPerson &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate
    }
}

// 删除这个扩展
// extension Relationship {
//     enum RelationType: Equatable {
//         case parent
//         case child
//         case spouse
//     }
// }

// 在文件末尾添加 Generation 相关定义
public enum Generation: Int, Equatable {
    case fourthUp = 4    // 高祖
    case thirdUp = 3     // 曾祖
    case secondUp = 2    // 祖父母辈
    case firstUp = 1     // 父母辈
    case current = 0     // 同辈
    case firstDown = -1  // 子辈
    case secondDown = -2 // 孙辈
    case thirdDown = -3  // 曾孙辈
    
    var title: String {
        switch self {
        case .fourthUp: return "高"
        case .thirdUp: return "曾"
        case .secondUp: return ""
        case .firstUp: return ""
        case .current: return ""
        case .firstDown: return ""
        case .secondDown: return ""
        case .thirdDown: return "曾"
        }
    }
    
    public enum RelativeType {
        case direct           // 直系
        case fatherSibling    // 父系旁系（伯父叔父姑姑）
        case motherSibling    // 母系旁系（舅舅姨妈）
        case cousinFromFatherSide  // 父系表亲
        case cousinFromMotherSide  // 母系表亲
        case spouse          // 配偶
        case nephewFromBrother     // 侄子/侄女（兄弟的子女）
        case nephewFromSister      // 外甥/外甥女（姐妹的子女）
    }
    
    func getTitle(for relative: Person, relativeType: RelativeType, isSiblingElder: Bool?) -> String {
        switch self {
        case .fourthUp:
            return relative.gender == .male ? "高祖父" : "高祖母"
            
        case .thirdUp:
            return relative.gender == .male ? "曾祖父" : "曾祖母"
            
        case .secondUp:
            return relative.gender == .male ? "祖父" : "祖母"
            
        case .firstUp:
            switch relativeType {
            case .direct:
                return relative.gender == .male ? "父亲" : "母亲"
            case .fatherSibling:
                if relative.gender == .male {
                    return isSiblingElder == true ? "伯父" : "叔父"
                } else {
                    return isSiblingElder == true ? "姑母" : "小姑"
                }
            case .motherSibling:
                if relative.gender == .male {
                    return isSiblingElder == true ? "舅父" : "小舅"
                } else {
                    return isSiblingElder == true ? "姨母" : "小姨"
                }
            default:
                return ""
            }
            
        case .current:
            switch relativeType {
            case .direct:
                if relative.gender == .male {
                    return isSiblingElder == true ? "哥哥" : "弟弟"
                } else {
                    return isSiblingElder == true ? "姐姐" : "妹妹"
                }
            case .spouse:
                return relative.gender == .male ? "丈夫" : "妻子"
            case .cousinFromFatherSide:
                if relative.gender == .male {
                    return isSiblingElder == true ? "堂兄" : "堂弟"
                } else {
                    return isSiblingElder == true ? "堂姐" : "堂妹"
                }
            case .cousinFromMotherSide:
                if relative.gender == .male {
                    return isSiblingElder == true ? "表兄" : "表弟"
                } else {
                    return isSiblingElder == true ? "表姐" : "表妹"
                }
            default:
                return ""
            }
            
        case .firstDown:
            switch relativeType {
            case .direct:
                return relative.gender == .male ? "儿子" : "女儿"
            case .nephewFromBrother:
                return relative.gender == .male ? "侄子" : "侄女"
            case .nephewFromSister:
                return relative.gender == .male ? "外甥" : "外甥女"
            default:
                return ""
            }
            
        case .secondDown:
            return relative.gender == .male ? "孙子" : "孙女"
            
        case .thirdDown:
            return relative.gender == .male ? "曾孙" : "曾孙女"
        }
    }
}
