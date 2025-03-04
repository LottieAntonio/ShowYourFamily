import Foundation

struct AppState {
    // 当前选中的家谱
    var currentFamily: Family?
    
    // 当前家谱的数据
    var persons: [Person] = []
    var relationships: [Relationship] = []
    var selectedPerson: Person?
    
    // 所有家谱列表
    var families: [Family] = []
    
    // 应用状态
    var isInitialized: Bool = false
    var isLoading: Bool = false
    var error: Error?
}