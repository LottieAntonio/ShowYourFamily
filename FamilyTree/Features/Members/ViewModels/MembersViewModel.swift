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
        // 使用 removeDuplicates 避免重复更新
        familyTreeViewModel.$persons
            .removeDuplicates()  // 添加这行
            .sink { [weak self] persons in
                self?.persons = persons
                // 移到主线程执行，避免多次更新
                Task { @MainActor [weak self] in
                    await self?.preloadAllTitles()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() async {
        do {
            print("📱 MembersViewModel 开始加载数据")
            
            // 确保 familyManager 已设置
            guard let familyManager = familyTreeViewModel.familyManager else {
                print("⚠️ loadData 时 familyManager 为空")
                throw FamilyError.noCurrentFamily
            }
            
            // 先加载家谱列表
            print("📝 开始加载家谱列表")
            await familyManager.loadFamilies()
            
            // 如果没有选择当前家谱，尝试选择第一个可用的家谱
            if familyManager.currentFamily == nil {
                print("📝 尝试选择默认家谱")
                if let firstFamily = familyManager.families.first {
                    await familyManager.switchFamily(firstFamily)
                    print("✅ 已选择家谱：\(firstFamily.name)")
                } else {
                    print("⚠️ 没有可用的家谱")
                    throw FamilyError.noCurrentFamily
                }
            }
            
            guard let currentFamily = familyManager.currentFamily else {
                print("⚠️ 未选择当前家谱")
                throw FamilyError.noCurrentFamily
            }
            
            print("📱 正在加载家谱[\(currentFamily.name)]的数据")
            
            // 先清空缓存
            titleCache.removeAll()
            
            // 直接加载数据，移除多余的刷新调用
            try await familyTreeViewModel.loadData()
            print("✅ FamilyTreeViewModel 数据加载完成，persons: \(familyTreeViewModel.persons.count)")
            
            // 预加载称谓
            await preloadAllTitles()
            
            print("✅ MembersViewModel 数据加载完成")
        } catch {
            print("❌ MembersViewModel 加载数据失败：\(error)")
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
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
        
 
