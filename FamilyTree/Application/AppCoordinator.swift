import SwiftUI

class AppCoordinator: ObservableObject {
    enum Screen {
        case familyTree
        case members
        case graph  // 添加关系图页面
    }
    
    @Published var currentScreen: Screen = .familyTree
    @Published var showingExitConfirmation = false
    @Published var navigateToRoot = false
}
