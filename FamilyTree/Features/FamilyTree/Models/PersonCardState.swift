import Foundation

struct PersonCardState {
    var mode: PersonCardMode = .view  // 直接使用 PersonCardMode.swift 中定义的类型
    var basicInfo: BasicInfo
    var contacts: ContactInfo
    var events: [LifeEvent]
    var stories: [Story]
    
    struct BasicInfo {
        var firstName: String = ""
        var lastName: String = ""
        var gender: Person.Gender = .male
        var birthDate: Date?
        var deathDate: Date?
        var notes: String = ""
    }
    
    struct ContactInfo {
        var isEnabled: Bool = false
        var phone: String = ""
        var wechat: String = ""
        var address: String = ""
        var email: String = ""
        var qq: String = ""
        
        var isEmpty: Bool {
            phone.isEmpty && wechat.isEmpty && address.isEmpty && email.isEmpty && qq.isEmpty
        }
    }
    
    static func empty() -> PersonCardState {
        PersonCardState(
            basicInfo: BasicInfo(),
            contacts: ContactInfo(),
            events: [],
            stories: []
        )
    }
    
    static func from(_ person: Person) -> PersonCardState {
        PersonCardState(
            basicInfo: BasicInfo(
                firstName: person.firstName,
                lastName: person.lastName,
                gender: person.gender,
                birthDate: person.birthDate,
                deathDate: person.deathDate,
                notes: person.notes ?? ""
            ),
            contacts: ContactInfo(
                isEnabled: person.contacts != nil,
                phone: person.contacts?.phone ?? "",
                wechat: person.contacts?.wechat ?? "",
                address: person.contacts?.address ?? "",
                email: person.contacts?.email ?? "",
                qq: person.contacts?.qq ?? ""
            ),
            events: person.lifeEvents ?? [],
            stories: person.stories ?? []
        )
    }
}