
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
    
    private var person: Person?
    private let stateManager: StateManager
    weak var appViewModel: FamilyAppViewModel?  // 改为公开属性
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
            // 使用appViewModel而不是relationshipManager来生成称谓
            if let appViewModel = appViewModel, let title = appViewModel.generateTitle(for: person) {
                self.cachedTitle = title
                self.objectWillChange.send()
            } else if let title = relationshipManager.generateTitle(for: person) {
                // 如果没有appViewModel，则回退到使用relationshipManager
                self.cachedTitle = title
                self.objectWillChange.send()
            }
        }
        
        // 如果没有称谓，返回姓名（确保姓在前名在后）
        return "\(person.lastName)\(person.firstName)"
    }
    
    @MainActor
    func updateDisplayTitle() async {
        guard let person = currentPerson else { return }
        
        // 使用appViewModel而不是relationshipManager来生成称谓
        if let appViewModel = appViewModel, let title = appViewModel.generateTitle(for: person) {
            cachedTitle = title
            objectWillChange.send()
        } else if let title = relationshipManager.generateTitle(for: person) {
            // 如果没有appViewModel，则回退到使用relationshipManager
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
            
            // 获取目标人物
            let targetPerson = self.targetPerson
            
            // 如果有临时图片ID，从ImagePickerManager中获取图片数据
            if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
               let tempId = UUID(uuidString: tempIdString),
               let imageData = ImagePickerManager.shared.getImageData(for: tempId) {
                
                print("从临时ID获取图片数据: \(tempId)")
                newPerson.photo = imageData
                
                // 使用后清除临时ID
                UserDefaults.standard.removeObject(forKey: "TempPersonPhotoId")
                
                // 将图片数据从临时ID转移到新的personId
                if let image = ImagePickerManager.shared.getImage(for: tempId) {
                    ImagePickerManager.shared.clearCache(for: tempId)
                    ImagePickerManager.shared.setImage(for: newPerson.id, image: image, data: imageData)
                    print("图片数据已从临时ID转移到新personId: \(newPerson.id)")
                }
            }
            
            // 委托给 PersonManagementViewModel 处理添加人物和关系的逻辑
            if let personManager = appViewModel?.personManager {
                try await personManager.addPersonWithRelationship(
                    newPerson,
                    relationType: relationType,
                    targetPerson: targetPerson
                )
            } else {
                // 如果没有 personManager，则使用原来的逻辑
                var personToSave = newPerson
                personToSave.familyId = currentFamily.id
                
                if stateManager.state.persons.isEmpty {
                    personToSave.isSelf = true
                }
                
                try await stateManager.addPerson(personToSave)
                
                if stateManager.state.persons.isEmpty {
                    stateManager.selectPerson(personToSave)
                }
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
        
        // 使用state中的照片数据
        person.photo = state.photo
        
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
                } else {
                    errorMessage = "未找到当前人物"
                }
            }
        } catch {
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
        
        // 重新加载当前人物数据
        await reloadData()
        
        // 强制刷新UI
        objectWillChange.send()
    }

    // 修改updatePhoto方法
    @MainActor
    func updatePhoto(data: Data) async {
        print("PersonCardViewModel.updatePhoto 开始执行，模式: \(mode)")
        
        switch mode {
        case .add(let relationType):
            print("Add模式: 更新state中的照片")
            // 在add模式下，只更新state
            var newState = state
            newState.photo = data
            state = newState
            
            // 强制刷新UI
            objectWillChange.send()
            
            // 检查是否已有临时ID
            if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
               let tempId = UUID(uuidString: tempIdString) {
                // 如果已有临时ID，则使用现有临时ID
                print("Add模式: 使用现有临时ID: \(tempId)")
                
                // 将图片保存到ImagePickerManager中
                if let image = UIImage(data: data) {
                    ImagePickerManager.shared.setImage(for: tempId, image: image, data: data)
                    print("Add模式: 更新临时ID的图片: \(tempId)")
                    
                    // 发送通知，让所有PersonAvatarView知道有新的临时图片
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TempPhotoUpdated"),
                        object: nil,
                        userInfo: ["tempId": tempId, "forceRefresh": true]
                    )
                }
            } else {
                // 如果没有临时ID，则创建新的临时ID
                let tempPersonId = UUID()
                print("Add模式: 创建临时personId: \(tempPersonId)")
                
                // 将图片保存到ImagePickerManager中
                if let image = UIImage(data: data) {
                    ImagePickerManager.shared.setImage(for: tempPersonId, image: image, data: data)
                    print("Add模式: 图片已保存到ImagePickerManager，tempPersonId: \(tempPersonId)")
                    
                    // 将临时ID保存到UserDefaults，以便在创建person时使用
                    UserDefaults.standard.set(tempPersonId.uuidString, forKey: "TempPersonPhotoId")
                    
                    // 添加通知，让所有PersonAvatarView知道有新的临时图片
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TempPhotoUpdated"),
                        object: nil,
                        userInfo: ["tempId": tempPersonId]
                    )
                }
            }
            
            // 通知刷新
            NotificationCenter.default.post(name: NSNotification.Name("RefreshPersonData"), object: nil)
            print("Add模式: 发送刷新通知")
            
        case .edit:
            // 编辑模式的处理逻辑
            guard var updatedPerson = currentPerson else {
                print("错误: currentPerson为nil")
                return
            }
            
            // 立即更新本地person对象
            updatedPerson.photo = data
            self.person = updatedPerson
            
            // 立即更新state
            var newState = state
            newState.photo = data
            state = newState
            
            // 强制刷新UI
            objectWillChange.send()
            print("本地状态已更新，开始保存到数据库")
            
            do {
                // 异步更新数据库
                try await stateManager.updatePerson(updatedPerson)
                print("数据库更新成功")
                
                // 清除缓存
                cachedTitle = nil
                
                // 清除ImagePickerManager中的缓存，确保下次从数据库重新加载
                ImagePickerManager.shared.clearCache(for: updatedPerson.id)
                
                // 再次强制刷新UI
                objectWillChange.send()
                
                // 通知appViewModel刷新数据
                if let appViewModel = appViewModel {
                    print("通知appViewModel刷新数据")
                    await appViewModel.refreshData()
                }
                
                // 重新加载数据以确保一致性
                print("重新加载数据")
                await reloadData()
                
                // 最后一次强制刷新UI
                objectWillChange.send()
                print("照片更新完成")
            } catch {
                errorMessage = "更新照片失败: \(error.localizedDescription)"
                print("更新照片失败: \(error)")
            }
            
        case .view:
            // 查看模式下不应该调用此方法，但为了switch语句完整性添加此分支
            print("警告: 在查看模式下尝试更新照片")
            break
        }
        
        print("照片已更新到ViewModel")
    }
}


