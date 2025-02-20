import Foundation

class SiblingHandler: BasePersonHandler {
    func getSiblings(for person: Person, type: RelationType) -> [Person] {
        var siblings = Set<Person>()
        
        // 获取直接关系的兄弟姐妹
        let directSiblings = relationships.filter {
            ($0.fromPerson == person.id || $0.toPerson == person.id) &&
            ($0.type == .brother || $0.type == .sister)
        }.compactMap { relationship in
            persons.first { $0.id == (relationship.fromPerson == person.id ? relationship.toPerson : relationship.fromPerson) }
        }
        siblings.formUnion(directSiblings)
        
        // 获取当前人物的父母
       let parents = getParents(for: person)
       let father = parents.father
       let mother = parents.mother
       
       // 获取父亲的所有子女
       if let father = father {
           let fatherChildren = getChildren(for: father)
           siblings.formUnion(fatherChildren)
       }
       
       // 获取母亲的所有子女
       if let mother = mother {
           let motherChildren = getChildren(for: mother)
           siblings.formUnion(motherChildren)
       }
       
       // 过滤条件：
       // 1. 不是自己
       // 2. 性别符合要求
       // 3. 至少有一个共同父母
       return Array(siblings).filter { sibling in
           guard sibling.id != person.id else { return false }
           guard type == .brother ? sibling.gender == .male : sibling.gender == .female else { return false }
           
           // 获取兄弟姐妹的父母
           let siblingParents = getParents(for: sibling)
           
           // 检查是否至少有一个共同父母
           let hasSameFather = father?.id == siblingParents.father?.id && father != nil
           let hasSameMother = mother?.id == siblingParents.mother?.id && mother != nil
           
           return hasSameFather || hasSameMother
       }
    }
    
    func handleSiblingAddition(from person: Person, newSibling: Person, type: RelationType) async throws {
        // 创建新的兄弟姐妹
        var newPerson = newSibling
        newPerson.gender = type == .brother ? .male : .female
        try await dataManager.savePerson(newPerson)
        
        // 建立与父母的关系
        await establishParentRelations(for: newPerson, from: person)
        
        // 建立与其他兄弟姐妹的关系
        await establishSiblingRelations(for: newPerson, from: person)
    }
    
    private func establishParentRelations(for newPerson: Person, from person: Person) async {
        let parents = getParents(for: person)
        if let father = parents.father {
            try? await addChildRelationship(parent: father, child: newPerson)
        }
        if let mother = parents.mother {
            try? await addChildRelationship(parent: mother, child: newPerson)
        }
    }
    
    private func establishSiblingRelations(for newPerson: Person, from person: Person) async {
        let siblings = getSiblings(for: person, type: .brother) + getSiblings(for: person, type: .sister)
        var allSiblings = siblings
        allSiblings.append(person)
        
        for sibling in allSiblings where sibling.id != newPerson.id {
            let siblingToNewType: RelationType = newPerson.gender == .male ? .brother : .sister
            let newToSiblingType: RelationType = sibling.gender == .male ? .brother : .sister
            
            try? await createSiblingRelationship(from: sibling, to: newPerson, type: siblingToNewType)
            try? await createSiblingRelationship(from: newPerson, to: sibling, type: newToSiblingType)
        }
    }
    
    private func createSiblingRelationship(from: Person, to: Person, type: RelationType) async throws {
        let relationship = Relationship(type: type, fromPerson: from.id, toPerson: to.id)
        try await dataManager.saveRelationship(relationship)
    }
}
