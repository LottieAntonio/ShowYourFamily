
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
    
    
    static func isElder(_ person1: Person, than person2: Person) -> Bool {
        let date1 = person1.birthDate ?? Date.distantFuture
        let date2 = person2.birthDate ?? Date.distantFuture
        return date1 < date2
    }
    
    
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
