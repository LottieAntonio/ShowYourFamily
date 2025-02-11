import Foundation
import SwiftUI

@MainActor
class PersonEditViewModel: ObservableObject {
    @Published private(set) var state: PersonState
    private let person: Person
    private let managementViewModel: PersonManagementViewModel
    
    init(person: Person, managementViewModel: PersonManagementViewModel) {
        self.person = person
        self.managementViewModel = managementViewModel
        self.state = PersonState(from: person)
    }
    
    // MARK: - Bindings
    var firstName: Binding<String> {
        Binding(
            get: { self.state.basicInfo.firstName },
            set: { self.state.basicInfo.firstName = $0 }
        )
    }
    
    var lastName: Binding<String> {
        Binding(
            get: { self.state.basicInfo.lastName },
            set: { self.state.basicInfo.lastName = $0 }
        )
    }
    
    var gender: Binding<Person.Gender> {
        Binding(
            get: { self.state.basicInfo.gender },
            set: { self.state.basicInfo.gender = $0 }
        )
    }
    
    var showContacts: Binding<Bool> {
        Binding(
            get: { self.state.contacts.isEnabled },
            set: { self.state.contacts.isEnabled = $0 }
        )
    }
    
    var phone: Binding<String> {
        Binding(
            get: { self.state.contacts.phone },
            set: { self.state.contacts.phone = $0 }
        )
    }
    
    var wechat: Binding<String> {
        Binding(
            get: { self.state.contacts.wechat },
            set: { self.state.contacts.wechat = $0 }
        )
    }
    
    var address: Binding<String> {
        Binding(
            get: { self.state.contacts.address },
            set: { self.state.contacts.address = $0 }
        )
    }
    
    var email: Binding<String> {
        Binding(
            get: { self.state.contacts.email },
            set: { self.state.contacts.email = $0 }
        )
    }
    
    var qq: Binding<String> {
        Binding(
            get: { self.state.contacts.qq },
            set: { self.state.contacts.qq = $0 }
        )
    }
    
    var contacts: Binding<PersonState.ContactsState> {
        Binding(
            get: { self.state.contacts },
            set: { self.state.contacts = $0 }
        )
    }
    
    var events: Binding<[LifeEvent]> {
        Binding(
            get: { self.state.events },
            set: { self.state.events = $0 }
        )
    }
    
    var stories: Binding<[Story]> {
        Binding(
            get: { self.state.stories },
            set: { self.state.stories = $0 }
        )
    }
    
    func updatePerson() async throws {
        var updatedPerson = person
        updatedPerson.firstName = state.basicInfo.firstName
        updatedPerson.lastName = state.basicInfo.lastName
        updatedPerson.gender = state.basicInfo.gender
        updatedPerson.birthDate = state.basicInfo.showBirthDate ? state.basicInfo.birthDate : nil
        updatedPerson.deathDate = state.basicInfo.showDeathDate ? state.basicInfo.deathDate : nil
        updatedPerson.notes = state.basicInfo.notes
        
        if state.contacts.isEnabled {
            updatedPerson.contacts = Contacts(
                phone: state.contacts.phone.isEmpty ? nil : state.contacts.phone,
                wechat: state.contacts.wechat.isEmpty ? nil : state.contacts.wechat,
                address: state.contacts.address.isEmpty ? nil : state.contacts.address,
                email: state.contacts.email.isEmpty ? nil : state.contacts.email,
                qq: state.contacts.qq.isEmpty ? nil : state.contacts.qq
            )
        }
        
        updatedPerson.lifeEvents = state.events.isEmpty ? nil : state.events
        updatedPerson.stories = state.stories.isEmpty ? nil : state.stories
        
        try await managementViewModel.updatePerson(updatedPerson)
    }
    
    var isValid: Bool {
        !state.basicInfo.firstName.isEmpty && !state.basicInfo.lastName.isEmpty
    }
    
    // 修改访问器名称以避免命名冲突
    var personManager: PersonManagementViewModel {
        return managementViewModel
    }
}