import Foundation

class BasePersonHandler {
    let dataManager: DataManaging
    var relationships: [Relationship]
    var persons: [Person]
    
    init(dataManager: DataManaging, relationships: [Relationship], persons: [Person]) {
        self.dataManager = dataManager
        self.relationships = relationships
        self.persons = persons
    }
    
    func updateData(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
    }
    
    func getParents(for person: Person) -> (father: Person?, mother: Person?) {
        let father = getRelatedPersons(for: person, relationType: .father).first
        let mother = getRelatedPersons(for: person, relationType: .mother).first
        return (father, mother)
    }
    
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        switch relationType {
        case .brother, .sister:
            var siblings = Set<Person>()
            
            // 获取直接设置的兄弟姐妹关系
            let directRelationships = relationships.filter { relationship in
                (relationship.fromPerson == person.id || relationship.toPerson == person.id) &&
                (relationship.type == .brother || relationship.type == .sister)
            }
            
            let directSiblings = directRelationships.compactMap { relationship in
                if relationship.fromPerson == person.id {
                    return persons.first { $0.id == relationship.toPerson }
                } else {
                    return persons.first { $0.id == relationship.fromPerson }
                }
            }
            siblings.formUnion(directSiblings)
            
            // 通过父母关联的兄弟姐妹
            let parents = getParents(for: person)
            if let father = parents.father {
                let fatherChildren = getRelatedPersons(for: father, relationType: .child)
                siblings.formUnion(fatherChildren)
            }
            if let mother = parents.mother {
                let motherChildren = getRelatedPersons(for: mother, relationType: .child)
                siblings.formUnion(motherChildren)
            }
            
            return Array(siblings).filter { sibling in
                let correctGender = relationType == .brother ? sibling.gender == .male : sibling.gender == .female
                return correctGender && sibling.id != person.id
            }
            
        default:
            let relationships = self.relationships.filter { relationship in
                switch relationType {
                case .father:
                    return relationship.fromPerson == person.id && relationship.type == .father
                case .mother:
                    return relationship.fromPerson == person.id && relationship.type == .mother
                case .child:
                    return relationship.toPerson == person.id && 
                           (relationship.type == .father || relationship.type == .mother)
                case .spouse:
                    return (relationship.fromPerson == person.id && relationship.type == .spouse) ||
                           (relationship.toPerson == person.id && relationship.type == .spouse)
                default:
                    return false
                }
            }
            
            return relationships.compactMap { relationship in
                if relationship.fromPerson == person.id {
                    return persons.first { $0.id == relationship.toPerson }
                } else {
                    return persons.first { $0.id == relationship.fromPerson }
                }
            }
        }
    }
    
    func getChildren(for person: Person) -> [Person] {
        let parentType: RelationType = person.gender == .male ? .father : .mother
        return relationships.filter { relationship in
            relationship.toPerson == person.id && relationship.type == parentType
        }.compactMap { relationship in
            persons.first { $0.id == relationship.fromPerson }
        }
        return []

    }
    
    func addChildRelationship(parent: Person, child: Person) async throws {
        let parentType: RelationType = parent.gender == .male ? .father : .mother
        let relationship = Relationship(
            type: parentType,
            fromPerson: child.id,
            toPerson: parent.id
        )
        try await dataManager.saveRelationship(relationship)
    }
}
