
/*
 * PersonCardViewModel 类
 * 作用：管理人物卡片的视图逻辑
 * - 处理人物信息的编辑
 * - 管理称谓的显示和更新
 * - 处理保存和删除操作
 */

import SwiftUI
import Foundation

// 修改 PersonCardViewModel 以使用 RelationshipManager
@MainActor
class PersonCardViewModel: ObservableObject {
    @Published private(set) var state: PersonCardState
    @Published var errorMessage: String?
    
    private let person: Person?
    private let stateManager: StateManager
    private weak var appViewModel: FamilyAppViewModel?  // 添加对 FamilyAppViewModel 的引用
    private let relationshipManager: RelationshipManager
    let mode: PersonCardMode
    
    private var targetPerson: Person? {
        if case .add = mode {
            return stateManager.state.selectedPerson
        }
        return nil
    }    
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
            if let title = relationshipManager.generateTitle(for: person) {
                self.cachedTitle = title
                self.objectWillChange.send()
            }
        }
        
        return "\(person.firstName)\(person.lastName)"
    }
    
    @MainActor
    func updateDisplayTitle() async {
        guard let person = currentPerson else { return }
        if let title = relationshipManager.generateTitle(for: person) {
            cachedTitle = title
            objectWillChange.send()
        }
    }
    
    // 修改初始化方法，添加 appViewModel 参数
    init(person: Person?, mode: PersonCardMode, stateManager: StateManager, appViewModel: FamilyAppViewModel? = nil) {
        self.person = person
        self.mode = mode
        self.stateManager = stateManager
        self.appViewModel = appViewModel
        self.relationshipManager = RelationshipManager(stateManager: stateManager)
        
        // 初始化 state
        if let person = person {
            self.state = PersonCardState.from(person)
        } else {
            var state = PersonCardState.empty()
            // 使用默认值
            if case .add = mode {
                if let currentFamily = stateManager.state.currentFamily {
                    // 如果有默认姓氏就使用，否则使用家谱名称中的姓氏（如果有的话）
                    state.basicInfo.lastName = currentFamily.defaultLastName ?? 
                        String(currentFamily.name.prefix(1))
                }
            }
            self.state = state
        }
        
        Task {
            await updateDisplayTitle()
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    func save() async throws {
        guard let currentFamily = stateManager.state.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault && person != nil {
            throw FamilyError.defaultFamilyNotEditable
        }
        
        if case .add(let relationType) = mode {
            var newPerson = createOrUpdatePerson()
            newPerson.familyId = currentFamily.id
            
            if stateManager.state.persons.isEmpty {
                newPerson.isSelf = true
            }
            
            // 先保存新人物
            try await stateManager.addPerson(newPerson)
            
            if stateManager.state.persons.isEmpty {
                stateManager.selectPerson(newPerson)
            }
            
            // 如果需要添加关系，确保有目标人物
            if let relationType = relationType {
                guard let targetPerson = self.targetPerson else {
                    print("⚠️ 未找到目标人物，跳过添加关系")
                    print("📝 当前模式：\(mode)")
                    print("📝 选中的人物：\(stateManager.state.selectedPerson?.firstName ?? "无")")
                    return
                }
                print("✅ 开始添加关系：从 \(newPerson.firstName) 到 \(targetPerson.firstName)，类型：\(relationType)")
                
                // 根据关系类型调整关系方向
                switch relationType {
                case .father, .mother:
                    // 根据新人物的性别确定正确的关系类型
                    let correctRelationType: RelationType
                    if newPerson.gender == .male {
                        correctRelationType = .father
                    } else {
                        correctRelationType = .mother
                    }
                    
                    // 如果是添加父母，则目标人物是子女，新人物是父母
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,  // 子女关系
                        fromPerson: targetPerson.id,
                        toPerson: newPerson.id
                    ))
                    
                    // 添加反向关系（父亲或母亲）
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: correctRelationType,  // 使用正确的父/母关系类型
                        fromPerson: newPerson.id,
                        toPerson: targetPerson.id
                    ))
                    
                    // 检查是否存在另一个父母，如果存在则添加配偶关系
                    let otherParentType: RelationType = correctRelationType == .father ? .mother : .father
                    if let otherParent = stateManager.getRelatedPersons(for: targetPerson, relationType: otherParentType).first {
                        // 添加配偶关系
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .spouse,
                            fromPerson: newPerson.id,
                            toPerson: otherParent.id
                        ))
                        
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .spouse,
                            fromPerson: otherParent.id,
                            toPerson: newPerson.id
                        ))
                    }
                    
                case .child:
                    // 如果是添加子女，则目标人物是父母，新人物是子女
                    // 根据目标人物的性别确定正确的父母关系类型
                    let parentRelationType: RelationType = targetPerson.gender == .male ? .father : .mother
                    
                    // 添加子女关系
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,
                        fromPerson: newPerson.id,
                        toPerson: targetPerson.id
                    ))
                    
                    // 添加反向关系（父亲或母亲）
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: parentRelationType,
                        fromPerson: targetPerson.id,
                        toPerson: newPerson.id
                    ))
                    
                    // 如果目标人物有配偶，也添加子女关系
                    let spouses = stateManager.getRelatedPersons(for: targetPerson, relationType: .spouse)
                    for spouse in spouses {
                        // 根据配偶的性别确定正确的父母关系类型
                        let spouseRelationType: RelationType = spouse.gender == .male ? .father : .mother
                        
                        // 添加子女关系
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .child,
                            fromPerson: newPerson.id,
                            toPerson: spouse.id
                        ))
                        
                        // 添加反向关系（父亲或母亲）
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: spouseRelationType,
                            fromPerson: spouse.id,
                            toPerson: newPerson.id
                        ))
                    }
                    
                case .spouse:
                    // 配偶关系是双向的
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .spouse,
                        fromPerson: newPerson.id,
                        toPerson: targetPerson.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .spouse,
                        fromPerson: targetPerson.id,
                        toPerson: newPerson.id
                    ))
                    
                    // 如果对方有子女，将新人物也设置为这些子女的父母
                    let children = stateManager.getRelatedPersons(for: targetPerson, relationType: .child)
                    for child in children {
                        // 根据新人物的性别确定正确的父母关系类型
                        let parentRelationType: RelationType = newPerson.gender == .male ? .father : .mother
                        
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .child,
                            fromPerson: child.id,
                            toPerson: newPerson.id
                        ))
                        
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: parentRelationType,
                            fromPerson: newPerson.id,
                            toPerson: child.id
                        ))
                    }
                    
                case .brother, .sister:
                    // 根据新人物的性别确定正确的兄弟姐妹关系类型
                    let siblingRelationType: RelationType = newPerson.gender == .male ? .brother : .sister
                    let targetSiblingRelationType: RelationType = targetPerson.gender == .male ? .brother : .sister
                    
                    // 添加兄弟姐妹关系（双向）
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: siblingRelationType,
                        fromPerson: targetPerson.id,
                        toPerson: newPerson.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: targetSiblingRelationType,
                        fromPerson: newPerson.id,
                        toPerson: targetPerson.id
                    ))
                    
                    // 获取目标人物的父母，将新人物也设置为其子女
                    let fathers = stateManager.getRelatedPersons(for: targetPerson, relationType: .father)
                    let mothers = stateManager.getRelatedPersons(for: targetPerson, relationType: .mother)
                    
                    // 处理父亲关系
                    for father in fathers {
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .child,
                            fromPerson: newPerson.id,
                            toPerson: father.id
                        ))
                        
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .father,
                            fromPerson: father.id,
                            toPerson: newPerson.id
                        ))
                    }
                    
                    // 处理母亲关系
                    for mother in mothers {
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .child,
                            fromPerson: newPerson.id,
                            toPerson: mother.id
                        ))
                        
                        try await stateManager.addRelationship(Relationship(
                            id: UUID(),
                            type: .mother,
                            fromPerson: mother.id,
                            toPerson: newPerson.id
                        ))
                    }
                }
                
                print("✅ 关系添加成功")
            }
        } else if case .edit = mode {
            try await stateManager.updatePerson(createOrUpdatePerson())
        }
        
        // 保存后通知 appViewModel 刷新数据
        await appViewModel?.refreshData()
    }

    private func createOrUpdatePerson() -> Person {
        // 获取当前家谱 ID
        guard let currentFamily = stateManager.state.currentFamily else {
            fatalError("未选择当前家谱")
        }
        
        var person = self.person ?? Person(
            familyId: currentFamily.id,
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
    
    // 保留其他方法，但修改数据访问方式
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
            try? await stateManager.updatePerson(person)
            
            // 通知 appViewModel 刷新数据
            await appViewModel?.refreshData()
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
                try await stateManager.updatePerson(updatedPerson)
                
                // 通知 appViewModel 刷新数据
                await appViewModel?.refreshData()
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
    
    // 添加 isSelfPerson 计算属性
    var isSelfPerson: Bool {
        return currentPerson?.isSelf == true
    }
    
    var currentPerson: Person? {
        person
    }

    
    @MainActor
    func setSelfPerson() async throws {
        guard let person = person else { return }
        
        // 1. 检查当前家谱
        guard let currentFamily = stateManager.state.currentFamily else {
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
        
        // 4. 将之前的"自己"标记取消
        if let oldSelf = stateManager.state.persons.first(where: { $0.isSelf }) {
            var updatedOldSelf = oldSelf
            updatedOldSelf.isSelf = false
            try await stateManager.updatePerson(updatedOldSelf)
        }
        
        // 5. 设置新的"自己"
        var updatedPerson = person
        updatedPerson.isSelf = true
        try await stateManager.updatePerson(updatedPerson)
        
        // 6. 通知 appViewModel 刷新数据
        await appViewModel?.refreshData()
        
        // 7. 重新加载数据
        await reloadData()
    }
    
    
    func deletePerson() async throws {
        guard let person = person else { return }
        
        // 1. 检查当前家谱
        guard let currentFamily = stateManager.state.currentFamily else {
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
        
        try await stateManager.deletePerson(person)
        
        // 删除后通知 appViewModel 刷新数据
        await appViewModel?.refreshData()
    }
    
    @MainActor
    func reloadData() async {
        print("🔄 开始重新加载数据...")
        
        do {
            // 使用 appViewModel 刷新数据
            if let appViewModel = appViewModel {
                await appViewModel.refreshData()
            } else {
                await stateManager.loadInitialData()
            }
            
            // 如果有当前人物，重新加载其数据
            if let personId = person?.id {
                if let updatedPerson = stateManager.state.persons.first(where: { $0.id == personId }) {
                    self.state = PersonCardState.from(updatedPerson)
                    await updateDisplayTitle()
                    print("✅ 人物数据重新加载成功")
                } else {
                    print("⚠️ 未找到当前人物，ID: \(personId)")
                    errorMessage = "未找到当前人物"
                }
            }
        } catch {
            print("❌ 重新加载数据失败: \(error.localizedDescription)")
            errorMessage = "重新加载数据失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 辅助方法
    
    func getRelatedPersons(relationType: RelationType) -> [Person] {
        guard let person = person else { return [] }
        return stateManager.getRelatedPersons(for: person, relationType: relationType)
    }
    
    func hasRelation(of type: RelationType) -> Bool {
        !getRelatedPersons(relationType: type).isEmpty
    }
    
    // 添加一个公开的计算属性来获取人物数量
    var totalPersonsCount: Int {
        return stateManager.state.persons.count
    }
    
    // 添加刷新数据的方法
    @MainActor
    func refreshData() async {
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
}


