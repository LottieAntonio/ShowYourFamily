import SwiftUI

@main
struct FamilyTreeApp: App {
    let dataManager = LocalDataManager()
    
    var body: some Scene {
        WindowGroup {
            FamilySelectionView(dataManager: dataManager)
                .task {
                    do {
                        _ = try await dataManager.loadFamilies()
                    } catch {
                        // 错误处理
                    }
                }
        }
    }
}