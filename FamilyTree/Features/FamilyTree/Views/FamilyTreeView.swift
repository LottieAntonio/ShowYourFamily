import SwiftUI

// 删除原来的动画配置

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    @State private var selectedPersonOffset: CGSize = .zero
    @State private var isTransitioning = false
    @State private var selectedPersonId: UUID?
    @State private var transitionOffset: CGSize = .zero
    
    @Namespace private var animation
    
    init(familyManager: FamilyManagementViewModel) {
        // 使用已存在的 FamilyTreeViewModel
        let familyViewModel = familyManager.familyTreeViewModel ?? FamilyTreeViewModel(familyManager: familyManager)
        
        _viewModel = StateObject(wrappedValue: familyViewModel)
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(
            familyTreeViewModel: familyViewModel,
            familyManager: familyManager
        ))
    }
    
    @AppStorage("hasInitializedSelf") private var hasInitializedSelf = false
    @AppStorage("lastSelectedPersonId") private var lastSelectedPersonId: String = ""
    
    var body: some View {
        NavigationStack {
            FamilyTreeContentView(
                viewModel: viewModel,
                personManager: personManager,
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
                        managementViewModel: personManager
                    )
                }
            }
            .onChange(of: personManager.persons) { oldValue, newPersons in
                // 如果人物列表发生变化
                if !newPersons.isEmpty {
                    // 如果是新添加的人物（通过比较数组长度和最后一个元素）
                    if newPersons.count > personManager.persons.count,
                       let lastPerson = newPersons.last {
                        Task { @MainActor in
                            // 将新添加的人物设置为当前选中的人物
                            personManager.selectedPerson = lastPerson
                            // 同时更新 lastSelectedPersonId
                            lastSelectedPersonId = lastPerson.id.uuidString
                            // 关闭添加表单
                            showingPersonCard = false
                            // 强制重新加载数据
                            await personManager.loadData()
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await personManager.loadData()
                // 只在第一次启动时设置默认选中人物
                if personManager.selectedPerson == nil {
                    if let lastId = UUID(uuidString: lastSelectedPersonId),
                       let lastPerson = personManager.persons.first(where: { $0.id == lastId }) {
                        // 恢复上次选中的人物
                        personManager.selectedPerson = lastPerson
                    } else if let selfPerson = personManager.persons.first(where: { $0.isSelf }) {
                        // 如果没有上次选中的人物，则显示"自己"
                        personManager.selectedPerson = selfPerson
                    }
                }
            }
        }
        .onChange(of: personManager.selectedPerson) { oldValue, newPerson in
            // 保存当前选中的人物 ID
            if let personId = newPerson?.id {
                lastSelectedPersonId = personId.uuidString
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

#Preview("家谱") {
    let dataManager = LocalDataManager()  // 修改这里，直接创建实例
    let familyManager = FamilyManagementViewModel(dataManager: dataManager)
    FamilyTreeView(familyManager: familyManager)
}

#Preview("家谱-深色") {
    let dataManager = LocalDataManager()  // 修改这里，直接创建实例
    let familyManager = FamilyManagementViewModel(dataManager: dataManager)
    FamilyTreeView(familyManager: familyManager)
        .preferredColorScheme(.dark)
}
