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

@MainActor
class PersonManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var persons: [Person] = []          // 所有人物列表
    @Published private(set) var relationships: [Relationship] = [] // 所有关系列表
    @Published var selectedPerson: Person?                      // 当前选中的人物
    @Published var errorMessage: String?                        // 错误信息
    @Published var defaultLastName: String?                     // 默认姓氏（用于新建人物）
    @Published var defaultGender: Person.Gender?                // 默认性别（用于新建人物）
    @Published var isProcessing: Bool = false  // 添加处理状态属性

    
    // MARK: - Dependencies
    let familyTreeViewModel: FamilyTreeViewModel                
    private(set) var titleGenerator: RelativeTitleGenerator     // 改为 private(set)
    var relationshipService: RelationshipService                
    private var personService: PersonDataService
    private var cancellables = Set<AnyCancellable>()           

    // MARK: - Initialization
    // 保留旧的初始化器以保持兼容性
    init(familyTreeViewModel: FamilyTreeViewModel, familyManager: FamilyManagementViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        let dataManager = familyTreeViewModel.dataManager
        
        // 初始化服务，使用协议类型
        self.titleGenerator = RelativeTitleGenerator(
            relationships: familyTreeViewModel.relationships,
            persons: familyTreeViewModel.persons
        )
        
        self.relationshipService = RelationshipService(
            dataManager: dataManager,  // 移除强制转换
            relationships: familyTreeViewModel.relationships,
            persons: familyTreeViewModel.persons
        )
        
        self.personService = PersonDataService(dataManager: dataManager)  // 移除强制转换
        
        // 设置数据观察者
        Task { @MainActor in
            await self.updateData()
            self.setupDataObservers()
        }
    }
    
    // MARK: - Private Methods
    private func setupDataObservers() {
        // 观察 FamilyTreeViewModel 的数据变化
        Publishers.CombineLatest(
            familyTreeViewModel.$persons,
            familyTreeViewModel.$relationships
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.updateData()
        }
        .store(in: &cancellables)
        
        // 观察 relationshipService 的数据变化
        relationshipService.$relationships
            .combineLatest(relationshipService.$persons)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateData()
            }
            .store(in: &cancellables)
    }
    
    private func updateData() {
        Task { @MainActor in
            // 只在必要时更新数据
            let newPersons = familyTreeViewModel.persons
            let newRelationships = familyTreeViewModel.relationships
            
            // 检查数据是否真的改变了
            guard persons != newPersons || relationships != newRelationships else {
                return
            }
            
            persons = newPersons
            relationships = newRelationships
            
            // 更新 relationshipService
            relationshipService.updateData(
                relationships: relationships,
                persons: persons
            )
            
            // 更新称谓生成器
            titleGenerator = RelativeTitleGenerator(
                relationships: relationships,
                persons: persons
            )
            
            // 更新选中状态
            // 修改选中状态的逻辑
            if let selectedId = selectedPerson?.id {
                selectedPerson = persons.first(where: { $0.id == selectedId })
            } else if let lastPerson = persons.last {
                // 如果没有选中的人物，选择最后一个（最新添加的）
                selectedPerson = lastPerson
            }
            
            objectWillChange.send()
        }
    }
    
    // 修改 loadData 方法中的类型转换
    // 修改 loadData 方法
    func loadData() async {
        guard let familyManager = familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else { return }
        
        do {
            let persons = try await familyTreeViewModel.dataManager.loadPersons(familyId: currentFamily.id)
            let relationships = try await familyTreeViewModel.dataManager.loadRelationships(familyId: currentFamily.id)
            
            await MainActor.run {
                self.persons = persons
                self.relationships = relationships
                updateServices(persons: persons, relationships: relationships)
            }
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
    // 修改 updatePerson 方法
    func updatePerson(_ person: Person) async throws {
        guard let familyManager = familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        // 修改这里：只在编辑默认家谱时抛出错误
        if currentFamily.isDefault && person.familyId == currentFamily.id {
            throw FamilyError.defaultFamilyNotEditable
        }
        
        var updatedPerson = person
        updatedPerson.familyId = currentFamily.id
        
        try await familyTreeViewModel.dataManager.savePerson(updatedPerson)
        await loadData()
    }
    
    // 修改 addRelationship 方法
    func addRelationship(from: Person, to: Person, type: RelationType) async throws {
        guard let familyManager = familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault {
            throw FamilyError.cannotModifyDefaultFamily
        }
        
        try await relationshipService.addRelationship(from: from, to: to, type: type)
        await reloadData()
    }
    
    // 修改 deletePerson 方法
    func deletePerson(_ person: Person) async throws {
        guard let familyManager = familyTreeViewModel.familyManager,
              let currentFamily = familyManager.currentFamily else {
            throw FamilyError.noCurrentFamily
        }
        
        if currentFamily.isDefault {
            throw FamilyError.cannotModifyDefaultFamily
        }
        
        try await personService.deletePerson(person.id, relationships: relationships)
        if selectedPerson?.id == person.id {
            selectedPerson = nil
        }
        await reloadData()
    }
    
    // 添加辅助方法
    private func updateServices(persons: [Person], relationships: [Relationship]) {
        relationshipService.updateData(relationships: relationships, persons: persons)
        titleGenerator = RelativeTitleGenerator(relationships: relationships, persons: persons)
    }



    
    
   
    // 添加新方法
    private func handleParentRelationship(_ parentType: RelationType, parent: Person, child: Person) async throws {
        // 修改这里：使用 relationshipService 来获取关系
        let otherParentType: RelationType = parentType == .father ? .mother : .father
        if let otherParent = relationshipService.getRelatedPersons(for: child, relationType: otherParentType).first {
            // 检查是否已经存在配偶关系
            let existingSpouseRelation = relationships.first { relationship in
                (relationship.fromPerson == parent.id && relationship.toPerson == otherParent.id ||
                 relationship.fromPerson == otherParent.id && relationship.toPerson == parent.id) &&
                relationship.type == .spouse
            }
            
            // 如果不存在配偶关系，则创建
            if existingSpouseRelation == nil {
                try await addRelationship(from: parent, to: otherParent, type: .spouse)
            }
        }
        
        // 然后再创建父母-子女关系
        let childRelationship = Relationship(type: parentType, fromPerson: child.id, toPerson: parent.id)
        try await familyTreeViewModel.dataManager.saveRelationship(childRelationship)
        await reloadData()
    }
    
    
    func addStory(_ story: Story, to person: Person) async throws {
        try await personService.addStory(story, to: person)
        await reloadData()
    }
    
    // 获取子女默认姓氏
    func getDefaultLastName(for person: Person, relationType: RelationType) -> String? {
        if relationType == .child,
           let father = relationshipService.getRelatedPersons(for: person, relationType: .father).first {
            return father.lastName
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
    
    private func reloadData() async {
        do {
            try await familyTreeViewModel.loadData()
            updateData()
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
}
