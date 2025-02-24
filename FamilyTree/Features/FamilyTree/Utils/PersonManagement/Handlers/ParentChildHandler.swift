import Foundation

class ParentChildHandler: BasePersonHandler {
    
    func getParents(for person: Person, type: RelationType) -> [Person] {
        relationships.filter { relationship in
            relationship.fromPerson == person.id && relationship.type == type
        }.compactMap { relationship in
            persons.first { $0.id == relationship.toPerson }
        }
    }
    
    override func getChildren(for person: Person) -> [Person] {
        let parentType: RelationType = person.gender == .male ? .father : .mother
        return relationships.filter { relationship in
            // 修改这里：查找所有指向当前人物（作为父/母）的关系
            relationship.toPerson == person.id && 
            relationship.type == parentType
        }.compactMap { relationship in
            // 关系的另一端（fromPerson）就是子女
            persons.first { $0.id == relationship.fromPerson }
        }
    }
    
    func handleParentAddition(from child: Person, to parent: Person, type: RelationType) async throws {
        // 先检查是否已有同类型的父/母
        let existingParents = getParents(for: child, type: type)
        
        // 如果已有父/母，先解除原有关系
        for existingParent in existingParents {
            // 找到并删除原有的父子关系
            if let relationshipToRemove = relationships.first(where: { relationship in
                relationship.fromPerson == child.id && 
                relationship.toPerson == existingParent.id && 
                relationship.type == type
            }) {
                try await dataManager.deleteRelationship(relationshipToRemove.id)
                
                // 可选：解除原父母之间的配偶关系（如果没有其他共同子女）
                await handlePotentialSpouseRelationRemoval(parent: existingParent)
            }
        }
        
        // 创建新的父母-子女关系
        let relationship = Relationship(type: type, fromPerson: child.id, toPerson: parent.id)
        try await dataManager.saveRelationship(relationship)
        
        // 处理配偶关系（与另一方父/母）
        await handleSpouseRelation(for: parent, with: child, type: type)
        
        // 更新兄弟姐妹关系
        await updateSiblingRelations(for: child)
    }
    
    // 新增：处理潜在的配偶关系解除
    private func handlePotentialSpouseRelationRemoval(parent: Person) async {
        // 获取该父/母的所有子女
        let children = getChildren(for: parent)
        
        // 如果没有其他子女，考虑解除配偶关系
        if children.isEmpty {
            // 获取所有配偶关系
            let spouseRelationships = relationships.filter { relationship in
                (relationship.fromPerson == parent.id || relationship.toPerson == parent.id) &&
                relationship.type == .spouse
            }
            
            // 删除配偶关系
            for relationship in spouseRelationships {
                try? await dataManager.deleteRelationship(relationship.id)
            }
        }
    }
    
    // 新增：更新兄弟姐妹关系
    private func updateSiblingRelations(for person: Person) async {
        // 获取父亲和母亲
        let father = getParents(for: person, type: .father).first
        let mother = getParents(for: person, type: .mother).first
        
        // 获取同父的子女（排除父母的父母）
        var paternalSiblings: Set<Person> = []
        if let father = father {
            // 只获取父亲的子女，而不是所有关联人
            paternalSiblings = Set(getChildren(for: father).filter { child in
                // 确保这个人不是父亲的父母
                !getParents(for: father, type: .father).contains(child) &&
                !getParents(for: father, type: .mother).contains(child)
            })
        }
        
        // 获取同母的子女（排除母亲的父母）
        var maternalSiblings: Set<Person> = []
        if let mother = mother {
            // 只获取母亲的子女，而不是所有关联人
            maternalSiblings = Set(getChildren(for: mother).filter { child in
                // 确保这个人不是母亲的父母
                !getParents(for: mother, type: .father).contains(child) &&
                !getParents(for: mother, type: .mother).contains(child)
            })
        }
        
        // 获取同父同母的兄弟姐妹
        let fullSiblings = paternalSiblings.intersection(maternalSiblings)
        
        // 更新兄弟姐妹关系
        for sibling in fullSiblings where sibling.id != person.id {
            let siblingType: RelationType = sibling.gender == .male ? .brother : .sister
            let personType: RelationType = person.gender == .male ? .brother : .sister
            
            // 创建双向关系
            try? await createSiblingRelationship(from: person, to: sibling, type: siblingType)
            try? await createSiblingRelationship(from: sibling, to: person, type: personType)
        }
    }
    
    private func handleSpouseRelation(for parent: Person, with child: Person, type: RelationType) async {
        let otherParentType: RelationType = type == .father ? .mother : .father
        if let otherParent = getParents(for: child, type: otherParentType).first {
            // 检查是否已存在配偶关系
            let hasSpouseRelation = relationships.contains { relationship in
                (relationship.fromPerson == parent.id && relationship.toPerson == otherParent.id ||
                 relationship.fromPerson == otherParent.id && relationship.toPerson == parent.id) &&
                relationship.type == .spouse
            }
            
            if !hasSpouseRelation {
                let spouseRelationship = Relationship(type: .spouse, fromPerson: parent.id, toPerson: otherParent.id)
                try? await dataManager.saveRelationship(spouseRelationship)
            }
        }
    }
    
    private func handleSiblingRelations(for child: Person, with parent: Person, type: RelationType) async {
        // 获取所有可能的兄弟姐妹
        let potentialSiblings = getChildren(for: parent)
        
        for sibling in potentialSiblings where sibling.id != child.id {
            // 检查是否有共同的另一个父母
            let hasCommonParent = await checkCommonParent(sibling: sibling, person: child, type: type)
            
            if hasCommonParent {
                // 根据性别确定关系类型
                let siblingType: RelationType = sibling.gender == .male ? .brother : .sister
                let childType: RelationType = child.gender == .male ? .brother : .sister
                
                // 创建双向关系
                try? await createSiblingRelationship(from: child, to: sibling, type: siblingType)
                try? await createSiblingRelationship(from: sibling, to: child, type: childType)
            }
        }
    }
    
    private func checkCommonParent(sibling: Person, person: Person, type: RelationType) async -> Bool {
        let otherParentType: RelationType = type == .father ? .mother : .father
        let siblingParents = getParents(for: sibling, type: otherParentType)
        let personParents = getParents(for: person, type: otherParentType)
        
        return siblingParents.contains { siblingParent in
            personParents.contains { personParent in
                siblingParent.id == personParent.id
            }
        }
    }
    
    private func createSiblingRelationship(from: Person, to: Person, type: RelationType) async throws {
        let relationship = Relationship(type: type, fromPerson: from.id, toPerson: to.id)
        try await dataManager.saveRelationship(relationship)
    }
    
    func getPotentialParents(for person: Person, type: RelationType) -> [Person] {
        // 获取现有的另一方父/母
        let otherParentType: RelationType = type == .father ? .mother : .father
        guard let otherParent = getParents(for: person, type: otherParentType).first else {
            return []
        }
        
        // 获取另一方父/母的所有配偶
        return relationships.filter { relationship in
            (relationship.fromPerson == otherParent.id || relationship.toPerson == otherParent.id) &&
            relationship.type == .spouse
        }.compactMap { relationship in
            let spouseId = relationship.fromPerson == otherParent.id ? 
                relationship.toPerson : relationship.fromPerson
            return persons.first { 
                $0.id == spouseId && 
                $0.gender == (type == .father ? .male : .female)
            }
        }
    }
}
