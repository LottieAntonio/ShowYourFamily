
/*
 * RelationshipUtils 工具类
 * 作用：提供关系查找和处理的辅助方法
 * - 查找父母关系
 * - 查找兄弟姐妹关系
 * - 处理亲属关系的判断
 */

import Foundation

struct RelationshipUtils {
    static func findParents(for personId: UUID, in relationships: [Relationship]) -> [UUID]? {
        let parents = relationships.compactMap { relation in
            if relation.toPerson == personId && (relation.type == .father || relation.type == .mother) {
                return relation.fromPerson
            }
            return nil
        }
        return parents.isEmpty ? nil : parents
    }
    
    static func findSiblings(for parents: [UUID], in relationships: [Relationship]) -> Set<UUID>? {
        var siblings = Set<UUID>()
        var toCheck = Set<UUID>()
        
        // 首先从父母关系中找到所有子女
        for parentId in parents {
            let childRelations = relationships.filter {
                ($0.type == .child) &&
                ($0.fromPerson == parentId)
            }
            let children = childRelations.map { $0.toPerson }
            toCheck.formUnion(children)
            siblings.formUnion(children)
        }
        
        // 然后查找这些子女之间的兄弟姐妹关系
        let siblingRelations = relationships.filter { 
            $0.type == .brother || $0.type == .sister 
        }
        
        while !toCheck.isEmpty {
            let currentId = toCheck.removeFirst()
            
            // 查找当前人物的直接兄弟姐妹
            let directSiblings = siblingRelations.filter {
                ($0.fromPerson == currentId || $0.toPerson == currentId)
            }.map {
                $0.fromPerson == currentId ? $0.toPerson : $0.fromPerson
            }
            
            // 添加找到的兄弟姐妹
            for sibling in directSiblings {
                if !siblings.contains(sibling) {
                    siblings.insert(sibling)
                    toCheck.insert(sibling)
                }
            }
        }
        
        return siblings.isEmpty ? nil : siblings
    }
    
    static func findParentSiblings(for personId: UUID, in relationships: [Relationship]) async -> [(UUID, Bool, Bool)]? {
        guard let parents = findParents(for: personId, in: relationships) else { return nil }
        
        var siblings: [(UUID, Bool, Bool)] = []
        
        for parentId in parents {
            let siblingRelations = relationships.filter {
                ($0.type == .brother || $0.type == .sister) &&
                ($0.fromPerson == parentId || $0.toPerson == parentId)
            }
            
            let isFromFatherSide = relationships.first { 
                $0.fromPerson == parentId && $0.toPerson == personId 
            }?.type == .father
            
            for relation in siblingRelations {
                let siblingId = relation.fromPerson == parentId ? relation.toPerson : relation.fromPerson
                let isElder = relation.type == .brother
                siblings.append((siblingId, isFromFatherSide, isElder))
            }
        }
        
        return siblings.isEmpty ? nil : siblings
    }
    
    static func isFatherSide(_ relativeId: UUID, for personId: UUID, in relationships: [Relationship], persons: [Person]) -> Bool {
        guard let parents = findParents(for: personId, in: relationships) else { return false }
        
        for parentId in parents {
            if let parent = persons.first(where: { $0.id == parentId }) {
                let siblingRelations = relationships.filter {
                    ($0.type == .brother || $0.type == .sister) &&
                    (($0.fromPerson == parentId && $0.toPerson == relativeId) ||
                     ($0.fromPerson == relativeId && $0.toPerson == parentId))
                }
                
                if !siblingRelations.isEmpty {
                    return parent.gender == .male
                }
            }
        }
        
        return false
    }
    
    static func isElder(_ person1: Person, than person2: Person) -> Bool {
        let date1 = person1.birthDate ?? Date.distantFuture
        let date2 = person2.birthDate ?? Date.distantFuture
        return date1 < date2
    }
    
    static func findNephewNieceRelation(from selfId: UUID, to nephewId: UUID, in relationships: [Relationship], persons: [Person]) -> [Relationship]? {
        // 1. 先找到自己的所有兄弟姐妹关系
        let siblingRelations = relationships.filter {
            ($0.type == .brother || $0.type == .sister) &&
            ($0.fromPerson == selfId || $0.toPerson == selfId)
        }
        
        for siblingRel in siblingRelations {
            // 2. 获取兄弟姐妹的ID
            let siblingId = siblingRel.fromPerson == selfId ? siblingRel.toPerson : siblingRel.fromPerson
            
            // 3. 获取兄弟姐妹的信息，判断是兄弟还是姐妹
            guard let sibling = persons.first(where: { $0.id == siblingId }) else { continue }
            
            // 4. 查找这个兄弟姐妹和目标人物之间的父子/母子关系
            let childRelation = relationships.first {
                // 兄弟姐妹是父母，目标是子女
                ($0.type == .child && $0.fromPerson == siblingId && $0.toPerson == nephewId) ||
                // 目标是子女，兄弟姐妹是父母
                ($0.type == .father && $0.fromPerson == nephewId && $0.toPerson == siblingId) ||
                ($0.type == .mother && $0.fromPerson == nephewId && $0.toPerson == siblingId)
            }
            
            if let childRel = childRelation {
                // 5. 保持原始的兄弟姐妹关系类型
                return [siblingRel, childRel]
            }
        }
        
        return nil
    }
    
    static func findRelationshipPath(from sourceId: UUID?, to targetId: UUID, in relationships: [Relationship], persons: [Person]) async -> [Relationship] {
        guard let sourceId = sourceId else { return [] }
        
        // 1. 先检查是否是伯父/叔父/姑姑看侄子/侄女
        if let nephewPath = findNephewNieceRelation(from: sourceId, to: targetId, in: relationships, persons: persons) {
            return nephewPath
        }
        
        // 2. 再检查是否是侄子/侄女看伯父/叔父/姑姑
        if let unclePath = findNephewNieceRelation(from: targetId, to: sourceId, in: relationships, persons: persons) {
            return unclePath.reversed()
        }
        
        // 3. 检查直系亲属关系
        // 3.1 检查是否是父子关系（父亲看儿子）
        let directChildPath = relationships.filter {
            $0.type == .child &&
            $0.fromPerson == sourceId &&
            $0.toPerson == targetId
        }
        
        if !directChildPath.isEmpty {
            return directChildPath
        }
        
        // 3.2 检查是否是子父关系（儿子看父亲）
        let parentPath = relationships.filter {
            ($0.type == .father || $0.type == .mother) &&
            $0.fromPerson == targetId &&
            $0.toPerson == sourceId
        }
        
        if !parentPath.isEmpty {
            return parentPath
        }
        
        // 4. 检查兄弟姐妹关系
        let directSiblingPath = relationships.filter {
            ($0.type == .brother || $0.type == .sister) &&
            (($0.fromPerson == sourceId && $0.toPerson == targetId) ||
             ($0.fromPerson == targetId && $0.toPerson == sourceId))
        }
        
        if !directSiblingPath.isEmpty {
            return directSiblingPath
        }
        
        // 5. 检查是否有共同父母（这表明是兄弟姐妹关系）
        if let sourceParents = findParents(for: sourceId, in: relationships),
           let targetParents = findParents(for: targetId, in: relationships) {
            let commonParents = Set(sourceParents).intersection(Set(targetParents))
            if !commonParents.isEmpty {
                return [Relationship(
                    type: .sister,
                    fromPerson: sourceId,
                    toPerson: targetId
                )]
            }
        }
        
        // 返回空数组表示未找到路径
        return []
    }
    
    // 删除 findGeneralPath 方法
    
    static func findSpouse(for personId: UUID, in relationships: [Relationship], persons: [Person]) -> (UUID, Person.Gender)? {
        let spouseRelation = relationships.first { relation in
            relation.type == .spouse && (relation.fromPerson == personId || relation.toPerson == personId)
        }
        
        if let relation = spouseRelation {
            let spouseId = relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
            if let spouse = persons.first(where: { $0.id == spouseId }) {
                return (spouseId, spouse.gender)
            }
        }
        return nil
    }
}
