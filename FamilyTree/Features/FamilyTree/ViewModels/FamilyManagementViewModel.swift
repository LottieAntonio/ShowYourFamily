import Foundation

@MainActor
class FamilyManagementViewModel: ObservableObject {
    @Published private(set) var families: [Family] = []
    @Published var persons: [Person] = []  // 添加 persons 属性
    @Published private(set) var currentFamily: Family?
    @Published private(set) var errorMessage: String?
    
    private let dataManager: DataManaging
    weak var familyTreeViewModel: FamilyTreeViewModel?  // 改为 weak 引用
    
    public init(dataManager: DataManaging = LocalDataManager()) {
        self.dataManager = dataManager
    }
    
    // 添加设置 FamilyTreeViewModel 的方法
    func setFamilyTreeViewModel(_ viewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = viewModel
    }
    
    // 添加公开的初始化方法
    func initialize() async throws {
        print("\n=== FamilyManagementViewModel 初始化开始 ===")
        print("🔄 执行数据初始化...")
        
        // 加载示例数据
        print("📥 加载示例数据...")
        let (family, persons, relationships) = ExampleData.loadExampleData()
        
        // 保存数据
        print("💾 保存示例数据...")
        
        // 先保存家谱
        print("📝 保存家谱...")
        try await dataManager.saveFamily(family)
        
        // 保存人物数据
        print("👥 保存 \(persons.count) 个成员...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for person in persons {
                group.addTask {
                    try await self.dataManager.savePerson(person)
                    print("✅ 成功保存成员：\(person.firstName) \(person.lastName)")
                }
            }
            try await group.waitForAll()
        }
        
        // 保存关系数据
        print("🔗 保存 \(relationships.count) 个关系...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for relationship in relationships {
                group.addTask {
                    try await self.dataManager.saveRelationship(relationship)
                    print("✅ 成功保存关系：\(relationship.type.rawValue)")
                }
            }
            try await group.waitForAll()
        }
        
        print("✅ 数据初始化完成")
        print("=== FamilyManagementViewModel 初始化结束 ===\n")
        
        // 重新加载数据以确保更新
        await loadFamilies()
    }
    
    // 修改 loadFamilies 方法
    func loadFamilies() async {
        print("\n=== FamilyManagementViewModel.loadFamilies 开始执行 ===")
        do {
            print("📥 开始加载家谱数据...")
            families = try await dataManager.loadFamilies()
            print("✅ 加载成功：\(families.count) 个家谱")
            
            // 如果没有家谱，不要自动初始化
            if families.isEmpty {
                print("ℹ️ 没有找到任何家谱")
                currentFamily = nil
                persons = []
                return
            }
            
            // 只在当前没有选中家谱时，才自动选择默认家谱
            if currentFamily == nil {
                if let defaultFamily = families.first(where: { $0.isDefault }) {
                    print("🎯 找到默认家谱：\(defaultFamily.name)")
                    currentFamily = defaultFamily
                    
                    // 加载该家谱的所有成员
                    print("👥 加载家谱成员...")
                    persons = try await dataManager.loadPersons(familyId: defaultFamily.id)
                    print("✅ 成功加载 \(persons.count) 个成员")
                }
            }
            print("=== FamilyManagementViewModel.loadFamilies 执行完成 ===\n")
        } catch {
            print("❌ 加载失败：\(error.localizedDescription)")
            setError(error.localizedDescription)
        }
    }
    
    func createFamilyFromDefault() async throws {
        // 检查是否已经有非默认家谱
        if families.contains(where: { !$0.isDefault }) {
            throw FamilyError.userFamilyAlreadyExists
        }
        
        // 创建新家谱
        let newFamily = Family(
            name: "我的家谱",
            description: "这是我的家谱",
            isDefault: false
        )
        
        // 保存新家谱
        try await dataManager.saveFamily(newFamily)
        
        // 如果有示例家谱并且用户想要复制数据，则复制数据
        if let defaultFamily = families.first(where: { $0.isDefault }) {
            // 复制默认家谱的数据
            let defaultPersons = try await dataManager.loadPersons(familyId: defaultFamily.id)
            let defaultRelationships = try await dataManager.loadRelationships(familyId: defaultFamily.id)
            
            // 复制并保存人物数据
            var newPersonIds: [UUID: UUID] = [:]
            
            // 先复制所有人物并保存新旧 ID 的映射关系
            for person in defaultPersons {
                let newId = UUID()
                newPersonIds[person.id] = newId
                
                // 使用初始化方法创建新的 Person
                let newPerson = Person(
                    id: newId,
                    familyId: newFamily.id,
                    firstName: person.firstName,
                    lastName: person.lastName,
                    gender: person.gender
                )
                
                try await dataManager.savePerson(newPerson)
            }
            
            // 使用新的 ID 复制关系
            for relationship in defaultRelationships {
                guard let newFromId = newPersonIds[relationship.fromPerson],
                      let newToId = newPersonIds[relationship.toPerson] else {
                    continue
                }
                
                let newRelationship = Relationship(
                    id: UUID(),
                    type: relationship.type,
                    fromPerson: newFromId,
                    toPerson: newToId
                )
                try await dataManager.saveRelationship(newRelationship)
            }
        }
        
        // 重新加载数据
        await loadFamilies()
        await switchFamily(newFamily)
    }
    
    // 添加创建空白家谱的方法
    func createEmptyFamily(name: String, description: String) async throws {
        // 检查是否已经有非默认家谱
        if families.contains(where: { !$0.isDefault }) {
            throw FamilyError.userFamilyAlreadyExists
        }
        
        // 创建新家谱
        let newFamily = Family(
            name: name,
            description: description,
            isDefault: false
        )
        
        // 保存新家谱
        try await dataManager.saveFamily(newFamily)
        
        // 重新加载数据
        await loadFamilies()
        currentFamily = newFamily
    }
    
    func createFamilyFromDefault(name: String, description: String) async throws {
        // 检查是否已经有非默认家谱
        if families.contains(where: { !$0.isDefault }) {
            throw FamilyError.userFamilyAlreadyExists
        }
        
        // 创建新家谱
        let newFamily = Family(
            name: name,
            description: description,
            isDefault: false
        )
        
        // 保存新家谱
        try await dataManager.saveFamily(newFamily)
        
        // 如果有示例家谱，复制其数据
        if let defaultFamily = families.first(where: { $0.isDefault }) {
            // 复制默认家谱的数据
            let defaultPersons = try await dataManager.loadPersons(familyId: defaultFamily.id)
            let defaultRelationships = try await dataManager.loadRelationships(familyId: defaultFamily.id)
            
            // 复制并保存人物数据
            var newPersonIds: [UUID: UUID] = [:]
            
            for person in defaultPersons {
                let newId = UUID()
                newPersonIds[person.id] = newId
                
                // 修改这里，只使用必需的参数
                let newPerson = Person(
                    id: newId,
                    familyId: newFamily.id,
                    firstName: person.firstName,
                    lastName: person.lastName,
                    gender: person.gender
                )
                
                try await dataManager.savePerson(newPerson)
            }
            
            // 使用新的 ID 复制关系
            for relationship in defaultRelationships {
                guard let newFromId = newPersonIds[relationship.fromPerson],
                      let newToId = newPersonIds[relationship.toPerson] else {
                    continue
                }
                
                let newRelationship = Relationship(
                    id: UUID(),
                    type: relationship.type,
                    fromPerson: newFromId,
                    toPerson: newToId
                )
                try await dataManager.saveRelationship(newRelationship)
            }
        }
        
        // 重新加载数据
        await loadFamilies()
        currentFamily = newFamily
    }
    
    // 修改 switchFamily 方法
    func switchFamily(_ family: Family) async {
        do {
            print("🔄 开始切换家谱：\(family.name)")
            
            // 1. 先加载该家谱的数据
            let loadedPersons = try await dataManager.loadPersons(familyId: family.id)
            print("📊 成功加载 \(loadedPersons.count) 个成员")
            
            await MainActor.run {
                // 2. 更新状态
                self.currentFamily = family
                self.persons = loadedPersons
                print("✅ 已设置当前家谱：\(family.name)")
            }
            
            // 3. 通知 FamilyTreeViewModel 刷新数据
            if let familyTreeViewModel = familyTreeViewModel {
                await familyTreeViewModel.refreshAfterFamilySwitch()
                print("✅ FamilyTreeViewModel 已更新")
            } else {
                print("⚠️ FamilyTreeViewModel 未设置")
            }
        } catch {
            print("❌ 切换家谱失败：\(error.localizedDescription)")
            setError(error.localizedDescription)
        }
    }
    
    // 添加设置错误信息的方法
    func setError(_ message: String) {
        errorMessage = message
    }
    
        
       
        var localDataManager: DataManaging {
            return dataManager
        }
    
    // 添加公开方法来加载特定家谱的成员和关系
    func loadPersonsForFamily(_ familyId: UUID) async throws -> [Person] {
        return try await dataManager.loadPersons(familyId: familyId)
    }
    
    func loadRelationships(for familyId: UUID) async throws -> [Relationship] {
        return try await dataManager.loadRelationships(familyId: familyId)
    }
}

