import SwiftUI

@main
struct FamilyTreeApp: App {
    // 创建 dataManager
    private let dataManager = LocalDataManager()
    
    // 创建 FamilyAppViewModel 而不是 StateManager
    @StateObject private var appViewModel = FamilyAppViewModel()
    
    var body: some Scene {
        WindowGroup {
            FamilySelectionView()
                .task {
                    // 使用 appViewModel 加载初始数据
                    await appViewModel.loadInitialData()
                }
                .environmentObject(appViewModel)
                .tint(Color.familyTheme.primary) // 设置全局按钮颜色
        }
    }
}
