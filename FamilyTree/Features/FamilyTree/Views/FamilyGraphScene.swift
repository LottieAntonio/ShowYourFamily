import SpriteKit
import UIKit  // 添加 UIKit 导入

class FamilyGraphScene: SKScene, UIGestureRecognizerDelegate {  // 添加协议遵循
    private var graphNodes: [UUID: SKNode] = [:]
    private var currentGraphData: FamilyGraphData?
    // 添加一个集合来跟踪已绘制的线条
    private var drawnLines: Set<String> = []
    
    // 添加相机节点
    private var cameraNode: SKCameraNode?
    private var contentNode: SKNode?  // 添加内容节点，所有图谱内容都添加到这个节点上
    
    // 添加初始化视图的方法
    func setupInitialView(with size: CGSize) {
        // 设置场景大小，确保足够大以容纳所有内容
        self.size = CGSize(width: size.width * 2, height: size.height * 2)
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // 创建内容节点
        if contentNode == nil {
            contentNode = SKNode()
            addChild(contentNode!)
        }
        
        // 创建相机节点
        if cameraNode == nil {
            cameraNode = SKCameraNode()
            addChild(cameraNode!)
            self.camera = cameraNode
        }
        
        // 设置相机初始位置 - 调整为考虑底部标签栏
        cameraNode?.position = CGPoint(x: 0, y: 0)
        
        // 设置初始缩放
        cameraNode?.setScale(1.0)
        
        // 确保背景是白色
        self.backgroundColor = .white
        
    }
 
    // 处理平移手势
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let camera = cameraNode else { return }
        
        if gesture.state == .changed {
            let translation = gesture.translation(in: gesture.view)
            let dx = translation.x * camera.xScale
            let dy = translation.y * camera.xScale
            
            // 使用 CATransaction 禁用隐式动画
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            camera.position = CGPoint(
                x: camera.position.x - dx,
                y: camera.position.y + dy
            )
            
            CATransaction.commit()
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
    }
    
    // 处理缩放手势
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let camera = cameraNode else { return }
        
        if gesture.state == .changed {
            let scale = 1.0 / gesture.scale
            let newScale = camera.xScale * scale
            let constrainedScale = min(max(newScale, 0.3), 2.0)
            
            // 使用 CATransaction 禁用隐式动画
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            camera.setScale(constrainedScale)
            
            CATransaction.commit()
            
            gesture.scale = 1.0
            
        }
    }
    
    
    override func didMove(to view: SKView) {
        // 基本设置
        backgroundColor = .white
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // 设置场景大小
        let viewSize = view.bounds.size
        self.size = CGSize(width: viewSize.width * 2, height: viewSize.height * 2)
        
        // 创建内容节点（如果还没有）
        if contentNode == nil {
            contentNode = SKNode()
            addChild(contentNode!)
        }
        
        // 创建和配置相机（如果还没有）
        if cameraNode == nil {
            cameraNode = SKCameraNode()
            camera = cameraNode
            addChild(cameraNode!)
            
            // 设置相机初始位置和缩放
            cameraNode?.position = .zero
            cameraNode?.setScale(1.0)
        }
        
        // 视图设置 - 确保这些设置正确
        self.isUserInteractionEnabled = true
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        
        // 设置手势识别器
        setupGestureRecognizers(for: view)
        
        // 如果有保存的数据，更新图谱
        if let savedGraphData = currentGraphData {
            updateGraph(with: savedGraphData)
        }
        
    }
    
   
    // 修改 updateGraph 方法，支持类似 FamilyTreeView 的布局
    // 添加一个属性来存储所有已处理的人物ID
    private var processedPersons: Set<UUID> = []
    
    // 修改 updateGraph 方法，支持显示完整家族关系
        // 修改 updateGraph 方法，支持显示完整家族关系
    // 修改 updateGraph 方法，添加自动调整视图的功能
    // 修改 updateGraph 方法，优化初始缩放和视图调整
    func updateGraph(with graphData: FamilyGraphData?) {
        guard let graphData = graphData else { return }
        
        // 清除现有节点
        contentNode?.removeAllChildren()
        graphNodes.removeAll()
        drawnLines.removeAll() // 清除已绘制线条的记录
        processedPersons.removeAll() // 清除已处理人物记录
        
        // 保存当前图谱数据
        currentGraphData = graphData
        
        // 创建中心人物节点
        let rootNode = createPersonNode(for: graphData.centerPerson, isCenter: true)
        rootNode.position = CGPoint(x: 0, y: 0)  // 将中心人物放在中心位置
        contentNode?.addChild(rootNode)
        graphNodes[graphData.centerPerson.id] = rootNode
        
        // 标记中心人物为已处理
        processedPersons.insert(graphData.centerPerson.id)
        
        // 递归处理所有家族关系
        processAllFamilyRelationships(graphData: graphData, centerNode: rootNode)
        
        // 确保相机位置重置
        cameraNode?.position = .zero
        cameraNode?.setScale(0.4)  // 使用更小的初始缩放值，显示更多内容
        
        // 添加：自动调整视图以显示所有节点，延迟稍微长一点，确保所有节点都已创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.adjustCameraToShowAllNodes()
        }
        
    }
    
    // 优化调整相机方法，确保所有节点都可见
    private func adjustCameraToShowAllNodes() {
        guard let contentNode = contentNode, !graphNodes.isEmpty else { return }
        
        // 计算所有节点的边界
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        
        for (_, node) in graphNodes {
            let position = node.position
            minX = min(minX, position.x)
            maxX = max(maxX, position.x)
            minY = min(minY, position.y)
            maxY = max(maxY, position.y)
        }
        
        // 添加更大的边距，确保名字标签也能显示
        let padding: CGFloat = 150
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        
        // 计算中心点和所需的缩放
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // 计算所需的缩放比例
        let width = maxX - minX
        let height = maxY - minY
        let sceneSize = self.size
        let scaleX = sceneSize.width / width
        let scaleY = sceneSize.height / height
        let scale = min(min(scaleX, scaleY), 1.0) * 0.7 // 限制最大缩放并留出更多空间
        
        // 应用相机变换
        guard let camera = cameraNode else { return }
        let moveAction = SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.8)
        let scaleAction = SKAction.scale(to: scale, duration: 0.8)
        
        camera.run(SKAction.group([moveAction, scaleAction]))
        
    }

        // 处理所有家族关系的递归方法
    // 修改 processAllFamilyRelationships 方法，确保正确递归处理所有关系
    private func processAllFamilyRelationships(graphData: FamilyGraphData, centerNode: SKNode) {
        // 处理配偶关系
        processSpouses(graphData: graphData, centerNode: centerNode)
        
        // 处理子女关系
        processChildren(graphData: graphData, centerNode: centerNode)
        
        // 处理父母关系
        processParents(graphData: graphData, centerNode: centerNode)
        
        // 处理兄弟姐妹关系
        processSiblings(graphData: graphData, centerNode: centerNode)
    }

        // 处理配偶关系
    // 修改处理配偶关系的方法，减小间距
    private func processSpouses(graphData: FamilyGraphData, centerNode: SKNode) {
        let spouses = graphData.spouses
        
        // 配偶位置（右侧），减小间距
        var currentSpouseX = centerNode.position.x + 100  // 从120改为100
        
        for spouse in spouses {
            // 如果配偶已经处理过，跳过
            if processedPersons.contains(spouse.person.id) {
                continue
            }
            
            // 标记配偶为已处理
            processedPersons.insert(spouse.person.id)
            
            let spouseNode = createPersonNode(for: spouse.person, isCenter: false)
            spouseNode.position = CGPoint(x: currentSpouseX, y: centerNode.position.y)
            contentNode?.addChild(spouseNode)
            graphNodes[spouse.person.id] = spouseNode
            
            // 绘制连接线
            drawHorizontalLine(from: centerNode.position, to: spouseNode.position, color: .systemPink)
            
            // 更新X坐标
            currentSpouseX += 100  // 从120改为100
            
            // 递归处理配偶的关系
            processAllFamilyRelationships(graphData: spouse.subNodes, centerNode: spouseNode)
        }
    }
    
    // 修改处理子女关系的方法，减小间距
    private func processChildren(graphData: FamilyGraphData, centerNode: SKNode) {
        let children = graphData.children
        
        if children.isEmpty {
            return
        }
        
        // 过滤出未处理的子女
        let unprocessedChildren = children.filter { !processedPersons.contains($0.person.id) }
        
        if unprocessedChildren.isEmpty {
            return
        }
        
        // 子女位置（下方），减小垂直间距
        let childY = centerNode.position.y - 120  // 从150改为120
        
        // 计算子女的总宽度，减小水平间距
        let totalWidth = CGFloat(unprocessedChildren.count - 1) * 100  // 从120改为100
        let startX = centerNode.position.x - totalWidth / 2
        
        // 绘制从父母到子女的连接线
        if unprocessedChildren.count > 0 {
            // 从中心点画一条垂直线
            let midY = (centerNode.position.y + childY) / 2
            drawLine(
                from: CGPoint(x: centerNode.position.x, y: centerNode.position.y),
                to: CGPoint(x: centerNode.position.x, y: midY),
                color: .systemGreen
            )
            
            // 如果有多个子女，画一条水平线连接所有子女
            if unprocessedChildren.count > 1 {
                let firstChildX = startX
                let lastChildX = startX + totalWidth
                drawLine(
                    from: CGPoint(x: firstChildX, y: midY),
                    to: CGPoint(x: lastChildX, y: midY),
                    color: .systemGreen
                )
                
                // 为每个子女位置添加垂直连接线
                for i in 0..<unprocessedChildren.count {
                    let childX = startX + CGFloat(i) * 100  // 从120改为100
                    drawLine(
                        from: CGPoint(x: childX, y: midY),
                        to: CGPoint(x: childX, y: childY),
                        color: .systemGreen
                    )
                }
            } else {
                // 只有一个子女时，直接连接到子女位置
                drawLine(
                    from: CGPoint(x: centerNode.position.x, y: midY),
                    to: CGPoint(x: centerNode.position.x, y: childY),
                    color: .systemGreen
                )
            }
        }
        
        // 绘制子女节点
        for (index, child) in unprocessedChildren.enumerated() {
            let childX = startX + CGFloat(index) * 100  // 从120改为100
            let childPosition = CGPoint(x: childX, y: childY)
            
            // 标记子女为已处理
            processedPersons.insert(child.person.id)
            
            let childNode = createPersonNode(for: child.person, isCenter: false)
            childNode.position = childPosition
            contentNode?.addChild(childNode)
            graphNodes[child.person.id] = childNode
            
            // 重要修改：递归处理子女的关系，确保子女的子女也能显示
            if !child.subNodes.children.isEmpty || !child.subNodes.spouses.isEmpty {
                processAllFamilyRelationships(graphData: child.subNodes, centerNode: childNode)
            }
        }
    }

        // 处理父母关系
    private func processParents(graphData: FamilyGraphData, centerNode: SKNode) {
        // 过滤出未处理的父母
        let unprocessedParents = graphData.parents.filter { !processedPersons.contains($0.person.id) }
        
        if unprocessedParents.isEmpty {
            return
        }
        
        let parentLevelY = centerNode.position.y + 120  // 父母在上方
        let totalParentWidth = CGFloat(unprocessedParents.count - 1) * 100  // 从120改为100
        let startParentX = centerNode.position.x - totalParentWidth / 2
        
        // 绘制从子女到父母的连接线
        if unprocessedParents.count > 0 {
            // 从子女中心点画一条垂直线
            let midY = (centerNode.position.y + parentLevelY) / 2
            drawLine(
                from: CGPoint(x: centerNode.position.x, y: centerNode.position.y),
                to: CGPoint(x: centerNode.position.x, y: midY),
                color: .systemBlue
            )
            
            // 如果有多个父母，画一条水平线连接所有父母
            if unprocessedParents.count > 1 {
                let firstParentX = startParentX
                let lastParentX = startParentX + totalParentWidth
                drawLine(
                    from: CGPoint(x: firstParentX, y: midY),
                    to: CGPoint(x: lastParentX, y: midY),
                    color: .systemBlue
                )
                
                // 为每个父母位置添加垂直连接线
                for i in 0..<unprocessedParents.count {
                    let parentX = startParentX + CGFloat(i) * 100  // 从120改为100
                    drawLine(
                        from: CGPoint(x: parentX, y: midY),
                        to: CGPoint(x: parentX, y: parentLevelY),
                        color: .systemBlue
                    )
                }
            } else {
                // 只有一个父母时，直接连接到父母位置
                drawLine(
                    from: CGPoint(x: centerNode.position.x, y: midY),
                    to: CGPoint(x: centerNode.position.x, y: parentLevelY),
                    color: .systemBlue
                )
            }
        }
        
        // 绘制父母节点
        for (index, parent) in unprocessedParents.enumerated() {
            let parentX = startParentX + CGFloat(index) * 100  // 从120改为100
            let parentPosition = CGPoint(x: parentX, y: parentLevelY)
            
            // 标记父母为已处理
            processedPersons.insert(parent.person.id)
            
            let parentNode = createPersonNode(for: parent.person, isCenter: false)
            parentNode.position = parentPosition
            contentNode?.addChild(parentNode)
            graphNodes[parent.person.id] = parentNode
            
            // 递归处理父母的关系
            processAllFamilyRelationships(graphData: parent.subNodes, centerNode: parentNode)
        }
    }

        // 处理兄弟姐妹关系
    private func processSiblings(graphData: FamilyGraphData, centerNode: SKNode) {
        // 过滤出未处理的兄弟姐妹
        let unprocessedSiblings = graphData.siblings.filter { !processedPersons.contains($0.person.id) }
        
        if unprocessedSiblings.isEmpty {
            return
        }
        
        // 兄弟姐妹位置（同一水平线，左右分布）
        let siblingY = centerNode.position.y
        var leftSiblingX = centerNode.position.x - 100
        var rightSiblingX = centerNode.position.x + 100
        
        for (index, sibling) in unprocessedSiblings.enumerated() {
            // 标记兄弟姐妹为已处理
            processedPersons.insert(sibling.person.id)
            
            let siblingNode = createPersonNode(for: sibling.person, isCenter: false)
            
            // 左右交替放置兄弟姐妹
            if index % 2 == 0 {
                siblingNode.position = CGPoint(x: leftSiblingX, y: siblingY)
                leftSiblingX -= 100
            } else {
                siblingNode.position = CGPoint(x: rightSiblingX, y: siblingY)
                rightSiblingX += 100
            }
            
            contentNode?.addChild(siblingNode)
            graphNodes[sibling.person.id] = siblingNode
            
            // 绘制连接线
            drawDashedLine(from: centerNode.position, to: siblingNode.position, color: .systemGray)
            
            // 递归处理兄弟姐妹的关系
            processAllFamilyRelationships(graphData: sibling.subNodes, centerNode: siblingNode)
        }
    }
    
    // 改进人物节点的创建方法，使其更美观
    private func createPersonNode(for person: Person, isCenter: Bool) -> SKNode {
        let container = SKNode()
        container.name = person.id.uuidString
        
        // 创建圆形背景
        let radius: CGFloat = isCenter ? 40 : 30
        let circle = SKShapeNode(circleOfRadius: radius)
        
        // 根据性别设置不同的颜色
        if isCenter {
            circle.fillColor = .systemBlue.withAlphaComponent(0.2)
            circle.strokeColor = .systemBlue
        } else if person.gender == .male {
            circle.fillColor = .systemBlue.withAlphaComponent(0.1)
            circle.strokeColor = .systemBlue
        } else if person.gender == .female {
            circle.fillColor = .systemPink.withAlphaComponent(0.1)
            circle.strokeColor = .systemPink
        } else {
            circle.fillColor = .white
            circle.strokeColor = .gray
        }
        
        circle.lineWidth = 2
        container.addChild(circle)
        
        // 创建名字标签
        let nameLabel = SKLabelNode(text: person.name)
        nameLabel.fontSize = 14
        nameLabel.fontName = "PingFangSC-Regular"
        nameLabel.fontColor = .black
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -(radius + 15))
        container.addChild(nameLabel)
        
        // 添加点击检测区域
        let touchArea = SKShapeNode(circleOfRadius: radius + 10)
        touchArea.fillColor = .clear
        touchArea.strokeColor = .clear
        touchArea.name = "touchArea-\(person.id.uuidString)"
        container.addChild(touchArea)
        
        return container
    }

        // 绘制虚线方法
    private func drawDashedLine(from: CGPoint, to: CGPoint, color: SKColor) {
        // 创建唯一标识符
        let lineId = createLineId(from: from, to: to)
        
        // 检查是否已经绘制过这条线
        if drawnLines.contains(lineId) {
            return
        }
        
        // 记录这条线已经绘制
        drawnLines.insert(lineId)
        
        let dashLength: CGFloat = 8
        let gapLength: CGFloat = 4
        
        // 计算线段总长度
        let dx = to.x - from.x
        let dy = to.y - from.y
        let lineLength = sqrt(dx * dx + dy * dy)
        
        // 计算单位向量
        let unitX = dx / lineLength
        let unitY = dy / lineLength
        
        var currentPoint = from
        var remainingLength = lineLength
        var isDash = true
        
        while remainingLength > 0 {
            let segmentLength = min(isDash ? dashLength : gapLength, remainingLength)
            
            if isDash {
                let path = CGMutablePath()
                let endPoint = CGPoint(
                    x: currentPoint.x + unitX * segmentLength,
                    y: currentPoint.y + unitY * segmentLength
                )
                
                path.move(to: currentPoint)
                path.addLine(to: endPoint)
                
                let line = SKShapeNode(path: path)
                line.strokeColor = color
                line.lineWidth = 2
                contentNode?.addChild(line)
            }
            
            // 更新当前点位置
            currentPoint = CGPoint(
                x: currentPoint.x + unitX * segmentLength,
                y: currentPoint.y + unitY * segmentLength
            )
            
            remainingLength -= segmentLength
            isDash.toggle()
        }
    }

        // 添加节点点击功能
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 将触摸位置转换为内容节点的坐标系
        let locationInContent = contentNode?.convert(location, from: self) ?? location
        
        // 检查是否点击了人物节点
        if let touchedNode = contentNode?.nodes(at: locationInContent).first(where: { node in
            // 检查节点是否有名称（UUID字符串）
            return node.name != nil && UUID(uuidString: node.name ?? "") != nil
        }) {
            // 找到对应的人物ID
            if let nodeId = touchedNode.name, let personId = UUID(uuidString: nodeId) {
                // 触发点击事件
                handleNodeTapped(personId: personId)
            }
        }
    }
    
    // 处理节点点击事件
    private func handleNodeTapped(personId: UUID) {
        // 通知外部处理点击事件
        NotificationCenter.default.post(
            name: NSNotification.Name("PersonNodeTapped"),
            object: nil,
            userInfo: ["personId": personId]
        )
    }

        // 在 setupGestureRecognizers 方法中添加双击手势
    func setupGestureRecognizers(for view: SKView) {
        // 移除可能存在的旧手势识别器
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
        
        // 创建平移手势识别器
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        // 创建缩放手势识别器
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        
        // 添加双击手势用于重置视图
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        view.addGestureRecognizer(doubleTapGesture)
    }
    
    // 处理双击手势
    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        // 双击重置视图
        guard let camera = cameraNode else { return }
        
        let resetAction = SKAction.group([
            SKAction.moveTo(x: 0, duration: 0.3),
            SKAction.moveTo(y: 0, duration: 0.3),
            SKAction.scale(to: 0.8, duration: 0.3)
        ])
        
        camera.run(resetAction)
    }
    
    // 添加 UIGestureRecognizerDelegate 方法
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许同时识别多个手势
        return true
    }
    
    // 添加这个公共方法，用于从 SwiftUI 视图中控制相机缩放
    func scaleCamera(to scale: CGFloat) {
        guard let camera = cameraNode else { return }
        
        // 使用 CATransaction 禁用隐式动画，减少闪烁
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        camera.setScale(scale)
        CATransaction.commit()
        
    }

    // 创建线条唯一标识符的方法
    private func createLineId(from: CGPoint, to: CGPoint) -> String {
        // 确保线条ID不受点的顺序影响
        let sortedPoints = [from, to].sorted { p1, p2 in
            if p1.x == p2.x {
                return p1.y < p2.y
            }
            return p1.x < p2.x
        }
        
        return "\(sortedPoints[0].x),\(sortedPoints[0].y)-\(sortedPoints[1].x),\(sortedPoints[1].y)"
    }
    
    // 绘制普通线条的方法
    private func drawLine(from: CGPoint, to: CGPoint, color: SKColor) {
        // 创建唯一标识符
        let lineId = createLineId(from: from, to: to)
        
        // 检查是否已经绘制过这条线
        if drawnLines.contains(lineId) {
            return
        }
        
        // 记录这条线已经绘制
        drawnLines.insert(lineId)
        
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 2
        contentNode?.addChild(line)
    }
    
    // 绘制水平线条的方法
    private func drawHorizontalLine(from: CGPoint, to: CGPoint, color: SKColor) {
        // 创建唯一标识符
        let lineId = createLineId(from: from, to: to)
        
        // 检查是否已经绘制过这条线
        if drawnLines.contains(lineId) {
            return
        }
        
        // 记录这条线已经绘制
        drawnLines.insert(lineId)
        
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 2
        
        // 添加装饰，表示婚姻关系
        let heartNode = SKShapeNode(circleOfRadius: 5)
        heartNode.fillColor = color
        heartNode.strokeColor = color
        heartNode.position = CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
        
        contentNode?.addChild(line)
        contentNode?.addChild(heartNode)
    }
}




extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - x
        let dy = point.y - y
        return sqrt(dx * dx + dy * dy)
    }
}




