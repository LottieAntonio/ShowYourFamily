/*
 * PersonState 模型
 * 作用：管理人物信息的编辑状态
 * - 基本信息的编辑状态
 * - 联系方式的编辑状态
 * - 事件和故事的编辑状态
 */

import Foundation

struct PersonState {
    var basicInfo: BasicInfo
    var contacts: ContactsState
    var events: [LifeEvent]
    var stories: [Story]
    
    init(from person: Person) {
        self.basicInfo = BasicInfo(from: person)
        self.contacts = ContactsState(from: person.contacts)
        self.events = person.lifeEvents ?? []
        self.stories = person.stories ?? []
    }
    
    struct BasicInfo {
        var firstName: String
        var lastName: String
        var gender: Person.Gender
        var birthDate: Date?
        var deathDate: Date?
        var notes: String?
        var showBirthDate: Bool
        var showDeathDate: Bool
        
        init(from person: Person) {
            self.firstName = person.firstName
            self.lastName = person.lastName
            self.gender = person.gender
            self.birthDate = person.birthDate
            self.deathDate = person.deathDate
            self.notes = person.notes
            self.showBirthDate = person.birthDate != nil
            self.showDeathDate = person.deathDate != nil
        }
    }
    
    struct ContactsState {
        var isEnabled: Bool
        var phone: String
        var wechat: String
        var address: String
        var email: String
        var qq: String
        
        init(from contacts: Contacts?) {
            self.isEnabled = contacts != nil
            self.phone = contacts?.phone ?? ""
            self.wechat = contacts?.wechat ?? ""
            self.address = contacts?.address ?? ""
            self.email = contacts?.email ?? ""
            self.qq = contacts?.qq ?? ""
        }
    }
}
