import SpriteKit
import UIKit

class FamilyGraphScene: SKScene, UIGestureRecognizerDelegate {
    // 核心属性
    var graphNodes: [UUID: SKNode] = [:]
    var currentGraphData: FamilyGraphData?
    var drawnLines: Set<String> = []
    
    // 相机和内容节点
    var cameraNode: SKCameraNode?
    var contentNode: SKNode?
    
    // 筛选相关属性
    var selectedCategories: [RelationCategory] = [.all]
    var displayDepth: Int = 5
    
    // 布局相关属性
    var nodeLayoutMap: [UUID: NodeLayoutInfo] = [:]
    var connections: [ConnectionInfo] = []
    var processedPersons: Set<UUID> = []
    
    // 布局常量
    let horizontalSpacing: CGFloat = 100
    let verticalSpacing: CGFloat = 150  // 增加垂直间距
    let reducedSpacing: CGFloat = 60
    
    // 更新筛选条件的方法
    func updateFilter(categories: [RelationCategory], depth: Int) {
        self.selectedCategories = categories
        self.displayDepth = depth
        
        if let currentData = currentGraphData {
            updateGraph(with: currentData)
        }
    }
    
    // 初始化视图的方法
    func setupInitialView(with size: CGSize) {
        // 设置场景大小，确保足够大以容纳所有内容
        self.size = CGSize(width: size.width * 5, height: size.height * 5)  // 增加场景大小
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
        
        // 设置相机初始位置
        cameraNode?.position = CGPoint(x: 0, y: 0)
        
        // 设置初始缩放
        cameraNode?.setScale(0.8)  // 调整初始缩放
        
        // 确保背景是白色
        self.backgroundColor = .white
    }
    
    // didMove 方法
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
        
        // 视图设置
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
    
    // 更新图谱方法
    func updateGraph(with graphData: FamilyGraphData?) {
        guard let graphData = graphData else { return }
        
        // 清除现有节点和数据
        contentNode?.removeAllChildren()
        graphNodes.removeAll()
        drawnLines.removeAll()
        processedPersons.removeAll()
        nodeLayoutMap.removeAll()
        connections.removeAll()
        
        // 保存当前图谱数据
        currentGraphData = graphData
        
        // 应用筛选
        let filteredData = selectedCategories.contains(.all) ? 
            graphData : graphData.filtered(by: selectedCategories, maxDepth: displayDepth)
        
        // 添加调试信息：打印筛选后的数据深度
        print("筛选设置 - 类别: \(selectedCategories), 深度: \(displayDepth)")
        printGraphDataDepth(filteredData)
        
        // 第一阶段：计算所有节点的位置
        calculateLayout(for: filteredData)
        
        // 添加调试信息：打印布局信息
        print("布局后节点数量: \(nodeLayoutMap.count)")
        
        // 第二阶段：创建节点并绘制连接线
        createNodesAndConnections()
        
        // 确保相机位置重置
        cameraNode?.position = .zero
        cameraNode?.setScale(0.4)
        
        // 自动调整视图以显示所有节点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.zoomToFitContent()
        }
    }
    
    // 添加一个辅助方法来打印图谱数据的深度
    private func printGraphDataDepth(_ data: FamilyGraphData, level: Int = 0, path: String = "中心") {
        if level == 0 {
            print("=== 图谱数据深度分析 ===")
            print("中心人物: \(data.centerPerson.name)")
        }
        
        // 打印当前级别的关系数量
        if level < 5 { // 限制打印深度，避免过多输出
            print("\(String(repeating: "  ", count: level))[\(path)] 父母: \(data.parents.count), 子女: \(data.children.count), 配偶: \(data.spouses.count), 兄弟姐妹: \(data.siblings.count)")
            
            // 递归检查下一级
            for parent in data.parents {
                printGraphDataDepth(parent.subNodes, level: level + 1, path: "\(path) -> 父母(\(parent.person.name))")
            }
            
            for child in data.children {
                printGraphDataDepth(child.subNodes, level: level + 1, path: "\(path) -> 子女(\(child.person.name))")
            }
            
            for spouse in data.spouses {
                printGraphDataDepth(spouse.subNodes, level: level + 1, path: "\(path) -> 配偶(\(spouse.person.name))")
            }
            
            for sibling in data.siblings {
                printGraphDataDepth(sibling.subNodes, level: level + 1, path: "\(path) -> 兄弟姐妹(\(sibling.person.name))")
            }
        }
        
        if level == 0 {
            print("=========================")
        }
    }
    
    // 自动缩放以适应内容
    func zoomToFitContent() {
        guard let camera = cameraNode, let contentNode = contentNode else { return }
        
        // 如果没有节点，不执行缩放
        if contentNode.children.isEmpty {
            return
        }
        
        // 计算内容的边界
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        
        for node in contentNode.children {
            let nodeMinX = node.position.x - node.frame.width / 2
            let nodeMaxX = node.position.x + node.frame.width / 2
            let nodeMinY = node.position.y - node.frame.height / 2
            let nodeMaxY = node.position.y + node.frame.height / 2
            
            minX = min(minX, nodeMinX)
            maxX = max(maxX, nodeMaxX)
            minY = min(minY, nodeMinY)
            maxY = max(maxY, nodeMaxY)
        }
        
        // 计算内容的中心点
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // 计算内容的宽度和高度
        let contentWidth = maxX - minX
        let contentHeight = maxY - minY
        
        // 计算适当的缩放比例，增加可见范围
        let scaleX = self.size.width / (contentWidth * 1.5)  // 增加缩放系数
        let scaleY = self.size.height / (contentHeight * 1.5)  // 增加缩放系数
        let scale = min(scaleX, scaleY, 1.0) * 0.8  // 额外缩小一点，确保所有内容可见
        
        // 应用缩放和位置
        camera.run(SKAction.group([
            SKAction.scale(to: scale, duration: 0.3),
            SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.3)
        ]))
    }
    
  
}
