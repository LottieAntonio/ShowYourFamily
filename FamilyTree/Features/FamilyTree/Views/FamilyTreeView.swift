import SwiftUI

// 删除原来的动画配置

struct FamilyTreeView: View {
    // 修改 stateManager 为 appViewModel
    @EnvironmentObject private var appViewModel: FamilyAppViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    @State private var selectedPersonOffset: CGSize = .zero
    @State private var isTransitioning = false
    @State private var selectedPersonId: UUID?
    @State private var transitionOffset: CGSize = .zero
    
    @Namespace private var animation
    
    // 使用 appViewModel 创建所需的视图模型
    @StateObject private var viewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
   
    // 修改初始化方法，使用 @EnvironmentObject 的方式
    init() {
        // 使用临时的空 StateManager 初始化，实际的 StateManager 会通过 appViewModel 获取
        let tempStateManager = StateManager(dataManager: LocalDataManager())
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(stateManager: tempStateManager))
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(stateManager: tempStateManager))
    }
    
    @AppStorage("hasInitializedSelf") private var hasInitializedSelf = false
    @AppStorage("lastSelectedPersonId") private var lastSelectedPersonId: String = ""
    
    var body: some View {
        NavigationStack {
            FamilyTreeContentView(
                showingPersonCard: $showingPersonCard,
                selectedMode: $selectedMode,
                isTransitioning: $isTransitioning,
                selectedPersonId: $selectedPersonId,
                transitionOffset: $transitionOffset,
                animation: animation,
                showAddPerson: showAddPerson,
                showAddRelation: showAddRelation
            )
            .sheet(isPresented: $showingPersonCard) {
                NavigationStack {
                    PersonCard(
                        person: {
                            if case .add = selectedMode {
                                return nil
                            }
                            return personManager.selectedPerson
                        }(),
                        mode: selectedMode,
                        stateManager: appViewModel.getStateManager(),
                        appViewModel: appViewModel
                    )
                }
            }
            .onChange(of: personManager.persons) { oldValue, newPersons in
                if !newPersons.isEmpty {
                    if newPersons.count > oldValue.count,  // 修改这里使用 oldValue
                       let lastPerson = newPersons.last {
                        Task { @MainActor in
                            personManager.selectedPerson = lastPerson
                            lastSelectedPersonId = lastPerson.id.uuidString
                            showingPersonCard = false
                            await appViewModel.refreshData()
                        }
                    }
                }
            }
        }
        .onAppear {
            // 初始化视图模型，使用 appViewModel 的 stateManager
            viewModel.updateStateManager(appViewModel.getStateManager())
            personManager.updateStateManager(appViewModel.getStateManager())
            
            Task {
                // 确保数据已经加载完成
                if appViewModel.persons.isEmpty {
                    await appViewModel.refreshData()
                }
                await setSelfPersonAsSelected()
            }
        }
        .onChange(of: personManager.selectedPerson) { oldValue, newPerson in
            if let personId = newPerson?.id {
                lastSelectedPersonId = personId.uuidString
                Task {
                    await appViewModel.refreshData()
                }
            }
        }
    }
    
    // 添加设置自己为选中人物的方法
    private func setSelfPersonAsSelected() async {
        await MainActor.run {
            if let selfPerson = personManager.persons.first(where: { $0.isSelf }) {
                personManager.selectedPerson = selfPerson
            } else if personManager.selectedPerson == nil, let firstPerson = personManager.persons.first {
                // 如果没有设置"自己"，且当前没有选中的人，则选择第一个人
                personManager.selectedPerson = firstPerson
            }
        }
    }
    
    private func showAddPerson() {
        selectedMode = .add(relationType: nil)
        showingPersonCard = true
        personManager.selectedPerson = nil
    }
    
    private func showAddRelation(
        for person: Person,
        type: RelationType,  // 修改这里，直接使用 RelationType
        defaultLastName: String? = nil,
        defaultGender: Person.Gender? = nil
    ) async {
        personManager.selectedPerson = person
        await personManager.setDefaultValues(lastName: defaultLastName, gender: defaultGender)
        selectedMode = .add(relationType: type)
        showingPersonCard = true
    }
    
    // 删除第二个重复的 showAddRelation 方法
}


