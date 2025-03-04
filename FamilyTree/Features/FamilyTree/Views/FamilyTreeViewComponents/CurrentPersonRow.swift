import SwiftUI

struct CurrentPersonRow: View {
    let currentPerson: Person
    // 修改为使用 appViewModel
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    var animation: Namespace.ID
    
    @State private var isProcessing = false
    
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
                                        mode: PersonCardMode.view,
                                        stateManager: appViewModel.getStateManager()
                                    )
                                    try? await cardViewModel.setSelfPerson()
                                    await appViewModel.refreshData()  // 添加刷新
                                }
                            }) {
                                Label("设置为自己", systemImage: "person.crop.circle.badge.checkmark")
                            }
                            
                            Divider()
                            
                            // 设置为父亲
                            if currentPerson.gender == .male {
                                Button(action: {
                                    isProcessing = true
                                    Task {
                                        if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                            let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                            
                                            if existingRelations.isEmpty {
                                                try? await appViewModel.getStateManager().addRelationship(
                                                    from: selfPerson,
                                                    to: currentPerson,
                                                    type: .father
                                                )
                                                await appViewModel.refreshData()  // 添加刷新
                                            }
                                        }
                                        isProcessing = false
                                    }
                                }) {
                                    Label("设置为父亲", systemImage: "person.2.circle")
                                }
                                .disabled(isProcessing)
                            }
                            
                            // 设置为母亲
                            if currentPerson.gender == .female {
                                Button(action: {
                                    isProcessing = true
                                    Task {
                                        if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                            let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                            if existingRelations.isEmpty {
                                                try? await appViewModel.getStateManager().addRelationship(
                                                    from: selfPerson,
                                                    to: currentPerson,
                                                    type: .mother
                                                )
                                                await appViewModel.refreshData()  // 添加刷新
                                            }
                                        }
                                        isProcessing = false
                                    }
                                }) {
                                    Label("设置为母亲", systemImage: "person.2.circle")
                                }
                                .disabled(isProcessing)
                            }
                            
                            // 设置为配偶
                            Button(action: {
                                isProcessing = true
                                Task {
                                    if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                        let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                        
                                        if existingRelations.isEmpty {
                                            try? await appViewModel.getStateManager().addRelationship(
                                                from: selfPerson,
                                                to: currentPerson,
                                                type: .spouse
                                            )
                                            await appViewModel.refreshData()  // 添加刷新
                                        }
                                    }
                                    isProcessing = false
                                }
                            }) {
                                Label("设置为配偶", systemImage: "heart.circle")
                            }
                            .disabled(isProcessing)
                            
                            // 设置为子女
                            Button(action: {
                                isProcessing = true
                                Task {
                                    if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                        let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                        
                                        if existingRelations.isEmpty {
                                            try? await appViewModel.getStateManager().addRelationship(
                                                from: selfPerson,
                                                to: currentPerson,
                                                type: .child
                                            )
                                        }
                                    }
                                    isProcessing = false
                                }
                            }) {
                                Label("设置为子女", systemImage: "person.crop.circle.badge.plus")
                            }
                            .disabled(isProcessing)
                            
                            // 设置为兄弟/姐妹
                            if currentPerson.gender == .male {
                                Button(action: {
                                    isProcessing = true
                                    Task {
                                        if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                            let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                            
                                            if existingRelations.isEmpty {
                                                try? await appViewModel.getStateManager().addRelationship(
                                                    from: selfPerson,
                                                    to: currentPerson,
                                                    type: .brother
                                                )
                                            }
                                        }
                                        isProcessing = false
                                    }
                                }) {
                                    Label("设置为兄弟", systemImage: "person.3")
                                }
                                .disabled(isProcessing)
                            } else {
                                Button(action: {
                                    isProcessing = true
                                    Task {
                                        if let selfPerson = await appViewModel.getStateManager().getSelfPerson() {
                                            let existingRelations = appViewModel.getStateManager().getRelationships(between: currentPerson, and: selfPerson)
                                            
                                            if existingRelations.isEmpty {
                                                try? await appViewModel.getStateManager().addRelationship(
                                                    from: selfPerson,
                                                    to: currentPerson,
                                                    type: .sister
                                                )
                                            }
                                        }
                                        isProcessing = false
                                    }
                                }) {
                                    Label("设置为姐妹", systemImage: "person.3")
                                }
                                .disabled(isProcessing)
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
                    stateManager: appViewModel.getStateManager(),
                    appViewModel: appViewModel  // 添加 appViewModel
                )
                .id(currentPerson.id)
                .onTapGesture {
                    withAnimation(.personTransition) {
                        appViewModel.getStateManager().selectPerson(currentPerson)
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
