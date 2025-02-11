import SwiftUI

class AppCoordinator: ObservableObject {
    enum Screen {
        case familyTree
        case members // 新增
        case profile
        case settings
    }
    
    @Published var currentScreen: Screen = .familyTree
}