import Foundation

class RelationshipPathFinder {
    private var relationships: [Relationship]
    
    init(relationships: [Relationship]) {
        self.relationships = relationships
    }
    
    func updateData(relationships: [Relationship]) {
        self.relationships = relationships
    }
    
    func findPath(from startId: UUID, to endId: UUID) -> [Relationship] {
        var visited = Set<UUID>()
        var queue = [(UUID, [Relationship])]()
        queue.append((startId, []))
        visited.insert(startId)
        
        while !queue.isEmpty {
            let (currentId, path) = queue.removeFirst()
            
            if currentId == endId {
                return path
            }
            
            let relatedRelationships = relationships.filter {
                $0.fromPerson == currentId || $0.toPerson == currentId
            }
            
            for relationship in relatedRelationships {
                let nextId = relationship.fromPerson == currentId ? relationship.toPerson : relationship.fromPerson
                if !visited.contains(nextId) {
                    visited.insert(nextId)
                    queue.append((nextId, path + [relationship]))
                }
            }
        }
        
        return []
    }
    
    func calculateGeneration(from relationships: [Relationship]) -> Generation? {
        var generation = 0
        
        for relationship in relationships {
            switch relationship.type {
            case .father, .mother:
                generation += 1
            case .child:
                generation -= 1
            case .spouse, .brother, .sister:
                continue
            }
        }
        
        return Generation(rawValue: generation)
    }
}