import SwiftUI

struct FamilyTreeContentView: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    @ObservedObject var personManager: PersonManagementViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddPerson: () -> Void
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    var body: some View {
        ZStack {
            Color.familyTheme.primary.opacity(0.2)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if personManager.persons.isEmpty {
                FamilyTreeEmptyStateView(showAddPerson: showAddPerson)
            } else if let currentPerson = personManager.selectedPerson {
                FamilyTreeGridView(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
            }
        }
        
    }
}

// 可以继续拆分 FamilyTreeGridView 和 EmptyStateView 到单独的文件中
