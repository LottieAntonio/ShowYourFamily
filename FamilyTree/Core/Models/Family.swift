import Foundation

struct Family: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var isDefault: Bool
    var createdAt: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
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
