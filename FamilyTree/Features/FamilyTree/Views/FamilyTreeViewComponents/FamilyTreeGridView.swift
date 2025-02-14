import SwiftUI

struct FamilyTreeGridView: View {
    let currentPerson: Person
    @ObservedObject var personManager: PersonManagementViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                // 父母行
                ParentsRow(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                
                // 配偶行
                SpouseRow(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                
                // 当前人物行
                CurrentPersonRow(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode,
                    isTransitioning: $isTransitioning,
                    animation: animation
                )
                
                // 子女行
                ChildrenRow(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                
                // 兄弟姐妹行
                SiblingsRow(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
            }
        }
        .padding()
    }
}

