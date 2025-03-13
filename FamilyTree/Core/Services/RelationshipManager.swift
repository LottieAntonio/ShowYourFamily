import Foundation

@MainActor
class RelationshipManager {
    private let stateManager: StateManager
    private var titleGenerator: RelativeTitleGenerator?
    private var lastRelationshipCount = 0
    private var lastPersonCount = 0
    
    init(stateManager: StateManager) {
        self.stateManager = stateManager
    }
    
    // 生成亲属称谓
    func generateTitle(for person: Person) -> String? {
        // 检查数据是否变化，如果变化则重置生成器
        let currentRelationshipCount = stateManager.state.relationships.count
        let currentPersonCount = stateManager.state.persons.count
        
        if titleGenerator == nil || 
           currentRelationshipCount != lastRelationshipCount || 
           currentPersonCount != lastPersonCount {
            
            titleGenerator = RelativeTitleGenerator(
                relationships: stateManager.state.relationships,
                persons: stateManager.state.persons
            )
            
            lastRelationshipCount = currentRelationshipCount
            lastPersonCount = currentPersonCount
        }
        
        return titleGenerator?.generateTitle(for: person)
    }
    
    // 当数据变化时重置生成器
    func resetTitleGenerator() {
        titleGenerator = nil
        lastRelationshipCount = 0
        lastPersonCount = 0
    }
    
    // 查找关系路径
    func findRelationPath(from source: Person, to target: Person) -> [Relationship] {
        let pathFinder = RelationshipPathFinder(relationships: stateManager.state.relationships)
        return pathFinder.findPath(from: source.id, to: target.id)
    }
    
    // 获取关系描述
    func getRelationshipDescription(from source: Person, to target: Person) -> String {
        let path = findRelationPath(from: source, to: target)
        if path.isEmpty {
            return "没有直接关系"
        }
        
        // 使用RelativeTitleGenerator生成更详细的关系描述
        if let title = generateTitle(for: target) {
            return title.replacingOccurrences(of: "\(source.lastName)\(source.firstName)的", with: "")
        }
        
        return "有\(path.count)个关系连接"
    }
    
    // 调试方法：打印所有关系
    func printAllRelationships() {
        let relationships = stateManager.state.relationships
        let persons = stateManager.state.persons
        
        print("📋 所有关系数量: \(relationships.count)")
        print("👥 所有人物数量: \(persons.count)")
        
        // 打印所有人物信息
        print("\n👤 人物信息:")
        for (index, person) in persons.enumerated() {
            print("  #\(index): ID=\(person.id), 姓名=\(person.name), 性别=\(person.gender), 是自己=\(person.isSelf)")
        }
        
        // 打印所有关系信息
        print("\n🔗 关系信息:")
        for (index, relation) in relationships.enumerated() {
            let fromPerson = persons.first(where: { $0.id == relation.fromPerson })?.name ?? "未知"
            let toPerson = persons.first(where: { $0.id == relation.toPerson })?.name ?? "未知"
            
            print("  #\(index): 类型=\(relation.type), 从=\(fromPerson)(\(relation.fromPerson)), 到=\(toPerson)(\(relation.toPerson))")
        }
        
        // 检查父子关系
        print("\n👨‍👧 父子关系检查:")
        for person in persons {
            let fatherRelations = relationships.filter { relation in
                (relation.fromPerson == person.id && relation.type == .father) ||
                (relation.toPerson == person.id && relation.type == .child && 
                 persons.first(where: { $0.id == relation.fromPerson })?.gender == .male)
            }
            
            let motherRelations = relationships.filter { relation in
                (relation.fromPerson == person.id && relation.type == .mother) ||
                (relation.toPerson == person.id && relation.type == .child && 
                 persons.first(where: { $0.id == relation.fromPerson })?.gender == .female)
            }
            
            print("  \(person.name): 父亲关系数量=\(fatherRelations.count), 母亲关系数量=\(motherRelations.count)")
        }
        
        // 检查自己的人物
        if let selfPerson = persons.first(where: { $0.isSelf }) {
            print("\n🧑 自己: \(selfPerson.name) (ID=\(selfPerson.id))")
            
            // 检查自己的直系亲属
            let directRelatives = relationships.filter {
                $0.fromPerson == selfPerson.id || $0.toPerson == selfPerson.id
            }
            
            print("  直系关系数量: \(directRelatives.count)")
            for (index, relation) in directRelatives.enumerated() {
                let otherPersonId = relation.fromPerson == selfPerson.id ? relation.toPerson : relation.fromPerson
                let otherPerson = persons.first(where: { $0.id == otherPersonId })?.name ?? "未知"
                let direction = relation.fromPerson == selfPerson.id ? "自己->对方" : "对方->自己"
                
                print("  #\(index): 类型=\(relation.type), \(direction), 对方=\(otherPerson)")
            }
        } else {
            print("\n⚠️ 未找到标记为自己的人物")
        }
        // 在printAllRelationships方法中添加
        // 特别检查李秀兰和张建国的关系
        print("\n🔍 特别检查李秀兰和张建国的关系:")
        let liXiuLan = persons.first(where: { $0.name == "李秀兰" })
        let zhangJianGuo = persons.first(where: { $0.name == "张建国" })
        
        if let liXiuLan = liXiuLan, let zhangJianGuo = zhangJianGuo {
            print("  李秀兰ID: \(liXiuLan.id)")
            print("  张建国ID: \(zhangJianGuo.id)")
            
            let directRelations = relationships.filter {
                ($0.fromPerson == liXiuLan.id && $0.toPerson == zhangJianGuo.id) ||
                ($0.fromPerson == zhangJianGuo.id && $0.toPerson == liXiuLan.id)
            }
            
            print("  直接关系数量: \(directRelations.count)")
            for (index, relation) in directRelations.enumerated() {
                let direction = relation.fromPerson == liXiuLan.id ? "李秀兰->张建国" : "张建国->李秀兰"
                print("  #\(index): 类型=\(relation.type), 方向=\(direction)")
            }
        } else {
            print("  ⚠️ 未找到李秀兰或张建国")
        }
        
        // 特别检查张小红的关系
        print("\n🔍 特别检查张小红的关系:")
        let zhangXiaoHong = persons.first(where: { $0.name == "张小红" })
        
        if let zhangXiaoHong = zhangXiaoHong {
            print("  张小红ID: \(zhangXiaoHong.id)")
            
            // 查找张小红的所有关系
            let xiaoHongRelations = relationships.filter {
                $0.fromPerson == zhangXiaoHong.id || $0.toPerson == zhangXiaoHong.id
            }
            
            print("  关系数量: \(xiaoHongRelations.count)")
            for (index, relation) in xiaoHongRelations.enumerated() {
                let otherPersonId = relation.fromPerson == zhangXiaoHong.id ? relation.toPerson : relation.fromPerson
                let otherPerson = persons.first(where: { $0.id == otherPersonId })?.name ?? "未知"
                let direction = relation.fromPerson == zhangXiaoHong.id ? "张小红->对方" : "对方->张小红"
                print("  #\(index): 类型=\(relation.type), \(direction), 对方=\(otherPerson)")
            }
        } else {
            print("  ⚠️ 未找到张小红")
        }
        
        // 特别检查张建国的父母关系
        print("\n🔍 特别检查张建国的父母关系:")
        if let zhangJianGuo = zhangJianGuo {
            // 查找张建国的父亲
            let fatherRelations = relationships.filter { relation in
                (relation.fromPerson == zhangJianGuo.id && relation.type == .father) ||
                (relation.toPerson == zhangJianGuo.id && relation.type == .child && 
                 persons.first(where: { $0.id == relation.fromPerson })?.gender == .male)
            }
            
            print("  父亲关系数量: \(fatherRelations.count)")
            for (index, relation) in fatherRelations.enumerated() {
                let fatherId = relation.type == .father ? relation.toPerson : relation.fromPerson
                let fatherName = persons.first(where: { $0.id == fatherId })?.name ?? "未知"
                print("  #\(index): 父亲=\(fatherName), 类型=\(relation.type)")
            }
            
            // 查找张建国的母亲
            let motherRelations = relationships.filter { relation in
                (relation.fromPerson == zhangJianGuo.id && relation.type == .mother) ||
                (relation.toPerson == zhangJianGuo.id && relation.type == .child && 
                 persons.first(where: { $0.id == relation.fromPerson })?.gender == .female)
            }
            
            print("  母亲关系数量: \(motherRelations.count)")
            for (index, relation) in motherRelations.enumerated() {
                let motherId = relation.type == .mother ? relation.toPerson : relation.fromPerson
                let motherName = persons.first(where: { $0.id == motherId })?.name ?? "未知"
                print("  #\(index): 母亲=\(motherName), 类型=\(relation.type)")
            }
        } else {
            print("  ⚠️ 未找到张建国")
        }
    }
}