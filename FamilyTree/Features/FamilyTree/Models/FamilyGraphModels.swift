import Foundation
import UIKit

// 布局相关的数据结构
struct NodeLayoutInfo {
    let personId: UUID
    var position: CGPoint
    let isCenter: Bool
    let isInFilter: Bool
    var level: Int  // 表示在家谱中的层级（0为中心人物，正数向下为子女，负数向上为父母）
    var horizontalIndex: Int  // 在同一层级中的水平索引
    var children: [UUID] = []  // 子节点ID
    var parents: [UUID] = []   // 父节点ID
    var spouses: [UUID] = []   // 配偶节点ID
    var siblings: [UUID] = []  // 兄弟姐妹节点ID
    var spouseChildrenGroups: [UUID: [UUID]] = [:]  // 每个配偶对应的子女组
}

// 连接线信息结构
struct ConnectionInfo {
    enum ConnectionType {
        case parent  // 父母关系
        case spouse  // 配偶关系
        case child   // 子女关系
        case sibling // 兄弟姐妹关系
    }
    
    let fromId: UUID
    let toId: UUID
    let type: ConnectionType
    let isInFilter: Bool
    var midPoint: CGPoint?  // 用于绘制连接点
}