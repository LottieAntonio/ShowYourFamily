import SwiftUI

struct CurrentPersonRow: View {
    let currentPerson: Person
    @ObservedObject var personManager: PersonManagementViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    var animation: Namespace.ID
    
    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前人物")
                        .font(.caption)
                        .foregroundStyle(Color.familyTheme.primary)
                    Spacer()
                    Menu {
                        Button(action: {
                            withAnimation(.personTransition) {
                                personManager.selectedPerson = currentPerson
                                selectedMode = .edit
                                showingPersonCard = true
                            }
                        }) {
                            Label("编辑", systemImage: "pencil")
                        }
                        
                        if !currentPerson.isSelf {
                            Button(action: {
                                Task {
                                    let cardViewModel = PersonCardViewModel(
                                        person: currentPerson,
                                        mode: .view,
                                        managementViewModel: personManager
                                    )
                                    try? await cardViewModel.setSelfPerson()
                                }
                            }) {
                                Label("设置为自己", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(Color.familyTheme.primary)
                            .font(.callout)
                    }
                }
                
                PersonCard(
                    person: currentPerson,
                    mode: .view,
                    managementViewModel: personManager
                )
                .id(currentPerson.id)
                .onTapGesture {
                    withAnimation(.personTransition) {
                        personManager.selectedPerson = currentPerson
                        selectedMode = .edit
                        showingPersonCard = true
                    }
                }
            }
            .padding(8)
            .gridCellColumns(2)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(
                        color: Color.familyTheme.primary.opacity(0.2),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .opacity(isTransitioning ? 0.3 : 1)
            .scaleEffect(isTransitioning ? 0.8 : 1)
        }
    }
}
