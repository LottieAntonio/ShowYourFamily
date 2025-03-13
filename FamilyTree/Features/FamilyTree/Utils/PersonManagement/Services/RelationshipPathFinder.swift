import Foundation

class RelationshipPathFinder {
    private var relationships: [Relationship]
    private var pathCache: [String: [Relationship]] = [:]
    
    init(relationships: [Relationship]) {
        self.relationships = relationships
    }
    
    // 生成缓存键
    private func cacheKey(from sourceId: UUID, to targetId: UUID) -> String {
        return "\(sourceId.uuidString)_\(targetId.uuidString)"
    }
    
    // 查找两个人之间的关系路径
    func findPath(from sourceId: UUID, to targetId: UUID) -> [Relationship] {
        // 如果是同一个人，返回空路径
        guard sourceId != targetId else { return [] }
        
        // 检查缓存
        let key = cacheKey(from: sourceId, to: targetId)
        if let cachedPath = pathCache[key] {
            return cachedPath
        }
        
        // 使用双向BFS优化查找效率
        let path = findPathWithBidirectionalBFS(from: sourceId, to: targetId)
        
        // 缓存结果
        pathCache[key] = path
        
        return path
    }
    
    // 使用双向BFS查找路径
    private func findPathWithBidirectionalBFS(from sourceId: UUID, to targetId: UUID) -> [Relationship] {
        // 从源和目标同时开始搜索
        var forwardQueue = [(sourceId, [Relationship]())]
        var backwardQueue = [(targetId, [Relationship]())]
        var forwardVisited = [sourceId: [Relationship]()]
        var backwardVisited = [targetId: [Relationship]()]
        
        while !forwardQueue.isEmpty && !backwardQueue.isEmpty {
            // 从较小的队列开始搜索，提高效率
            if forwardQueue.count <= backwardQueue.count {
                let (current, path) = forwardQueue.removeFirst()
                
                // 检查是否与反向搜索相遇
                if let backPath = backwardVisited[current] {
                    // 合并路径并返回
                    return mergePaths(forwardPath: path, backwardPath: backPath.reversed())
                }
                
                // 继续正向搜索
                let possibleRelations = relationships.filter { relation in
                    relation.fromPerson == current || relation.toPerson == current
                }
                
                for relation in possibleRelations {
                    let nextPerson = relation.fromPerson == current ? relation.toPerson : relation.fromPerson
                    
                    if forwardVisited[nextPerson] == nil {
                        let newPath = path + [relation]
                        forwardVisited[nextPerson] = newPath
                        forwardQueue.append((nextPerson, newPath))
                    }
                }
            } else {
                let (current, path) = backwardQueue.removeFirst()
                
                // 检查是否与正向搜索相遇
                if let forwardPath = forwardVisited[current] {
                    // 合并路径并返回
                    return mergePaths(forwardPath: forwardPath, backwardPath: path.reversed())
                }
                
                // 继续反向搜索
                let possibleRelations = relationships.filter { relation in
                    relation.fromPerson == current || relation.toPerson == current
                }
                
                for relation in possibleRelations {
                    let nextPerson = relation.fromPerson == current ? relation.toPerson : relation.fromPerson
                    
                    if backwardVisited[nextPerson] == nil {
                        let newPath = path + [relation]
                        backwardVisited[nextPerson] = newPath
                        backwardQueue.append((nextPerson, newPath))
                    }
                }
            }
        }
        
        return [] // 没有找到路径
    }
    
    // 合并正向和反向路径
    private func mergePaths(forwardPath: [Relationship], backwardPath: [Relationship]) -> [Relationship] {
        // 需要确保路径的连续性
        var result = forwardPath
        
        // 反向路径需要反转关系方向
        for relation in backwardPath {
            let reversedRelation = Relationship(
                id: relation.id,
                type: relation.type, fromPerson: relation.toPerson,
                toPerson: relation.fromPerson
            )
            result.append(reversedRelation)
        }
        
        return result
    }
    
    // 清除缓存
    func clearCache() {
        pathCache.removeAll()
    }
    
    // 当关系发生变化时更新
    func updateRelationships(_ newRelationships: [Relationship]) {
        self.relationships = newRelationships
        clearCache() // 关系变化后需要清除缓存
    }
}
