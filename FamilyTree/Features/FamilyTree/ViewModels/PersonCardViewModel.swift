
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
    
    private let person: Person?
    private let managementViewModel: PersonManagementViewModel
    let mode: PersonCardMode
    // 添加 targetPerson 属性
    // 修改 targetPerson 属性
    private var targetPerson: Person? {
        if case .add = mode {
            // 使用 managementViewModel 的 selectedPerson 作为目标人物
            return managementViewModel.selectedPerson
        }
        return nil
    }
    
    // 删除 isLoading 和 isSettingSelf
    
    // 添加公开的访问器
    var personManagementViewModel: PersonManagementViewModel {
        managementViewModel
    }
    
    // 修改称呼缓存的实现
    @Published private var cachedTitle: String?
    
    var displayTitle: String {
        guard let person = currentPerson else { return "未知" }
        
        // 如果是自己，直接返回"自己"
        if person.isSelf {
            return "自己"
        }
        
        // 如果有缓存的称谓，返回缓存
        if let cached = cachedTitle {
            return cached
        }
        
        // 触发异步更新
        Task { @MainActor in
            if let title = managementViewModel.titleGenerator.generateTitle(for: person) {
                self.cachedTitle = title
                self.objectWillChange.send()
            }
        }
        
        // 修改这里：返回人物姓名而不是"计算中"的提示
        return "\(person.firstName)\(person.lastName)"
    }
    
    @MainActor
    func updateDisplayTitle() async {
        guard let person = currentPerson else { return }
        if let title = managementViewModel.titleGenerator.generateTitle(for: person) {
            cachedTitle = title
            objectWillChange.send()
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
        Task {
            await updateDisplayTitle()
        }
        // 清除默认值
        Task {
            await managementViewModel.setDefaultValues()
        }
    }
    
    // MARK: - Actions
    
    // 将 private 改为 internal（默认访问级别）
    @MainActor
    func save() async throws {
        guard let familyManager = managementViewModel.familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault && person != nil {
            throw FamilyError.defaultFamilyNotEditable
        }
        
        if case .add(let relationType) = mode {
            var newPerson = createOrUpdatePerson()
            newPerson.familyId = currentFamily.id
            
            if managementViewModel.persons.isEmpty {
                newPerson.isSelf = true
            }
            
            // 先保存新人物
            try await managementViewModel.updatePerson(newPerson)
            
            if managementViewModel.persons.isEmpty {
                managementViewModel.selectedPerson = newPerson
            }
            
            // 如果需要添加关系，确保有目标人物
            if let relationType = relationType {
                guard let targetPerson = self.targetPerson else {
                    print("⚠️ 未找到目标人物，跳过添加关系")
                    print("📝 当前模式：\(mode)")
                    print("📝 选中的人物：\(managementViewModel.selectedPerson?.firstName ?? "无")")
                    return
                }
                print("✅ 开始添加关系：从 \(newPerson.firstName) 到 \(targetPerson.firstName)，类型：\(relationType)")
                
                // 根据关系类型调整关系方向
                switch relationType {
                case .father, .mother:
                    // 如果是添加父母，则目标人物是子女，新人物是父母
                    try await managementViewModel.addRelationship(from: targetPerson, to: newPerson, type: relationType)
                    
                    // 检查是否存在另一个父母，如果存在则添加配偶关系
                    let otherParentType: RelationType = relationType == .father ? .mother : .father
                    if let otherParent = managementViewModel.relationshipService.getRelatedPersons(
                        for: targetPerson,
                        relationType: otherParentType
                    ).first {
                        // 添加配偶关系
                        try await managementViewModel.addRelationship(from: newPerson, to: otherParent, type: .spouse)
                    }
                    
                case .child:
                    // 如果是添加子女，则目标人物是父母，新人物是子女
                    try await managementViewModel.addRelationship(from: newPerson, to: targetPerson, type: relationType)
                    
                    // 如果目标人物有配偶，也添加子女关系
                    let spouses = managementViewModel.relationshipService.getRelatedPersons(
                        for: targetPerson,
                        relationType: .spouse
                    )
                    for spouse in spouses {
                        try await managementViewModel.addRelationship(from: newPerson, to: spouse, type: relationType)
                    }
                    
                case .spouse:
                    // 配偶关系是双向的
                    try await managementViewModel.addRelationship(from: newPerson, to: targetPerson, type: .spouse)
                    try await managementViewModel.addRelationship(from: targetPerson, to: newPerson, type: .spouse)
                    
                    // 如果对方有子女，将新人物也设置为这些子女的父母
                    let children = managementViewModel.relationshipService.getRelatedPersons(
                        for: targetPerson,
                        relationType: .child
                    )
                    for child in children {
                        try await managementViewModel.addRelationship(
                            from: child,
                            to: newPerson,
                            type: newPerson.gender == .male ? .father : .mother
                        )
                    }
                    
                case .brother, .sister:
                    // 兄弟姐妹关系
                    try await managementViewModel.addRelationship(from: newPerson, to: targetPerson, type: relationType)
                    try await managementViewModel.addRelationship(from: targetPerson, to: newPerson, type: relationType)
                    
                    // 获取目标人物的父母，将新人物也设置为其子女
                    let parents = managementViewModel.relationshipService.getRelatedPersons(
                        for: targetPerson,
                        relationType: .father
                    ) + managementViewModel.relationshipService.getRelatedPersons(
                        for: targetPerson,
                        relationType: .mother
                    )
                    
                    for parent in parents {
                        try await managementViewModel.addRelationship(
                            from: newPerson,
                            to: parent,
                            type: parent.gender == .male ? .father : .mother
                        )
                    }
                }
                
                print("✅ 关系添加成功")
            }
        } else if case .edit = mode {
            try await managementViewModel.updatePerson(createOrUpdatePerson())
        }
    }
    
    private func createOrUpdatePerson() -> Person {
        // 获取当前家谱 ID
        guard let familyManager = managementViewModel.familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            fatalError("未选择当前家谱")  // 在实际开发中应该抛出错误而不是使用 fatalError
        }
        
        var person = self.person ?? Person(
            familyId: currentFamily.id,  // 使用确定存在的 familyId
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
        // 1. 更新本地状态
        var newState = state
        newState.basicInfo.notes = notes
        state = newState
        
        // 2. 更新 Person 模型
        if var person = self.person {
            person.notes = notes.isEmpty ? nil : notes
            try? await managementViewModel.updatePerson(person)
        }
        
        // 3. 清除称谓缓存，强制重新计算
        cachedTitle = nil
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
    // 修改 deletePerson 方法
       func deletePerson() async throws {
           guard let person = person else { return }
           
           // 1. 检查当前家谱
           guard let familyManager = managementViewModel.familyTreeViewModel.familyManager,
                 let currentFamily = familyManager.currentFamily else {
               throw FamilyError.noCurrentFamily
           }
           
           // 2. 检查是否是默认家谱
           if currentFamily.isDefault {
               throw FamilyError.cannotModifyDefaultFamily
           }
           
           // 3. 检查人物是否属于当前家谱
           if person.familyId != currentFamily.id {
               throw FamilyError.personNotInCurrentFamily
           }
           
           try await managementViewModel.deletePerson(person)
       }
    
    // 添加称呼生成器
    private var titleGenerator: RelativeTitleGenerator {
        RelativeTitleGenerator(
            relationships: managementViewModel.relationships,
            persons: managementViewModel.persons
        )
    }
   
    
    @MainActor
    func reloadData() async {
        guard managementViewModel.familyTreeViewModel.familyManager != nil else {
            print("⚠️ FamilyTreeViewModel 未设置")
            return
        }
        
        print("🔄 开始重新加载数据...")
        
        do {
            try await managementViewModel.familyTreeViewModel.loadData()
            
            if let person = managementViewModel.persons.first(where: { $0.id == currentPerson?.id }) {
                self.state = PersonCardState.from(person)
                objectWillChange.send()
                print("✅ 数据加载完成：\(managementViewModel.persons.count) 个成员")
            } else {
                print("⚠️ 未找到当前人物")
            }
        } catch {
            print("❌ 加载数据失败：\(error.localizedDescription)")
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
    @MainActor
    func setSelf() async {
        if currentPerson != nil {
            // 使用已有的 setSelfPerson 方法
            try? await setSelfPerson()
            // 重新加载数据以更新称呼
            try? await managementViewModel.familyTreeViewModel.loadData()  // 修改这里
        }
    }
    
    // 修改 setSelfPerson 方法中的错误类型
    func setSelfPerson() async throws {
        guard let person = currentPerson else { return }
        
        // 1. 检查当前家谱
        guard let familyManager = managementViewModel.familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        // 2. 检查是否是默认家谱
        if currentFamily.isDefault {
            throw FamilyError.defaultFamilyNotEditable  // 修改这里
        }
        
        // 3. 检查人物是否属于当前家谱
        if person.familyId != currentFamily.id {
            throw FamilyError.personNotInCurrentFamily
        }
        
        // 先清除其他人的自己标记并等待完成
        for var otherPerson in managementViewModel.persons where otherPerson.id != person.id && otherPerson.isSelf {
            print("⏳ 清除其他人的自己标记：\(otherPerson.firstName)\(otherPerson.lastName)")
            otherPerson.isSelf = false
            try await managementViewModel.updatePerson(otherPerson)
            // 等待数据保存完成
            try await managementViewModel.familyTreeViewModel.dataManager.savePerson(otherPerson)
        }
        
        // 设置并保存当前人物为自己，同时清空 notes
        var updatedPerson = person
        updatedPerson.isSelf = true
        updatedPerson.notes = ""  // 清空 notes
        try await managementViewModel.updatePerson(updatedPerson)
        // 确保数据被保存
        try await managementViewModel.familyTreeViewModel.dataManager.savePerson(updatedPerson)
        print("✅ 已设置新的自己")
        
        // 更新本地状态
        await MainActor.run {
            var newState = state
            newState.basicInfo.notes = ""  // 同时更新本地状态的 notes
            self.state = newState
            self.objectWillChange.send()
        }
        
        // 重新加载数据（这会同时更新所有人的称呼）
        print("⏳ 重新加载数据")
        try await managementViewModel.familyTreeViewModel.loadData()  // 修改这里，明确指定调用路径
        
        // 通知所有相关视图模型更新
        try await managementViewModel.familyTreeViewModel.loadData()
        
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

    private func handleFamilyError(_ error: Error) {
        if let familyError = error as? FamilyError {
            switch familyError {
            case .noCurrentFamily:
                errorMessage = "请先选择一个家谱"
            case .defaultFamilyNotEditable:
                errorMessage = "示例家谱不可修改"
            case .personNotInCurrentFamily:
                errorMessage = "该人物不属于当前家谱"
            default:
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    var isSelfPerson: Bool {
        currentPerson?.isSelf ?? false
    }
}
