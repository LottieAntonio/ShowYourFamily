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
    
    var body: some View {
        TabView(selection: $coordinator.currentScreen) {
            // 家谱视图
            FamilyTreeView()
                .environmentObject(appViewModel)
                .tabItem {
                    Label("家谱", systemImage: "tree")
                }
                .tag(AppCoordinator.Screen.familyTree)
            
            // 关系图视图
            Group {
                if let currentFamily = appViewModel.currentFamily {
                    FamilyGraphSpriteView()
                        .id(currentFamily.id)  // 使用家谱ID作为视图标识符
                        .environmentObject(appViewModel)
                } else {
                    ContentUnavailableView("请先选择家谱", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .background(Color.white)
            .edgesIgnoringSafeArea(.all)
            .tabItem {
                Label("关系图", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .tag(AppCoordinator.Screen.graph)
            .disabled(appViewModel.currentFamily == nil)
            
            // 成员视图
            Group {
                if let currentFamily = appViewModel.currentFamily {
                    MembersView(family: currentFamily)
                        .environmentObject(appViewModel)
                } else {
                    ContentUnavailableView("请先选择家谱", systemImage: "person.3.sequence")
                }
            }
            .tabItem {
                Label("成员", systemImage: "person.3")
            }
            .tag(AppCoordinator.Screen.members)
        }
        .tabViewSidebarBottomBar(content: {
            RoundedRectangle(cornerSize: .zero)
        })
        .onAppear {
            // 只在首次出现时加载数据
            if !initialDataLoaded {
                Task {
                    print("🔄 开始加载家谱数据")
                    await appViewModel.loadInitialData()
                    initialDataLoaded = true
                    print("✅ 加载完成[\(appViewModel.currentFamily?.name ?? "无")]：\(appViewModel.persons.count) 个成员，\(appViewModel.relationships.count) 个关系")
                }
            }
        }
        .onChange(of: coordinator.currentScreen) { oldValue, newValue in
            // 只在切换到图谱视图时刷新图谱数据，且只在必要时刷新
            if newValue == .graph && oldValue != .graph {
                Task {
                    if appViewModel.familyGraphViewModel.graphData == nil {
                        print("📝 切换到家谱：\(appViewModel.currentFamily?.name ?? "未知")")
                        await appViewModel.familyGraphViewModel.loadData()
                    }
                }
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
    }
}
