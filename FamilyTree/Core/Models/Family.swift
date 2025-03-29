import Foundation
import UIKit

struct Family: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var isDefault: Bool
    var defaultLastName: String?  // 添加默认姓氏属性
    var createdAt: Date
    var lastModified: Date
    var badgeImageName: String?  // 存储SF符号名称或自定义图片的标识符
    var badgeType: BadgeType  // 新增：标记徽章类型
    var badgeImage: UIImage?  // 非持久化字段，仅用于UI显示
    
    enum BadgeType: String, Codable {
        case sfSymbol  // 系统SF符号
        case emoji     // Emoji表情
        case custom    // 自定义上传图片
    }
    
    // 自定义编码方法，因为 UIImage 不符合 Codable
    private enum CodingKeys: String, CodingKey {
        case id, name, description, isDefault, defaultLastName, createdAt, lastModified, badgeImageName, badgeType
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        isDefault: Bool = false,
        defaultLastName: String? = nil,
        badgeImageName: String? = "animal10",  // 默认使用书本图标
        badgeType: BadgeType = .custom,
        badgeImage: UIImage? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.defaultLastName = defaultLastName
        self.badgeImageName = badgeImageName
        self.badgeType = badgeType
        self.badgeImage = badgeImage
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    // 添加 Hashable 协议的实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Family, rhs: Family) -> Bool {
        lhs.id == rhs.id
    }
    
    // 获取默认族徽选项
    static var defaultBadgeOptions: [(name: String, type: BadgeType)] {
        [
            ("animal3", .custom),
            ("animal4", .custom),
            ("animal5", .custom),
            ("animal6", .custom),
            ("animal7", .custom),
            ("animal8", .custom),
            ("animal9", .custom),
            ("animal10", .custom),
            ("animal11", .custom),
            ("animal12", .custom),
            ("animal13", .custom),
            ("animal14", .custom),
            ("animal15", .custom),
            ("plant1", .custom),
            ("plant2", .custom),
            ("plant3", .custom),
            ("plant4", .custom),
            ("plant6", .custom)
        ]
    }
}
