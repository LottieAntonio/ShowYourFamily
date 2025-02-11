/*
 * Person 模型
 * 作用：定义人物的基本信息结构，包括：
 * - 基本信息（姓名、性别、生日等）
 * - 联系方式
 * - 人生大事件
 * - 故事
 */

import Foundation

struct Person: Identifiable, Codable, Hashable {
    let id: UUID
    // 个人信息
    var firstName: String
    var lastName: String
    
    var name: String {
        "\(lastName)\(firstName)"
    }
    
    var gender: Gender
    var birthDate: Date?
    var deathDate: Date?
    var photo: Data?
    var notes: String?
    var isSelf: Bool = false  // 添加 isSelf 属性，默认为 false
    
    // 联系方式
    var contacts: Contacts?
    // 人生大事
    var lifeEvents: [LifeEvent]?
    // 故事
    var stories: [Story]?
    
    enum Gender: String, Codable {
        case male = "男"
        case female = "女"
        case other = "其他"
    }
    
    init(id: UUID = UUID(), firstName: String, lastName: String, gender: Gender, isSelf: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.isSelf = isSelf
    }
}

// 联系方式
struct Contacts: Codable, Hashable {
    var phone: String?
    var wechat: String?
    var address: String?
    var email: String?
    var qq: String?
}

// 人生大事
struct LifeEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var type: EventType
    var date: Date
    var location: String?
    var description: String?
    
    enum EventType: String, Codable, CaseIterable {
        case birth = "出生"
        case school = "入学"
        case work = "工作"
        case marriage = "婚姻"
        case death = "去世"
        case custom = "自定义"
        
        var description: String {
            return self.rawValue
        }
    }
    
    init(id: UUID = UUID(), type: EventType, date: Date, location: String? = nil, description: String? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.location = location
        self.description = description
    }
}

// 故事
struct Story: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var date: Date
    var photos: [Data]?
    
    init(id: UUID = UUID(), title: String, content: String, date: Date, photos: [Data]? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.photos = photos
    }
}

extension Person {
    func with(
        birthDate: Date? = nil,
        deathDate: Date? = nil,
        contacts: Contacts? = nil,
        lifeEvents: [LifeEvent]? = nil,
        stories: [Story]? = nil,
        notes: String? = nil,
        isSelf: Bool? = nil  // 添加 isSelf 参数
    ) -> Person {
        var person = self
        person.birthDate = birthDate
        person.deathDate = deathDate
        person.contacts = contacts
        person.lifeEvents = lifeEvents
        person.stories = stories
        person.notes = notes
        if let isSelf = isSelf {
            person.isSelf = isSelf
        }
        return person
    }
}
