import SpriteKit

extension FamilyGraphScene {
    // 计算布局的方法
    func calculateLayout(for graphData: FamilyGraphData) {
        // 清空之前的布局信息
        nodeLayoutMap.removeAll()
        connections.removeAll()
        processedPersons.removeAll()
        
        // 首先计算中心人物的位置
        let centerPerson = graphData.centerPerson
        let centerInfo = NodeLayoutInfo(
            personId: centerPerson.id,
            position: CGPoint(x: 0, y: 0),
            isCenter: true,
            isInFilter: true,
            level: 0,
            horizontalIndex: 0
        )
        nodeLayoutMap[centerPerson.id] = centerInfo
        processedPersons.insert(centerPerson.id)
        
        // 计算所有关系的布局
        calculateRelationshipsLayout(graphData: graphData, parentInfo: centerInfo)
        
        // 添加碰撞检测和位置调整步骤
        adjustNodePositionsToAvoidOverlap()
        
        // 添加平均分布步骤
        distributeNodesEvenly()
        
        // 确保中心人物居中显示
        centerSelectedPerson()
    }
    
    // 优化：调整节点位置以避免水平方向重叠
    func adjustNodePositionsToAvoidOverlap() {
        // 节点大小（估计值，可以根据实际情况调整）
        let nodeWidth: CGFloat = 100  // 减小节点宽度估计值
        let nodeHorizontalPadding: CGFloat = 5  // 减小节点之间的额外间距
        
        // 最小安全距离（节点之间的最小间距）
        let minHorizontalDistance: CGFloat = nodeWidth + nodeHorizontalPadding
        
        // 按层级分组节点
        var levelGroups: [Int: [NodeLayoutInfo]] = [:]
        for (id, info) in nodeLayoutMap {
            if levelGroups[info.level] == nil {
                levelGroups[info.level] = []
            }
            levelGroups[info.level]?.append(info)
        }
        
        // 从上到下（祖先到后代）处理每个层级
        for level in levelGroups.keys.sorted() {
            guard let nodesInLevel = levelGroups[level] else { continue }
            
            // 按水平位置排序
            var sortedNodes = nodesInLevel.sorted { $0.position.x < $1.position.x }
            
            // 多次迭代检查重叠，直到没有重叠为止
            var hasOverlap = true
            var iterationCount = 0
            let maxIterations = 5  // 防止无限循环
            
            while hasOverlap && iterationCount < maxIterations {
                hasOverlap = false
                iterationCount += 1
                
                // 检查并调整同一层级内的节点
                for i in 0..<sortedNodes.count {
                    for j in (i+1)..<sortedNodes.count {
                        let node1 = sortedNodes[i]
                        let node2 = sortedNodes[j]
                        
                        // 计算两个节点之间的水平距离
                        let horizontalDistance = node2.position.x - node1.position.x
                        
                        // 如果距离小于最小安全距离，则调整位置
                        if horizontalDistance < minHorizontalDistance {
                            // 需要移动的距离
                            let moveDistance = minHorizontalDistance - horizontalDistance + 2  // 进一步减少额外距离
                            
                            // 更新第二个节点的位置（向右移动）
                            if var updatedNode2 = nodeLayoutMap[node2.personId] {
                                updatedNode2.position.x += moveDistance
                                nodeLayoutMap[node2.personId] = updatedNode2
                                
                                // 同时移动该节点的所有子节点和配偶
                                moveChildrenAndSpouses(parentId: node2.personId, offsetX: moveDistance)
                                
                                // 标记仍有重叠
                                hasOverlap = true
                            }
                        }
                    }
                }
                
                // 更新排序后的节点列表，以便下一次迭代
                if hasOverlap {
                    for i in 0..<sortedNodes.count {
                        if let updatedInfo = nodeLayoutMap[sortedNodes[i].personId] {
                            sortedNodes[i] = updatedInfo
                        }
                    }
                    // 重新排序
                    sortedNodes.sort { $0.position.x < $1.position.x }
                }
            }
        }
    }
    
    // 新增：平均分布节点
    func distributeNodesEvenly() {
        // 按层级分组节点
        var levelGroups: [Int: [NodeLayoutInfo]] = [:]
        for (id, info) in nodeLayoutMap {
            if levelGroups[info.level] == nil {
                levelGroups[info.level] = []
            }
            levelGroups[info.level]?.append(info)
        }
        
        // 处理每个层级
        for level in levelGroups.keys.sorted() {
            guard var nodesInLevel = levelGroups[level] else { continue }
            
            // 按水平位置排序
            nodesInLevel.sort { $0.position.x < $1.position.x }
            
            // 如果该层级只有一个节点，跳过
            if nodesInLevel.count <= 1 { continue }
            
            // 找出该层级的最左和最右节点
            let leftmostNode = nodesInLevel.first!
            let rightmostNode = nodesInLevel.last!
            
            // 计算总宽度
            let totalWidth = rightmostNode.position.x - leftmostNode.position.x
            
            // 计算理想间距
            let idealSpacing = totalWidth / CGFloat(nodesInLevel.count - 1)
            
            // 如果理想间距太小，使用最小间距
            let minSpacing: CGFloat = 115 // 减小最小间距
            let spacing = max(idealSpacing, minSpacing)
            
            // 重新分布节点
            var currentX = leftmostNode.position.x
            
            // 保持第一个节点位置不变
            for i in 1..<nodesInLevel.count {
                let node = nodesInLevel[i]
                let idealX = leftmostNode.position.x + spacing * CGFloat(i)
                
                // 如果节点需要向右移动
                if idealX > node.position.x {
                    let moveDistance = idealX - node.position.x
                    
                    // 更新节点位置
                    if var updatedNode = nodeLayoutMap[node.personId] {
                        updatedNode.position.x = idealX
                        nodeLayoutMap[node.personId] = updatedNode
                        
                        // 同时移动该节点的所有子节点和配偶
                        moveChildrenAndSpouses(parentId: node.personId, offsetX: moveDistance)
                    }
                }
                // 如果节点需要向左移动（只在间距过大时）
                else if node.position.x - nodesInLevel[i-1].position.x > spacing * 1.3 { // 减小触发向左移动的阈值
                    let moveDistance = node.position.x - idealX
                    
                    // 更新节点位置
                    if var updatedNode = nodeLayoutMap[node.personId] {
                        updatedNode.position.x = idealX
                        nodeLayoutMap[node.personId] = updatedNode
                        
                        // 同时移动该节点的所有子节点和配偶
                        moveChildrenAndSpouses(parentId: node.personId, offsetX: -moveDistance)
                    }
                }
            }
        }
    }
    
    // 新增：确保中心人物居中显示
    func centerSelectedPerson() {
        // 找到中心人物节点
        var centerNodeId: UUID? = nil
        for (id, info) in nodeLayoutMap {
            if info.isCenter {
                centerNodeId = id
                break
            }
        }
        
        guard let centerNodeId = centerNodeId,
              let centerNodeInfo = nodeLayoutMap[centerNodeId] else { return }
        
        // 如果中心人物不在原点，需要移动整个图
        if centerNodeInfo.position != .zero {
            let offsetX = -centerNodeInfo.position.x
            
            // 移动所有节点
            for (id, info) in nodeLayoutMap {
                var updatedInfo = info
                updatedInfo.position.x += offsetX
                nodeLayoutMap[id] = updatedInfo
            }
        }
    }
    
    // 优化：移动节点的所有子节点和配偶
    func moveChildrenAndSpouses(parentId: UUID, offsetX: CGFloat) {
        guard let parentInfo = nodeLayoutMap[parentId] else { return }
        
        // 移动直接子女
        for childId in parentInfo.children {
            if var childInfo = nodeLayoutMap[childId] {
                childInfo.position.x += offsetX
                nodeLayoutMap[childId] = childInfo
                
                // 递归移动子女的子女
                moveChildrenAndSpouses(parentId: childId, offsetX: offsetX)
            }
        }
        
        // 移动配偶
        for spouseId in parentInfo.spouses {
            if var spouseInfo = nodeLayoutMap[spouseId] {
                spouseInfo.position.x += offsetX
                nodeLayoutMap[spouseId] = spouseInfo
                
                // 移动与配偶共同的子女
                if let spouseChildrenIds = parentInfo.spouseChildrenGroups[spouseId] {
                    for childId in spouseChildrenIds {
                        if var childInfo = nodeLayoutMap[childId] {
                            childInfo.position.x += offsetX
                            nodeLayoutMap[childId] = childInfo
                            
                            // 递归移动子女的子女
                            moveChildrenAndSpouses(parentId: childId, offsetX: offsetX)
                        }
                    }
                }
            }
        }
    }
    
    // 计算关系布局
    func calculateRelationshipsLayout(graphData: FamilyGraphData, parentInfo: NodeLayoutInfo) {
        // 计算配偶布局
        calculateSpousesLayout(graphData: graphData, parentInfo: parentInfo)
        
        // 计算子女布局
        calculateChildrenLayout(graphData: graphData, parentInfo: parentInfo)
        
        // 计算父母布局
        calculateParentsLayout(graphData: graphData, childInfo: parentInfo)
        
        // 计算兄弟姐妹布局
        calculateSiblingsLayout(graphData: graphData, siblingInfo: parentInfo)
        
        // 直接计算祖父母（父母的父母）
        calculateGrandparentsLayout(graphData: graphData, grandchildInfo: parentInfo)
        
        // 直接计算孙子女（子女的子女）
        calculateGrandchildrenLayout(graphData: graphData, grandparentInfo: parentInfo)
        
        // 直接计算曾祖父母（祖父母的父母）
        calculateGreatGrandparentsLayout(graphData: graphData, greatGrandchildInfo: parentInfo)
        
        // 直接计算曾孙子女（孙子女的子女）
        calculateGreatGrandchildrenLayout(graphData: graphData, greatGrandparentInfo: parentInfo)
    }
    
    // 计算配偶布局
    func calculateSpousesLayout(graphData: FamilyGraphData, parentInfo: NodeLayoutInfo) {
        let spouses = graphData.spouses
        if spouses.isEmpty { return }
        
        // 配偶总是放在右侧
        var currentX = parentInfo.position.x + horizontalSpacing
        var spouseInfos: [NodeLayoutInfo] = []
        var updatedParentInfo = parentInfo
        
        for spouse in spouses {
            if processedPersons.contains(spouse.person.id) { continue }
            
            processedPersons.insert(spouse.person.id)
            
            let spousePosition = CGPoint(x: currentX, y: parentInfo.position.y)
            let spouseInfo = NodeLayoutInfo(
                personId: spouse.person.id,
                position: spousePosition,
                isCenter: false,
                isInFilter: spouse.isInFilter,
                level: parentInfo.level,
                horizontalIndex: parentInfo.horizontalIndex + spouseInfos.count + 1
            )
            
            nodeLayoutMap[spouse.person.id] = spouseInfo
            spouseInfos.append(spouseInfo)
            
            // 添加配偶连接信息
            connections.append(ConnectionInfo(
                fromId: parentInfo.personId,
                toId: spouse.person.id,
                type: .spouse,
                isInFilter: spouse.isInFilter
            ))
            
            // 更新父节点的配偶列表
            updatedParentInfo.spouses.append(spouse.person.id)
            
            // 更新X坐标 - 配偶依次向右排列
            currentX += spouse.isInFilter ? horizontalSpacing : reducedSpacing
            
            // 计算与该配偶的子女关系
            calculateChildrenWithSpouseLayout(
                graphData: spouse.subNodes,
                parentInfo: parentInfo,
                spouseInfo: spouseInfo
            )
        }
        
        // 更新父节点信息
        nodeLayoutMap[parentInfo.personId] = updatedParentInfo
    }
    
    // 计算与特定配偶的子女布局
    func calculateChildrenWithSpouseLayout(
        graphData: FamilyGraphData,
        parentInfo: NodeLayoutInfo,
        spouseInfo: NodeLayoutInfo
    ) {
        let children = graphData.children
        if children.isEmpty { return }
        
        // 计算子女的垂直位置（比父母低一级）
        let childrenY = parentInfo.position.y - verticalSpacing
        
        // 计算子女的水平起始位置（父母和配偶之间的中点）
        let startX = (parentInfo.position.x + spouseInfo.position.x) / 2
        
        // 计算子女的总宽度
        let totalWidth = CGFloat(children.count - 1) * horizontalSpacing
        
        // 计算第一个子女的X坐标（居中排列）
        var currentX = startX - totalWidth / 2
        
        // 更新父节点和配偶节点的信息
        var updatedParentInfo = parentInfo
        var updatedSpouseInfo = spouseInfo
        var childrenIds: [UUID] = []
        
        // 布局每个子女
        for (index, child) in children.enumerated() {
            if processedPersons.contains(child.person.id) { continue }
            
            processedPersons.insert(child.person.id)
            childrenIds.append(child.person.id)
            
            // 创建子女的布局信息
            let childPosition = CGPoint(x: currentX, y: childrenY)
            let childInfo = NodeLayoutInfo(
                personId: child.person.id,
                position: childPosition,
                isCenter: false,
                isInFilter: child.isInFilter,
                level: parentInfo.level + 1,
                horizontalIndex: index
            )
            
            // 保存子女的布局信息
            nodeLayoutMap[child.person.id] = childInfo
            
            // 添加父母到子女的连接
            connections.append(ConnectionInfo(
                fromId: parentInfo.personId,
                toId: child.person.id,
                type: .child,
                isInFilter: child.isInFilter
            ))
            
            // 添加配偶到子女的连接
            connections.append(ConnectionInfo(
                fromId: spouseInfo.personId,
                toId: child.person.id,
                type: .child,
                isInFilter: child.isInFilter
            ))
            
            // 更新X坐标
            currentX += child.isInFilter ? horizontalSpacing : reducedSpacing
        }
        
        // 更新父节点和配偶节点的子女列表
        updatedParentInfo.children.append(contentsOf: childrenIds)
        updatedSpouseInfo.children.append(contentsOf: childrenIds)
        
        // 更新配偶对应的子女组
        updatedParentInfo.spouseChildrenGroups[spouseInfo.personId] = childrenIds
        updatedSpouseInfo.spouseChildrenGroups[parentInfo.personId] = childrenIds
        
        // 保存更新后的节点信息
        nodeLayoutMap[parentInfo.personId] = updatedParentInfo
        nodeLayoutMap[spouseInfo.personId] = updatedSpouseInfo
    }
    
    // 计算父母布局
    func calculateParentsLayout(graphData: FamilyGraphData, childInfo: NodeLayoutInfo) {
        let parents = graphData.parents
        if parents.isEmpty { return }
        
        // 计算父母的垂直位置（比子女高一级）
        let parentsY = childInfo.position.y + verticalSpacing
        
        // 如果有两个父母，需要计算他们的水平位置
        var fatherX = childInfo.position.x - horizontalSpacing / 2
        var motherX = childInfo.position.x + horizontalSpacing / 2
        
        // 更新子节点信息
        var updatedChildInfo = childInfo
        
        // 布局每个父母
        for parent in parents {
            if processedPersons.contains(parent.person.id) { continue }
            
            processedPersons.insert(parent.person.id)
            
            // 根据性别确定位置（父亲在左，母亲在右）
            let parentX = parent.person.gender == .male ? fatherX : motherX
            let parentPosition = CGPoint(x: parentX, y: parentsY)
            
            let parentInfo = NodeLayoutInfo(
                personId: parent.person.id,
                position: parentPosition,
                isCenter: false,
                isInFilter: parent.isInFilter,
                level: childInfo.level - 1,
                horizontalIndex: parent.person.gender == .male ? 0 : 1
            )
            
            // 保存父母的布局信息
            nodeLayoutMap[parent.person.id] = parentInfo
            
            // 添加子女到父母的连接
            connections.append(ConnectionInfo(
                fromId: childInfo.personId,
                toId: parent.person.id,
                type: .parent,
                isInFilter: parent.isInFilter
            ))
            
            // 更新子节点的父母列表
            updatedChildInfo.parents.append(parent.person.id)
        }
        
        // 如果有两个父母，添加他们之间的配偶连接
        if parents.count == 2 {
            let parent1 = parents[0]
            let parent2 = parents[1]
            
            connections.append(ConnectionInfo(
                fromId: parent1.person.id,
                toId: parent2.person.id,
                type: .spouse,
                isInFilter: parent1.isInFilter && parent2.isInFilter
            ))
        }
        
        // 保存更新后的子节点信息
        nodeLayoutMap[childInfo.personId] = updatedChildInfo
    }
    
    // 计算子女布局
    func calculateChildrenLayout(graphData: FamilyGraphData, parentInfo: NodeLayoutInfo) {
        let children = graphData.children
        if children.isEmpty { return }
        
        // 计算子女的垂直位置（比父母低一级）
        let childrenY = parentInfo.position.y - verticalSpacing
        
        // 计算子女的总宽度
        let totalWidth = CGFloat(children.count - 1) * horizontalSpacing
        
        // 计算第一个子女的X坐标（居中排列在父母下方）
        var currentX = parentInfo.position.x - totalWidth / 2
        
        // 更新父节点信息
        var updatedParentInfo = parentInfo
        
        // 布局每个子女
        for (index, child) in children.enumerated() {
            if processedPersons.contains(child.person.id) { continue }
            
            processedPersons.insert(child.person.id)
            
            // 创建子女的布局信息
            let childPosition = CGPoint(x: currentX, y: childrenY)
            let childInfo = NodeLayoutInfo(
                personId: child.person.id,
                position: childPosition,
                isCenter: false,
                isInFilter: child.isInFilter,
                level: parentInfo.level + 1,
                horizontalIndex: index
            )
            
            // 保存子女的布局信息
            nodeLayoutMap[child.person.id] = childInfo
            
            // 添加父母到子女的连接
            connections.append(ConnectionInfo(
                fromId: parentInfo.personId,
                toId: child.person.id,
                type: .child,
                isInFilter: child.isInFilter
            ))
            
            // 更新父节点的子女列表
            updatedParentInfo.children.append(child.person.id)
            
            // 更新X坐标
            currentX += child.isInFilter ? horizontalSpacing : reducedSpacing
        }
        
        // 保存更新后的父节点信息
        nodeLayoutMap[parentInfo.personId] = updatedParentInfo
    }
    
    // 计算兄弟姐妹布局
    func calculateSiblingsLayout(graphData: FamilyGraphData, siblingInfo: NodeLayoutInfo) {
        let siblings = graphData.siblings
        if siblings.isEmpty { return }
        
        // 兄弟姐妹与当前节点在同一水平线上
        let siblingsY = siblingInfo.position.y
        
        // 兄弟姐妹总是放在左侧
        var currentX = siblingInfo.position.x - horizontalSpacing
        
        // 更新当前节点信息
        var updatedSiblingInfo = siblingInfo
        
        // 布局每个兄弟姐妹
        for (index, sibling) in siblings.enumerated() {
            if processedPersons.contains(sibling.person.id) { continue }
            
            processedPersons.insert(sibling.person.id)
            
            // 所有兄弟姐妹都放在左侧，依次向左排列
            let siblingPosition = CGPoint(x: currentX, y: siblingsY)
            
            let siblingNodeInfo = NodeLayoutInfo(
                personId: sibling.person.id,
                position: siblingPosition,
                isCenter: false,
                isInFilter: sibling.isInFilter,
                level: siblingInfo.level,
                horizontalIndex: siblingInfo.horizontalIndex - (index + 1)
            )
            
            // 保存兄弟姐妹的布局信息
            nodeLayoutMap[sibling.person.id] = siblingNodeInfo
            
            // 添加兄弟姐妹连接
            connections.append(ConnectionInfo(
                fromId: siblingInfo.personId,
                toId: sibling.person.id,
                type: .sibling,
                isInFilter: sibling.isInFilter
            ))
            
            // 更新当前节点的兄弟姐妹列表
            updatedSiblingInfo.siblings.append(sibling.person.id)
            
            // 更新水平位置 - 向左移动
            currentX -= sibling.isInFilter ? horizontalSpacing : reducedSpacing
        }
        
        // 保存更新后的当前节点信息
        nodeLayoutMap[siblingInfo.personId] = updatedSiblingInfo
    }
    
    // 直接计算祖父母布局
    func calculateGrandparentsLayout(graphData: FamilyGraphData, grandchildInfo: NodeLayoutInfo) {
        // 获取父母
        let parents = graphData.parents
        if parents.isEmpty { return }
        
        // 遍历每个父母
        for parent in parents {
            // 获取父母的ID
            let parentId = parent.person.id
            
            // 获取父母的子图数据
            let parentSubGraph = parent.subNodes
            
            // 获取祖父母（父母的父母）
            let grandparents = parentSubGraph.parents
            if grandparents.isEmpty { continue }
            
            // 如果父节点不在布局中，跳过
            guard let parentInfo = nodeLayoutMap[parentId] else { continue }
            
            // 计算祖父母的垂直位置（比父母高一级）
            let grandparentsY = parentInfo.position.y + verticalSpacing
            
            // 计算祖父母的水平位置
            var grandfatherX = parentInfo.position.x - horizontalSpacing / 2
            var grandmotherX = parentInfo.position.x + horizontalSpacing / 2
            
            // 布局每个祖父母
            for grandparent in grandparents {
                if processedPersons.contains(grandparent.person.id) { continue }
                
                processedPersons.insert(grandparent.person.id)
                
                // 根据性别确定位置
                let grandparentX = grandparent.person.gender == .male ? grandfatherX : grandmotherX
                let grandparentPosition = CGPoint(x: grandparentX, y: grandparentsY)
                
                let grandparentInfo = NodeLayoutInfo(
                    personId: grandparent.person.id,
                    position: grandparentPosition,
                    isCenter: false,
                    isInFilter: grandparent.isInFilter,
                    level: parentInfo.level - 1,
                    horizontalIndex: grandparent.person.gender == .male ? 0 : 1
                )
                
                // 保存祖父母的布局信息
                nodeLayoutMap[grandparent.person.id] = grandparentInfo
                
                // 添加父节点到祖父母的连接
                connections.append(ConnectionInfo(
                    fromId: parentId,
                    toId: grandparent.person.id,
                    type: .parent,
                    isInFilter: grandparent.isInFilter
                ))
                
                // 更新父节点的父节点列表
                if var updatedParentInfo = nodeLayoutMap[parentId] {
                    updatedParentInfo.parents.append(grandparent.person.id)
                    nodeLayoutMap[parentId] = updatedParentInfo
                }
            }
            
            // 如果有两个祖父母，添加他们之间的配偶连接
            if grandparents.count == 2 {
                let grandparent1 = grandparents[0]
                let grandparent2 = grandparents[1]
                
                connections.append(ConnectionInfo(
                    fromId: grandparent1.person.id,
                    toId: grandparent2.person.id,
                    type: .spouse,
                    isInFilter: grandparent1.isInFilter && grandparent2.isInFilter
                ))
            }
        }
    }
    
    // 直接计算孙子女布局
    func calculateGrandchildrenLayout(graphData: FamilyGraphData, grandparentInfo: NodeLayoutInfo) {
        // 获取子女
        let children = graphData.children
        if children.isEmpty { return }
        
        // 遍历每个子女
        for child in children {
            // 获取子女的ID
            let childId = child.person.id
            
            // 获取子女的子图数据
            let childSubGraph = child.subNodes
            
            // 获取孙子女（子女的子女）
            let grandchildren = childSubGraph.children
            if grandchildren.isEmpty { continue }
            
            // 如果子女节点不在布局中，跳过
            guard let childInfo = nodeLayoutMap[childId] else { continue }
            
            // 计算孙子女的垂直位置（比子女低一级）
            let grandchildrenY = childInfo.position.y - verticalSpacing
            
            // 计算孙子女的总宽度
            let totalWidth = CGFloat(grandchildren.count - 1) * horizontalSpacing
            
            // 计算第一个孙子女的X坐标（居中排列在子女下方）
            var currentX = childInfo.position.x - totalWidth / 2
            
            // 布局每个孙子女
            for (index, grandchild) in grandchildren.enumerated() {
                if processedPersons.contains(grandchild.person.id) { continue }
                
                processedPersons.insert(grandchild.person.id)
                
                // 创建孙子女的布局信息
                let grandchildPosition = CGPoint(x: currentX, y: grandchildrenY)
                let grandchildInfo = NodeLayoutInfo(
                    personId: grandchild.person.id,
                    position: grandchildPosition,
                    isCenter: false,
                    isInFilter: grandchild.isInFilter,
                    level: childInfo.level + 1,
                    horizontalIndex: index
                )
                
                // 保存孙子女的布局信息
                nodeLayoutMap[grandchild.person.id] = grandchildInfo
                
                // 添加子女到孙子女的连接
                connections.append(ConnectionInfo(
                    fromId: childId,
                    toId: grandchild.person.id,
                    type: .child,
                    isInFilter: grandchild.isInFilter
                ))
                
                // 更新子女节点的子女列表
                if var updatedChildInfo = nodeLayoutMap[childId] {
                    updatedChildInfo.children.append(grandchild.person.id)
                    nodeLayoutMap[childId] = updatedChildInfo
                }
                
                // 更新X坐标
                currentX += grandchild.isInFilter ? horizontalSpacing : reducedSpacing
            }
        }
    }
    
    // 直接计算曾祖父母布局
    func calculateGreatGrandparentsLayout(graphData: FamilyGraphData, greatGrandchildInfo: NodeLayoutInfo) {
        // 获取父母
        let parents = graphData.parents
        if parents.isEmpty { return }
        
        // 遍历每个父母
        for parent in parents {
            // 获取父母的子图数据
            let parentSubGraph = parent.subNodes
            
            // 获取祖父母（父母的父母）
            let grandparents = parentSubGraph.parents
            if grandparents.isEmpty { continue }
            
            // 遍历每个祖父母
            for grandparent in grandparents {
                // 获取祖父母的ID
                let grandparentId = grandparent.person.id
                
                // 如果祖父母节点不在布局中，跳过
                guard let grandparentInfo = nodeLayoutMap[grandparentId] else { continue }
                
                // 获取祖父母的子图数据
                let grandparentSubGraph = grandparent.subNodes
                
                // 获取曾祖父母（祖父母的父母）
                let greatGrandparents = grandparentSubGraph.parents
                if greatGrandparents.isEmpty { continue }
                
                // 计算曾祖父母的垂直位置（比祖父母高一级）
                let greatGrandparentsY = grandparentInfo.position.y + verticalSpacing
                
                // 计算曾祖父母的水平位置
                var greatGrandfatherX = grandparentInfo.position.x - horizontalSpacing / 2
                var greatGrandmotherX = grandparentInfo.position.x + horizontalSpacing / 2
                
                // 布局每个曾祖父母
                for greatGrandparent in greatGrandparents {
                    if processedPersons.contains(greatGrandparent.person.id) { continue }
                    
                    processedPersons.insert(greatGrandparent.person.id)
                    
                    // 根据性别确定位置
                    let greatGrandparentX = greatGrandparent.person.gender == .male ? greatGrandfatherX : greatGrandmotherX
                    let greatGrandparentPosition = CGPoint(x: greatGrandparentX, y: greatGrandparentsY)
                    
                    let greatGrandparentInfo = NodeLayoutInfo(
                        personId: greatGrandparent.person.id,
                        position: greatGrandparentPosition,
                        isCenter: false,
                        isInFilter: greatGrandparent.isInFilter,
                        level: grandparentInfo.level - 1,
                        horizontalIndex: greatGrandparent.person.gender == .male ? 0 : 1
                    )
                    
                    // 保存曾祖父母的布局信息
                    nodeLayoutMap[greatGrandparent.person.id] = greatGrandparentInfo
                    
                    // 添加祖父母到曾祖父母的连接
                    connections.append(ConnectionInfo(
                        fromId: grandparentId,
                        toId: greatGrandparent.person.id,
                        type: .parent,
                        isInFilter: greatGrandparent.isInFilter
                    ))
                    
                    // 更新祖父母节点的父节点列表
                    if var updatedGrandparentInfo = nodeLayoutMap[grandparentId] {
                        updatedGrandparentInfo.parents.append(greatGrandparent.person.id)
                        nodeLayoutMap[grandparentId] = updatedGrandparentInfo
                    }
                }
                
                // 如果有两个曾祖父母，添加他们之间的配偶连接
                if greatGrandparents.count == 2 {
                    let greatGrandparent1 = greatGrandparents[0]
                    let greatGrandparent2 = greatGrandparents[1]
                    
                    connections.append(ConnectionInfo(
                        fromId: greatGrandparent1.person.id,
                        toId: greatGrandparent2.person.id,
                        type: .spouse,
                        isInFilter: greatGrandparent1.isInFilter && greatGrandparent2.isInFilter
                    ))
                }
            }
        }
    }
    
    // 直接计算曾孙子女布局
    func calculateGreatGrandchildrenLayout(graphData: FamilyGraphData, greatGrandparentInfo: NodeLayoutInfo) {
        // 获取子女
        let children = graphData.children
        if children.isEmpty { return }
        
        // 遍历每个子女
        for child in children {
            // 获取子女的子图数据
            let childSubGraph = child.subNodes
            
            // 获取孙子女（子女的子女）
            let grandchildren = childSubGraph.children
            if grandchildren.isEmpty { continue }
            
            // 遍历每个孙子女
            for grandchild in grandchildren {
                // 获取孙子女的ID
                let grandchildId = grandchild.person.id
                
                // 如果孙子女节点不在布局中，跳过
                guard let grandchildInfo = nodeLayoutMap[grandchildId] else { continue }
                
                // 获取孙子女的子图数据
                let grandchildSubGraph = grandchild.subNodes
                
                // 获取曾孙子女（孙子女的子女）
                let greatGrandchildren = grandchildSubGraph.children
                if greatGrandchildren.isEmpty { continue }
                
                // 计算曾孙子女的垂直位置（比孙子女低一级）
                let greatGrandchildrenY = grandchildInfo.position.y - verticalSpacing
                
                // 计算曾孙子女的总宽度
                let totalWidth = CGFloat(greatGrandchildren.count - 1) * horizontalSpacing
                
                // 计算第一个曾孙子女的X坐标（居中排列在孙子女下方）
                var currentX = grandchildInfo.position.x - totalWidth / 2
                
                // 布局每个曾孙子女
                for (index, greatGrandchild) in greatGrandchildren.enumerated() {
                    if processedPersons.contains(greatGrandchild.person.id) { continue }
                    
                    processedPersons.insert(greatGrandchild.person.id)
                    
                    // 创建曾孙子女的布局信息
                    let greatGrandchildPosition = CGPoint(x: currentX, y: greatGrandchildrenY)
                    let greatGrandchildInfo = NodeLayoutInfo(
                        personId: greatGrandchild.person.id,
                        position: greatGrandchildPosition,
                        isCenter: false,
                        isInFilter: greatGrandchild.isInFilter,
                        level: grandchildInfo.level + 1,
                        horizontalIndex: index
                    )
                    
                    // 保存曾孙子女的布局信息
                    nodeLayoutMap[greatGrandchild.person.id] = greatGrandchildInfo
                    
                    // 添加孙子女到曾孙子女的连接
                    connections.append(ConnectionInfo(
                        fromId: grandchildId,
                        toId: greatGrandchild.person.id,
                        type: .child,
                        isInFilter: greatGrandchild.isInFilter
                    ))
                    
                    // 更新孙子女节点的子女列表
                    if var updatedGrandchildInfo = nodeLayoutMap[grandchildId] {
                        updatedGrandchildInfo.children.append(greatGrandchild.person.id)
                        nodeLayoutMap[grandchildId] = updatedGrandchildInfo
                    }
                    
                    // 更新X坐标
                    currentX += greatGrandchild.isInFilter ? horizontalSpacing : reducedSpacing
                }
            }
        }
    }
}
