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
        state.isLoading = true
        defer { 
            state.isLoading = false 
            print("🔧 StateManager[\(instanceId)] - loadInitialData 执行结束 ===")
        }
        
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
        let relationships = state.relationships.filter { relationship in
            switch relationType {
            case .father, .mother:
                return relationship.fromPerson == person.id && 
                       (relationship.type == .father || relationship.type == .mother)
            case .child:
                return relationship.fromPerson == person.id && relationship.type == .child
            case .spouse:
                return (relationship.fromPerson == person.id || relationship.toPerson == person.id) && 
                       relationship.type == .spouse
            case .brother, .sister:
                return relationship.fromPerson == person.id && 
                       (relationship.type == .brother || relationship.type == .sister)
            }
        }
        
        return relationships.compactMap { relationship in
            state.persons.first { $0.id == (relationship.fromPerson == person.id ? relationship.toPerson : relationship.fromPerson) }
        }
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
    
    // 添加更新加载状态的方法
    func updateLoadingState(_ isLoading: Bool) {
        state.isLoading = isLoading
    }
    
}


