import Foundation
import SwiftUI
import Combine


@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // 添加计算属性获取当前家谱
    var currentFamily: Family? {
        return stateManager.state.currentFamily
    }
    
    private var stateManager: StateManager  // 改为 var
    private weak var appViewModel: FamilyAppViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    private var isInitialized = false
    private var loadDataTask: Task<Void, Error>?
    private var currentFamilyId: UUID?
    private var personsDict: [UUID: Person] = [:]
    private var relationshipsDict: [UUID: Relationship] = [:]
    
    init(stateManager: StateManager, appViewModel: FamilyAppViewModel? = nil) {
        self.stateManager = stateManager
        self.appViewModel = appViewModel
        setupBindings()
    }
    
    private func setupBindings() {
        stateManager.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // 更新本地数据
                self.persons = state.persons
                self.relationships = state.relationships
                
                // 同步选中的人物
                if let selectedPersonId = state.selectedPerson?.id {
                    if self.selectedPerson?.id != selectedPersonId {
                        self.selectedPerson = state.selectedPerson
                    }
                } else if let firstPerson = state.persons.first, self.selectedPerson == nil {
                    // 如果没有选中人物但有可用人物，选择第一个
                    self.selectedPerson = firstPerson
                    self.stateManager.selectPerson(firstPerson)
                }
            }
            .store(in: &cancellables)
    }
    
    
    // 修改选择人物方法，添加通知
    func selectPerson(_ person: Person) {
        selectedPerson = person
        stateManager.selectPerson(person)
        // 通知 appViewModel 更新
        Task {
            await appViewModel?.refreshData()
        }
    }
    
    // 修改添加人物方法
    func addPerson(_ person: Person) async throws {
        try await stateManager.addPerson(person)
        await appViewModel?.refreshData()
    }
    
    // 修改更新人物方法
    func updatePerson(_ person: Person) async throws {
        try await stateManager.updatePerson(person)
        await appViewModel?.refreshData()
    }
    
    // 修改删除人物方法
    func deletePerson(_ person: Person) async throws {
        try await stateManager.deletePerson(person)
        await appViewModel?.refreshData()
    }
    
    // 修改添加关系方法
    func addRelationship(_ relationship: Relationship) async throws {
        try await stateManager.addRelationship(relationship)
        await appViewModel?.refreshData()
    }
    
    // 修改切换家谱方法
    func switchFamily(_ family: Family) async {
        await stateManager.selectFamily(family)
        await appViewModel?.refreshData()
    }
    
    // 修改加载数据方法
    func loadData() async throws {
        if isInitialized && !persons.isEmpty {
            return
        }
        
        loadDataTask?.cancel()
        
        guard let currentFamily = stateManager.state.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let task = Task { @MainActor in
            do {
                self.currentFamilyId = currentFamily.id
                
                // 清空现有数据
                self.persons = []
                self.relationships = []
                self.personsDict = [:]
                self.relationshipsDict = [:]
                
                // 使用 appViewModel 加载数据
                await appViewModel?.refreshData()
                
                if Task.isCancelled { return }
                
                // 从 stateManager 获取最新数据
                self.persons = stateManager.state.persons
                self.relationships = stateManager.state.relationships
                self.personsDict = Dictionary(uniqueKeysWithValues: persons.map { ($0.id, $0) })
                self.relationshipsDict = Dictionary(uniqueKeysWithValues: relationships.map { ($0.id, $0) })
            } catch {
                throw error
            }
        }
        
        loadDataTask = task
        try await task.value
        
        isInitialized = true
    }
    
  
    
}

// 添加扩展方法
extension FamilyTreeViewModel {
    func updateStateManager(_ stateManager: StateManager) {
        self.stateManager = stateManager
        // 重新设置绑定
        cancellables.removeAll()
        setupBindings()
        // 同步当前数据
        self.persons = stateManager.state.persons
        self.relationships = stateManager.state.relationships
        self.selectedPerson = stateManager.state.selectedPerson
    }
}
