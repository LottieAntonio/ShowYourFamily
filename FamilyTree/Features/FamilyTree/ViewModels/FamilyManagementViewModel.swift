import Foundation
import Combine

@MainActor
class FamilyManagementViewModel: ObservableObject {
    @Published private(set) var families: [Family] = []
    @Published private(set) var currentFamily: Family?
    @Published private(set) var errorMessage: String?
    @Published private(set) var memberCount: Int = 0
    
    private let stateManager: StateManager
    // 添加对 FamilyAppViewModel 的弱引用
    private weak var appViewModel: FamilyAppViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    // 修改初始化方法，移除 appViewModel 参数
    init(stateManager: StateManager) {
        self.stateManager = stateManager
        setupBindings()
    }
    
    // 添加设置 appViewModel 的方法
    func setAppViewModel(_ viewModel: FamilyAppViewModel) {
        self.appViewModel = viewModel
    }
    
    private func setupBindings() {
        // 保持现有的绑定逻辑
        stateManager.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                
                self.families = state.families
                self.currentFamily = state.currentFamily
                
                // 更新成员数量
                if let currentFamily = state.currentFamily {
                    self.memberCount = state.persons.count
                }
            }
            .store(in: &cancellables)
    }
    
    // 添加加载成员数量的方法
    func loadMemberCount(for familyId: UUID) async {
        do {
            let persons = try await loadPersonsForFamily(familyId)
            await MainActor.run {
                if let currentFamily = currentFamily, currentFamily.id == familyId {
                    self.memberCount = persons.count
                }
            }
        } catch {
            print("加载成员数量失败: \(error.localizedDescription)")
        }
    }
    
    // 添加加载家谱成员的方法
    func loadPersonsForFamily(_ familyId: UUID) async throws -> [Person] {
        // 使用 stateManager 提供的方法而不是直接访问 dataManager
        return try await stateManager.loadPersons(for: familyId)
    }
    
    // 添加加载关系的方法
    func loadRelationships(for familyId: UUID) async throws -> [Relationship] {
        // 使用 stateManager 提供的方法而不是直接访问 dataManager
        return try await stateManager.loadRelationships(for: familyId)
    }
    
    func loadFamilies() async {
        // 使用 stateManager 的 loadInitialData 方法
        await stateManager.loadInitialData()
    }
    
    // 删除这个重复的方法
    // func createFamilyFromDefault(name: String, description: String) async throws {
    //     // 创建一个新的家谱并添加到 stateManager
    //     let newFamily = Family(
    //         id: UUID(),
    //         name: name,
    //         description: description,
    //         isDefault: false
    //     )
    //     try await stateManager.addFamily(newFamily)
    //     await stateManager.setCurrentFamily(newFamily)
    // }
    
    // 添加创建空白家谱的方法
    func createEmptyFamily(name: String, description: String) async throws {
        // 创建一个空白家谱
        let emptyFamily = Family(
            id: UUID(),
            name: name,
            description: description,
            isDefault: false
        )
        try await stateManager.addFamily(emptyFamily)
        await stateManager.setCurrentFamily(emptyFamily)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
    
    func createFamilyFromDefault(name: String, description: String) async throws {
        try await stateManager.createFamilyFromDefault(name: name, description: description)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
    
    // 添加切换家谱的方法
    func switchFamily(_ family: Family) async {
        // 使用 stateManager 切换当前家谱
        await stateManager.selectFamily(family)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
}

