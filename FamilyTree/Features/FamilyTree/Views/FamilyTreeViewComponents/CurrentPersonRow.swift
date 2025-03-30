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
    
    // 添加状态变量来控制Toast显示
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        // 将GridRow内容提取到一个单独的视图中
        CurrentPersonRowContent(
            currentPerson: currentPerson,
            appViewModel: appViewModel,
            showingPersonCard: $showingPersonCard,
            selectedMode: $selectedMode,
            isTransitioning: $isTransitioning,
            isProcessing: $isProcessing,
            refreshID: $refreshID,
            backgroundImage: $backgroundImage,
            showToast: $showToast,
            toastMessage: $toastMessage,
            animation: animation,
            loadBackgroundImage: loadBackgroundImage
        )
    }
    
    // 提取加载背景图片的逻辑到一个方法
    func loadBackgroundImage() {
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

// 提取GridRow内容到单独的视图
struct CurrentPersonRowContent: View {
    let currentPerson: Person
    let appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    @Binding var isProcessing: Bool
    @Binding var refreshID: UUID
    @Binding var backgroundImage: UIImage?
    @Binding var showToast: Bool
    @Binding var toastMessage: String
    var animation: Namespace.ID
    var loadBackgroundImage: () -> Void
    
    var body: some View {
        GridRow {
            // 内容层，不再使用ZStack
            VStack(alignment: .leading, spacing: 8) {
                // 提取标题行到单独的视图
                CurrentPersonHeaderView(
                    currentPerson: currentPerson,
                    appViewModel: appViewModel,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode,
                    isProcessing: $isProcessing,
                    refreshID: $refreshID,
                    showToast: $showToast,
                    toastMessage: $toastMessage,
                    loadBackgroundImage: loadBackgroundImage
                )
                
                // 提取PersonCard到单独的视图包装
                PersonCardWrapper(
                    currentPerson: currentPerson,
                    appViewModel: appViewModel,
                    refreshID: refreshID,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode
                )
            }
            .padding(15)
            .gridCellColumns(2)
            // 使用background添加背景图片
            .background {
                BackgroundView(backgroundImage: backgroundImage, refreshID: refreshID)
            }
        }
        // 在GridRow上直接添加背景和其他修饰符
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(
                    color: Color.familyTheme.primary.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isTransitioning ? 0.3 : 1)
        .scaleEffect(isTransitioning ? 0.8 : 1)
        // 添加Toast提示，使用更新后的CurrentPersonToastView
        .overlay(
            CurrentPersonToastView(showToast: showToast, toastMessage: toastMessage)
        )
        // 添加通知监听器，监听图片更新
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPersonData"))) { _ in
            handleRefreshNotification()
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
    
    // 简化通知处理逻辑
    private func handleRefreshNotification() {
        print("CurrentPersonRow: 收到刷新通知，刷新UI")
        
        // 获取最新的人物数据并更新本地引用
        if let updatedPerson = appViewModel.persons.first(where: { $0.id == currentPerson.id }) {
            print("CurrentPersonRow: 从数据库获取最新人物数据，isSelf: \(updatedPerson.isSelf)")
            
            // 清除缓存的背景图片
            backgroundImage = nil
            
            // 尝试从ImagePickerManager获取最新图片
            if let image = ImagePickerManager.shared.getImage(for: updatedPerson.id) {
                backgroundImage = image
                print("CurrentPersonRow: 从ImagePickerManager获取最新图片")
            } else if let photoData = updatedPerson.photo, let uiImage = UIImage(data: photoData) {
                backgroundImage = uiImage
                print("CurrentPersonRow: 从数据库获取最新图片")
                
                // 更新ImagePickerManager缓存
                ImagePickerManager.shared.setImage(for: updatedPerson.id, image: uiImage, data: photoData)
            } else {
                print("CurrentPersonRow: 无法获取图片，ID: \(updatedPerson.id)")
            }
            
            // 强制刷新UI
            refreshID = UUID()
            print("CurrentPersonRow: 强制刷新UI，refreshID: \(refreshID)")
        } else {
            print("CurrentPersonRow: 无法从数据库获取最新人物数据")
        }
    }
}

// 提取背景视图
struct BackgroundView: View {
    let backgroundImage: UIImage?
    let refreshID: UUID
    
    var body: some View {
        Group {
            if let image = backgroundImage {
                // 优先使用已加载的背景图片
                ZStack {
                    Color.familyTheme.greenGradient
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                }
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

// 修改名称为CurrentPersonToastView，避免与PersonBasicInfoSection中的ToastView冲突
struct CurrentPersonToastView: View {
    let showToast: Bool
    let toastMessage: String
    
    var body: some View {
        Group {
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            // 3秒后自动隐藏
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    // 这里不能直接修改showToast，因为它是一个let属性
                                    // 需要在父视图中处理
                                }
                            }
                        }
                    Spacer().frame(height: 20)
                }
            }
        }
    }
}

// 提取PersonCard包装视图
struct PersonCardWrapper: View {
    let currentPerson: Person
    let appViewModel: FamilyAppViewModel
    let refreshID: UUID
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    
    var body: some View {
        ZStack {
            // 添加一个透明的按钮层，确保点击事件被捕获
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    print("PersonCardWrapper: 点击了卡片")
                    withAnimation(.personTransition) {
                        appViewModel.getStateManager().selectPerson(currentPerson)
                        selectedMode = .edit
                        showingPersonCard = true
                    }
                }
            
            // 原有的 PersonCard
            PersonCard(
                person: currentPerson,
                mode: .view,
                stateManager: appViewModel.getStateManager(),
                appViewModel: appViewModel
            )
            .id("\(currentPerson.id)-\(refreshID)") // 使用复合ID确保刷新
            .allowsHitTesting(false) // 禁用 PersonCard 的点击事件，让上层的 onTapGesture 处理
        }
    }
}

// 这里需要继续实现CurrentPersonHeaderView
// 由于代码较长，我们可以将其放在单独的文件中
