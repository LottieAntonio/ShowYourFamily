import SwiftUI

struct SpouseRow: View {
    let currentPerson: Person
// 修改参数，使用 stateManager
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    var body: some View {
        GridRow {
            RelationshipSection(
                title: "配偶",
                
                persons: appViewModel.getStateManager().getRelatedPersons(for: currentPerson, relationType: .spouse),
                onAddTap: {
                    Task {
                        let defaultSpouseGender = currentPerson.gender == .male ? Person.Gender.female : .male
                        await showAddRelation(
                            currentPerson,
                            .spouse,
                            nil,
                            defaultSpouseGender
                        )
                    }
                },
                onPersonTap: { person in
                    handlePersonTap(person)
                },
                animation: animation,
                selectedPersonId: $selectedPersonId,
                type: .spouse
            )
            .gridCellColumns(2)
            .matchedGeometryEffect(
                id: "spouse-container-\(selectedPersonId ?? UUID())",
                in: animation,
                properties: .position,
                isSource: true
            )
        }
    }
    
    private func handlePersonTap(_ person: Person) {
        selectedPersonId = person.id
        
        // 第一阶段：上升并缩小
        withAnimation(.flyTransition) {
            transitionOffset = CGSize(width: 0, height: -50)
            isTransitioning = true
        }
        
        // 第二阶段：水平移动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.flyTransition) {
                transitionOffset = CGSize(width: 0, height: -30)
            }
        }
        
        // 第三阶段：下降到目标位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.flyTransition) {
                transitionOffset = .zero
                appViewModel.getStateManager().selectPerson(person)  // 添加这行
                showingPersonCard = false
                isTransitioning = false
            }
        }
    }
}
