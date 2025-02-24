import SwiftUI
import Combine

@MainActor
class MembersViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?
    @Published private var titleCache: [UUID: String] = [:] // 添加称谓缓存
    
    private let familyTreeViewModel: FamilyTreeViewModel
    private var cancellables = Set<AnyCancellable>()
    private let personManager: PersonManagementViewModel  // 改为普通属性
        
    // 修改 titleGenerator 的初始化方式
    private var titleGenerator: RelativeTitleGenerator {
        RelativeTitleGenerator(
            relationships: familyTreeViewModel.relationships,
            persons: familyTreeViewModel.persons
        )
    }
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        
        // 如果 familyManager 不存在，创建一个新的
        let familyManager = familyTreeViewModel.familyManager ?? 
            FamilyManagementViewModel(dataManager: familyTreeViewModel.dataManager)
        
        // 初始化 personManager
        self.personManager = PersonManagementViewModel(
            familyTreeViewModel: familyTreeViewModel,
            familyManager: familyManager
        )
        
        familyTreeViewModel.$persons
            .sink { [weak self] persons in
                self?.persons = persons
                // 当 persons 更新时，预加载所有称谓
                Task { [weak self] in
                    await self?.preloadAllTitles()
                }
            }
            .store(in: &cancellables)
    }
    
    // 添加预加载称谓的方法
    private func preloadAllTitles() async {
        for person in persons where !person.isSelf {
            if let title = await titleGenerator.generateTitle(for: person) {
                titleCache[person.id] = title
            }
        }
        objectWillChange.send()
    }
    
    
    func loadData() async {
        do {
            // 先清空缓存
            titleCache.removeAll()
            
            // 加载数据
            try await familyTreeViewModel.loadData()
            
            // 确保所有称谓都已预加载完成
            for person in persons where !person.isSelf {
                if let title = await titleGenerator.generateTitle(for: person) {
                    titleCache[person.id] = title
                }
            }
            
            // 通知 UI 更新
            objectWillChange.send()
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
    private func getParents(for person: Person) -> (father: Person?, mother: Person?) {
        let father = getRelatedPersons(for: person, relationType: .father).first
        let mother = getRelatedPersons(for: person, relationType: .mother).first
        return (father, mother)
    }
    
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        switch relationType {
        case .father, .mother, .child, .spouse:
            let relationships = familyTreeViewModel.relationships.filter { relationship in
                switch relationType {
                case .father:
                    return relationship.fromPerson == person.id && relationship.type == .father
                case .mother:
                    return relationship.fromPerson == person.id && relationship.type == .mother
                case .child:
                    return (relationship.toPerson == person.id && relationship.type == .father) ||
                    (relationship.toPerson == person.id && relationship.type == .mother)
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
            
        case .brother, .sister:
            let parents = getParents(for: person)
            let fatherChildren = parents.father.map { getRelatedPersons(for: $0, relationType: .child) } ?? []
            let motherChildren = parents.mother.map { getRelatedPersons(for: $0, relationType: .child) } ?? []
            let allChildren = Array(Set(fatherChildren.compactMap { $0 } + motherChildren.compactMap { $0 }))
            
            return allChildren.filter { sibling in
                let correctGender = relationType == .brother ? sibling.gender == .male : sibling.gender == .female
                return correctGender && sibling.id != person.id
            }
        }
    }
    
    func updateSelectedPerson(_ person: Person) {
        selectedPerson = person
        familyTreeViewModel.selectedPerson = person
    }
    
    // 添加获取称谓的方法
    // 修改为异步方法
    // 添加 titleGenerator 属性
 
    
    func getRelativeTitle(for person: Person) async -> String? {
        // 获取自己的人物
        guard let selfPerson = persons.first(where: { $0.isSelf }) else {
            return nil
        }
        
        // 如果是自己，返回 nil（因为已经有专门的"自己"标识）
        if person.id == selfPerson.id {
            return nil
        }
        
        // 先检查缓存
        if let cachedTitle = titleCache[person.id] {
            return cachedTitle
        }
        
        // 如果没有缓存，生成称谓
        if let title = await titleGenerator.generateTitle(for: person) {
            // 缓存新生成的称谓
            await MainActor.run {
                titleCache[person.id] = title
            }
            return title
        }
        
        return nil
    }
}
        
 
