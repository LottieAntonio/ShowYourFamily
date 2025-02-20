import SwiftUI

struct ChildrenRow: View {
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
                title: "子女",
                persons: personManager.relationshipService.getRelatedPersons(for: currentPerson, relationType: .child),
                onAddTap: {
                    Task {
                        await showAddRelation(
                            currentPerson,
                            .child,
                            currentPerson.lastName,
                            nil
                        )
                    }
                },
                onPersonTap: { person in
                    handlePersonTap(person)
                },
                viewModel: personManager,
                animation: animation,
                selectedPersonId: $selectedPersonId,
                type: .child
            )
            .gridCellColumns(2)
            .matchedGeometryEffect(
                id: "children-container-\(selectedPersonId ?? UUID())",
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
                transitionOffset = CGSize(width: 0, height: 50)
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