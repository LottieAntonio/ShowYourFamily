import SwiftUI

struct SiblingsRow: View {
    let currentPerson: Person
    @ObservedObject var personManager: PersonManagementViewModel
    @Binding var showingPersonCard: Bool
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    var body: some View {
        GridRow {
            RelationshipSection(
                title: "兄弟",
                persons: personManager.relationshipService.getRelatedPersons(for: currentPerson, relationType: .brother),
                onAddTap: {
                    Task {
                        await showAddRelation(
                            currentPerson,
                            .brother,
                            currentPerson.lastName,
                            .male
                        )
                    }
                },
                onPersonTap: { person in
                    handlePersonTap(person, direction: .left)
                },
                viewModel: personManager,
                animation: animation,
                selectedPersonId: $selectedPersonId,
                type: .brother
            )
            
            RelationshipSection(
                title: "姐妹",
                persons: personManager.relationshipService.getRelatedPersons(for: currentPerson, relationType: .sister),
                onAddTap: {
                    Task {
                        await showAddRelation(
                            currentPerson,
                            .sister,
                            currentPerson.lastName,
                            .female
                        )
                    }
                },
                onPersonTap: { person in
                    handlePersonTap(person, direction: .right)
                },
                viewModel: personManager,
                animation: animation,
                selectedPersonId: $selectedPersonId,
                type: .sister
            )
        }
    }
    
    private func handlePersonTap(_ person: Person, direction: TransitionDirection) {
        selectedPersonId = person.id
        
        // 第一阶段：上升并缩小
        withAnimation(.flyTransition) {
            transitionOffset = CGSize(width: 0, height: -50)
            isTransitioning = true
        }
        
        // 第二阶段：水平移动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.flyTransition) {
                let horizontalOffset = direction == .left ? 
                    -UIScreen.main.bounds.width * 0.3 : 
                    UIScreen.main.bounds.width * 0.3
                transitionOffset = CGSize(width: horizontalOffset, height: -50)
            }
        }
        
        // 第三阶段：下降到目标位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.flyTransition) {
                transitionOffset = .zero
                personManager.selectedPerson = person
                showingPersonCard = false
                isTransitioning = false
            }
        }
    }
}

private enum TransitionDirection {
    case left, right
}
