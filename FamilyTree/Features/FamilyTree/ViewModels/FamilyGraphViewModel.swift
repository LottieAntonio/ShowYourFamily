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
        
        // 直接从 persons 和 relationships 中获取关系，避免调用 getRelatedPersons
        let safeRelationships = relationships
        let safePersons = persons
        
        // 获取父亲
        let fatherIds = safeRelationships
            .filter { $0.fromPerson == centerPerson.id && $0.type == .father }
            .map { $0.toPerson }
        let fathers = safePersons.filter { fatherIds.contains($0.id) && $0.gender == .male }
        
        // 获取母亲
        let motherIds = safeRelationships
            .filter { $0.fromPerson == centerPerson.id && $0.type == .mother }
            .map { $0.toPerson }
        let mothers = safePersons.filter { motherIds.contains($0.id) && $0.gender == .female }
        
        // 获取子女
        let childrenIds = safeRelationships
            .filter { $0.toPerson == centerPerson.id && ($0.type == .father || $0.type == .mother) }
            .map { $0.fromPerson }
        let children = safePersons.filter { childrenIds.contains($0.id) }
        
        // 获取配偶
        let spouseIds = safeRelationships
            .filter { ($0.fromPerson == centerPerson.id || $0.toPerson == centerPerson.id) && $0.type == .spouse }
            .map { $0.fromPerson == centerPerson.id ? $0.toPerson : $0.fromPerson }
        let spouses = safePersons.filter { spouseIds.contains($0.id) }
        
        // 获取兄弟姐妹（通过父母间接获取）
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
        siblingIds.remove(centerPerson.id)
        
        // 获取兄弟和姐妹
        let brothers = safePersons.filter { siblingIds.contains($0.id) && $0.gender == .male }
        let sisters = safePersons.filter { siblingIds.contains($0.id) && $0.gender == .female }
        
        // 打印详细的关系信息
        print("📊 关系数据详情:")
        if !fathers.isEmpty {
            print("   - 父亲: \(fathers.map { $0.name }.joined(separator: ", "))")
        }
        if !mothers.isEmpty {
            print("   - 母亲: \(mothers.map { $0.name }.joined(separator: ", "))")
        }
        if !children.isEmpty {
            print("   - 子女: \(children.map { $0.name }.joined(separator: ", "))")
        }
        if !spouses.isEmpty {
            print("   - 配偶: \(spouses.map { $0.name }.joined(separator: ", "))")
        }
        if !brothers.isEmpty {
            print("   - 兄弟: \(brothers.map { $0.name }.joined(separator: ", "))")
        }
        if !sisters.isEmpty {
            print("   - 姐妹: \(sisters.map { $0.name }.joined(separator: ", "))")
        }
        
        let parents = fathers + mothers
        print("📊 关系数据: 父母(\(parents.count)), 子女(\(children.count)), 配偶(\(spouses.count)), 兄弟(\(brothers.count)), 姐妹(\(sisters.count))")
        
        // 创建图谱数据
        graphData = createGraphData(for: centerPerson, level: 0, maxDepth: 3)
    }
    
    private func createGraphData(for person: Person, level: Int, maxDepth: Int) -> FamilyGraphData {
        // 使用队列存储待处理的节点
        struct QueueItem {
            let person: Person
            let level: Int
            let parentNode: FamilyGraphData.RelationNode?
        }
        
        // 存储已处理的节点，避免重复处理
        var processedPeople = Set<UUID>()
        var nodeMap = [UUID: FamilyGraphData.RelationNode]()
        var queue = [QueueItem]()
        
        // 初始化根节点
        queue.append(QueueItem(person: person, level: 0, parentNode: nil))
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            
            // 如果已处理过该节点，跳过
            if processedPeople.contains(current.person.id) {
                continue
            }
            
            // 标记为已处理
            processedPeople.insert(current.person.id)
            
            // 获取当前人物的所有关系
            let relations = getPersonRelations(current.person)
            
            // 创建当前节点的子节点
            var parentNodes: [FamilyGraphData.RelationNode] = []
            var childrenNodes: [FamilyGraphData.RelationNode] = []
            var spouseNodes: [FamilyGraphData.RelationNode] = []
            var siblingNodes: [FamilyGraphData.RelationNode] = []
            
            // 如果未超过最大深度，继续处理关系
            if current.level < maxDepth {
                // 处理父母
                for parent in relations.parents {
                    let node = FamilyGraphData.RelationNode(
                        person: parent,
                        relationType: parent.gender == .male ? .father : .mother,
                        level: current.level + 1,
                        subNodes: FamilyGraphData(
                            centerPerson: parent,
                            parents: [], children: [], spouses: [], siblings: []
                        )
                    )
                    parentNodes.append(node)
                    nodeMap[parent.id] = node
                    
                    // 将父母加入队列继续处理
                    queue.append(QueueItem(person: parent, level: current.level + 1, parentNode: node))
                }
                
                // 处理子女
                for child in relations.children {
                    let node = FamilyGraphData.RelationNode(
                        person: child,
                        relationType: .child,
                        level: current.level + 1,
                        subNodes: FamilyGraphData(
                            centerPerson: child,
                            parents: [], children: [], spouses: [], siblings: []
                        )
                    )
                    childrenNodes.append(node)
                    nodeMap[child.id] = node
                    
                    // 将子女加入队列继续处理
                    queue.append(QueueItem(person: child, level: current.level + 1, parentNode: node))
                }
                
                // 处理配偶和兄弟姐妹（这些关系不需要递归处理）
                spouseNodes = relations.spouses.map {
                    FamilyGraphData.RelationNode(
                        person: $0,
                        relationType: .spouse,
                        level: current.level,
                        subNodes: FamilyGraphData(
                            centerPerson: $0,
                            parents: [], children: [], spouses: [], siblings: []
                        )
                    )
                }
                
                siblingNodes = relations.siblings.map {
                    FamilyGraphData.RelationNode(
                        person: $0,
                        relationType: $0.gender == .male ? .brother : .sister,
                        level: current.level,
                        subNodes: FamilyGraphData(
                            centerPerson: $0,
                            parents: [], children: [], spouses: [], siblings: []
                        )
                    )
                }
            }
            
            // 更新节点的关系数据
            let currentNode = FamilyGraphData(
                centerPerson: current.person,
                parents: parentNodes,
                children: childrenNodes,
                spouses: spouseNodes,
                siblings: siblingNodes
            )
            
            // 如果有父节点，更新父节点的子节点数据
            if let parentNode = current.parentNode {
                nodeMap[parentNode.person.id]?.subNodes = currentNode
            }
        }
        
        // 返回根节点的数据
        return FamilyGraphData(
            centerPerson: person,
            parents: nodeMap.values.filter { $0.relationType == .father || $0.relationType == .mother },
            children: nodeMap.values.filter { $0.relationType == .child },
            spouses: nodeMap.values.filter { $0.relationType == .spouse },
            siblings: nodeMap.values.filter { $0.relationType == .brother || $0.relationType == .sister }
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
