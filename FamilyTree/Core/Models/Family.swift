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
    var badgeImage: UIImage?
    
    // 自定义编码方法，因为 UIImage 不符合 Codable
    private enum CodingKeys: String, CodingKey {
        case id, name, description, isDefault, defaultLastName, createdAt, lastModified
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        isDefault: Bool = false,
        defaultLastName: String? = nil,
        badgeImage: UIImage? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.defaultLastName = defaultLastName
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
}
