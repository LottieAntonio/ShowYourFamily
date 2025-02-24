import SwiftUI

class AppCoordinator: ObservableObject {
    @Published var currentScreen: Screen = .familyTree
    @Published var showingExitConfirmation = false
    @Published var navigateToRoot = false
    
    enum Screen {
        case familyTree
        case members // 新增
        case profile
        case settings
    }
    
}
