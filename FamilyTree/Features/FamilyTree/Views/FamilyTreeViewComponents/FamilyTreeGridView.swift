import SwiftUI

struct FamilyTreeGridView: View {
    let currentPerson: Person
    // 修改为使用 appViewModel
    @EnvironmentObject var appViewModel: FamilyAppViewModel
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
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                .environmentObject(appViewModel)  // 传递 appViewModel 给子视图
                
                // 配偶行
                SpouseRow(
                    currentPerson: currentPerson,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                .environmentObject(appViewModel)  // 传递 appViewModel 给子视图
                
                // 当前人物行
                CurrentPersonRow(
                    currentPerson: currentPerson,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode,
                    isTransitioning: $isTransitioning,
                    animation: animation
                )
                .environmentObject(appViewModel)  // 传递 appViewModel 给子视图
                
                // 子女行
                ChildrenRow(
                    currentPerson: currentPerson,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                .environmentObject(appViewModel)  // 传递 appViewModel 给子视图
                
                // 兄弟姐妹行
                SiblingsRow(
                    currentPerson: currentPerson,
                    showingPersonCard: $showingPersonCard,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
                .environmentObject(appViewModel)  // 传递 appViewModel 给子视图
            }
        }
        .padding()
    }
}

