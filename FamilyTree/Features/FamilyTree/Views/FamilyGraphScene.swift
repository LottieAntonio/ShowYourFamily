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
        contentNode?.addChild(rootNode)  // 确保添加到 contentNode 而不是 self
        
        // 添加关系连线和其他节点
        addRelationships(for: graphData, centerNode: rootNode)
        
        // 确保相机位置重置
        cameraNode?.position = .zero
        
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
        
    
    // 修改 addRelationshipsRecursively 方法中的子女节点创建部分
    // 修复 addRelationshipsRecursively 方法中的节点添加
    private func addRelationshipsRecursively(
        graphData: FamilyGraphData,
        centerNode: SKNode,
        level: Int,
        maxDepth: Int,
        processedNodes: inout [UUID: SKNode],
        basePosition: CGPoint = .zero
    ) {
        if level >= maxDepth { return }
        
        // 动态计算间距
        let baseSpacing: CGFloat = 200
        let spouseSpacing: CGFloat = 100
        let verticalSpacing: CGFloat = 150
        
        let siblingSpacing: CGFloat = max(
            baseSpacing / CGFloat(max(1, graphData.children.count)),
            spouseSpacing * 2.5
        )
        
        let currentLevelY = basePosition.y
        let nextLevelY = currentLevelY - verticalSpacing
        let midLevelY = (currentLevelY + nextLevelY) / 2
        
        // 处理配偶节点
        var spouseNode: SKNode? = nil
        if let spouse = graphData.spouses.first {
            spouseNode = processedNodes[spouse.person.id] ?? {
                let node = createPersonNode(for: spouse.person, isCenter: false)
                let spousePosition = CGPoint(
                    x: basePosition.x + spouseSpacing,
                    y: basePosition.y
                )
                node.position = spousePosition
                contentNode?.addChild(node)  // 修改为添加到 contentNode
                drawHorizontalLine(from: centerNode.position, to: spousePosition, color: .systemPink)
                processedNodes[spouse.person.id] = node
                return node
            }()
        }
        
        // 处理子女节点
        if !graphData.children.isEmpty {
            // 计算父母中间点
            let parentsCenterX = spouseNode.map { (centerNode.position.x + $0.position.x) / 2 } ?? centerNode.position.x
            
            // 计算子女布局
            let totalWidth = CGFloat(graphData.children.count - 1) * siblingSpacing
            let startX = parentsCenterX - totalWidth / 2
            
            // 从父母中点画竖线
            drawLine(
                from: CGPoint(x: parentsCenterX, y: currentLevelY),
                to: CGPoint(x: parentsCenterX, y: midLevelY),
                color: .systemGreen
            )
            
            // 如果有多个子女，画横线
            if graphData.children.count > 1 {
                drawLine(
                    from: CGPoint(x: startX, y: midLevelY),
                    to: CGPoint(x: startX + totalWidth, y: midLevelY),
                    color: .systemGreen
                )
                
                // 为每个子女位置添加竖线连接
                for i in 0..<graphData.children.count {
                    let childX = startX + CGFloat(i) * siblingSpacing  // 使用 siblingSpacing 替换 horizontalSpacing
                    drawLine(
                        from: CGPoint(x: childX, y: midLevelY),
                        to: CGPoint(x: childX, y: nextLevelY),
                        color: .systemGreen
                    )
                }
            } else {
                // 单个子女时也需要画竖线
                drawLine(
                    from: CGPoint(x: startX, y: midLevelY),
                    to: CGPoint(x: startX, y: nextLevelY),
                    color: .systemGreen
                )
            }
            
            // 创建并添加所有子女节点
            var allChildNodes: [(node: SKNode, position: CGPoint)] = []
            for (index, child) in graphData.children.enumerated() {
                let childNode = processedNodes[child.person.id] ?? {
                    let node = createPersonNode(for: child.person, isCenter: false)
                    let childX = startX + CGFloat(index) * siblingSpacing  // 使用兄弟姐妹间距
                    let childPosition = CGPoint(x: childX, y: nextLevelY)
                    node.position = childPosition
                    contentNode?.addChild(node)  // 修改为添加到 contentNode
                    processedNodes[child.person.id] = node
                    
                    // 处理子女的配偶
                    if let childSpouse = child.subNodes?.spouses.first {
                        let spouseNode = createPersonNode(for: childSpouse.person, isCenter: false)
                        let spousePosition = CGPoint(
                            x: childX + spouseSpacing,  // 使用配偶间距
                            y: nextLevelY
                        )
                        spouseNode.position = spousePosition
                        contentNode?.addChild(spouseNode)  // 修改为添加到 contentNode
                        drawHorizontalLine(from: childPosition, to: spousePosition, color: .systemPink)
                        processedNodes[childSpouse.person.id] = spouseNode
                    }
                    
                    return node
                }()
                
                allChildNodes.append((childNode, childNode.position))
                
                // 立即处理这个子女的子图谱
                if let child = graphData.children.first(where: { $0.person.id == UUID(uuidString: childNode.name ?? "") }),
                   let subNodes = child.subNodes {
                    addRelationshipsRecursively(
                        graphData: subNodes,
                        centerNode: childNode,
                        level: level + 1,
                        maxDepth: maxDepth,
                        processedNodes: &processedNodes,
                        basePosition: childNode.position
                    )
                }
            }
        }
    }
    
     
    
    
    private func createPersonNode(for person: Person, isCenter: Bool, isSmaller: Bool = false) -> SKNode {
        let container = SKNode()
        container.name = person.id.uuidString  // 添加这一行，用于后续查找
        
        // 创建圆形背景
        let radius: CGFloat = isCenter ? 40 : (isSmaller ? 25 : 30)
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = isCenter ? .blue.withAlphaComponent(0.1) : .white
        circle.strokeColor = isCenter ? .blue : .gray
        circle.lineWidth = 2
        container.addChild(circle)
        
        // 创建名字标签
        let nameLabel = SKLabelNode(text: person.name)
        nameLabel.fontSize = isSmaller ? 12 : 14
        nameLabel.fontName = "PingFangSC-Regular"
        nameLabel.fontColor = .black
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -(radius + 10))
        container.addChild(nameLabel)
        
        return container
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
        
        // 递归处理所有关系
        for parent in graphData.parents {
            if let subNodes = parent.subNodes {
                calculateGenerations(graphData: subNodes, level: level - 1, generations: &generations)
            }
        }
        
        for child in graphData.children {
            if let subNodes = child.subNodes {
                calculateGenerations(graphData: subNodes, level: level + 1, generations: &generations)
            }
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
        let dotRadius: CGFloat = 3
        let dotCount = 20
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
            contentNode?.addChild(dot)  // 修改为添加到 contentNode
        }
        
        contentNode?.addChild(line)  // 修改为添加到 contentNode
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
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - x
        let dy = point.y - y
        return sqrt(dx * dx + dy * dy)
    }
}
