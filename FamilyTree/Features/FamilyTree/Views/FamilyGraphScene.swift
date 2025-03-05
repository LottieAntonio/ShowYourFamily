import SpriteKit
import UIKit  // 添加 UIKit 导入

class FamilyGraphScene: SKScene, UIGestureRecognizerDelegate {  // 添加协议遵循
    private var graphNodes: [UUID: SKNode] = [:]
    private var currentGraphData: FamilyGraphData?
    
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
        
        print("初始视图设置完成，相机位置: \(String(describing: cameraNode?.position)), 缩放: \(String(describing: cameraNode?.xScale))")
    }

      // 设置手势识别器
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
            
            print("相机缩放设置为: \(constrainedScale)")
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
        
        print("Scene setup completed - Size: \(self.size)")
    }
  
    // 修改 updateGraph 方法，确保节点添加到 contentNode
    func updateGraph(with graphData: FamilyGraphData?) {
        guard let graphData = graphData else { return }
        
        // 保存当前图谱数据
        self.currentGraphData = graphData
        
        // 清除现有节点
        contentNode?.removeAllChildren()
        graphNodes.removeAll()
        
        // 创建并添加新节点
        let rootNode = createPersonNode(for: graphData.centerPerson, isCenter: true)
        rootNode.position = .zero  // 确保中心节点在原点
        contentNode?.addChild(rootNode)
        graphNodes[graphData.centerPerson.id] = rootNode
        
        // 添加关系连线和其他节点
        addRelationships(for: graphData, centerNode: rootNode)
        
        // 确保相机位置重置
        cameraNode?.position = .zero
        cameraNode?.setScale(0.8)  // 稍微缩小一点，以便看到更多内容
        
        print("图谱更新完成，中心人物: \(graphData.centerPerson.name)")
    }
    
    private func addRelationships(for graphData: FamilyGraphData, centerNode: SKNode) {
        // 添加世代背景（可选）
        // addGenerationBackground(for: graphData)
        
        // 递归添加所有关系节点
        addRelationshipsRecursively(
            graphData: graphData,
            centerNode: centerNode,
            level: 0,
            maxDepth: 3,  // 限制递归深度
            processedNodes: &graphNodes
        )
    }
        
    
    private func addRelationshipsRecursively(
        graphData: FamilyGraphData,
        centerNode: SKNode,
        level: Int,
        maxDepth: Int,
        processedNodes: inout [UUID: SKNode],
        basePosition: CGPoint = .zero
    ) {
        if level >= maxDepth { return }
        
        // 调整间距参数
        let horizontalSpacing: CGFloat = 200  // 水平间距
        let verticalSpacing: CGFloat = 180    // 垂直间距
        let spouseSpacing: CGFloat = 120      // 配偶间距
        
        let currentLevelY = basePosition.y
        let parentLevelY = currentLevelY + verticalSpacing
        let childLevelY = currentLevelY - verticalSpacing
        
        // ===== 处理父母节点 =====
        if !graphData.parents.isEmpty {
            // 计算父母总宽度
            let totalParentWidth = CGFloat(graphData.parents.count - 1) * horizontalSpacing
            let startParentX = basePosition.x - totalParentWidth / 2
            
            // 从中心点画竖线到父母连接线
            let midParentY = (currentLevelY + parentLevelY) / 2
            drawLine(
                from: CGPoint(x: basePosition.x, y: currentLevelY),
                to: CGPoint(x: basePosition.x, y: midParentY),
                color: .systemGreen
            )
            
            // 如果有多个父母，画横线连接
            if graphData.parents.count > 1 {
                drawLine(
                    from: CGPoint(x: startParentX, y: midParentY),
                    to: CGPoint(x: startParentX + totalParentWidth, y: midParentY),
                    color: .systemGreen
                )
            }
            
            // 为每个父母位置添加竖线
            for i in 0..<graphData.parents.count {
                let parentX = startParentX + CGFloat(i) * horizontalSpacing
                drawLine(
                    from: CGPoint(x: parentX, y: midParentY),
                    to: CGPoint(x: parentX, y: parentLevelY),
                    color: .systemGreen
                )
            }
            
            // 创建并添加所有父母节点
            for (index, parent) in graphData.parents.enumerated() {
                let parentNode = processedNodes[parent.person.id] ?? {
                    let node = createPersonNode(for: parent.person, isCenter: false)
                    let parentX = startParentX + CGFloat(index) * horizontalSpacing
                    let parentPosition = CGPoint(x: parentX, y: parentLevelY)
                    node.position = parentPosition
                    contentNode?.addChild(node)
                    processedNodes[parent.person.id] = node
                    
                    // 如果是相邻的父母，绘制配偶连线
                    if index < graphData.parents.count - 1 {
                        let nextParent = graphData.parents[index + 1]
                        if (parent.relationType == .father && nextParent.relationType == .mother) ||
                           (parent.relationType == .mother && nextParent.relationType == .father) {
                            let nextParentX = startParentX + CGFloat(index + 1) * horizontalSpacing
                            drawHorizontalLine(
                                from: parentPosition,
                                to: CGPoint(x: nextParentX, y: parentLevelY),
                                color: .systemPink
                            )
                        }
                    }
                    
                    return node
                }()
                
                // 递归处理父母的父母
                addRelationshipsRecursively(
                    graphData: parent.subNodes,
                    centerNode: parentNode,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedNodes: &processedNodes,
                    basePosition: parentNode.position
                )
            }
        }
        
        // ===== 处理兄弟姐妹节点 =====
        if !graphData.siblings.isEmpty {
            // 计算兄弟姐妹总宽度
            let totalSiblingWidth = CGFloat(graphData.siblings.count - 1) * horizontalSpacing
            let startSiblingX = basePosition.x - totalSiblingWidth / 2
            
            // 创建并添加所有兄弟姐妹节点
            for (index, sibling) in graphData.siblings.enumerated() {
                // 跳过自己
                if sibling.person.id == graphData.centerPerson.id { continue }
                
                let siblingNode = processedNodes[sibling.person.id] ?? {
                    let node = createPersonNode(for: sibling.person, isCenter: false)
                    let siblingX = startSiblingX + CGFloat(index) * horizontalSpacing
                    let siblingPosition = CGPoint(x: siblingX, y: currentLevelY)
                    node.position = siblingPosition
                    contentNode?.addChild(node)
                    processedNodes[sibling.person.id] = node
                    return node
                }()
                
                // 递归处理兄弟姐妹的关系
                addRelationshipsRecursively(
                    graphData: sibling.subNodes,
                    centerNode: siblingNode,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedNodes: &processedNodes,
                    basePosition: siblingNode.position
                )
            }
        }
        
        // ===== 处理配偶节点 =====
        var spouseNode: SKNode? = nil
        if let spouse = graphData.spouses.first {
            spouseNode = processedNodes[spouse.person.id] ?? {
                let node = createPersonNode(for: spouse.person, isCenter: false)
                let spousePosition = CGPoint(
                    x: basePosition.x + spouseSpacing,
                    y: basePosition.y
                )
                node.position = spousePosition
                contentNode?.addChild(node)
                drawHorizontalLine(from: centerNode.position, to: spousePosition, color: .systemPink)
                processedNodes[spouse.person.id] = node
                return node
            }()
            
            // 递归处理配偶的关系
            addRelationshipsRecursively(
                graphData: spouse.subNodes,
                centerNode: spouseNode!,
                level: level + 1,
                maxDepth: maxDepth,
                processedNodes: &processedNodes,
                basePosition: spouseNode!.position
            )
        }
        
        // ===== 处理子女节点 =====
        if !graphData.children.isEmpty {
            // 计算父母中间点（如果有配偶，则取中心人物和配偶的中点）
            let parentsCenterX = spouseNode.map { (centerNode.position.x + $0.position.x) / 2 } ?? centerNode.position.x
            
            // 计算子女布局
            let totalChildrenWidth = CGFloat(graphData.children.count - 1) * horizontalSpacing
            let startChildX = parentsCenterX - totalChildrenWidth / 2
            
            // 从父母中点画竖线到子女连接线
            let midChildY = (currentLevelY + childLevelY) / 2
            drawLine(
                from: CGPoint(x: parentsCenterX, y: currentLevelY),
                to: CGPoint(x: parentsCenterX, y: midChildY),
                color: .systemGreen
            )
            
            // 如果有多个子女，画横线连接
            if graphData.children.count > 1 {
                drawLine(
                    from: CGPoint(x: startChildX, y: midChildY),
                    to: CGPoint(x: startChildX + totalChildrenWidth, y: midChildY),
                    color: .systemGreen
                )
            }
            
            // 为每个子女位置添加竖线
            for i in 0..<graphData.children.count {
                let childX = startChildX + CGFloat(i) * horizontalSpacing
                drawLine(
                    from: CGPoint(x: childX, y: midChildY),
                    to: CGPoint(x: childX, y: childLevelY),
                    color: .systemGreen
                )
            }
            
            // 创建并添加所有子女节点
            for (index, child) in graphData.children.enumerated() {
                let childNode = processedNodes[child.person.id] ?? {
                    let node = createPersonNode(for: child.person, isCenter: false)
                    let childX = startChildX + CGFloat(index) * horizontalSpacing
                    let childPosition = CGPoint(x: childX, y: childLevelY)
                    node.position = childPosition
                    contentNode?.addChild(node)
                    processedNodes[child.person.id] = node
                    return node
                }()
                
                // 递归处理子女的关系
                addRelationshipsRecursively(
                    graphData: child.subNodes,
                    centerNode: childNode,
                    level: level + 1,
                    maxDepth: maxDepth,
                    processedNodes: &processedNodes,
                    basePosition: childNode.position
                )
            }
        }
    }
    
    private func addGenerationBackground(for graphData: FamilyGraphData) {
        // 递归计算所有世代
        var activeGenerations = Set<Int>()
        calculateGenerations(graphData: graphData, level: 0, generations: &activeGenerations)
        
        // 为每个世代创建背景
        for generation in activeGenerations.sorted() {
            let background = SKShapeNode(rectOf: CGSize(width: 800, height: 120))
            let alpha: CGFloat = generation == 0 ? 0.6 : 0.4
            background.fillColor = UIColor(red: 0.3, green: 0.2, blue: 0.4, alpha: alpha)
            background.strokeColor = .clear
            background.position = CGPoint(x: 0, y: -CGFloat(generation) * 150)  // 注意这里是负数
            background.zPosition = -1
            contentNode?.addChild(background)  // 修改这里
            
            // 添加世代标签
            let label = SKLabelNode(text: "世代 \(abs(generation))")
            label.fontSize = 14
            label.fontName = "PingFangSC-Regular"
            label.fontColor = .white
            label.position = CGPoint(x: -350, y: -CGFloat(generation) * 150)
            contentNode?.addChild(label)  // 修改这里
        }
    }
    
    private func calculateGenerations(graphData: FamilyGraphData, level: Int, generations: inout Set<Int>) {
        generations.insert(level)
        
        // 递归处理所有关系 - 修改这里，直接访问 subNodes
        for parent in graphData.parents {
            calculateGenerations(graphData: parent.subNodes, level: level - 1, generations: &generations)
        }
        
        for child in graphData.children {
            calculateGenerations(graphData: child.subNodes, level: level + 1, generations: &generations)
        }
    }
    
    // 修改所有绘图方法，确保一致添加到 contentNode
    private func drawLine(from: CGPoint, to: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 2
        contentNode?.addChild(line)  // 修改为添加到 contentNode
    }
    
    private func drawHorizontalLine(from: CGPoint, to: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 2
        line.zPosition = -0.5
        
        // 添加装饰点
        let dotRadius: CGFloat = 2
        let dotCount = 10
        let totalLength = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let spacing = totalLength / CGFloat(dotCount)
        
        for i in 0...dotCount {
            let dot = SKShapeNode(circleOfRadius: dotRadius)
            let progress = CGFloat(i) / CGFloat(dotCount)
            dot.position = CGPoint(
                x: from.x + (to.x - from.x) * progress,
                y: from.y + (to.y - from.y) * progress
            )
            dot.fillColor = color
            dot.strokeColor = color
            dot.zPosition = -0.4
            contentNode?.addChild(dot)
        }
        
        contentNode?.addChild(line)
    }
    
    private func drawCurvedLine(from: CGPoint, to: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        let controlPoint = CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
        
        path.move(to: from)
        path.addQuadCurve(to: to, control: controlPoint)
        
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 2
        line.zPosition = -0.5
        contentNode?.addChild(line)  // 修改为添加到 contentNode
    }
    
    private func drawDashedLine(from: CGPoint, to: CGPoint, color: SKColor) {
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
                contentNode?.addChild(line)  // 修改为添加到 contentNode
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
        
        print("相机缩放设置为: \(scale)")
    }

    private func createPersonNode(for person: Person, isCenter: Bool, isSmaller: Bool = false) -> SKNode {
        let container = SKNode()
        container.name = person.id.uuidString
        
        // 创建圆形背景
        let radius: CGFloat = isCenter ? 40 : 30
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = isCenter ? .systemBlue.withAlphaComponent(0.2) : .white
        circle.strokeColor = isCenter ? .systemBlue : .gray
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
        
        return container
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - x
        let dy = point.y - y
        return sqrt(dx * dx + dy * dy)
    }
}


