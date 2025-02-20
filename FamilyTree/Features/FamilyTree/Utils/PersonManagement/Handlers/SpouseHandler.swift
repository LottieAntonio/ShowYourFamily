import Foundation

class SpouseHandler: BasePersonHandler {
    func getSpouses(for person: Person) -> [Person] {
        relationships.filter {
            ($0.fromPerson == person.id || $0.toPerson == person.id) &&
            $0.type == .spouse
        }.compactMap { relationship in
            persons.first { $0.id == (relationship.fromPerson == person.id ? relationship.toPerson : relationship.fromPerson) }
        }
    }
    
    func handleSpouseAddition(from person: Person, to spouse: Person) async throws {
        // 创建配偶关系
        let relationship = Relationship(type: .spouse, fromPerson: person.id, toPerson: spouse.id)
        try await dataManager.saveRelationship(relationship)
        
        // 处理子女关系
        await handleChildrenRelations(for: person, with: spouse)
    }
    
    private func handleChildrenRelations(for person: Person, with spouse: Person) async {
        let children = getChildren(for: person)
        
        for child in children {
            let isAlreadyParent = isParentOf(parent: spouse, child: child)
            
            if !isAlreadyParent {
                let parentType: RelationType = spouse.gender == .male ? .father : .mother
                try? await addChildRelationship(parent: spouse, child: child)
            }
        }
    }
    
    private func isParentOf(parent: Person, child: Person) -> Bool {
        let parentType: RelationType = parent.gender == .male ? .father : .mother
        return relationships.contains {
            $0.fromPerson == child.id && $0.toPerson == parent.id && $0.type == parentType
        }
    }
}