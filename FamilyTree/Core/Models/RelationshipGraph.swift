/*
 * RelationshipGraph 类
 * 作用：构建和管理家庭关系图
 * - 使用邻接表存储关系
 * - 计算两人之间的关系路径
 * - 计算代际差异
 */

import Foundation

class RelationshipGraph {
    // 图节点结构
    struct Node {
        let personId: UUID
        var generationDiff: Int  // 与参照点的代际差
        var relationshipPath: [RelationType]  // 关系路径
    }
    
    // 邻接表表示的图
    private var adjacencyList: [UUID: [(UUID, RelationType)]] = [:]
    // 代际差缓存
    
    // 添加关系边
    func addRelationship(_ relationship: Relationship) {
        // 添加双向边
        adjacencyList[relationship.fromPerson, default: []].append((relationship.toPerson, relationship.type))
        
        // 对于父子关系，需要特殊处理反向关系
        let reverseType: RelationType
        switch relationship.type {
        case .father:
            reverseType = .child
        case .mother:
            reverseType = .child
        case .child:
            // 修复：使用 Person.Gender 而不是 UUID
            reverseType = .father  // 默认设置为父亲关系，因为这里无法获取性别信息
        default:
            reverseType = relationship.type
        }
        
        adjacencyList[relationship.toPerson, default: []].append((relationship.fromPerson, reverseType))
    }
    
    // 添加清理方法
    func clear() {
        adjacencyList.removeAll()
    }
    
    func calculateRelationship(from sourceId: UUID, to targetId: UUID) -> (generationDiff: Int, path: [RelationType])? {
        var visited = Set<UUID>()
        var queue = [(UUID, [RelationType], Int)]() // (节点ID, 路径, 代际差)
        
        queue.append((sourceId, [], 0))
        visited.insert(sourceId)
        
        while !queue.isEmpty {
            let (currentId, currentPath, currentGeneration) = queue.removeFirst()
            
            if currentId == targetId {
                return (currentGeneration, currentPath)
            }
            
            guard let neighbors = adjacencyList[currentId] else { continue }
            
            for (nextId, relationType) in neighbors {
                if !visited.contains(nextId) {
                    visited.insert(nextId)
                    
                    // 修复：将 switch 表达式改为正确的语法
                    let generationDiff = currentGeneration + {
                        switch relationType {
                        case .father, .mother:
                            return 1
                        case .child:
                            return -1
                        default:
                            return 0
                        }
                    }()
                    
                    queue.append((nextId, currentPath + [relationType], generationDiff))
                }
            }
        }
        
        return nil
    }
}
