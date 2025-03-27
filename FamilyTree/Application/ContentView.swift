import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    // 使用 EnvironmentObject 接收从 FamilyTreeApp 传递的 ViewModel
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // 添加状态标记，确保数据只加载一次
    @State private var initialDataLoaded = false
    
    // 添加一个状态来控制图谱视图的显示
    @State private var graphViewCreated = false
    
    // 添加状态控制返回确认对话框
    @State private var showingReturnConfirmation = false
    
    // 添加顶部提示显示状态
    @State private var showTopHint = true
    
    // 添加底部导航栏高度常量
    private let tabBarHeight: CGFloat = 60
    
    // 添加下拉手势状态
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域
            VStack(spacing: 0) {
                // 显示当前选中的屏幕
                Group {
                    switch coordinator.currentScreen {
                    case .familyTree:
                        // 主内容
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                FamilyTreeView()
                                    .environmentObject(appViewModel)
                                RoundedRectangle(cornerRadius: 5)
                                    .frame(height: 68)
                                    .foregroundStyle(Color.clear)
                                    .ignoresSafeArea()
                                    .background(Color.familyTheme.primary.opacity(0.4))
                            }
                            
                            // 添加顶部下拉提示
                            if !isDragging {
                                TopPullDownHint(isVisible: $showTopHint)
                                .padding(.top, -15)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { value in
                                    // 使用更平滑的计算方式
                                    if value.translation.height > 0 {
                                        // 添加阻尼效果，使下拉感觉更自然
                                        let dampingFactor: CGFloat = 0.7
                                        let newOffset = value.translation.height * dampingFactor
                                        
                                        // 使用withAnimation包装状态更新，确保平滑过渡
                                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2)) {
                                            dragOffset = newOffset
                                            isDragging = true
                                        }
                                    }
                                }
                                .onEnded { value in
                                    // 如果拖动超过屏幕高度的20%，显示返回确认
                                    let threshold = UIScreen.main.bounds.height * 0.2
                                    if value.translation.height > threshold {
                                        // 先恢复位置，再显示对话框，避免视觉上的跳跃
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            isDragging = false
                                        }
                                        
                                        // 延迟一点显示确认对话框，让动画完成
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            showingReturnConfirmation = true
                                        }
                                    } else {
                                        // 恢复原位，使用更平滑的弹簧动画
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            isDragging = false
                                        }
                                    }
                                }
                        )
                        
                    case .graph:
                        // 关系图视图
                        Group {
                            if let currentFamily = appViewModel.currentFamily {
                                FamilyGraphSpriteView()
                                    .id("FamilyGraphView-\(currentFamily.id)")
                                    .environmentObject(appViewModel)
                                    .edgesIgnoringSafeArea(.top)
                            } else {
                                ContentUnavailableView("请先选择家谱", systemImage: "point.3.connected.trianglepath.dotted")
                            }
                        }
                      
                    case .members:
                        // 成员视图
                        Group {
                            if let currentFamily = appViewModel.currentFamily {
                                MembersView(family: currentFamily)
                                    .environmentObject(appViewModel)
                                    .padding(.bottom, tabBarHeight) // 添加底部内边距

                            } else {
                                ContentUnavailableView("请先选择家谱", systemImage: "person.3.sequence")
                            }
                        }
                        
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: dragOffset)
            }
            
            // 替换原来的下拉提示为新的组件
            if isDragging || dragOffset > 0 {  // 修改条件，确保平滑过渡
                DragDownIndicator(
                    dragOffset: dragOffset,
                    threshold: UIScreen.main.bounds.height * 0.2
                )
                .transition(.opacity)  // 添加过渡效果
                .animation(.interactiveSpring(), value: isDragging)  // 添加动画
            }
            
            // 自定义底部导航栏
            CustomTabBar(
                selectedTab: $coordinator.currentScreen,
                isEnabled: appViewModel.currentFamily != nil,
                showReturnConfirmation: $showingReturnConfirmation
            )
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // 只在首次出现时加载数据
            if !initialDataLoaded {
                Task {
                    await appViewModel.loadInitialData()
                    initialDataLoaded = true
                }
            }
            
            // 重置顶部提示显示状态
            showTopHint = true
        }
        .onChange(of: coordinator.currentScreen) { oldValue, newValue in
            // 只在以下情况处理数据加载：
            // 1. 从家谱视图切换到其他视图
            // 2. 切换到家谱视图
            if oldValue == .familyTree || newValue == .familyTree {
                Task {
                    if appViewModel.familyGraphViewModel.graphData == nil {
                        await appViewModel.familyGraphViewModel.loadData()
                    } 
                }
            }
            
            // 如果切换到家谱视图，显示顶部提示
            if newValue == .familyTree {
                showTopHint = true
            }
        }
        .environmentObject(coordinator)
        .overlay {
            if appViewModel.isLoading {
                ProgressView("加载中...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .alert(
            "错误",
            isPresented: .constant(appViewModel.errorMessage != nil),
            actions: {
                Button("确定") {
                    appViewModel.errorMessage = nil
                }
            },
            message: {
                if let errorMessage = appViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        )
        // 添加确认返回的对话框
        .confirmationDialog(
            "返回家谱选择",
            isPresented: $showingReturnConfirmation,
            titleVisibility: .visible
        ) {
            Button("返回", role: .destructive) {
                // 返到家谱选择界面
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要返回家谱选择界面吗？")
        }
    }
}

// 自定义底部导航栏
struct CustomTabBar: View {
    @Binding var selectedTab: AppCoordinator.Screen
    var isEnabled: Bool
    @Binding var showReturnConfirmation: Bool // 添加返回确认绑定
    
    var body: some View {
        HStack(spacing: 16) {
            // 移除返回按钮，只保留导航标签
            ForEach(AppCoordinator.Screen.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    selectedTab: $selectedTab,
                    isEnabled: isEnabled || tab == .familyTree
                )
                
                if tab != .members { // 最后一个按钮后不加间距
                    Spacer()
                }
            }
        }
        .padding(.horizontal,50)
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
        )
    }
}

// 自定义底部导航按钮
struct TabBarButton: View {
    let tab: AppCoordinator.Screen
    @Binding var selectedTab: AppCoordinator.Screen
    var isEnabled: Bool
    
    // 添加动画状态
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            if isEnabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                    // 点击时触发缩放动画
                    iconScale = 0.8
                    
                    // 恢复原始大小
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            iconScale = 1.0
                        }
                    }
                }
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // 背景圆形
                    Circle()
                        .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    // 图标
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .accentColor : .gray)
                        .scaleEffect(selectedTab == tab ? iconScale : 1.0)
                }
                .overlay(
                    // 选中时的边框
                    Circle()
                        .stroke(selectedTab == tab ? Color.accentColor : Color.clear, lineWidth: 2)
                        .scaleEffect(selectedTab == tab ? 1.0 : 0.8)
                        .opacity(selectedTab == tab ? 1 : 0)
                        .animation(.spring(response: 0.3), value: selectedTab)
                )
                
               
            }
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
    }
    
    private var iconName: String {
        switch tab {
        case .familyTree:
            return "tree"
        case .graph:
            return "point.3.connected.trianglepath.dotted"
        case .members:
            return "person.3"
        }
    }
    
    private var title: String {
        switch tab {
        case .familyTree:
            return "家谱"
        case .graph:
            return "关系图"
        case .members:
            return "成员"
        }
    }
}

// 扩展 AppCoordinator.Screen 以支持 allCases
extension AppCoordinator.Screen: CaseIterable {
    public static var allCases: [AppCoordinator.Screen] {
        return [.familyTree, .graph, .members]
    }
}

// 添加预览视图
#Preview("内容视图") {
    ContentView()
        .environmentObject(FamilyAppViewModel.preview)
}

// 顶部下拉提示组件
struct TopPullDownHint: View {
    @Binding var isVisible: Bool
    @State private var opacity: Double = 0.8
    
    var body: some View {
        if isVisible {
            VStack(spacing: 4) {
                HStack {
                    Text("下拉返回家谱选择")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.7))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 5)
            .shadow(color: .black.opacity(0.2), radius: 3)
            .opacity(opacity)
            .onAppear {
                // 创建闪烁动画
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    opacity = 0.4
                }
            }
        }
    }
}

// 下拉指示器组件
struct DragDownIndicator: View {
    let dragOffset: CGFloat
    let threshold: CGFloat
    
    // 计算下拉进度百分比，添加平滑处理
    private var progress: CGFloat {
        // 使用 smoothstep 函数使进度更平滑
        let rawProgress = min(dragOffset / threshold, 1.0)
        return smoothstep(rawProgress)
    }
    
    // smoothstep 函数，使过渡更平滑
    private func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }
    
    // 根据进度返回不同的颜色
    private var progressColor: Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .gray
        }
    }
    
    // 根据进度返回不同的文本
    private var statusText: String {
        if progress >= 1.0 {
            return "松开返回家谱选择"
        } else if progress >= 0.5 {
            return "继续下拉返回"
        } else {
            return "下拉返回家谱选择"
        }
    }
    
    // 根据进度返回不同的图标
    private var statusIcon: String {
        if progress >= 1.0 {
            return "checkmark.circle.fill"
        } else {
            return "chevron.down"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 状态文本
            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(progressColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 2)
                )
            
            // 进度指示器
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.interactiveSpring(response: 0.3), value: progress)  // 添加动画
                
                // 中心图标
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(progressColor)
                    .scaleEffect(progress >= 1.0 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: progress >= 1.0)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(progressColor, lineWidth: progress >= 1.0 ? 2 : 0)
        )
        .scaleEffect(1.0 + progress * 0.1)
        .opacity(min(1, dragOffset / 50))
        .position(x: UIScreen.main.bounds.width / 2, y: 50)
        // 使用drawingGroup()启用Metal硬件加速
        .drawingGroup()
    }
}


