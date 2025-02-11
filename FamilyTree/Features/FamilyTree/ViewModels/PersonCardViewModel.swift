
/*
 * PersonCardViewModel 类
 * 作用：管理人物卡片的视图逻辑
 * - 处理人物信息的编辑
 * - 管理称谓的显示和更新
 * - 处理保存和删除操作
 */

import SwiftUI
import Foundation

@MainActor
class PersonCardViewModel: ObservableObject {
    @Published private(set) var state: PersonCardState
    @Published var errorMessage: String?
    // 删除 isLoading 和 isSettingSelf
    
    private let person: Person?
    private let managementViewModel: PersonManagementViewModel
    let mode: PersonCardMode
    
    // 添加公开的访问器
    var personManagementViewModel: PersonManagementViewModel {
        managementViewModel
    }
    
    // 修改称呼缓存的实现
    @Published private var cachedTitle: String?
    
    var displayTitle: String {
        if let person = currentPerson {
            // 1. 如果是自己，返回"自己"
            if person.isSelf {
                return "自己"
            }
            // 2. 如果有自定义称呼（用户手动编辑的），直接返回
            if let notes = person.notes, !notes.isEmpty {
                return notes
            }
            // 3. 如果有缓存的自动生成称呼，返回缓存
            if let cached = cachedTitle {
                return cached
            }
            // 4. 异步获取自动生成的称呼
            Task {
                if person.notes?.isEmpty ?? true {  // 只在没有自定义称呼时更新
                    cachedTitle = await managementViewModel.titleGenerator.generateTitle(for: person)
                }
            }
            return "加载中..."
        }
        return "称呼：未编辑"
    }
    
    // 修改更新称呼的方法
    @MainActor
    func updateDisplayTitle() async {
        guard let person = currentPerson else { return }
        // 只在没有自定义称呼时才更新自动生成的称呼
        if person.notes?.isEmpty ?? true {
            if let title = await titleGenerator.generateTitle(for: person) {
                cachedTitle = title
                objectWillChange.send()
            }
        }
    }
    
    // 在 init 中添加称呼更新
    init(person: Person?, mode: PersonCardMode, managementViewModel: PersonManagementViewModel) {
        self.person = person
        self.mode = mode
        self.managementViewModel = managementViewModel
        
        // 初始化 state
        if let person = person {
            self.state = PersonCardState.from(person)
        } else {
            var state = PersonCardState.empty()
            // 使用默认值
            if case .add = mode {
                state.basicInfo.lastName = managementViewModel.defaultLastName ?? ""
                if let defaultGender = managementViewModel.defaultGender {
                    state.basicInfo.gender = defaultGender
                }
            }
            self.state = state
        }
        
        // 清除默认值
        Task {
            await managementViewModel.setDefaultValues()
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    func save() async throws {
        if case .add(let relationType) = mode {
            // 创建新人物
            var newPerson = createOrUpdatePerson()
            
            // 如果是第一个人物，设置为自己
            if managementViewModel.persons.isEmpty {
                newPerson.isSelf = true
            }
            
            try await managementViewModel.updatePerson(newPerson)
            // 如果是第一个人物，设置为选中的人物
            if managementViewModel.persons.isEmpty {
                managementViewModel.selectedPerson = newPerson
            }
            
            // 如果有关系类型，创建关系
            if let relationType = relationType,
               let currentPerson = managementViewModel.selectedPerson {
                try await managementViewModel.addRelationship(
                    from: currentPerson,
                    to: newPerson,
                    type: relationType
                )
                // 删除手动更新称呼的代码，因为 addRelationship 会处理这些
            }
            
            await MainActor.run {
                objectWillChange.send()
            }
        } else if case .edit = mode {
            let updatedPerson = createOrUpdatePerson()
            try await managementViewModel.updatePerson(updatedPerson)
            
            // 添加刷新
            await MainActor.run {
                objectWillChange.send()
                // 更新 managementViewModel 的选中人物
                managementViewModel.selectedPerson = updatedPerson
            }
        }
    }
    
    private func createOrUpdatePerson() -> Person {
        var person = self.person ?? Person(
            firstName: state.basicInfo.firstName,
            lastName: state.basicInfo.lastName,
            gender: state.basicInfo.gender
        )
        
        person.firstName = state.basicInfo.firstName
        person.lastName = state.basicInfo.lastName
        person.gender = state.basicInfo.gender
        person.birthDate = state.basicInfo.birthDate
        person.deathDate = state.basicInfo.deathDate
        person.notes = state.basicInfo.notes.isEmpty ? nil : state.basicInfo.notes
        
        if state.contacts.isEnabled {
            person.contacts = Contacts(
                phone: state.contacts.phone.isEmpty ? nil : state.contacts.phone,
                wechat: state.contacts.wechat.isEmpty ? nil : state.contacts.wechat,
                address: state.contacts.address.isEmpty ? nil : state.contacts.address,
                email: state.contacts.email.isEmpty ? nil : state.contacts.email,
                qq: state.contacts.qq.isEmpty ? nil : state.contacts.qq
            )
        } else {
            person.contacts = nil
        }
        
        person.lifeEvents = state.events.isEmpty ? nil : state.events
        person.stories = state.stories.isEmpty ? nil : state.stories
        
        return person
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        let valid = !state.basicInfo.firstName.isEmpty && !state.basicInfo.lastName.isEmpty
        return valid
    }
    
    // 删除重复的同步和异步版本，只保留一个异步版本
    @MainActor
    func updateFirstName(_ firstName: String) async {
        var newState = state
        newState.basicInfo.firstName = firstName
        state = newState
        objectWillChange.send()
    }
    
    @MainActor
    func updateLastName(_ lastName: String) async {
        var newState = state
        newState.basicInfo.lastName = lastName
        state = newState
        objectWillChange.send()
    }
    
    @MainActor
    func updateGender(_ gender: Person.Gender) async {
        var newState = state
        newState.basicInfo.gender = gender
        state = newState
        objectWillChange.send()
    }
    
    @MainActor
    func updateBirthDate(_ date: Date) async {
        // 添加日期验证
        guard !date.timeIntervalSince1970.isNaN else { return }
        
        var newState = state
        newState.basicInfo.birthDate = date
        state = newState
        objectWillChange.send()
    }
    
    @MainActor
    func updateNotes(_ notes: String) async {
        var newState = state
        newState.basicInfo.notes = notes
        state = newState
        objectWillChange.send()
    }
    var isViewMode: Bool {
        mode == .view
    }

    func updatePhone(_ phone: String) {
        var newState = state
        newState.contacts.phone = phone
        state = newState
    }

    func updateWechat(_ wechat: String) {
        var newState = state
        newState.contacts.wechat = wechat
        state = newState
    }
    func updateAddress(_ address: String) {
        var newState = state
        newState.contacts.address = address
        state = newState
    }
    func updateEmail(_ email: String) {
        var newState = state
        newState.contacts.email = email
        state = newState
    }
    func updateQQ(_ qq: String) {
        var newState = state
        newState.contacts.qq = qq
        state = newState
    }
    func updateEvents(_ events: [LifeEvent]) {
        var newState = state
        newState.events = events
        state = newState
    }
    func updateStories(_ stories: [Story]) {
        var newState = state
        newState.stories = stories
        state = newState
    }
    @MainActor
    func updateContacts(_ contacts: PersonCardState.ContactInfo) async {
        var newState = state
        newState.contacts = contacts
        state = newState
        objectWillChange.send()
        
        if let person = self.person {
            do {
                var updatedPerson = person
                updatedPerson.contacts = Contacts(
                    phone: contacts.phone.isEmpty ? nil : contacts.phone,
                    wechat: contacts.wechat.isEmpty ? nil : contacts.wechat,
                    address: contacts.address.isEmpty ? nil : contacts.address,
                    email: contacts.email.isEmpty ? nil : contacts.email,
                    qq: contacts.qq.isEmpty ? nil : contacts.qq
                )
                try await managementViewModel.updatePerson(updatedPerson)
            } catch {
                errorMessage = "保存联系方式失败：\(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    func updateContactsEnabled(_ enabled: Bool) async {
        var newState = state
        newState.contacts.isEnabled = enabled
        state = newState
        objectWillChange.send()
    }
    
    // 删除这个简单版本的 birthDate
    // var birthDate: Date {
    //     state.basicInfo.birthDate ?? Date()
    // }
    
    var isEditable: Bool {
        mode != .view
    }
    
    // 保留这个完整版本的 birthDate
    var birthDate: Date {
        get {
            state.basicInfo.birthDate ?? Date()
        }
        set {
            var newState = state
            newState.basicInfo.birthDate = newValue
            state = newState
        }
    }
    // 添加公开的只读属性
    var currentPerson: Person? {
        person
    }
    func deletePerson() async throws {
        if let person = person {
            try await managementViewModel.deletePerson(person)
        }
    }
    
    // 添加称呼生成器
    private lazy var titleGenerator = RelativeTitleGenerator(managementViewModel: managementViewModel)
    
    // 添加获取称呼的计算属性
   
    
    @MainActor  // 只保留一个 @MainActor
    func reloadData() async {
        // 先重新加载 managementViewModel 的数据
        await managementViewModel.loadData()
        
        // 然后更新本地状态
        if let person = managementViewModel.persons.first(where: { $0.id == currentPerson?.id }) {
            self.state = PersonCardState.from(person)
            objectWillChange.send()
        }
    }
    
    // 添加状态控制属性
    @Published var isSettingSelf = false  // 添加这个状态变量
    
    @MainActor
    func setSelf() async {
        if let person = currentPerson {
            // 使用已有的 setSelfPerson 方法
            try? await setSelfPerson()
            // 重新加载数据以更新称呼
            await managementViewModel.loadData()
        }
    }
    
    func setSelfPerson() async throws {
        guard let person = currentPerson else { return }
        
        print("⏳ 开始设置自己：\(person.firstName)\(person.lastName)")
        
        // 先清除其他人的自己标记并等待完成
        for var otherPerson in managementViewModel.persons where otherPerson.id != person.id && otherPerson.isSelf {
            print("⏳ 清除其他人的自己标记：\(otherPerson.firstName)\(otherPerson.lastName)")
            otherPerson.isSelf = false
            try await managementViewModel.updatePerson(otherPerson)
            // 等待数据保存完成
            try await managementViewModel.familyTreeViewModel.dataManager.savePerson(otherPerson)
        }
        
        // 设置并保存当前人物为自己
        var updatedPerson = person
        updatedPerson.isSelf = true
        try await managementViewModel.updatePerson(updatedPerson)
        // 确保数据被保存
        try await managementViewModel.familyTreeViewModel.dataManager.savePerson(updatedPerson)
        print("✅ 已设置新的自己")
        
        // 更新本地状态
        await MainActor.run {
            self.state = PersonCardState.from(updatedPerson)
            objectWillChange.send()
        }
        
        // 重新加载数据（这会同时更新所有人的称呼）
        print("⏳ 重新加载数据")
        await managementViewModel.loadData()
        
        // 再次确认更新
        if let reloadedPerson = managementViewModel.persons.first(where: { $0.id == person.id }) {
            print("✅ 确认更新成功：\(reloadedPerson.firstName)\(reloadedPerson.lastName) isSelf=\(reloadedPerson.isSelf)")
            await MainActor.run {
                self.state = PersonCardState.from(reloadedPerson)
                objectWillChange.send()
            }
        }
        
        print("✅ setSelfPerson 执行完成")
    }
    
    var isSelfPerson: Bool {
        currentPerson?.isSelf ?? false
    }
}
