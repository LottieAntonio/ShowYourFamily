import SwiftUI

// 修改 CurrentPersonRow 中的背景图片处理
struct CurrentPersonRow: View {
    let currentPerson: Person
    // 修改为使用 appViewModel
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    var animation: Namespace.ID
    
    @State private var isProcessing = false
    // 添加一个状态来强制刷新背景图片
    @State private var refreshID = UUID()
    // 添加一个状态来存储当前使用的图片
    @State private var backgroundImage: UIImage?
    
    var body: some View {
        GridRow {
            // 内容层，不再使用ZStack
            VStack(alignment: .leading, spacing: 8) {
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
                            .padding(2)
                            .background {
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                            }
                    }

                }
                PersonCard(
                    person: currentPerson,
                    mode: .view,
                    stateManager: appViewModel.getStateManager(),
                    appViewModel: appViewModel
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
            // 使用background添加背景图片
            .background {
                Group {
                    if let image = backgroundImage {
                        // 优先使用已加载的背景图片
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        // 如果没有图片，使用渐变色背景
                        LinearGradient(
                            colors: [
                                Color.familyTheme.primary.opacity(0.7),
                                Color.familyTheme.primary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .id(refreshID) // 使用ID来强制刷新背景
            }
        }
        // 在GridRow上直接添加背景和其他修饰符
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isTransitioning ? 0.3 : 1)
        .scaleEffect(isTransitioning ? 0.8 : 1)
        // 添加通知监听器，监听图片更新
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPersonData"))) { _ in
            print("CurrentPersonRow: 收到刷新通知，强制刷新背景图片")
            
            // 强制刷新背景
            refreshID = UUID()
            
            // 清除缓存的背景图片
            backgroundImage = nil
            
            // 延迟一点时间再加载新图片，确保数据库已更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 尝试从ImagePickerManager获取最新图片
                if let image = ImagePickerManager.shared.getImage(for: currentPerson.id) {
                    backgroundImage = image
                    print("CurrentPersonRow: 延迟加载 - 从ImagePickerManager获取最新图片")
                } else if let photoData = currentPerson.photo, let uiImage = UIImage(data: photoData) {
                    backgroundImage = uiImage
                    print("CurrentPersonRow: 延迟加载 - 从数据库获取最新图片")
                }
                
                // 再次强制刷新
                refreshID = UUID()
            }
        }
        // 添加onAppear生命周期方法
        .onAppear {
            print("CurrentPersonRow: 视图出现，检查图片更新")
            loadBackgroundImage()
        }
        // 添加onChange监听器，监听currentPerson变化
        .onChange(of: currentPerson.id) { _, _ in
            print("CurrentPersonRow: 人物ID变化，更新背景图片")
            loadBackgroundImage()
        }
    }
    
    // 提取加载背景图片的逻辑到一个方法
    private func loadBackgroundImage() {
        // 清除现有图片
        backgroundImage = nil
        
        // 尝试从ImagePickerManager获取最新图片
        if let image = ImagePickerManager.shared.getImage(for: currentPerson.id) {
            backgroundImage = image
            print("CurrentPersonRow: 从ImagePickerManager加载背景图片")
        } else if let photoData = currentPerson.photo, let uiImage = UIImage(data: photoData) {
            backgroundImage = uiImage
            print("CurrentPersonRow: 从数据库加载背景图片")
            
            // 同时更新ImagePickerManager缓存
            ImagePickerManager.shared.setImage(for: currentPerson.id, image: uiImage, data: photoData)
        }
        
        // 强制刷新背景
        refreshID = UUID()
    }
}
