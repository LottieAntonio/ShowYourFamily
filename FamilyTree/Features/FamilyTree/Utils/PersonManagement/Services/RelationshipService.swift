import Foundation

class RelationshipService: ObservableObject {
    private let dataManager: DataManager
    @Published private(set) var relationships: [Relationship]
    @Published private(set) var persons: [Person]
    
    private let parentChildHandler: ParentChildHandler
    private let siblingHandler: SiblingHandler
    private let spouseHandler: SpouseHandler
    
    init(dataManager: DataManager, relationships: [Relationship], persons: [Person]) {
        self.dataManager = dataManager
        self.relationships = relationships
        self.persons = persons
        
        // 初始化处理器时传入 self 作为数据源
        self.parentChildHandler = ParentChildHandler(
            dataManager: dataManager,
            relationships: relationships,
            persons: persons
        )
        self.siblingHandler = SiblingHandler(
            dataManager: dataManager,
            relationships: relationships,
            persons: persons
        )
        self.spouseHandler = SpouseHandler(
            dataManager: dataManager,
            relationships: relationships,
            persons: persons
        )
    }
    
    func updateData(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
        
        // 更新所有处理器的数据
        parentChildHandler.updateData(relationships: relationships, persons: persons)
        siblingHandler.updateData(relationships: relationships, persons: persons)
        spouseHandler.updateData(relationships: relationships, persons: persons)
        
        // 发送数据变更通知
        objectWillChange.send()
    }
    
    func addRelationship(from: Person, to: Person, type: RelationType) async throws {
        // 基本验证
        if from.id == to.id {
            throw RelationshipError.invalidRelationship("不能与自己建立关系")
        }
        
        // 检查是否已存在关系
        let existingRelations = getRelatedPersons(for: from, relationType: type)
        if existingRelations.contains(where: { $0.id == to.id }) {
            return // 如果关系已存在，直接返回
        }
        
        // 检查是否存在冲突的关系
        if await hasConflictingRelationship(from: from, to: to, type: type) {
            throw RelationshipError.conflictingRelationship("存在冲突的关系")
        }
        
        switch type {
        case .father, .mother:
            try await parentChildHandler.handleParentAddition(from: from, to: to, type: type)
        case .brother, .sister:
            try await siblingHandler.handleSiblingAddition(from: from, newSibling: to, type: type)
        case .spouse:
            try await spouseHandler.handleSpouseAddition(from: from, to: to)
        case .child:
            let parentType: RelationType = from.gender == .male ? .father : .mother
            try await parentChildHandler.handleParentAddition(from: to, to: from, type: parentType)
        }
        
        await refreshData()
    }
    
    // 添加检查冲突关系的方法
    private func hasConflictingRelationship(from: Person, to: Person, type: RelationType) async -> Bool {
        // 检查是否已经是子女关系
        let isChild = getRelatedPersons(for: from, relationType: .child)
            .contains(where: { $0.id == to.id })
        let isParent = (getRelatedPersons(for: from, relationType: .father) + 
                       getRelatedPersons(for: from, relationType: .mother))
            .contains(where: { $0.id == to.id })
            
        switch type {
        case .father, .mother:
            // 如果目标人物已经是子女或配偶，则冲突
            return isChild || getRelatedPersons(for: from, relationType: .spouse)
                .contains(where: { $0.id == to.id })
        case .child:
            // 如果目标人物已经是父母或配偶，则冲突
            return isParent || getRelatedPersons(for: from, relationType: .spouse)
                .contains(where: { $0.id == to.id })
        case .spouse:
            // 如果目标人物是直系亲属，则冲突
            return isChild || isParent
        case .brother, .sister:
            // 如果目标人物是直系亲属或配偶，则冲突
            return isChild || isParent || getRelatedPersons(for: from, relationType: .spouse)
                .contains(where: { $0.id == to.id })
        }
    }
    
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        switch relationType {
        case .father, .mother:
            return parentChildHandler.getParents(for: person, type: relationType)
        case .child:
            return parentChildHandler.getChildren(for: person)
        case .brother, .sister:
            return siblingHandler.getSiblings(for: person, type: relationType)
        case .spouse:
            return spouseHandler.getSpouses(for: person)
        }
    }
    
    // 添加获取潜在父母的方法
    func getPotentialParents(for person: Person, type: RelationType) -> [Person] {
        // 获取现有的另一方父/母
        let otherParentType: RelationType = type == .father ? .mother : .father
        guard let otherParent = getRelatedPersons(for: person, relationType: otherParentType).first else {
            return []
        }
        
        // 获取另一方父/母的所有配偶
        return getRelatedPersons(for: otherParent, relationType: .spouse)
            .filter { $0.gender == (type == .father ? .male : .female) }
    }
    
    // 添加刷新数据的方法
    private func refreshData() async {
        do {
            async let newRelationships = dataManager.getAllRelationships()
            async let newPersons = dataManager.getAllPersons()
            
            // 并行获取数据
            let (relationships, persons) = try await (newRelationships, newPersons)
            
            await MainActor.run {
                updateData(relationships: relationships, persons: persons)
            }
        } catch {
            print("刷新数据失败：\(error.localizedDescription)")
        }
    }
}
// 在类定义前添加
enum RelationshipError: Error {
    case invalidRelationship(String)
    case conflictingRelationship(String)
}