import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var familyViewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    let familyManager: FamilyManagementViewModel
    
    init(familyManager: FamilyManagementViewModel) {
        self.familyManager = familyManager
        
        // 使用传入的 familyManager 的 localDataManager
        let dataManager = familyManager.localDataManager
        
        // 创建视图模型，使用协议类型
        let fvm = FamilyTreeViewModel(dataManager: dataManager)
        
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
            
            // 修复：使用 MembersView 而不是直接使用 PersonListView
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
            
            ProfileView()
                .tabItem {
                    Label("个人", systemImage: "person")
                }
                .tag(AppCoordinator.Screen.profile)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(AppCoordinator.Screen.settings)
        }
        .tabViewSidebarBottomBar(content: {
            RoundedRectangle(cornerSize: .zero)
        })
        .onAppear {
            // 确保数据加载
            Task {
                await familyManager.loadFamilies()
                await personManager.loadData()
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
}

#Preview {
    let dataManager = LocalDataManager()
    let familyManager = FamilyManagementViewModel(dataManager: dataManager)
    return ContentView(familyManager: familyManager)
}
