import Foundation

enum FamilyError: LocalizedError {
    case noCurrentFamily
    case defaultFamilyNotEditable
    case defaultFamilyNotFound
    case userFamilyAlreadyExists
    case cannotModifyDefaultFamily
    case personNotInCurrentFamily
    
    var errorDescription: String? {
        switch self {
        case .noCurrentFamily:
            return "未选择当前家谱"
        case .defaultFamilyNotEditable:
            return "示例家谱不可修改"
        case .defaultFamilyNotFound:
            return "未找到默认家谱"
        case .userFamilyAlreadyExists:
            return "已创建过家谱"
        case .cannotModifyDefaultFamily:
            return "示例家谱不可修改"
        case .personNotInCurrentFamily:
            return "该人物不属于当前家谱"
        }
    }
}