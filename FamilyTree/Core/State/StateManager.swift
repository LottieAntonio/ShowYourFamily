import Foundation
import Combine

@MainActor
class StateManager: ObservableObject {
    @Published private(set) var state: AppState
    private let dataManager: DataManaging
    private let instanceId = UUID().uuidString.prefix(8)  // 添加实例标识符
    
    init(dataManager: DataManaging) {
        print("🔧 StateManager[\(instanceId)] - 初始化")
        self.dataManager = dataManager
        self.state = AppState()
    }
    
    // MARK: - 数据加载
    
    func loadInitialData() async {
        // 防止重复加载
        if state.isInitialized && !state.families.isEmpty {
            print("🔧 StateManager[\(instanceId)] - 数据已初始化，跳过重复加载")
            return
        }
        
        print("🔧 StateManager[\(instanceId)] - loadInitialData 开始执行 ===")
        
        // 使用 withLoading 方法包装加载逻辑
        await withLoading {
            do {
                // 加载家谱列表
                print("🔧 StateManager[\(instanceId)] - 开始加载家谱列表")
                let families = try await dataManager.loadFamilies()
                print("🔧 StateManager[\(instanceId)] - 加载到 \(families.count) 个家谱")
                
                await MainActor.run {
                    state.families = families
                    
                    // 如果有默认家谱，自动选择
                    if let defaultFamily = families.first(where: { $0.isDefault }) {
                        print("🔧 StateManager[\(instanceId)] - 自动选择默认家谱: \(defaultFamily.name)")
                        state.currentFamily = defaultFamily
                    }
                    
                    state.isInitialized = true
                }
                
                // 如果有当前家谱，加载其数据
                if let currentFamily = state.currentFamily {
                    print("🔧 StateManager[\(instanceId)] - 开始加载当前家谱数据: \(currentFamily.name)")
                    try await loadFamilyData(family: currentFamily)
                }
            } catch {
                await MainActor.run {
                    state.error = error
                    print("❌ StateManager[\(instanceId)] - 加载初始数据失败：\(error.localizedDescription)")
                }
            }
        }
        
        print("🔧 StateManager[\(instanceId)] - loadInitialData 执行结束 ===")
    }
    
    // 添加一个辅助方法来处理加载状态
    private func withLoading<T>(_ operation: () async throws -> T) async rethrows -> T {
        // 设置加载状态
        await MainActor.run {
            print("🔧 StateManager[\(instanceId)] - 设置加载状态: true")
            state.isLoading = true
        }
        
        // 执行操作
        do {
            let result = try await operation()
            
            // 清除加载状态
            await MainActor.run {
                print("🔧 StateManager[\(instanceId)] - 设置加载状态: false (成功)")
                state.isLoading = false
            }
            
            return result
        } catch {
            // 发生错误时也清除加载状态
            await MainActor.run {
                print("🔧 StateManager[\(instanceId)] - 设置加载状态: false (错误)")
                state.isLoading = false
            }
            throw error
        }
    }
    
    private func loadFamilyData(family: Family) async throws {
        print("🔧 StateManager[\(instanceId)] - loadFamilyData 开始: \(family.name)")
        
        // 加载家谱成员
        let persons = try await dataManager.loadPersons(familyId: family.id)
        print("🔧 StateManager[\(instanceId)] - 加载到 \(persons.count) 个成员")
        
        // 加载关系数据
        let relationships = try await dataManager.loadRelationships(familyId: family.id)
        print("🔧 StateManager[\(instanceId)] - 加载到 \(relationships.count) 个关系")
        
        await MainActor.run {
            state.persons = persons
            state.relationships = relationships
            
            // 如果没有选中的人物，选择第一个
            if state.selectedPerson == nil {
                if let firstPerson = persons.first {
                    print("🔧 StateManager[\(instanceId)] - 自动选择第一个人物: \(firstPerson.name)")
                    state.selectedPerson = firstPerson
                }
            }
        }
        
        print("🔧 StateManager[\(instanceId)] - loadFamilyData 完成: \(family.name)")
    }
    
    // MARK: - 家谱操作
    
    func selectFamily(_ family: Family) async {
        print("🔧 StateManager[\(instanceId)] - selectFamily: \(family.name), ID: \(family.id)")
        
        guard family.id != state.currentFamily?.id else {
            print("🔧 StateManager[\(instanceId)] - 已经是当前家谱，跳过")
            return
        }
        
        await withLoading {
            print("🔧 StateManager[\(instanceId)] - 切换到新家谱: \(family.name)")
            state.currentFamily = family
            state.persons = []
            state.relationships = []
            state.selectedPerson = nil
            
            do {
                print("🔧 StateManager[\(instanceId)] - 开始加载新家谱数据")
                try await loadFamilyData(family: family)
            } catch {
                state.error = error
                print("❌ StateManager[\(instanceId)] - 加载家谱数据失败：\(error.localizedDescription)")
            }
        }
    }
    
    // 设置当前家谱
    func setCurrentFamily(_ family: Family) async {
        print("🔧 StateManager[\(instanceId)] - setCurrentFamily: \(family.name)")
        await selectFamily(family)
    }
    
    // 添加新家谱
    func addFamily(_ family: Family) async throws {
        print("🔧 StateManager[\(instanceId)] - addFamily: \(family.name)")
        try await dataManager.saveFamily(family)
        await MainActor.run {
            state.families.append(family)
        }
    }
    
    // 从默认家谱创建新家谱
    func createFamilyFromDefault(name: String, description: String) async throws {
        print("🔧 StateManager[\(instanceId)] - createFamilyFromDefault: \(name)")
        
        // 查找默认家谱
        guard let defaultFamily = state.families.first(where: { $0.isDefault }) else {
            print("❌ StateManager[\(instanceId)] - 未找到默认家谱")
            throw FamilyError.defaultFamilyNotFound
        }
        
        // 创建新家谱
        let newFamily = Family(
            id: UUID(),
            name: name,
            description: description,
            isDefault: false
        )
        
        // 保存新家谱
        try await addFamily(newFamily)
        
        // 加载默认家谱的数据
        print("🔧 StateManager[\(instanceId)] - 加载默认家谱数据用于复制")
        let defaultPersons = try await dataManager.loadPersons(familyId: defaultFamily.id)
        let defaultRelationships = try await dataManager.loadRelationships(familyId: defaultFamily.id)
        
        // 复制人物和关系到新家谱
        print("🔧 StateManager[\(instanceId)] - 复制 \(defaultPersons.count) 个人物到新家谱")
        for person in defaultPersons {
            let newPerson = Person(
                id: UUID(),
                familyId: newFamily.id,
                firstName: person.firstName,
                lastName: person.lastName,
                gender: person.gender,
                isSelf: false
            )
            try await dataManager.savePerson(newPerson)
        }
        
        // 设置为当前家谱
        print("🔧 StateManager[\(instanceId)] - 设置新家谱为当前家谱")
        await setCurrentFamily(newFamily)
    }
    
    // 创建空白家谱
    func createEmptyFamily(name: String, description: String) async throws {
        // 修改初始化参数
        let emptyFamily = Family(
            id: UUID(),
            name: name,
            description: description,
            isDefault: false
        )
        
        try await addFamily(emptyFamily)
        await setCurrentFamily(emptyFamily)
    }
    
    // MARK: - 人物操作
    
    func selectPerson(_ person: Person) {
        state.selectedPerson = person
    }
    
    func addPerson(_ person: Person) async throws {
        try await dataManager.savePerson(person)
        await MainActor.run {
            state.persons.append(person)
        }
    }
    
    func updatePerson(_ person: Person) async throws {
        try await dataManager.savePerson(person)
        await MainActor.run {
            if let index = state.persons.firstIndex(where: { $0.id == person.id }) {
                state.persons[index] = person
            }
        }
    }
    
    func deletePerson(_ person: Person) async throws {
        // 传递 person.id 而不是 person 对象
        try await dataManager.deletePerson(person.id)
        await MainActor.run {
            state.persons.removeAll { $0.id == person.id }
            if state.selectedPerson?.id == person.id {
                state.selectedPerson = nil
            }
        }
    }
    
    // MARK: - 关系操作
    
    func addRelationship(_ relationship: Relationship) async throws {
        try await dataManager.saveRelationship(relationship)
        await MainActor.run {
            state.relationships.append(relationship)
        }
    }
    
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        // 防御性检查：确保传入的 person 是有效的
        guard person.id != UUID() else {
            print("⚠️ StateManager[\(instanceId)] - 传入的人物ID无效")
            return []
        }
        
        // 创建一个安全的关系列表副本，避免多线程访问问题
        let safeRelationships = state.relationships
        let safePersons = state.persons
        
        // 处理兄弟姐妹关系 - 不使用递归
        if relationType == .brother || relationType == .sister {
            var siblings = Set<Person>()
            
            // 直接查找父母
            let fatherIds = safeRelationships
                .filter { $0.fromPerson == person.id && $0.type == .father }
                .map { $0.toPerson }
            
            let motherIds = safeRelationships
                .filter { $0.fromPerson == person.id && $0.type == .mother }
                .map { $0.toPerson }
            
            // 通过父亲找兄弟姐妹
            for fatherId in fatherIds {
                // 找到所有以这个父亲为目标的父子关系
                let childrenIds = safeRelationships
                    .filter { $0.toPerson == fatherId && ($0.type == .father || $0.type == .mother) }
                    .map { $0.fromPerson }
                
                // 添加这些子女到兄弟姐妹集合中，排除自己
                for childId in childrenIds where childId != person.id {
                    if let child = safePersons.first(where: { $0.id == childId }) {
                        siblings.insert(child)
                    }
                }
            }
            
            // 通过母亲找兄弟姐妹
            for motherId in motherIds {
                // 找到所有以这个母亲为目标的父子关系
                let childrenIds = safeRelationships
                    .filter { $0.toPerson == motherId && ($0.type == .father || $0.type == .mother) }
                    .map { $0.fromPerson }
                
                // 添加这些子女到兄弟姐妹集合中，排除自己
                for childId in childrenIds where childId != person.id {
                    if let child = safePersons.first(where: { $0.id == childId }) {
                        siblings.insert(child)
                    }
                }
            }
            
            // 根据性别过滤
            return Array(siblings).filter { sibling in
                if relationType == .brother {
                    return sibling.gender == .male
                } else {
                    return sibling.gender == .female
                }
            }
        }
        
        // 处理其他关系类型
        var result = [Person]()
        
        // 根据关系类型筛选关系
        for relationship in safeRelationships {
            // 跳过可能的无效关系
            guard relationship.id != UUID() else { continue }
            
            switch relationType {
            case .father:
                if relationship.fromPerson == person.id && relationship.type == .father {
                    if let father = safePersons.first(where: { $0.id == relationship.toPerson && $0.gender == .male }) {
                        result.append(father)
                    }
                }
                
            case .mother:
                if relationship.fromPerson == person.id && relationship.type == .mother {
                    if let mother = safePersons.first(where: { $0.id == relationship.toPerson && $0.gender == .female }) {
                        result.append(mother)
                    }
                }
                
            case .child:
                if relationship.toPerson == person.id && 
                   (relationship.type == .father || relationship.type == .mother) {
                    if let child = safePersons.first(where: { $0.id == relationship.fromPerson }) {
                        result.append(child)
                    }
                }
                
            case .spouse:
                if relationship.type == .spouse {
                    if relationship.fromPerson == person.id {
                        if let spouse = safePersons.first(where: { $0.id == relationship.toPerson }) {
                            result.append(spouse)
                        }
                    } else if relationship.toPerson == person.id {
                        if let spouse = safePersons.first(where: { $0.id == relationship.fromPerson }) {
                            result.append(spouse)
                        }
                    }
                }
                
            case .brother, .sister:
                // 这部分已经在上面特殊处理了
                break
            }
        }
        
        return result
    }
    
    // MARK: - 辅助方法
    
    // 获取自己的人物
    func getSelfPerson() async -> Person? {
        return state.persons.first { $0.isSelf }
    }
    
    // 获取两个人物之间的关系
    func getRelationships(between person1: Person, and person2: Person) -> [Relationship] {
        return state.relationships.filter { relationship in
            (relationship.fromPerson == person1.id && relationship.toPerson == person2.id) ||
            (relationship.fromPerson == person2.id && relationship.toPerson == person1.id)
        }
    }
    
    // 添加关系的便捷方法
    func addRelationship(from: Person, to: Person, type: RelationType) async throws {
        let relationship = Relationship(
            id: UUID(),
            type: type,
            fromPerson: from.id,
            toPerson: to.id
        )
        try await addRelationship(relationship)
    }

        // 加载特定家谱的成员
    func loadPersons(for familyId: UUID) async throws -> [Person] {
        return try await dataManager.loadPersons(familyId: familyId)
    }
    
    // 加载特定家谱的关系
    func loadRelationships(for familyId: UUID) async throws -> [Relationship] {
        return try await dataManager.loadRelationships(familyId: familyId)
    }
    
    // 修改更新加载状态的方法
    func updateLoadingState(_ isLoading: Bool) {
        print("🔧 StateManager[\(instanceId)] - 手动设置加载状态: \(isLoading)")
        state.isLoading = isLoading
    }
}


