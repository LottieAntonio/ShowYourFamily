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
    
    // MARK: - Dependencies
    let familyTreeViewModel: FamilyTreeViewModel                // 家谱视图模型
    private let relationshipGraph = RelationshipGraph()         // 关系图
    let titleGenerator: RelativeTitleGenerator                  // 称谓生成器
    private var cancellables = Set<AnyCancellable>()           // 订阅者集合
    
    // MARK: - Initialization
    init(familyTreeViewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        // 先创建一个临时的 titleGenerator
        let tempGenerator = RelativeTitleGenerator(managementViewModel: nil)
        self.titleGenerator = tempGenerator
        
        // 完成初始化后再设置 managementViewModel
        tempGenerator.managementViewModel = self
        
        updateData()
        
        // 合并两个观察者
        Publishers.CombineLatest(
            familyTreeViewModel.$persons,
            familyTreeViewModel.$relationships
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.updateData()
        }
        .store(in: &cancellables)
    }
    
    
    
    // 合并重复的数据加载逻辑
    private func reloadData() async {
        do {
            try await familyTreeViewModel.loadData()
            updateData()
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
 
    
    private func updateData() {
        Task { @MainActor in
            // 先更新基础数据
            persons = familyTreeViewModel.persons
            relationships = familyTreeViewModel.relationships
            
            // 更新关系图
            relationshipGraph.clear()
            relationships.forEach { relationship in
                relationshipGraph.addRelationship(relationship)
            }
            
            // 先找到自己
            let selfPerson = persons.first(where: { $0.isSelf })
            
            // 更新所有人物的称谓（避免递归更新）
            var updatedPersons: [Person] = []
            for person in persons {
                var updatedPerson = person
                // 只有当 notes 为空或为 nil 时，才使用自动生成的称谓
                if updatedPerson.notes?.isEmpty ?? true {
                    if let title = await titleGenerator.generateTitle(for: person) {
                        updatedPerson.notes = title
                    }
                }
                updatedPersons.append(updatedPerson)
            }
            
            // 批量更新到数据库
            do {
                try await familyTreeViewModel.dataManager.savePersons(updatedPersons)
                persons = updatedPersons
            } catch {
                errorMessage = "更新称谓失败：\(error.localizedDescription)"
            }
            
            // 如果有选中的人物，保持选中
            if let selectedId = selectedPerson?.id,
               let updatedPerson = persons.first(where: { $0.id == selectedId }) {
                selectedPerson = updatedPerson
            } 
            // 如果没有选中的人物，使用第一个人物（最早添加的）
            else if selectedPerson == nil && !persons.isEmpty {
                selectedPerson = persons.first
            }
            
            objectWillChange.send()
        }
    }
    
    // 统一的数据加载方法
    func loadData() async {
        do {
            try await familyTreeViewModel.loadData()
            await MainActor.run {
                updateData()
            }
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
    func updatePerson(_ person: Person) async throws {
        // 先保存到数据管理器
        try await familyTreeViewModel.dataManager.savePerson(person)
        
        await MainActor.run {
            // 立即更新本地数据
            if let index = persons.firstIndex(where: { $0.id == person.id }) {
                persons[index] = person
            } else {
                persons.append(person)
            }
            
            // 更新选中的人物
            if selectedPerson?.id == person.id {
                selectedPerson = person
            }
            
            // 强制更新
            objectWillChange.send()
        }
        
        // 最后再刷新一次确保数据同步
        await loadData()
    }
    
    
   
    // 添加新方法
    private func handleParentRelationship(_ parentType: RelationType, parent: Person, child: Person) async throws {
        // 修改这里：先检查是否存在另一个父母，如果存在则先建立配偶关系
        let otherParentType: RelationType = parentType == .father ? .mother : .father
        if let otherParent = getRelatedPersons(for: child, relationType: otherParentType).first {
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
    
    // 修改现有方法
    func addRelationship(from: Person, to: Person, type: RelationType) async throws {
        switch type {
        case .brother, .sister:
            // 创建新人物
            var newPerson = to
            newPerson.gender = type == .brother ? .male : .female
            try await familyTreeViewModel.dataManager.savePerson(newPerson)
            
            // 获取当前人物的父母
            let currentParents = getParents(for: from)
            
            // 建立与现有父母的关系（如果存在）
            if let father = currentParents.father {
                try await _addChildRelationship(parent: father, child: newPerson)
            }
            if let mother = currentParents.mother {
                try await _addChildRelationship(parent: mother, child: newPerson)
            }
            
            // 获取所有现有兄弟姐妹（包括通过父母关联的）
            let existingSiblings = getRelatedPersons(for: from, relationType: .brother) + 
                                 getRelatedPersons(for: from, relationType: .sister)
            
            // 建立与所有兄弟姐妹的关系（包括 from）
            var allSiblings = existingSiblings
            allSiblings.append(from)
            
            for sibling in allSiblings where sibling.id != newPerson.id {
                // 确定关系类型（根据各自的性别）
                let siblingToNewType: RelationType = newPerson.gender == .male ? .brother : .sister
                let newToSiblingType: RelationType = sibling.gender == .male ? .brother : .sister
                
                // 检查是否已存在关系
                let existingRelation = relationships.first { relationship in
                    (relationship.fromPerson == sibling.id && relationship.toPerson == newPerson.id) ||
                    (relationship.fromPerson == newPerson.id && relationship.toPerson == sibling.id)
                }
                
                if existingRelation == nil {
                    // 建立双向关系
                    let siblingToNew = Relationship(
                        type: siblingToNewType,
                        fromPerson: sibling.id,
                        toPerson: newPerson.id
                    )
                    try await familyTreeViewModel.dataManager.saveRelationship(siblingToNew)
                    
                    let newToSibling = Relationship(
                        type: newToSiblingType,
                        fromPerson: newPerson.id,
                        toPerson: sibling.id
                    )
                    try await familyTreeViewModel.dataManager.saveRelationship(newToSibling)
                }
            }
            
            await updateRelativeTitles()
            await reloadData()
            
        default:
            // 如果是添加父母关系
            if type == .father || type == .mother {
                // 创建子女->父母关系（注意：这里是 from -> to，因为 from 是子女）
                let parentChildRelationship = Relationship(type: type, fromPerson: from.id, toPerson: to.id)
                try await familyTreeViewModel.dataManager.saveRelationship(parentChildRelationship)
                
                // 获取当前人物的所有兄弟姐妹
                let siblings = getRelatedPersons(for: from, relationType: .brother) + 
                             getRelatedPersons(for: from, relationType: .sister)
                
                // 为所有兄弟姐妹建立与新父母的关系
                for sibling in siblings {
                    try await _addChildRelationship(parent: to, child: sibling)
                }
                
                // 检查并处理配偶关系
                let otherParentType: RelationType = type == .father ? .mother : .father
                if let otherParent = getRelatedPersons(for: from, relationType: otherParentType).first {
                    // 检查是否已经存在配偶关系
                    let existingSpouseRelation = relationships.first { relationship in
                        (relationship.fromPerson == to.id && relationship.toPerson == otherParent.id ||
                         relationship.fromPerson == otherParent.id && relationship.toPerson == to.id) &&
                        relationship.type == .spouse
                    }
                    
                    // 如果不存在配偶关系，则创建
                    if existingSpouseRelation == nil {
                        let spouseRelationship = Relationship(type: .spouse, fromPerson: to.id, toPerson: otherParent.id)
                        try await familyTreeViewModel.dataManager.saveRelationship(spouseRelationship)
                    }
                }
            }
            // 如果是添加子女关系
            else if type == .child {
                // 根据 from（父母）的性别确定父母类型
                let parentType: RelationType = from.gender == .male ? .father : .mother
                // 创建父母->子女关系
                let parentChildRelationship = Relationship(type: parentType, fromPerson: to.id, toPerson: from.id)
                try await familyTreeViewModel.dataManager.saveRelationship(parentChildRelationship)
                
                // 如果有配偶，自动设置为子女的另一个父母
                if let spouse = getRelatedPersons(for: from, relationType: .spouse).first {
                    let spouseParentType: RelationType = spouse.gender == .male ? .father : .mother
                    let spouseChildRelationship = Relationship(type: spouseParentType, fromPerson: to.id, toPerson: spouse.id)
                    try await familyTreeViewModel.dataManager.saveRelationship(spouseChildRelationship)
                }
            }
            // 如果是添加配偶关系
            else if type == .spouse {
                // 创建配偶关系
                let spouseRelationship = Relationship(type: .spouse, fromPerson: from.id, toPerson: to.id)
                try await familyTreeViewModel.dataManager.saveRelationship(spouseRelationship)
                
                // 获取 from 的所有子女
                let children = getRelatedPersons(for: from, relationType: .child)
                for child in children {
                    // 检查新配偶是否已经是子女的父母
                    let isAlreadyParent = getRelatedPersons(for: child, relationType: .father).contains(where: { $0.id == to.id }) ||
                                        getRelatedPersons(for: child, relationType: .mother).contains(where: { $0.id == to.id })
                    
                    if !isAlreadyParent {
                        // 根据性别确定父母类型
                        let parentType: RelationType = to.gender == .male ? .father : .mother
                        // 创建子女->父母关系（修改这里：从子女指向父母）
                        let parentChildRelationship = Relationship(type: parentType, fromPerson: child.id, toPerson: to.id)
                        try await familyTreeViewModel.dataManager.saveRelationship(parentChildRelationship)
                    }
                }
            }
            
            await reloadData()
        }
    }
    
    private func getParents(for person: Person) -> (father: Person?, mother: Person?) {
        let father = getRelatedPersons(for: person, relationType: .father).first
        let mother = getRelatedPersons(for: person, relationType: .mother).first
        return (father, mother)
    }
    
    private func _addChildRelationship(parent: Person, child: Person) async throws {
        // 根据父母的性别确定关系类型
        let parentType: RelationType = parent.gender == .male ? .father : .mother
        let relationship = Relationship(
            type: parentType,
            fromPerson: child.id,
            toPerson: parent.id
        )
        try await familyTreeViewModel.dataManager.saveRelationship(relationship)
    }
    
    func addStory(_ story: Story, to person: Person) async throws {
        var updatedPerson = person
        if var stories = updatedPerson.stories {
            stories.append(story)
            updatedPerson.stories = stories
        } else {
            updatedPerson.stories = [story]
        }
        try await updatePerson(updatedPerson)
    }
  
    
    // 获取子女默认姓氏
    func getDefaultLastName(for person: Person, relationType: RelationType) -> String? {
        if relationType == .child {
            // 如果是添加子女，查找父亲的姓氏
            if let father = getRelatedPersons(for: person, relationType: .father).first {
                return father.lastName
            }
        }
        return nil
    }

    // 修改 setDefaultValues 方法
    // 修改 setDefaultValues 方法
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
    
    // 更新获取关系的方法
    // 删除第一个简单版本的 getRelatedPersons 方法
    
    // 保留这个更完整的版本
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        switch relationType {
        case .brother, .sister:
            var siblings = Set<Person>()  // 使用 Set 避免重复
            
            // 1. 获取直接设置的兄弟姐妹关系
            let directRelationships = familyTreeViewModel.relationships.filter { relationship in
                (relationship.fromPerson == person.id || relationship.toPerson == person.id) &&
                (relationship.type == .brother || relationship.type == .sister)  // 同时检查兄弟和姐妹关系
            }
            
            let directSiblings = directRelationships.compactMap { relationship in
                if relationship.fromPerson == person.id {
                    return persons.first { $0.id == relationship.toPerson }
                } else {
                    return persons.first { $0.id == relationship.fromPerson }
                }
            }
            siblings.formUnion(directSiblings)
            
            // 2. 获取通过父母关联的兄弟姐妹
            let parents = getParents(for: person)
            if let father = parents.father {
                let fatherChildren = getRelatedPersons(for: father, relationType: .child)
                siblings.formUnion(fatherChildren)
            }
            if let mother = parents.mother {
                let motherChildren = getRelatedPersons(for: mother, relationType: .child)
                siblings.formUnion(motherChildren)
            }
            
            // 过滤出符合条件的兄弟姐妹
            return Array(siblings).filter { sibling in
                let correctGender = relationType == .brother ? sibling.gender == .male : sibling.gender == .female
                return correctGender && sibling.id != person.id
            }
            
        default:
            // 处理其他关系类型
            let relationships = familyTreeViewModel.relationships.filter { relationship in
                switch relationType {
                case .father:
                    return relationship.fromPerson == person.id && relationship.type == .father
                case .mother:
                    return relationship.fromPerson == person.id && relationship.type == .mother
                case .child:
                    return (relationship.toPerson == person.id && 
                           (relationship.type == .father || relationship.type == .mother))
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
    // 删除人物及其相关关系
    func deletePerson(_ person: Person) async throws {
        // 删除与该人物相关的所有关系
        let relatedRelationships = relationships.filter { relationship in
            relationship.fromPerson == person.id || relationship.toPerson == person.id
        }
        
        for relationship in relatedRelationships {
            try await familyTreeViewModel.dataManager.deleteRelationship(relationship.id)  // 修改这里，只传递 ID
        }
        
        // 删除人物
        try await familyTreeViewModel.dataManager.deletePerson(person.id)  // 修改这里，只传递 ID
        
        // 如果删除的是当前选中的人物，清除选中状态
        if selectedPerson?.id == person.id {
            selectedPerson = nil
        }
        
        await reloadData()
    }
    // 在 deletePerson 方法后添加
    private func findRelationshipPath(from startId: UUID, to endId: UUID) -> [Relationship] {
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
    
    private func calculateGeneration(from relationships: [Relationship]) -> Generation? {
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
    
    private func updateRelativeTitles() async {
        guard let selfPerson = persons.first(where: { $0.isSelf }) else { return }
        
        for var person in persons where person.id != selfPerson.id {
            let relationships = findRelationshipPath(from: selfPerson.id, to: person.id)
            if let generation = calculateGeneration(from: relationships) {
                var title = ""
                
                switch generation {
                case .firstUp:
                    title = person.gender == .male ? "\(selfPerson.firstName)的父亲" : "\(selfPerson.firstName) 的母亲"
                case .secondUp:
                    title = person.gender == .male ? "\(selfPerson.firstName)的爷爷" : "\(selfPerson.firstName)的奶奶"
                case .thirdUp:
                    title = person.gender == .male ? "\(selfPerson.firstName)的曾祖父" : "\(selfPerson.firstName)的曾祖母"
                case .fourthUp:
                    title = person.gender == .male ? "\(selfPerson.firstName)的高祖父" : "\(selfPerson.firstName)的高祖母"
                case .firstDown:
                    title = person.gender == .male ? "\(selfPerson.firstName)的儿子" : "\(selfPerson.firstName)的女儿"
                case .secondDown:
                    title = person.gender == .male ? "\(selfPerson.firstName)的孙子" : "\(selfPerson.firstName)的孙女"
                case .thirdDown:
                    title = person.gender == .male ? "\(selfPerson.firstName)的曾孙" : "\(selfPerson.firstName)的曾孙女"
                case .current:
                    if let _ = relationships.first(where: { $0.type == .spouse }) {
                        title = person.gender == .male ? "\(selfPerson.firstName)的丈夫" : "\(selfPerson.firstName)的妻子"
                    }
                default:
                    title = generation.title
                    if generation.rawValue > 0 {
                        title += person.gender == .male ? "父" : "母"
                    } else {
                        title += person.gender == .male ? "子" : "女"
                    }
                    title = "\(selfPerson.firstName)的\(title)"
                }
                
                if !title.isEmpty {
                    person.notes = title
                    try? await updatePerson(person)
                }
            }
        }
    }
}
