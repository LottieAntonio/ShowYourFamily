import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var familyViewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    let familyManager: FamilyManagementViewModel
    
    init(familyManager: FamilyManagementViewModel) {
        self.familyManager = familyManager
        
        // 使用已存在的 FamilyTreeViewModel
        let fvm = familyManager.familyTreeViewModel ?? FamilyTreeViewModel(familyManager: familyManager)
        
        _familyViewModel = StateObject(wrappedValue: fvm)
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(
            familyTreeViewModel: fvm,
            familyManager: familyManager
        ))
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView(selection: $coordinator.currentScreen) {
            FamilyTreeView(familyManager: familyManager)
                .environmentObject(familyViewModel)
                .environmentObject(personManager)
                .tabItem {
                    Label("家谱", systemImage: "tree")
                }
                .tag(AppCoordinator.Screen.familyTree)
            
            // 修改 SpriteKit 视图部分
            ZStack {
                Color.white  // 添加白色背景
                FamilyGraphSpriteView(familyTreeViewModel: familyViewModel)
                    // 添加 id 以确保视图在切换标签页时不会被重用
                    .id("graphView-\(coordinator.currentScreen == .graph)")
            }
            .edgesIgnoringSafeArea(.all)  // 确保扩展到安全区域外
            .tabItem {
                Label("关系图", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .tag(AppCoordinator.Screen.graph)
            .disabled(familyManager.currentFamily == nil)
            .onAppear {
                if coordinator.currentScreen == .graph {
                    print("关系图标签页出现")
                    // 强制刷新数据
                    Task {
                        try? await familyViewModel.loadData()
                    }
                }
            }
            .task {
                if coordinator.currentScreen == .graph && familyViewModel.persons.isEmpty {
                    print("📊 关系图：开始加载数据")
                    try? await familyViewModel.loadData()
                }
            }
            
            Group {
                if let currentFamily = familyManager.currentFamily {
                    MembersView(
                        familyTreeViewModel: familyViewModel,
                        family: currentFamily
                    )
                    .environmentObject(personManager)
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
            Task {
                print("🔄 ContentView: 开始加载初始数据")
                await familyManager.loadFamilies()
                
                // 自动选择第一个家谱并确保数据加载
                if familyManager.currentFamily == nil,
                   let firstFamily = familyManager.families.first {
                    print("📊 ContentView: 自动选择第一个家谱")
                    await familyManager.switchFamily(firstFamily)
                    try? await familyViewModel.loadData()
                    await personManager.loadData()
                }
            }
        }
        // 添加对当前家谱变化的监听
        .onChange(of: familyManager.currentFamily) { oldValue, newValue in
            if let family = newValue {
                print("📊 ContentView: 切换到家谱：\(family.name)")
                Task {
                    // 确保先切换家谱
                    await familyManager.switchFamily(family)
                    // 然后重新加载数据
                    try? await familyViewModel.loadData()
                    await personManager.loadData()
                }
            }
        }
        .environmentObject(coordinator)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.showingExitConfirmation = true
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
        }
        .alert("确认返回", isPresented: $coordinator.showingExitConfirmation) {
            Button("取消", role: .cancel) { }
            Button("返回主页", role: .destructive) {
                Task {
                    await MainActor.run {
                        coordinator.currentScreen = .familyTree
                        // 移除 switchFamily 调用
                        coordinator.navigateToRoot = true
                    }
                }
            }
        } message: {
            Text("确定要返回主页吗？")
        }
        // 添加环境值监听
        .onChange(of: coordinator.navigateToRoot) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    // 添加一个统一的数据刷新方法
    private func refreshAllData() async {
        guard let currentFamily = familyManager.currentFamily else {
            print("⚠️ ContentView: 没有当前家谱")
            return
        }
        
        print("📊 ContentView: 刷新家谱数据：\(currentFamily.name)")
        
        // 先切换家谱，确保 ID 一致
        await familyManager.switchFamily(currentFamily)
        
        // 强制刷新 FamilyTreeViewModel 数据
        await familyViewModel.refreshAfterFamilySwitch()
        
        // 重新加载数据
        try? await familyViewModel.loadData()
        
        // 刷新人员管理数据
        await personManager.loadData()
        
        // 确保选中的人物是当前家谱的成员
        if let firstPerson = familyViewModel.persons.first,
           familyViewModel.selectedPerson == nil ||
           !familyViewModel.persons.contains(where: { $0.id == familyViewModel.selectedPerson?.id }) {
            print("📊 ContentView: 自动选择第一个人物：\(firstPerson.name)")
            familyViewModel.selectPerson(firstPerson)
        }
        
        print("📊 ContentView: 数据刷新完成")
    }
}

#Preview {
    var dataManager = LocalDataManager()
    var familyManager = FamilyManagementViewModel(dataManager: dataManager)
    return ContentView(familyManager: familyManager)
}
