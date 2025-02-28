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
    private let personManager: PersonManagementViewModel
    private let familyManager: FamilyManagementViewModel  // 添加强引用
        
    init(familyTreeViewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        
        // 使用已存在的 familyManager，避免重复创建
        if let existingFamilyManager = familyTreeViewModel.familyManager {
            self.familyManager = existingFamilyManager
            self.personManager = PersonManagementViewModel(
                familyTreeViewModel: familyTreeViewModel,
                familyManager: existingFamilyManager
            )
        } else {
            // 只在必要时创建新的 familyManager
            let familyManager = FamilyManagementViewModel(dataManager: familyTreeViewModel.dataManager)
            self.familyManager = familyManager
            
            print("📝 设置 FamilyTreeViewModel 的 familyManager")
            familyTreeViewModel.familyManager = familyManager
            familyManager.setFamilyTreeViewModel(familyTreeViewModel)
            
            self.personManager = PersonManagementViewModel(
                familyTreeViewModel: familyTreeViewModel,
                familyManager: familyManager
            )
        }
        
        // 设置数据观察
        setupObservers()
        
        // 同步初始数据
        self.persons = familyTreeViewModel.persons
        
        print("✅ MembersViewModel 初始化完成")
    }
    
    // 添加 titleGenerator 属性
    private var titleGenerator: RelativeTitleGenerator {
        RelativeTitleGenerator(
            relationships: familyTreeViewModel.relationships,
            persons: familyTreeViewModel.persons
        )
    }
    
    
    private func setupObservers() {
        // 只在 FamilyTreeViewModel 初始化完成后才开始观察
        familyTreeViewModel.$isInitialized
            .filter { $0 }
            .sink { [weak self] _ in
                self?.startObserving()
            }
            .store(in: &cancellables)
    }
    
    private func startObserving() {
        familyTreeViewModel.$persons
            .removeDuplicates()
            .sink { [weak self] persons in
                self?.persons = persons
                Task { @MainActor [weak self] in
                    await self?.preloadAllTitles()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() async {
        // 如果 FamilyTreeViewModel 已经初始化且有数据，直接使用现有数据
        if familyTreeViewModel.isInitialized && !familyTreeViewModel.persons.isEmpty {
            self.persons = familyTreeViewModel.persons
            await preloadAllTitles()
            return
        }
        
        // 否则等待数据加载
        try? await familyTreeViewModel.loadData()
    }

    
    // 添加预加载称谓的方法
    private func preloadAllTitles() async {
        for person in persons where !person.isSelf {
            if let title = titleGenerator.generateTitle(for: person) {
                titleCache[person.id] = title
            }
        }
        objectWillChange.send()
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
        if let title = titleGenerator.generateTitle(for: person) {
            // 缓存新生成的称谓
            await MainActor.run {
                titleCache[person.id] = title
            }
            return title
        }
        
        return nil
    }
    
    // 添加公开方法用于切换家谱
    func switchFamily(_ family: Family) async {
        await familyManager.switchFamily(family)
    }
}
        
 
