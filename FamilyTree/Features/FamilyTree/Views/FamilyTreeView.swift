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
    
    init() {
        let familyViewModel = FamilyTreeViewModel()
        _viewModel = StateObject(wrappedValue: familyViewModel)
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(familyTreeViewModel: familyViewModel))
    }
    
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
        }
        .onAppear {
            Task {
                await personManager.loadData()
                if let selfPerson = personManager.persons.first(where: { $0.isSelf }) {
                    await MainActor.run {
                        personManager.selectedPerson = selfPerson
                    }
                }
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
    FamilyTreeView()
}

#Preview("家谱-深色") {
    FamilyTreeView()
        .preferredColorScheme(.dark)
}
