import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var familyViewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    
    init() {
        // 修复：移除重复创建的实例
        let fvm = FamilyTreeViewModel()
        _familyViewModel = StateObject(wrappedValue: fvm)
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(familyTreeViewModel: fvm))
    }
    
    var body: some View {
        TabView(selection: $coordinator.currentScreen) {
            FamilyTreeView()
                .environmentObject(familyViewModel)
                .environmentObject(personManager)
                .tabItem {
                    Label("家谱", systemImage: "tree")
                }
                .tag(AppCoordinator.Screen.familyTree)
            
            // 修复：使用 MembersView 而不是直接使用 PersonListView
            MembersView(familyTreeViewModel: familyViewModel)
                .environmentObject(personManager)  // 添加 personManager
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
            // 初始加载数据
            Task {
                await personManager.loadData()
            }
        }
        .environmentObject(coordinator)
    }
}

#Preview {
    ContentView()
}
