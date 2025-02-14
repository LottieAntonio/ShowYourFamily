
import SwiftUI

struct ParentsRow: View {
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
            // 父亲关系区域
            RelationshipSection(
                title: "父亲",
                persons: personManager.getRelatedPersons(for: currentPerson, relationType: .father),
                onAddTap: {
                    Task {
                        await MainActor.run {
                            withAnimation(.spring(duration: 0.3)) {
                                showingPersonCard = true
                            }
                        }
                        await showAddRelation(
                            currentPerson,
                            .father,
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
                type: .father
            )
            .matchedGeometryEffect(
                id: "father-container-\(selectedPersonId ?? UUID())",
                in: animation,
                properties: .position,
                isSource: true
            )
            
            // 母亲关系区域
            RelationshipSection(
                title: "母亲",
                persons: personManager.getRelatedPersons(for: currentPerson, relationType: .mother),
                onAddTap: {
                    Task {
                        await MainActor.run {
                            withAnimation(.spring(duration: 0.3)) {
                                showingPersonCard = true
                            }
                        }
                        await showAddRelation(
                            currentPerson,
                            .mother,
                            nil,
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
                type: .mother
            )
            .matchedGeometryEffect(
                id: "mother-container-\(selectedPersonId ?? UUID())",
                in: animation,
                properties: .position,
                isSource: true
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