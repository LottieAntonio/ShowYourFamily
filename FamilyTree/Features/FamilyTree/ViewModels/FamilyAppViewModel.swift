import Foundation
import Combine

@MainActor
class FamilyAppViewModel: ObservableObject {
    // 核心状态
    @Published var currentFamily: Family?
    @Published var persons: [Person] = []
    @Published var relationships: [Relationship] = []
    @Published var selectedPerson: Person?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 所有子模块 ViewModel
    let familyManager: FamilyManagementViewModel
    let personManager: PersonManagementViewModel
    let familyTreeViewModel: FamilyTreeViewModel
    let familyGraphViewModel: FamilyGraphViewModel
    let membersViewModel: MembersViewModel
    
    // PersonCardViewModel 和 PersonEditViewModel 是根据需要创建的，不需要持久持有
    
    private let dataManager: DataManaging
    private let stateManager: StateManager
    private var cancellables = Set<AnyCancellable>()
    
    // 移除单例相关的变量
    
    // 修改初始化方法，直接创建所有依赖
    private let relationshipManager: RelationshipManager
    
    // 改为公开初始化方法
    init(dataManager: DataManaging = DataManager.shared) {
        self.dataManager = dataManager
        self.stateManager = StateManager(dataManager: dataManager)
        
        // 初始化 RelationshipManager
        self.relationshipManager = RelationshipManager(stateManager: stateManager)
        
        // 所有 ViewModel 共享同一个 StateManager，但先不传递 self
        self.familyManager = FamilyManagementViewModel(stateManager: stateManager)
        self.personManager = PersonManagementViewModel(stateManager: stateManager)
        self.familyTreeViewModel = FamilyTreeViewModel(stateManager: stateManager)
        self.familyGraphViewModel = FamilyGraphViewModel(stateManager: stateManager)
        // 先创建 membersViewModel，不传入 self
        self.membersViewModel = MembersViewModel(stateManager: stateManager)
        
        // 设置状态同步
        setupBindings()
        
        // 初始化完成后，设置所有需要的 appViewModel 引用
        self.familyManager.setAppViewModel(self)
        self.membersViewModel.updateAppViewModel(self)
        
    }
    
    private func setupBindings() {
        // 监听 StateManager 的状态变化
        stateManager.$state
            .sink { [weak self] state in
                self?.currentFamily = state.currentFamily
                self?.persons = state.persons
                self?.relationships = state.relationships
                self?.selectedPerson = state.selectedPerson
                // 同步加载状态
                self?.isLoading = state.isLoading
            }
            .store(in: &cancellables)
        
        // 监听 familyManager 的状态变化
        familyManager.$currentFamily
            .sink { [weak self] family in
                // 当家谱变化时，刷新所有相关 ViewModel 的数据
                if let family = family, family.id != self?.currentFamily?.id {
                    Task {
                        await self?.refreshAllViewModels(for: family)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - ViewModel 工厂方法
    
    func createPersonCardViewModel(for person: Person?, mode: PersonCardMode) -> PersonCardViewModel {
        return PersonCardViewModel(person: person, mode: mode, stateManager: stateManager)
    }
    
    func createPersonEditViewModel(for person: Person) -> PersonEditViewModel {
        return PersonEditViewModel(person: person, stateManager: stateManager)
    }
    
    // MARK: - 数据刷新方法
    
    private func refreshAllViewModels(for family: Family) async {
        // 不再手动设置 isLoading，而是通过 StateManager 来控制
        errorMessage = nil
        
        do {
            // 先通知 StateManager 切换家谱
            await stateManager.selectFamily(family)
            
            // 并行刷新必要的数据
            async let familyTreeTask = familyTreeViewModel.loadData()
            async let personManagerTask = personManager.loadData()
            
            // 等待基础数据加载完成
            try await (familyTreeTask, personManagerTask)
            
        } catch {
            errorMessage = "数据刷新失败：\(error.localizedDescription)"
        }
    }
    
    func loadInitialData() async {
        // 防止重复加载
        if !persons.isEmpty && currentFamily != nil {
            return
        }
        
        // 通过 StateManager 控制加载状态
        stateManager.updateLoadingState(true)
        errorMessage = nil
        
        do {
            // 加载家谱列表
            await familyManager.loadFamilies()
            
            // 如果有当前家谱，加载其数据
            if let family = familyManager.currentFamily {
                await refreshAllViewModels(for: family)
            } else if let firstFamily = familyManager.families.first {
                // 自动选择第一个家谱
                await familyManager.switchFamily(firstFamily)
            }
        } catch {
            errorMessage = "初始数据加载失败：\(error.localizedDescription)"
        }
        
        stateManager.updateLoadingState(false)
    }
    
    // MARK: - 公共方法
    
    func switchFamily(_ family: Family) async {
        await familyManager.switchFamily(family)
    }
    
    func refreshData() async {
        if let family = currentFamily {
            await refreshAllViewModels(for: family)
        }
    }
    
    // 添加获取 stateManager 的方法
    func getStateManager() -> StateManager {
        return stateManager
    }
    
    // 添加公共方法
    func generateTitle(for person: Person) -> String? {
        return relationshipManager.generateTitle(for: person)
    }
    
    func getRelationshipDescription(from source: Person, to target: Person) -> String {
        return relationshipManager.getRelationshipDescription(from: source, to: target)
    }
    
    // 添加一个方法来重置所有称谓生成器
    // 重置称谓生成器
    // 简化重置称谓生成器的方法
    // 优化重置称谓生成器的方法
    // 添加一个新方法，结合重置称谓生成器和刷新数据
    func resetTitleGeneratorsAndRefresh() async {
        print("FamilyAppViewModel: 开始重置称谓生成器和刷新数据")
        
        // 1. 先刷新数据，确保使用最新数据
        await refreshData()
        
        // 2. 重置关系管理器中的称谓生成器
        relationshipManager.resetTitleGenerator()
        print("FamilyAppViewModel: 称谓生成器已重置")
        
        // 3. 发送单一通知，让所有视图更新
        DispatchQueue.main.async {
            // 发送重置称谓缓存通知
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetTitleCache"),
                object: nil
            )
            print("FamilyAppViewModel: 已发送ResetTitleCache通知")
            
            // 延迟一点发送刷新通知，确保称谓缓存已被重置
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshPersonData"),
                    object: nil
                )
                print("FamilyAppViewModel: 已发送RefreshPersonData通知")
            }
        }
    }
    
    // 简化原有的resetTitleGenerators方法
    func resetTitleGenerators() {
        print("FamilyAppViewModel: 开始重置称谓生成器")
        relationshipManager.resetTitleGenerator()
        print("FamilyAppViewModel: 称谓生成器已重置")
    }
}
