import Foundation

@MainActor
class RelationshipManager {
    private let stateManager: StateManager
    private var titleGenerator: RelativeTitleGenerator?
    
    init(stateManager: StateManager) {
        self.stateManager = stateManager
    }
    
    // 生成亲属称谓
    func generateTitle(for person: Person) -> String? {
        // 懒加载 titleGenerator
        if titleGenerator == nil || stateManager.state.relationships.count > 0 {
            titleGenerator = RelativeTitleGenerator(
                relationships: stateManager.state.relationships,
                persons: stateManager.state.persons
            )
        }
        
        return titleGenerator?.generateTitle(for: person)
    }
    
    // 当数据变化时重置生成器
    func resetTitleGenerator() {
        titleGenerator = nil
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
        
        // 这里可以实现更复杂的关系描述逻辑
        return "有\(path.count)个关系连接"
    }
}