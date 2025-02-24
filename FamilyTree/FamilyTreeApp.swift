import SwiftUI

@main
struct FamilyTreeApp: App {
    let dataManager = LocalDataManager()
    
    var body: some Scene {
        WindowGroup {
            FamilySelectionView(dataManager: dataManager)
                .task {
                    print("🚀 App启动，开始初始化数据...")
                    do {
                        _ = try await dataManager.loadFamilies()
                    } catch {
                        print("❌ 数据初始化失败：\(error.localizedDescription)")
                    }
                }
        }
    }
}