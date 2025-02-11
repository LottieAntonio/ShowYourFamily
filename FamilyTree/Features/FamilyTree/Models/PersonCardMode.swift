import Foundation

public enum PersonCardMode {
    case view
    case edit
    case add(relationType: RelationType?)
}

// 实现 Equatable
extension PersonCardMode: Equatable {
    public static func == (lhs: PersonCardMode, rhs: PersonCardMode) -> Bool {
        switch (lhs, rhs) {
        case (.view, .view):
            return true
        case (.edit, .edit):
            return true
        case (.add(let lhsType), .add(let rhsType)):
            return lhsType == rhsType
        default:
            return false
        }
    }
}