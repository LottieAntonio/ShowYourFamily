import SpriteKit
import UIKit

extension FamilyGraphScene {
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
        
        // 添加双击手势用于重置视图
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        view.addGestureRecognizer(doubleTapGesture)
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
    
    // 处理双击手势
    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        // 双击重置视图
        guard let camera = cameraNode else { return }
        
        // 使用动画平滑过渡到初始状态
        let resetAction = SKAction.group([
            SKAction.scale(to: 0.4, duration: 0.3),
            SKAction.move(to: .zero, duration: 0.3)
        ])
        
        camera.run(resetAction)
    }
    
    // 处理节点点击事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // 获取触摸位置
        let location = touch.location(in: self)
        
        // 检查是否点击了人物节点
        let touchedNodes = nodes(at: location)
        
        for node in touchedNodes {
            // 向上遍历节点层次结构，查找具有UUID名称的节点
            var currentNode: SKNode? = node
            while currentNode != nil {
                if let nodeName = currentNode?.name, let personId = UUID(uuidString: nodeName) {
                    handleNodeTapped(personId: personId)
                    return
                }
                currentNode = currentNode?.parent
            }
        }
    }
    
    // 处理节点点击事件
    func handleNodeTapped(personId: UUID) {
        // 查找被点击的人物
        guard let person = currentGraphData?.findPerson(by: personId) else { return }
        
        // 高亮显示被点击的节点
        if let node = graphNodes[personId] {
            // 创建一个简单的动画效果
            let pulseAction = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            
            node.run(pulseAction)
        }
        
        // 发送通知，通知其他组件人物被选中
        NotificationCenter.default.post(
            name: NSNotification.Name("PersonSelectedInGraph"),
            object: nil,
            userInfo: ["personId": personId]
        )
    }
    
    // UIGestureRecognizerDelegate 方法
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}