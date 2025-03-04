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
        
        // 获取所有关系
        let fathers = stateManager.getRelatedPersons(for: centerPerson, relationType: .father)
        let mothers = stateManager.getRelatedPersons(for: centerPerson, relationType: .mother)
        let parents = fathers + mothers
        let children = stateManager.getRelatedPersons(for: centerPerson, relationType: .child)
        let spouses = stateManager.getRelatedPersons(for: centerPerson, relationType: .spouse)
        let brothers = stateManager.getRelatedPersons(for: centerPerson, relationType: .brother)
        let sisters = stateManager.getRelatedPersons(for: centerPerson, relationType: .sister)
        
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
        
        print("📊 关系数据: 父母(\(parents.count)), 子女(\(children.count)), 配偶(\(spouses.count)), 兄弟(\(brothers.count)), 姐妹(\(sisters.count))")
        
        // 创建图谱数据
        graphData = createGraphData(for: centerPerson, level: 0, maxDepth: 3)
    }
    
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
        let fathers = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .father)))
        let mothers = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .mother)))
        let parents = fathers + mothers
        let children = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .child)))
        let spouses = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .spouse)))
        let brothers = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .brother)))
        let sisters = Array(Set(stateManager.getRelatedPersons(for: person, relationType: .sister)))
        
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
