import SwiftUI
import Combine

// 添加对 appViewModel 的访问
@MainActor
class MembersViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?
    @Published private var titleCache: [UUID: String] = [:] // 称谓缓存
    
    private var stateManager: StateManager
    private weak var appViewModel: FamilyAppViewModel?  // 使用 weak 引用避免循环引用
    private var cancellables = Set<AnyCancellable>()
    private let titleGenerator: RelativeTitleGenerator
    
    // 修改初始化方法
    // 修改初始化方法，使 appViewModel 参数可选
    init(stateManager: StateManager, appViewModel: FamilyAppViewModel? = nil) {
        self.stateManager = stateManager
        self.appViewModel = appViewModel
        self.titleGenerator = RelativeTitleGenerator(
            relationships: stateManager.state.relationships,
            persons: stateManager.state.persons
        )
        
        // 设置数据观察
        setupBindings()
        
        // 同步初始数据
        self.persons = stateManager.state.persons
        
        print("✅ MembersViewModel 初始化完成")
    }
    
    private func setupBindings() {
        // 观察 StateManager 的状态变化
        stateManager.$state
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)  // 添加防抖
            .removeDuplicates { oldState, newState in
                // 只在关键数据发生变化时才更新
                oldState.persons == newState.persons &&
                oldState.selectedPerson?.id == newState.selectedPerson?.id
            }
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // 更新人物列表
                if self.persons != state.persons {
                    self.persons = state.persons
                    
                    // 预加载所有称谓
                    Task { @MainActor in
                        await self.preloadAllTitles()
                    }
                }
                
                // 如果选中的人物不在列表中，重置选中状态
                if let selectedPerson = self.selectedPerson, 
                   !state.persons.contains(where: { $0.id == selectedPerson.id }) {
                    self.selectedPerson = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // 修改 loadData 方法，避免重复刷新
    func loadData() async {
        // 只在必要时加载数据
        if persons.isEmpty {
            print("📋 MembersViewModel 加载数据")
            // 直接使用 stateManager 的数据
            self.persons = stateManager.state.persons
            
            // 预加载称谓
            await preloadAllTitles()
        }
    }
    
    // 预加载所有称谓
    private func preloadAllTitles() async {
        for person in persons where !person.isSelf {
            if let title = titleGenerator.generateTitle(for: person), titleCache[person.id] == nil {
                titleCache[person.id] = title
            }
        }
        objectWillChange.send()
    }
    
    // 获取父母
    private func getParents(for person: Person) -> (father: Person?, mother: Person?) {
        let father = stateManager.getRelatedPersons(for: person, relationType: .father).first
        let mother = stateManager.getRelatedPersons(for: person, relationType: .mother).first
        return (father, mother)
    }
    
    // 获取相关人物
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        return stateManager.getRelatedPersons(for: person, relationType: relationType)
    }
    
    // 修改更新选中的人物方法
    func updateSelectedPerson(_ person: Person) {
        selectedPerson = person
        stateManager.selectPerson(person)
        
        // 通知 appViewModel 更新
        Task {
            await appViewModel?.refreshData()
        }
    }
    
    // 获取相对称谓
    func getRelativeTitle(for person: Person) async -> String? {
        // 获取自己的人物
        guard let selfPerson = persons.first(where: { $0.isSelf }) else {
            return nil
        }
        
        // 如果是自己，返回 nil（因为已经有专门的"自己"标识）
        if person.id == selfPerson.id {
            return nil
        }
        
        // 先检查缓存
        if let cachedTitle = titleCache[person.id] {
            return cachedTitle
        }
        
        // 如果没有缓存，生成称谓
        if let title = titleGenerator.generateTitle(for: person) {
            // 缓存新生成的称谓
            await MainActor.run {
                titleCache[person.id] = title
            }
            return title
        }
        
        return nil
    }
    
    // 修改切换家谱方法
    func switchFamily(_ family: Family) async {
        await stateManager.selectFamily(family)
        
        // 通知 appViewModel 更新
        await appViewModel?.refreshData()
    }
    
    // 添加更新 StateManager 的方法
    func updateStateManager(_ newStateManager: StateManager) {
        self.stateManager = newStateManager
        setupBindings() // 重新设置绑定
    }
    
    // 添加更新 appViewModel 的方法
    func updateAppViewModel(_ newAppViewModel: FamilyAppViewModel) {
        self.appViewModel = newAppViewModel
    }
    
    // 添加一个方法来检查 appViewModel 是否为 nil
    var hasAppViewModel: Bool {
        return appViewModel != nil
    }
}
        
 
