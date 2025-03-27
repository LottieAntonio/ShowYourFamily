import Foundation

@MainActor
class RelationshipManager {
    private let stateManager: StateManager
    private var titleGenerator: RelativeTitleGenerator?
    private var lastRelationshipCount = 0
    private var lastPersonCount = 0
    
    init(stateManager: StateManager) {
        self.stateManager = stateManager
    }
    
    // 生成亲属称谓
    func generateTitle(for person: Person) -> String? {
        // 检查数据是否变化，如果变化则重置生成器
        let currentRelationshipCount = stateManager.state.relationships.count
        let currentPersonCount = stateManager.state.persons.count
        
        if titleGenerator == nil || 
           currentRelationshipCount != lastRelationshipCount || 
           currentPersonCount != lastPersonCount {
            
            titleGenerator = RelativeTitleGenerator(
                relationships: stateManager.state.relationships,
                persons: stateManager.state.persons
            )
            
            lastRelationshipCount = currentRelationshipCount
            lastPersonCount = currentPersonCount
        }
        
        return titleGenerator?.generateTitle(for: person)
    }
    
    // 当数据变化时重置生成器
    func resetTitleGenerator() {
        // 如果已有生成器，先清除其缓存
        if let generator = titleGenerator {
            generator.clearCache()
            print("RelationshipManager: 已清除现有称谓生成器的缓存")
        }
        
        // 重置生成器
        titleGenerator = nil
        lastRelationshipCount = 0
        lastPersonCount = 0
        
        // 立即创建新的称谓生成器，确保"自己"的称谓能够立即生效
        titleGenerator = RelativeTitleGenerator(
            relationships: stateManager.state.relationships,
            persons: stateManager.state.persons
        )
        
        // 打印日志，方便调试
        print("RelationshipManager: 已重置称谓生成器")
    }
    
    // 查找关系路径
    func findRelationPath(from source: Person, to target: Person) -> [Relationship] {
        let pathFinder = RelationshipPathFinder(relationships: stateManager.state.relationships)
        return pathFinder.findPath(from: source.id, to: target.id)
    }
    
    // 获取关系描述
    func getRelationshipDescription(from source: Person, to target: Person) -> String {
        let path = findRelationPath(from: source, to: target)
        if path.isEmpty {
            return "没有直接关系"
        }
        
        // 使用RelativeTitleGenerator生成更详细的关系描述
        if let title = generateTitle(for: target) {
            return title.replacingOccurrences(of: "\(source.lastName)\(source.firstName)的", with: "")
        }
        
        return "有\(path.count)个关系连接"
    }
    
}
