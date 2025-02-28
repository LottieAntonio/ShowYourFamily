import SwiftUI
import Combine
import CoreGraphics

@MainActor
class FamilyGraphViewModel: ObservableObject {
    // 添加一个字典来存储已绘制节点的位置
    private var drawnNodePositions: [UUID: CGPoint] = [:]
    
    @Published private(set) var persons: [Person] = []
    @Published private(set) var relationships: [Relationship] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?
    @Published private(set) var graphData: FamilyGraphData?
    @Published private(set) var selfPerson: Person?  // 添加这个属性
    
    private let familyTreeViewModel: FamilyTreeViewModel
    private let relationshipService: RelationshipService
    private var cancellables = Set<AnyCancellable>()
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        self.relationshipService = RelationshipService(
            dataManager: familyTreeViewModel.dataManager,
            relationships: familyTreeViewModel.relationships,
            persons: familyTreeViewModel.persons
        )
        setupObservers()
    }
    
    private func setupObservers() {
        // 观察 FamilyTreeViewModel 的初始化状态
        familyTreeViewModel.$isInitialized
            .filter { $0 }
            .sink { [weak self] _ in
                print("📊 FamilyGraphViewModel: FamilyTreeViewModel 已初始化")
                self?.startObserving()
            }
            .store(in: &cancellables)
        
        // 添加对关系数据的专门观察
        familyTreeViewModel.$relationships
            .dropFirst()
            .sink { [weak self] relationships in
                print("📊 FamilyGraphViewModel: 检测到关系数据变化，共 \(relationships.count) 个关系")
            }
            .store(in: &cancellables)
        
        // 添加对选中人物的专门观察
        familyTreeViewModel.$selectedPerson
            .dropFirst()
            .compactMap { $0 }
            .sink { [weak self] person in
                print("📊 FamilyGraphViewModel: 检测到选中人物变化，\(person.name)")
                self?.selectedPerson = person
                self?.updateGraphData()
            }
            .store(in: &cancellables)
    }
    
    private func startObserving() {
        Publishers.CombineLatest3(
            familyTreeViewModel.$persons.removeDuplicates(),
            familyTreeViewModel.$relationships.removeDuplicates(),
            familyTreeViewModel.$selectedPerson.removeDuplicates()
        )
        .filter { persons, _, _ in !persons.isEmpty }
        .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
        .sink { [weak self] persons, relationships, selectedPerson in
            guard let self = self else { return }
            self.updateData(persons: persons, relationships: relationships, selectedPerson: selectedPerson)
        }
        .store(in: &cancellables)
    }
    
    private func updateData(persons: [Person], relationships: [Relationship], selectedPerson: Person?) {
        print("📊 FamilyGraphViewModel 更新数据：\(persons.count) 个成员，\(relationships.count) 个关系")
        self.persons = persons
        self.relationships = relationships
        self.selectedPerson = selectedPerson
        
        // 如果还没有设置"自己"，就用选中的人物或第一个人
        if self.selfPerson == nil {
            if let selected = selectedPerson {
                self.selfPerson = selected
            } else if let firstPerson = persons.first {
                self.selfPerson = firstPerson
            }
        }
        
        self.relationshipService.updateData(
            relationships: relationships,
            persons: persons
        )
        
        // 确保有选中的人物
        if selectedPerson == nil, let firstPerson = persons.first {
            print("📊 没有选中的人物，自动选择第一个人物：\(firstPerson.name)")
            self.selectedPerson = firstPerson
            familyTreeViewModel.selectPerson(firstPerson)
        } else if let person = selectedPerson {
            print("📊 更新图谱，中心人物：\(person.name)")
            self.updateGraphData()
        }
    }
    
    func loadData() async {
        print("📊 FamilyGraphViewModel 开始加载数据")
        
        // 等待 FamilyTreeViewModel 初始化完成
        if !familyTreeViewModel.isInitialized || familyTreeViewModel.persons.isEmpty {
            print("📊 等待 FamilyTreeViewModel 加载数据...")
            try? await familyTreeViewModel.loadData()
            
            // 再次检查数据是否加载成功
            if familyTreeViewModel.persons.isEmpty {
                print("⚠️ FamilyTreeViewModel 数据加载失败")
                return
            }
        }
        
        // 更新数据
        print("📊 更新图谱数据...")
        let persons = familyTreeViewModel.persons
        let relationships = familyTreeViewModel.relationships
        let selectedPerson = familyTreeViewModel.selectedPerson
        
        // 如果没有选中的人物，自动选择第一个
        if selectedPerson == nil, let firstPerson = persons.first {
            print("📊 自动选择第一个人物：\(firstPerson.name)")
            familyTreeViewModel.selectPerson(firstPerson)
            updateData(persons: persons, relationships: relationships, selectedPerson: firstPerson)
        } else {
            updateData(persons: persons, relationships: relationships, selectedPerson: selectedPerson)
        }
    }
    
    private func updateGraphData() {
        guard let centerPerson = selectedPerson else {
            graphData = nil
            return
        }
        
        graphData = createGraphData(for: centerPerson, level: 0, maxDepth: 3)
    }
    
    // 添加这个方法
    private func createGraphData(for person: Person, level: Int, maxDepth: Int) -> FamilyGraphData {
        var processedPeople = Set<UUID>()
        return createGraphDataInternal(
            for: person,
            level: level,
            maxDepth: maxDepth,
            processedPeople: &processedPeople
        )
    }
    
    private func createGraphDataInternal(
        for person: Person,
        level: Int,
        maxDepth: Int,
        processedPeople: inout Set<UUID>
    ) -> FamilyGraphData {
        // 如果超过最大深度，返回一个只包含基本信息的节点
        if level >= maxDepth {
            return FamilyGraphData(
                centerPerson: person,
                parents: [],
                children: [],
                spouses: [],
                siblings: []
            )
        }
        
        // 获取所有关系节点并去重
        let parents = Array(Set(relationshipService.getRelatedPersons(for: person, relationType: .parent)))
        let children = Array(Set(relationshipService.getRelatedPersons(for: person, relationType: .child)))
        let spouses = Array(Set(relationshipService.getRelatedPersons(for: person, relationType: .spouse)))
        let brothers = Array(Set(relationshipService.getRelatedPersons(for: person, relationType: .brother)))
        let sisters = Array(Set(relationshipService.getRelatedPersons(for: person, relationType: .sister)))
        
        // 创建各类关系节点
        var parentNodes: [FamilyGraphData.RelationNode] = []
        var childrenNodes: [FamilyGraphData.RelationNode] = []
        var spouseNodes: [FamilyGraphData.RelationNode] = []
        var siblingNodes: [FamilyGraphData.RelationNode] = []
        
        // 处理所有关系
        if level < maxDepth {
            // 添加父母节点（受 processedPeople 限制）
            if !processedPeople.contains(person.id) {
                for parent in parents {
                    if !processedPeople.contains(parent.id) {
                        let subNodes = createGraphDataInternal(
                            for: parent,
                            level: level + 1,
                            maxDepth: maxDepth,
                            processedPeople: &processedPeople
                        )
                        let node = FamilyGraphData.RelationNode(
                            person: parent,
                            relationType: parent.gender == Person.Gender.male ? .father : .mother,
                            level: level + 1,
                            subNodes: subNodes
                        )
                        parentNodes.append(node)
                    }
                }
            }
            
            // 添加配偶节点（不受 processedPeople 限制）
            for spouse in spouses {
                var spouseProcessed = processedPeople
                let subNodes = createGraphDataInternal(
                    for: spouse,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedPeople: &spouseProcessed
                )
                let node = FamilyGraphData.RelationNode(
                    person: spouse,
                    relationType: .spouse,
                    level: level,
                    subNodes: subNodes
                )
                spouseNodes.append(node)
            }
            
            // 添加子女节点（不受 processedPeople 限制）
            for child in children {
                var childProcessed = processedPeople
                let subNodes = createGraphDataInternal(
                    for: child,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedPeople: &childProcessed
                )
                let node = FamilyGraphData.RelationNode(
                    person: child,
                    relationType: .child,
                    level: level + 1,
                    subNodes: subNodes
                )
                childrenNodes.append(node)
            }
            
            // 标记当前人物已处理
            processedPeople.insert(person.id)
        }
        
        // 添加兄弟姐妹节点
        for sibling in (brothers + sisters) {
            if !processedPeople.contains(sibling.id) {
                let subNodes = createGraphDataInternal(
                    for: sibling,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedPeople: &processedPeople
                )
                let node = FamilyGraphData.RelationNode(
                    person: sibling,
                    relationType: sibling.gender == Person.Gender.male ? .brother : .sister,
                    level: level,
                    subNodes: subNodes
                )
                siblingNodes.append(node)
            }
        }
        
        // 返回构建好的家谱数据
        return FamilyGraphData(
            centerPerson: person,
            parents: parentNodes,
            children: childrenNodes,
            spouses: spouseNodes,
            siblings: siblingNodes
        )
    }
    
    
    // 添加设置"自己"的方法
    func setSelfPerson(_ person: Person) {
        self.selfPerson = person
    }
    
    // 新增：获取图谱数据的方法
    // 获取完整的图谱数据，包括布局信息
    func getGraphData() -> GraphLayoutData? {
        guard let data = graphData else { return nil }
        
        return GraphLayoutData(
            centerPerson: data.centerPerson,
            parents: data.parents.map { .init(person: $0.person, relationType: $0.relationType) },
            children: data.children.map { .init(person: $0.person, relationType: $0.relationType) },
            spouses: data.spouses.map { .init(person: $0.person, relationType: $0.relationType) },
            siblings: data.siblings.map { .init(person: $0.person, relationType: $0.relationType) }
        )
    }
    
    // 获取原始图谱数据
    func getRawGraphData() -> FamilyGraphData? {
        return graphData
    }
    
    // 移除 drawnNodePositions 属性，因为不再需要缓存节点位置
    // private var drawnNodePositions: [UUID: CGPoint] = [:]
}

// 新增：用于 SpriteKit 的数据结构
struct GraphLayoutData {
    struct NodeData {
        let person: Person
        let relationType: RelationType
    }
    
    let centerPerson: Person
    let parents: [NodeData]
    let children: [NodeData]
    let spouses: [NodeData]
    let siblings: [NodeData]
}
