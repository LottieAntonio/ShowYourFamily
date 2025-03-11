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
    
    private let stateManager: StateManager
    private var cancellables = Set<AnyCancellable>()
    
    // 保持初始化方法不变，由 FamilyAppViewModel 创建和管理实例
    init(stateManager: StateManager) {
        self.stateManager = stateManager
        setupBindings()
    }
    
    private func setupBindings() {
        stateManager.$state
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)  // 添加防抖
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // 只在必要时更新数据
                let personsChanged = self.persons != state.persons
                let relationshipsChanged = self.relationships != state.relationships
                let selectedPersonChanged = self.selectedPerson?.id != state.selectedPerson?.id
                
                if personsChanged || relationshipsChanged || selectedPersonChanged {
                    print("📊 FamilyGraphViewModel: 检测到重要数据变化")
                    self.persons = state.persons
                    self.relationships = state.relationships
                    
                    if selectedPersonChanged {
                        if let selectedPerson = state.selectedPerson {
                            print("📊 FamilyGraphViewModel: 选中人物变化，\(selectedPerson.name)")
                            self.selectedPerson = selectedPerson
                            self.updateGraphData()
                        }
                    } else if personsChanged || relationshipsChanged {
                        // 只在数据真正变化时更新图谱
                        self.updateGraphData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // 修改 loadData 方法，使其更适合被 FamilyAppViewModel 调用
    func loadData() async {
        print("📊 FamilyGraphViewModel 开始加载数据")
        
        // 如果状态中没有数据，不再自己加载，而是依赖 FamilyAppViewModel
        if !stateManager.state.persons.isEmpty {
            // 如果没有选中的人物，但有人物数据，选择第一个
            if selectedPerson == nil, let firstPerson = stateManager.state.persons.first {
                print("📊 自动选择第一个人物：\(firstPerson.name)")
                stateManager.selectPerson(firstPerson)
            }
            
            // 确保图谱数据已更新
            if let selectedPerson = selectedPerson, graphData == nil {
                updateGraphData()
            }
        }
    }
    
    private func updateGraphData() {
        guard let centerPerson = selectedPerson else {
            print("⚠️ 没有选中的中心人物，无法更新图谱")
            graphData = nil
            return
        }
        
        print("📊 开始为 \(centerPerson.name) (ID: \(centerPerson.id)) 创建图谱数据")
        
        // 打印所有关系，帮助调试
        print("📊 所有关系:")
        for rel in relationships {
            let fromPerson = persons.first { $0.id == rel.fromPerson }?.name ?? "未知"
            let toPerson = persons.first { $0.id == rel.toPerson }?.name ?? "未知"
            print("   - \(fromPerson) -> \(toPerson): \(rel.type)")
        }
        
        // 创建一个集合来跟踪已处理的人物
        var processedPersons = Set<UUID>()
        
        // 创建图谱数据
        graphData = createGraphData(for: centerPerson, level: 0, maxDepth: 3, processedPersons: &processedPersons)
    }
    
    private func createGraphData(for person: Person, level: Int, maxDepth: Int, processedPersons: inout Set<UUID>) -> FamilyGraphData {
        // 如果超过最大深度，返回空的图谱数据
        if level >= maxDepth {
            return FamilyGraphData(
                centerPerson: person,
                parents: [],
                children: [],
                spouses: [],
                siblings: []
            )
        }
        
        // 检查是否已处理过该人物
        let alreadyProcessed = processedPersons.contains(person.id)
        
        // 如果已处理过，但仍需要获取基本关系信息
        if alreadyProcessed && level > 0 {
            // 获取子女信息，但不递归处理
            let childrenIds = relationships
                .filter { $0.toPerson == person.id && ($0.type == .father || $0.type == .mother) }
                .map { $0.fromPerson }
            let children = persons.filter { childrenIds.contains($0.id) }
            
            // 获取配偶信息，但不递归处理
            let spouseIds = relationships
                .filter { ($0.fromPerson == person.id || $0.toPerson == person.id) && $0.type == .spouse }
                .map { $0.fromPerson == person.id ? $0.toPerson : $0.fromPerson }
            let spouses = persons.filter { spouseIds.contains($0.id) }
            
            // 创建简化版的关系节点，不包含子图谱
            let childNodes = children.map { child in
                FamilyGraphData.RelationNode(
                    person: child,
                    relationType: .child,
                    level: level + 1,
                    subNodes: FamilyGraphData(centerPerson: child, parents: [], children: [], spouses: [], siblings: [])
                )
            }
            
            let spouseNodes = spouses.map { spouse in
                FamilyGraphData.RelationNode(
                    person: spouse,
                    relationType: .spouse,
                    level: level,
                    subNodes: FamilyGraphData(centerPerson: spouse, parents: [], children: [], spouses: [], siblings: [])
                )
            }
            
            return FamilyGraphData(
                centerPerson: person,
                parents: [],
                children: childNodes,
                spouses: spouseNodes,
                siblings: []
            )
        }
        
        // 标记当前人物为已处理
        processedPersons.insert(person.id)
        
        // 直接从 persons 和 relationships 中获取关系
        let safeRelationships = relationships
        let safePersons = persons
        
        // 获取父亲
        let fatherIds = safeRelationships
            .filter { $0.fromPerson == person.id && $0.type == .father }
            .map { $0.toPerson }
        let fathers = safePersons.filter { fatherIds.contains($0.id) && $0.gender == .male }
        
        // 获取母亲
        let motherIds = safeRelationships
            .filter { $0.fromPerson == person.id && $0.type == .mother }
            .map { $0.toPerson }
        let mothers = safePersons.filter { motherIds.contains($0.id) && $0.gender == .female }
        
        // 获取子女
        let childrenIds = safeRelationships
            .filter { $0.toPerson == person.id && ($0.type == .father || $0.type == .mother) }
            .map { $0.fromPerson }
        let children = safePersons.filter { childrenIds.contains($0.id) }
        
        // 获取配偶
        let spouseIds = safeRelationships
            .filter { ($0.fromPerson == person.id || $0.toPerson == person.id) && $0.type == .spouse }
            .map { $0.fromPerson == person.id ? $0.toPerson : $0.fromPerson }
        let spouses = safePersons.filter { spouseIds.contains($0.id) }
        
        // 获取兄弟姐妹
        var siblingIds = Set<UUID>()
        
        // 通过父亲找兄弟姐妹
        for fatherId in fatherIds {
            let fatherChildrenIds = safeRelationships
                .filter { $0.toPerson == fatherId && ($0.type == .father || $0.type == .mother) }
                .map { $0.fromPerson }
            siblingIds.formUnion(fatherChildrenIds)
        }
        
        // 通过母亲找兄弟姐妹
        for motherId in motherIds {
            let motherChildrenIds = safeRelationships
                .filter { $0.toPerson == motherId && ($0.type == .father || $0.type == .mother) }
                .map { $0.fromPerson }
            siblingIds.formUnion(motherChildrenIds)
        }
        
        // 移除自己
        siblingIds.remove(person.id)
        
        // 获取兄弟和姐妹
        let siblings = safePersons.filter { siblingIds.contains($0.id) }
        
        // 递归构建关系节点
        let parentNodes = (fathers + mothers).map { parent in
            // 为每个父母递归创建子图谱，但减少深度以避免无限递归
            let parentSubGraph = createGraphData(for: parent, level: level + 1, maxDepth: maxDepth, processedPersons: &processedPersons)
            return FamilyGraphData.RelationNode(
                person: parent,
                relationType: parent.gender == .male ? .father : .mother,
                level: level - 1,  // 父母在上一代
                subNodes: parentSubGraph
            )
        }
        
        let childNodes = children.map { child in
            // 为每个子女递归创建子图谱
            let childSubGraph = createGraphData(for: child, level: level + 1, maxDepth: maxDepth, processedPersons: &processedPersons)
            return FamilyGraphData.RelationNode(
                person: child,
                relationType: .child,
                level: level + 1,  // 子女在下一代
                subNodes: childSubGraph
            )
        }
        
        let spouseNodes = spouses.map { spouse in
            // 为每个配偶递归创建子图谱
            let spouseSubGraph = createGraphData(for: spouse, level: level + 1, maxDepth: maxDepth, processedPersons: &processedPersons)
            return FamilyGraphData.RelationNode(
                person: spouse,
                relationType: .spouse,
                level: level,  // 配偶在同一代
                subNodes: spouseSubGraph
            )
        }
        
        let siblingNodes = siblings.map { sibling in
            // 为每个兄弟姐妹递归创建子图谱，但减少深度以避免无限递归
            let siblingSubGraph = createGraphData(for: sibling, level: level + 1, maxDepth: maxDepth, processedPersons: &processedPersons)
            return FamilyGraphData.RelationNode(
                person: sibling,
                relationType: sibling.gender == .male ? .brother : .sister,
                level: level,  // 兄弟姐妹在同一代
                subNodes: siblingSubGraph
            )
        }
        
        // 打印调试信息
        if level == 0 {
            print("中心人物: \(person.name)")
            print("父母: \(parentNodes.map { $0.person.name }.joined(separator: ", "))")
            print("子女: \(childNodes.map { $0.person.name }.joined(separator: ", "))")
            print("配偶: \(spouseNodes.map { $0.person.name }.joined(separator: ", "))")
            print("兄弟姐妹: \(siblingNodes.map { $0.person.name }.joined(separator: ", "))")
            
            // 打印子女的子女信息
            for child in childNodes {
                print("\(child.person.name) 的子女: \(child.subNodes.children.map { $0.person.name }.joined(separator: ", "))")
            }
        }
        
        return FamilyGraphData(
            centerPerson: person,
            parents: parentNodes,
            children: childNodes,
            spouses: spouseNodes,
            siblings: siblingNodes
        )
    }
    
    // 辅助方法：获取人物的所有关系
    private struct PersonRelations {
        let parents: [Person]
        let children: [Person]
        let spouses: [Person]
        let siblings: [Person]
    }
    
    private func getPersonRelations(_ person: Person) -> PersonRelations {
        let safeRelationships = self.relationships
        let safePersons = self.persons
        
        // 获取父母
        let fatherIds = safeRelationships
            .filter { $0.fromPerson == person.id && $0.type == .father }
            .map { $0.toPerson }
        let fathers = safePersons.filter { fatherIds.contains($0.id) && $0.gender == .male }
        
        let motherIds = safeRelationships
            .filter { $0.fromPerson == person.id && $0.type == .mother }
            .map { $0.toPerson }
        let mothers = safePersons.filter { motherIds.contains($0.id) && $0.gender == .female }
        
        // 获取子女
        let childrenIds = safeRelationships
            .filter { $0.toPerson == person.id && ($0.type == .father || $0.type == .mother) }
            .map { $0.fromPerson }
        let children = safePersons.filter { childrenIds.contains($0.id) }
        
        // 获取配偶
        let spouseIds = safeRelationships
            .filter { ($0.fromPerson == person.id || $0.toPerson == person.id) && $0.type == .spouse }
            .map { $0.fromPerson == person.id ? $0.toPerson : $0.fromPerson }
        let spouses = safePersons.filter { spouseIds.contains($0.id) }
        
        // 获取兄弟姐妹
        var siblingIds = Set<UUID>()
        for parentId in (fatherIds + motherIds) {
            let siblingRelations = safeRelationships
                .filter { $0.toPerson == parentId && ($0.type == .father || $0.type == .mother) }
                .map { $0.fromPerson }
            siblingIds.formUnion(siblingRelations)
        }
        siblingIds.remove(person.id)
        let siblings = safePersons.filter { siblingIds.contains($0.id) }
        
        return PersonRelations(
            parents: fathers + mothers,
            children: children,
            spouses: spouses,
            siblings: siblings
        )
    }
    
    // 添加设置"自己"的方法
    func setSelfPerson(_ person: Person) {
        self.selfPerson = person
    }
    
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
    
    // 添加一个公共方法，允许 FamilyAppViewModel 触发图谱数据更新
    func refreshGraphData() {
        if let selectedPerson = selectedPerson {
            updateGraphData()
        }
    }
}

// 用于 SpriteKit 的数据结构保持不变
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
