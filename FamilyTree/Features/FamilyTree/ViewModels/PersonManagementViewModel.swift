import Foundation
import SwiftUI
import Combine

/*
 * PersonManagementViewModel
 * 作用：管理家谱应用的核心数据和业务逻辑
 * 职责：
 * 1. 管理人物和关系数据的增删改查
 * 2. 处理人物之间的关系建立和维护
 * 3. 管理称谓的生成和更新
 * 4. 处理数据的持久化和同步
 */

// 将 stateManager 从 private let 改为 private var
@MainActor
class PersonManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?
    @Published var defaultLastName: String?
    @Published var defaultGender: Person.Gender?
    @Published var isProcessing: Bool = false
    
    // MARK: - Dependencies
    private var stateManager: StateManager  // 改为 var
    private weak var appViewModel: FamilyAppViewModel?
    private var titleGenerator: RelativeTitleGenerator
    private var cancellables = Set<AnyCancellable>()
    
    // 修改初始化方法，添加 appViewModel 参数
    init(stateManager: StateManager, appViewModel: FamilyAppViewModel? = nil) {
        self.stateManager = stateManager
        self.appViewModel = appViewModel
        self.titleGenerator = RelativeTitleGenerator(
            relationships: stateManager.state.relationships,
            persons: stateManager.state.persons
        )
        setupBindings()
        
        // 同步初始数据
        self.persons = stateManager.state.persons
        self.relationships = stateManager.state.relationships
        self.selectedPerson = stateManager.state.selectedPerson
    }
    
    // 修改 setupBindings 方法，添加 titleGenerator 更新逻辑
    private func setupBindings() {
        // 保持现有的绑定逻辑
    }
    
    // MARK: - Private Methods
    
    // 修改 loadData 方法
    func loadData() async {
        // 优先使用 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        } else {
            await stateManager.loadInitialData()
        }
    }
    
    // 修改 updatePerson 方法
    @MainActor
    func updatePerson(_ person: Person) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        try await stateManager.updatePerson(person)
        
        // 更新后通知 appViewModel
        await appViewModel?.refreshData()
    }
    
    // 修改 addRelationship 方法
    func addRelationship(from: Person, to: Person, type: RelationType) async throws {
        guard let currentFamily = stateManager.state.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault {
            throw FamilyError.cannotModifyDefaultFamily
        }
        
        let relationship = Relationship(
            type: type,
            fromPerson: from.id,
            toPerson: to.id
        )
        
        try await stateManager.addRelationship(relationship)
        
        // 处理特殊关系
        switch type {
        case .father, .mother:
            await handleParentRelationship(type, parent: from, child: to)
        case .spouse:
            await handleSpouseRelationship(from: from, to: to)
        default:
            break
        }
        
        // 添加关系后通知 appViewModel
        await appViewModel?.refreshData()
    }
    
    // 修改 deletePerson 方法
    func deletePerson(_ person: Person) async throws {
        guard let currentFamily = stateManager.state.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault {
            throw FamilyError.cannotModifyDefaultFamily
        }
        
        try await stateManager.deletePerson(person)
        
        if selectedPerson?.id == person.id {
            selectedPerson = nil
        }
        
        // 删除后通知 appViewModel
        await appViewModel?.refreshData()
    }
   
    // 修改 handleParentRelationship 方法
    private func handleParentRelationship(_ parentType: RelationType, parent: Person, child: Person) async {
        // 检查是否存在另一个父母
        let otherParentType: RelationType = parentType == .father ? .mother : .father
        if let otherParent = stateManager.getRelatedPersons(for: child, relationType: otherParentType).first {
            // 添加配偶关系
            try? await stateManager.addRelationship(Relationship(
                type: .spouse,
                fromPerson: parent.id,
                toPerson: otherParent.id
            ))
            
            // 添加关系后通知 appViewModel
            await appViewModel?.refreshData()
        }
    }

    // 修改 handleSpouseRelationship 方法
    private func handleSpouseRelationship(from person1: Person, to person2: Person) async {
        // 获取双方的子女
        let children1 = stateManager.getRelatedPersons(for: person1, relationType: .child)
        let children2 = stateManager.getRelatedPersons(for: person2, relationType: .child)
        
        // 为双方的子女添加关系
        for child in children1 {
            try? await stateManager.addRelationship(Relationship(
                type: person2.gender == .male ? .father : .mother,
                fromPerson: child.id,
                toPerson: person2.id
            ))
        }
        
        for child in children2 {
            try? await stateManager.addRelationship(Relationship(
                type: person1.gender == .male ? .father : .mother,
                fromPerson: child.id,
                toPerson: person1.id
            ))
        }
        
        // 添加关系后通知 appViewModel
        await appViewModel?.refreshData()
    }
    
    // 修改 addStory 方法
    func addStory(_ story: Story, to person: Person) async throws {
        var updatedPerson = person
        var stories = person.stories ?? []
        stories.append(story)
        updatedPerson.stories = stories
        try await stateManager.updatePerson(updatedPerson)
        
        // 添加故事后通知 appViewModel
        await appViewModel?.refreshData()
    }
    
    // 获取子女默认姓氏
    func getDefaultLastName(for person: Person, relationType: RelationType) -> String? {
        if relationType == .child {
            let father = stateManager.getRelatedPersons(for: person, relationType: .father).first
            return father?.lastName
        }
        return nil
    }
    
    @MainActor
    func setDefaultValues(lastName: String? = nil, gender: Person.Gender? = nil) async {
        defaultLastName = lastName
        defaultGender = gender
    }
    
    @MainActor
    func clearDefaultValues() async {
        defaultLastName = nil
        defaultGender = nil
    }
    
    // 添加关系查询的便捷方法
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        return stateManager.getRelatedPersons(for: person, relationType: relationType)
    }

    // 添加获取潜在父母的方法
    func getPotentialParents(for person: Person, type: RelationType) -> [Person] {
        // 实现类似 RelationshipService 中的逻辑
        let otherParentType: RelationType = type == .father ? .mother : .father
        guard let otherParent = getRelatedPersons(for: person, relationType: otherParentType).first else {
            return []
        }
        
        return getRelatedPersons(for: otherParent, relationType: .spouse)
            .filter { $0.gender == (type == .father ? .male : .female) }
    }
}

// 添加扩展方法
extension PersonManagementViewModel {
    func updateStateManager(_ stateManager: StateManager) {
        self.stateManager = stateManager
        // 更新 titleGenerator
        self.titleGenerator = RelativeTitleGenerator(
            relationships: stateManager.state.relationships,
            persons: stateManager.state.persons
        )
        // 重新设置绑定
        cancellables.removeAll()
        setupBindings()
        // 同步当前数据
        self.persons = stateManager.state.persons
        self.relationships = stateManager.state.relationships
        self.selectedPerson = stateManager.state.selectedPerson
    }
    
    // 添加新方法，用于添加人物并建立关系
    @MainActor
    func addPersonWithRelationship(_ person: Person, relationType: RelationType?, targetPerson: Person?) async throws {
        guard let currentFamily = stateManager.state.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault {
            throw FamilyError.defaultFamilyNotEditable
        }
        
        var newPerson = person
        newPerson.familyId = currentFamily.id
        
        if stateManager.state.persons.isEmpty {
            newPerson.isSelf = true
        }
        
        // 先保存新人物
        try await stateManager.addPerson(newPerson)
        
        if stateManager.state.persons.isEmpty {
            stateManager.selectPerson(newPerson)
        }
        
        // 如果需要添加关系，确保有目标人物
        if let relationType = relationType, let targetPerson = targetPerson {
            print("✅ 开始添加关系：从 \(newPerson.firstName) 到 \(targetPerson.firstName)，类型：\(relationType)")
            
            // 根据关系类型调整关系方向
            switch relationType {
            case .father, .mother:
                // 根据新人物的性别确定正确的关系类型
                let correctRelationType: RelationType
                if newPerson.gender == .male {
                    correctRelationType = .father
                } else {
                    correctRelationType = .mother
                }
                
                // 如果是添加父母，则目标人物是子女，新人物是父母
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: .child,  // 子女关系
                    fromPerson: targetPerson.id,
                    toPerson: newPerson.id
                ))
                
                // 添加反向关系（父亲或母亲）
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: correctRelationType,  // 使用正确的父/母关系类型
                    fromPerson: newPerson.id,
                    toPerson: targetPerson.id
                ))
                
                // 检查是否存在另一个父母，如果存在则添加配偶关系
                let otherParentType: RelationType = correctRelationType == .father ? .mother : .father
                if let otherParent = stateManager.getRelatedPersons(for: targetPerson, relationType: otherParentType).first {
                    // 添加配偶关系
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .spouse,
                        fromPerson: newPerson.id,
                        toPerson: otherParent.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .spouse,
                        fromPerson: otherParent.id,
                        toPerson: newPerson.id
                    ))
                }
                
            case .child:
                // 如果是添加子女，则目标人物是父母，新人物是子女
                // 根据目标人物的性别确定正确的父母关系类型
                let parentRelationType: RelationType = targetPerson.gender == .male ? .father : .mother
                
                // 添加子女关系
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: .child,
                    fromPerson: newPerson.id,
                    toPerson: targetPerson.id
                ))
                
                // 添加反向关系（父亲或母亲）
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: parentRelationType,
                    fromPerson: targetPerson.id,
                    toPerson: newPerson.id
                ))
                
                // 如果目标人物有配偶，也添加子女关系
                let spouses = stateManager.getRelatedPersons(for: targetPerson, relationType: .spouse)
                for spouse in spouses {
                    // 根据配偶的性别确定正确的父母关系类型
                    let spouseRelationType: RelationType = spouse.gender == .male ? .father : .mother
                    
                    // 添加子女关系
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,
                        fromPerson: newPerson.id,
                        toPerson: spouse.id
                    ))
                    
                    // 添加反向关系（父亲或母亲）
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: spouseRelationType,
                        fromPerson: spouse.id,
                        toPerson: newPerson.id
                    ))
                }
                
            case .spouse:
                // 配偶关系是双向的
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: .spouse,
                    fromPerson: newPerson.id,
                    toPerson: targetPerson.id
                ))
                
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: .spouse,
                    fromPerson: targetPerson.id,
                    toPerson: newPerson.id
                ))
                
                // 如果对方有子女，将新人物也设置为这些子女的父母
                let children = stateManager.getRelatedPersons(for: targetPerson, relationType: .child)
                for child in children {
                    // 根据新人物的性别确定正确的父母关系类型
                    let parentRelationType: RelationType = newPerson.gender == .male ? .father : .mother
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,
                        fromPerson: child.id,
                        toPerson: newPerson.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: parentRelationType,
                        fromPerson: newPerson.id,
                        toPerson: child.id
                    ))
                }
                
            case .brother, .sister:
                // 根据新人物的性别确定正确的兄弟姐妹关系类型
                let siblingRelationType: RelationType = newPerson.gender == .male ? .brother : .sister
                let targetSiblingRelationType: RelationType = targetPerson.gender == .male ? .brother : .sister
                
                // 添加兄弟姐妹关系（双向）
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: siblingRelationType,
                    fromPerson: targetPerson.id,
                    toPerson: newPerson.id
                ))
                
                try await stateManager.addRelationship(Relationship(
                    id: UUID(),
                    type: targetSiblingRelationType,
                    fromPerson: newPerson.id,
                    toPerson: targetPerson.id
                ))
                
                // 获取目标人物的父母，将新人物也设置为其子女
                let fathers = stateManager.getRelatedPersons(for: targetPerson, relationType: .father)
                let mothers = stateManager.getRelatedPersons(for: targetPerson, relationType: .mother)
                
                // 处理父亲关系
                for father in fathers {
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,
                        fromPerson: newPerson.id,
                        toPerson: father.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .father,
                        fromPerson: father.id,
                        toPerson: newPerson.id
                    ))
                }
                
                // 处理母亲关系
                for mother in mothers {
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .child,
                        fromPerson: newPerson.id,
                        toPerson: mother.id
                    ))
                    
                    try await stateManager.addRelationship(Relationship(
                        id: UUID(),
                        type: .mother,
                        fromPerson: mother.id,
                        toPerson: newPerson.id
                    ))
                }
            }
            
            print("✅ 关系添加成功")
        }
        
        // 添加关系后通知 appViewModel 刷新数据
        await appViewModel?.refreshData()
    }
}
