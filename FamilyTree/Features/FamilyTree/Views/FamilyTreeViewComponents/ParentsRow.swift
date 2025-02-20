
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
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @State private var pendingAction: (() async -> Void)?
    
    var body: some View {
        GridRow {
            // 父亲关系区域
            RelationshipSection(
                title: "父亲",
                persons: personManager.relationshipService.getRelatedPersons(for: currentPerson, relationType: .father),
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
                persons: personManager.relationshipService.getRelatedPersons(for: currentPerson, relationType: .mother),
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
        .alert("更换父母确认", 
               isPresented: $showConfirmation,
               actions: {
            Button("取消", role: .cancel) { }
            Button("确认", role: .destructive) {
                Task {
                    await pendingAction?()
                }
            }
        }, message: {
            Text(confirmationMessage)
        })
    }
    
    private func handleAddParent(_ person: Person, type: RelationType, lastName: String?, gender: Person.Gender?) async {
        let existingParents = personManager.relationshipService.getRelatedPersons(
            for: person,
            relationType: type
        )
        
        if !existingParents.isEmpty {
            confirmationMessage = """
                已检测到现有\(type == .father ? "父亲" : "母亲")，
                继续操作将解除与原有\(type == .father ? "父亲" : "母亲")的关系。
                是否确认？
                """
            pendingAction = {
                await showAddRelation(person, type, lastName, gender)
            }
            showConfirmation = true
        } else {
            await showAddRelation(person, type, lastName, gender)
        }
    }
    
    private func handlePersonTap(_ person: Person, direction: TransitionDirection) {
        selectedPersonId = person.id
        
        // 第一阶段：上升并缩小
        withAnimation(.spring(duration: 0.3)) {
            transitionOffset = CGSize(width: 0, height: -50)
            isTransitioning = true
        }
        
        // 第二阶段：水平移动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(duration: 0.3)) {
                let horizontalOffset = direction == .left ? 
                    -UIScreen.main.bounds.width * 0.3 : 
                    UIScreen.main.bounds.width * 0.3
                transitionOffset = CGSize(width: horizontalOffset, height: -50)
            }
        }
        
        // 第三阶段：下降到目标位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(duration: 0.3)) {
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
