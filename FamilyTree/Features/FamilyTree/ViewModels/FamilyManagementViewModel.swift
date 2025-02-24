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
        let (family, persons, relationships) = ExampleData.loadExampleData()
        
        try await dataManager.saveFamily(family)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for person in persons {
                group.addTask {
                    try await self.dataManager.savePerson(person)
                }
            }
            try await group.waitForAll()
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for relationship in relationships {
                group.addTask {
                    try await self.dataManager.saveRelationship(relationship)
                }
            }
            try await group.waitForAll()
        }
        
        await loadFamilies()
    }
    
    func loadFamilies() async {
        do {
            families = try await dataManager.loadFamilies()
            
            if families.isEmpty {
                currentFamily = nil
                persons = []
                return
            }
            
            if currentFamily == nil {
                if let defaultFamily = families.first(where: { $0.isDefault }) {
                    currentFamily = defaultFamily
                    persons = try await dataManager.loadPersons(familyId: defaultFamily.id)
                    
                    // 添加这部分，确保 FamilyTreeViewModel 同步更新
                    if let familyTreeViewModel = familyTreeViewModel {
                        await familyTreeViewModel.refreshAfterFamilySwitch()
                    }
                }
            }
        } catch {
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
            // 1. 先更新当前家谱
            await MainActor.run {
                self.currentFamily = family
            }
            
            // 2. 通知 FamilyTreeViewModel 刷新数据
            if let familyTreeViewModel = familyTreeViewModel {
                await familyTreeViewModel.refreshAfterFamilySwitch()
            } else {
                print("⚠️ FamilyTreeViewModel 未设置")
            }
            
            // 3. 最后加载人物数据
            let loadedPersons = try await dataManager.loadPersons(familyId: family.id)
            await MainActor.run {
                self.persons = loadedPersons
            }
        } catch {
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

