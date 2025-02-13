
/*
 * RelativeTitleGenerator 类
 * 作用：生成亲属称谓
 * - 计算并生成称谓
 * - 处理称谓的缓存
 * - 生成关系路径描述
 */

import Foundation

class RelativeTitleGenerator {
    weak var managementViewModel: PersonManagementViewModel?
    private var relationshipGraph: RelationshipGraph
    private var lastUpdateTime: Date = .distantPast
    private var titleCache: [UUID: String] = [:]
    private let updateInterval: TimeInterval = 0.5
    private var lastSelfId: UUID? = nil
    private var lastLogTime: Date = .distantPast
    private let logInterval: TimeInterval = 1.0
    
    init(managementViewModel: PersonManagementViewModel?) {
        self.managementViewModel = managementViewModel
        self.relationshipGraph = RelationshipGraph()
    }
    
    @MainActor
    func updateRelationshipGraphIfNeeded() {
        guard let viewModel = managementViewModel else { return }
        
        // 强制更新关系图
        relationshipGraph = RelationshipGraph()
        let relationships = viewModel.relationships
        relationships.forEach { relationship in
            relationshipGraph.addRelationship(relationship)
        }
        
        // 更新自己的ID
        if let selfPerson = viewModel.persons.first(where: { $0.isSelf }) {
            if selfPerson.id != lastSelfId {
                print("🔄 检测到'自己'发生变化，清除缓存")
                titleCache.removeAll()
            }
            lastSelfId = selfPerson.id
        }
        
        lastUpdateTime = Date()
    }
    
    @MainActor
    func generateTitle(for relative: Person) async -> String? {
        // 如果有用户自定义的称谓，优先使用
        if let customTitle = relative.notes, !customTitle.isEmpty {
            return customTitle
        }
        
        guard let viewModel = managementViewModel else { return nil }
        
        // 如果是自己，直接返回
        if relative.isSelf {
            return "自己"  // 修改这里，从"我"改为"自己"
        }
        
        // 强制更新关系图
        updateRelationshipGraphIfNeeded()
        
        // 确保获取最新的人物列表
        guard let selfPerson = viewModel.persons.first(where: { $0.isSelf }) else {
            print("⚠️ 未找到自己，跳过生成称呼")
            return nil
        }
        
        // 使用关系图计算
        guard let (generationDiff, path) = relationshipGraph.calculateRelationship(
            from: selfPerson.id,
            to: relative.id
        ) else {
            print("⚠️ 未找到关系：从 \(selfPerson.firstName) 到 \(relative.firstName)")
            return relative.name  // 改为返回人名而不是"未知关系"
        }
        
        // 生成称呼
        let title = getBaseTitleByGeneration(
            diff: generationDiff,
            gender: relative.gender,
            path: path,
            relativePerson: relative,
            selfPerson: selfPerson  // 传入自己的信息用于比较年龄
        )
        let pathDescription = getPathDescription(
            path: path, 
            gender: relative.gender,
            relativePerson: relative,
            selfPerson: selfPerson
        )
        
        // 返回新格式的称呼
        return "\(pathDescription)，所以我可以称呼\(relative.gender == .male ? "他" : "她")——\(title)"
    }
    
    // 添加新方法：生成路径描述
    private func getPathDescription(path: [RelationType], gender: Person.Gender, relativePerson: Person, selfPerson: Person) -> String {
        let pronoun = gender == .male ? "他" : "她"
        var description = "\(pronoun)是我"
        
        for (index, type) in path.enumerated() {
            switch type {
            case .father:
                description += "爸爸"
            case .mother:
                description += "妈妈"
            case .brother, .sister:
                // 检查是否是父/母的兄弟姐妹
                let isParentSibling = index > 0 && (path[index - 1] == .father || path[index - 1] == .mother)
                if isParentSibling {
                    // 如果是父/母的兄弟姐妹，直接根据性别显示兄弟或姐妹
                    description += gender == .male ? "兄弟" : "姐妹"
                } else {
                    // 普通的兄弟姐妹关系，需要根据生日判断
                    if let relativeBirth = relativePerson.birthDate,
                       let selfBirth = selfPerson.birthDate {
                        let isOlder = relativeBirth < selfBirth
                        description += gender == .male ? 
                            (isOlder ? "哥哥" : "弟弟") : 
                            (isOlder ? "姐姐" : "妹妹")
                    } else {
                        // 如果无法判断年龄，使用通用称呼
                        description += gender == .male ? "兄弟" : "姐妹"
                    }
                }
            case .spouse:
                if description.hasSuffix("的") {
                    description.removeLast()
                }
                description += gender == .male ? "的丈夫" : "的妻子"
                continue
            case .child:
                description += gender == .male ? "儿子" : "女儿"
            }
            description += "的"
        }
        
        if description.hasSuffix("的") {
            description.removeLast()
        }
        return description
    }
    
    private func getBaseTitleByGeneration(
        diff: Int,
        gender: Person.Gender,
        path: [RelationType],
        relativePerson: Person,
        selfPerson: Person
    ) -> String {
        // 添加配偶关系的处理
        if path.contains(.spouse) {
            return gender == .male ? "丈夫" : "妻子"
        }
        
        // 处理同代关系
        if diff == 0 {
            if path.contains(.brother) || path.contains(.sister) {
                // 通过生日判断年龄大小
                if let relativeBirth = relativePerson.birthDate,
                   let selfBirth = selfPerson.birthDate {
                    let isOlder = relativeBirth < selfBirth
                    if gender == .male {
                        return isOlder ? "哥哥" : "弟弟"
                    } else {
                        return isOlder ? "姐姐" : "妹妹"
                    }
                }
                return gender == .male ? "兄弟" : "姐妹"
            }
            // 处理表亲关系
            if path.contains(.father) || path.contains(.mother) {
                // 同样处理表兄弟姐妹的年龄关系
                if let relativeBirth = relativePerson.birthDate,
                   let selfBirth = selfPerson.birthDate {
                    let isOlder = relativeBirth < selfBirth
                    if gender == .male {
                        return isOlder ? "表哥" : "表弟"
                    } else {
                        return isOlder ? "表姐" : "表妹"
                    }
                }
                return gender == .male ? "表兄弟" : "表姐妹"
            }
        }
        
        // 处理长辈关系
        if diff > 0 {
            switch diff {
            case 1:
                if path.contains(.brother) || path.contains(.sister) {
                    // 处理叔伯姑姨
                    if path.contains(.father) {
                        return gender == .male ? "叔伯" : "姑妈"
                    } else {
                        return gender == .male ? "舅舅" : "姨妈"
                    }
                }
                return gender == .male ? "父亲" : "母亲"
            case 2:
                return gender == .male ? "祖父" : "祖母"
            case 3:
                return gender == .male ? "曾祖父" : "曾祖母"
            default:
                return gender == .male ? "祖父" : "祖母"
            }
        }
        
        // 处理晚辈关系
        if diff < 0 {
            switch diff {
            case -1:
                if path.contains(.brother) || path.contains(.sister) {
                    // 处理侄子/外甥关系
                    let isFromBrotherSide = path.contains(.brother)
                    return gender == .male ? 
                        (isFromBrotherSide ? "侄子" : "外甥") : 
                        (isFromBrotherSide ? "侄女" : "外甥女")
                }
                return gender == .male ? "儿子" : "女儿"
            case -2:
                return gender == .male ? "孙子" : "孙女"
            case -3:
                return gender == .male ? "曾孙" : "曾孙女"
            default:
                return gender == .male ? "孙子" : "孙女"
            }
        }
        
        return "未知"
    }
}
