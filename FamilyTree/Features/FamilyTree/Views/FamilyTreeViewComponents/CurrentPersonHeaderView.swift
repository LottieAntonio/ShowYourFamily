import SwiftUI

// 提取标题行视图
struct CurrentPersonHeaderView: View {
    let currentPerson: Person
    let appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isProcessing: Bool
    @Binding var refreshID: UUID
    @Binding var showToast: Bool
    @Binding var toastMessage: String
    var loadBackgroundImage: () -> Void
    
    var body: some View {
        HStack {
            Text("当前人物")
                .font(.caption)
                .foregroundStyle(Color.familyTheme.primary)
                .padding(3)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.6))
                }
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
                
                // 保持原有菜单项
                if !currentPerson.isSelf {
                    Button(action: {
                        Task {
                            await handleSetSelfPerson()
                        }
                    }) {
                        Label("设置为自己", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .disabled(isProcessing)
                    
                    Divider()
                    
                    // 其他菜单项...
                    RelationshipMenuItems(
                        currentPerson: currentPerson,
                        appViewModel: appViewModel,
                        isProcessing: $isProcessing
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(Color.familyTheme.primary)
                    .font(.callout)
                    .padding(2)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.6))
                    }
            }
        }
    }
    
    // 提取设置自己的逻辑
    // 进一步简化设置自己的逻辑
    private func handleSetSelfPerson() async {
        isProcessing = true // 添加处理状态
        let cardViewModel = PersonCardViewModel(
            person: currentPerson,
            mode: PersonCardMode.view,
            stateManager: appViewModel.getStateManager()
        )
        // 设置appViewModel引用，确保称谓生成正确
        cardViewModel.appViewModel = appViewModel
        
        do {
            print("调用setSelfPerson前: \(currentPerson.name), isSelf: \(currentPerson.isSelf)")
            try await cardViewModel.setSelfPerson()
            
            // 立即显示成功提示
            DispatchQueue.main.async {
                toastMessage = "已将 \(currentPerson.name) 设置为自己"
                showToast = true
                print("显示Toast: \(toastMessage)")
                
                // 3秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
            
            // 使用单一方法重置称谓生成器并刷新UI
            await appViewModel.resetTitleGeneratorsAndRefresh()
            print("设置自己完成: \(currentPerson.name)")
            
            // 强制刷新UI
            refreshID = UUID()
            loadBackgroundImage()
        } catch {
            // 显示错误提示
            print("设置自己失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                toastMessage = "设置失败: \(error.localizedDescription)"
                showToast = true
                
                // 3秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
        
        isProcessing = false
    }
}

// 提取关系菜单项
struct RelationshipMenuItems: View {
    let currentPerson: Person
    let appViewModel: FamilyAppViewModel
    @Binding var isProcessing: Bool
    
    var body: some View {
        Group {
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
    }
}
