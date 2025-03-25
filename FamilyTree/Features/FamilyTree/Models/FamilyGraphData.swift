import Foundation

// 定义亲属关系类别，用于筛选显示
enum RelationCategory: String, CaseIterable {
    case all = "全部"
    case paternal = "父系"
    case maternal = "母系"
    case spouse = "配偶"
    case children = "子女"
    case siblings = "兄弟姐妹"
}

struct FamilyGraphData: Equatable {
    struct RelationNode: Equatable {
        let person: Person
        let relationType: RelationType
        let level: Int
        var subNodes: FamilyGraphData
        var isInFilter: Bool = true  // 添加标记，表示是否在筛选范围内
        
        // 修改获取关系类别的方法，不再使用不存在的 getRelationTo 方法
        func getCategory(relativeTo centerPerson: Person) -> RelationCategory {
            switch relationType {
            case .father:
                return .paternal
            case .mother:
                return .maternal
            case .spouse:
                return .spouse
            case .child:
                return .children
            case .brother, .sister:
                return .siblings
            default:
                // 由于无法通过 getRelationTo 确定关系，直接返回 .all
                return .all
            }
        }
    }
    
    let centerPerson: Person
    var parents: [RelationNode]
    var children: [RelationNode]
    var spouses: [RelationNode]
    var siblings: [RelationNode]
    
    // 添加筛选方法，根据关系类别和深度筛选
    // 修改筛选方法，根据关系类别和深度筛选，并标记节点是否在筛选范围内
    func filtered(by categories: [RelationCategory], maxDepth: Int) -> FamilyGraphData {
        // 如果包含 .all 或者类别为空，返回完整数据（但仍然限制深度）
        if categories.contains(.all) || categories.isEmpty {
            return limitDepth(maxDepth: maxDepth, markFiltered: true)
        }
        
        // 创建一个完整的数据副本，但所有节点标记为不在筛选范围内
        var fullData = limitDepth(maxDepth: maxDepth, markFiltered: false)
        
        // 筛选各类关系并标记为在筛选范围内
        let filteredParents = parents.filter { categories.contains($0.getCategory(relativeTo: centerPerson)) }
            .map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: true) }
        
        let filteredSpouses = spouses.filter { categories.contains($0.getCategory(relativeTo: centerPerson)) }
            .map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: true) }
        
        let filteredChildren = children.filter { categories.contains($0.getCategory(relativeTo: centerPerson)) }
            .map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: true) }
        
        let filteredSiblings = siblings.filter { categories.contains($0.getCategory(relativeTo: centerPerson)) }
            .map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: true) }
        
        // 将筛选后的节点与完整数据合并
        // 这里我们保留所有节点，但只有筛选到的节点标记为 isInFilter = true
        for parent in filteredParents {
            if let index = fullData.parents.firstIndex(where: { $0.person.id == parent.person.id }) {
                fullData.parents[index] = parent
            }
        }
        
        for spouse in filteredSpouses {
            if let index = fullData.spouses.firstIndex(where: { $0.person.id == spouse.person.id }) {
                fullData.spouses[index] = spouse
            }
        }
        
        for child in filteredChildren {
            if let index = fullData.children.firstIndex(where: { $0.person.id == child.person.id }) {
                fullData.children[index] = child
            }
        }
        
        for sibling in filteredSiblings {
            if let index = fullData.siblings.firstIndex(where: { $0.person.id == sibling.person.id }) {
                fullData.siblings[index] = sibling
            }
        }
        
        return fullData
    }
    
    // 修改限制深度的辅助方法，添加标记参数
    private func limitDepth(maxDepth: Int, markFiltered: Bool) -> FamilyGraphData {
        let depthLimitedParents = parents.map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: markFiltered) }
        let depthLimitedSpouses = spouses.map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: markFiltered) }
        let depthLimitedChildren = children.map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: markFiltered) }
        let depthLimitedSiblings = siblings.map { limitNodeDepth($0, currentDepth: 1, maxDepth: maxDepth, isInFilter: markFiltered) }
        
        return FamilyGraphData(
            centerPerson: centerPerson,
            parents: depthLimitedParents,
            children: depthLimitedChildren,
            spouses: depthLimitedSpouses,
            siblings: depthLimitedSiblings
        )
    }
    
    // 修改限制节点深度的辅助方法，添加标记参数
    private func limitNodeDepth(_ node: RelationNode, currentDepth: Int, maxDepth: Int, isInFilter: Bool) -> RelationNode {
        if currentDepth >= maxDepth {
            // 超过最大深度，返回没有子节点的节点
            return RelationNode(
                person: node.person,
                relationType: node.relationType,
                level: node.level,
                subNodes: FamilyGraphData(
                    centerPerson: node.person,
                    parents: [],
                    children: [],
                    spouses: [],
                    siblings: []
                ),
                isInFilter: isInFilter
            )
        }
        
        // 递归处理子节点的所有关系
        let nextDepth = currentDepth + 1
        
        // 处理子节点的父母、子女、配偶和兄弟姐妹
        let subNodesParents = node.subNodes.parents.map { limitNodeDepth($0, currentDepth: nextDepth, maxDepth: maxDepth, isInFilter: isInFilter) }
        let subNodesChildren = node.subNodes.children.map { limitNodeDepth($0, currentDepth: nextDepth, maxDepth: maxDepth, isInFilter: isInFilter) }
        let subNodesSpouses = node.subNodes.spouses.map { limitNodeDepth($0, currentDepth: nextDepth, maxDepth: maxDepth, isInFilter: isInFilter) }
        let subNodesSiblings = node.subNodes.siblings.map { limitNodeDepth($0, currentDepth: nextDepth, maxDepth: maxDepth, isInFilter: isInFilter) }
        
        // 创建新的子节点数据
        let newSubNodes = FamilyGraphData(
            centerPerson: node.subNodes.centerPerson,
            parents: subNodesParents,
            children: subNodesChildren,
            spouses: subNodesSpouses,
            siblings: subNodesSiblings
        )
        
        return RelationNode(
            person: node.person,
            relationType: node.relationType,
            level: node.level,
            subNodes: newSubNodes,
            isInFilter: isInFilter
        )
    }
    
    // 由于 Person 和 RelationType 已经遵循 Equatable，
    // Swift 会自动生成 Equatable 的实现
    
    // 添加 isEmpty 属性
    var isEmpty: Bool {
        return parents.isEmpty && children.isEmpty && spouses.isEmpty && siblings.isEmpty
    }
    
    // 添加查找人物的方法
    func findPerson(by id: UUID) -> Person? {
        if centerPerson.id == id {
            return centerPerson
        }
        
        // 在父母中查找
        for parent in parents {
            if parent.person.id == id {
                return parent.person
            }
            
            if let found = parent.subNodes.findPerson(by: id) {
                return found
            }
        }
        
        // 在子女中查找
        for child in children {
            if child.person.id == id {
                return child.person
            }
            
            if let found = child.subNodes.findPerson(by: id) {
                return found
            }
        }
        
        // 在配偶中查找
        for spouse in spouses {
            if spouse.person.id == id {
                return spouse.person
            }
            
            if let found = spouse.subNodes.findPerson(by: id) {
                return found
            }
        }
        
        // 在兄弟姐妹中查找
        for sibling in siblings {
            if sibling.person.id == id {
                return sibling.person
            }
            
            if let found = sibling.subNodes.findPerson(by: id) {
                return found
            }
        }
        
        return nil
    }
}
