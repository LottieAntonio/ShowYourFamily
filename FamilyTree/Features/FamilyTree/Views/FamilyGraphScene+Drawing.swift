import SpriteKit

extension FamilyGraphScene {
   // 创建节点和连接线
    func createNodesAndConnections() {
        // 清除已绘制线条的记录
        drawnLines.removeAll()
        
        // 按照层级顺序创建节点
        // 首先按y坐标排序，对于y坐标相同的节点，再按x坐标从左到右排序
        let sortedLayoutInfo = nodeLayoutMap.sorted { 
            if $0.value.position.y != $1.value.position.y {
                return $0.value.position.y > $1.value.position.y  // y坐标大的先创建（屏幕下方）
            } else {
                return $0.value.position.x < $1.value.position.x  // y坐标相同时，x坐标小的先创建（左侧）
            }
        }
        
        // 然后按顺序创建节点
        for (index, (personId, layoutInfo)) in sortedLayoutInfo.enumerated() {
            if let person = currentGraphData?.findPerson(by: personId) {
                let personNode = createPersonNode(
                    for: person,
                    isCenter: layoutInfo.isCenter,
                    isInFilter: layoutInfo.isInFilter
                )
                personNode.position = layoutInfo.position
                
                // 设置节点的zPosition，确保上方的节点有更高的zPosition
                personNode.zPosition = 10 + CGFloat(index) * 0.1
                
                contentNode?.addChild(personNode)
                graphNodes[personId] = personNode
            }
        }
        
        // 最后绘制所有连接线（确保线在节点上方）
        for connection in connections {
            drawConnection(connection)
        }
    }
    
    // 绘制普通线条的方法
    func drawLine(from: CGPoint, to: CGPoint, color: SKColor, isInFilter: Bool = true) {
        // 创建线条的唯一标识符
        let lineId = createLineId(from: from, to: to)
        
        // 检查是否已经绘制过这条线
        if drawnLines.contains(lineId) {
            return
        }
        
        // 记录已绘制的线条
        drawnLines.insert(lineId)
        
        // 创建路径
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        // 创建形状节点
        let line = SKShapeNode(path: path)
        line.strokeColor = isInFilter ? color : .lightGray
        line.lineWidth = isInFilter ? 2.0 : 1.0
        line.zPosition = 5 // 提高线条的zPosition，确保可见
        
        // 添加到内容节点
        contentNode?.addChild(line)
    }
    
    // 绘制连接线
    func drawConnection(_ connection: ConnectionInfo) {
        switch connection.type {
        case .spouse:
            if let fromNode = graphNodes[connection.fromId],
               let toNode = graphNodes[connection.toId] {
                drawHorizontalLine(
                    from: fromNode.position,
                    to: toNode.position,
                    color: .systemPink,
                    isInFilter: connection.isInFilter
                )
            }
            
        case .child:
            if let fromNode = graphNodes[connection.fromId],
               let toNode = graphNodes[connection.toId] {
                // 子女连接线：从父母向下到子女
                let midY = (fromNode.position.y + toNode.position.y) / 2
                
                // 计算父母节点底部的位置（考虑节点高度）
                let parentBottomY = fromNode.position.y - 50 // 节点高度的一半
                
                // 计算子女节点顶部的位置
                let childTopY = toNode.position.y + 50 // 节点高度的一半
                
                // 使用节点边缘位置而不是中心位置
                let midPoint = CGPoint(x: toNode.position.x, y: midY)
                
                // 绘制从父母底部到中点的垂直线
                drawLine(
                    from: CGPoint(x: fromNode.position.x, y: parentBottomY),
                    to: CGPoint(x: fromNode.position.x, y: midY),
                    color: .systemBlue,
                    isInFilter: connection.isInFilter
                )
                
                // 绘制从中点到子女顶部的垂直线
                drawLine(
                    from: midPoint,
                    to: CGPoint(x: toNode.position.x, y: childTopY),
                    color: .systemBlue,
                    isInFilter: connection.isInFilter
                )
                
                // 如果父母和子女不在同一垂直线上，绘制水平连接线
                if fromNode.position.x != toNode.position.x {
                    drawLine(
                        from: CGPoint(x: fromNode.position.x, y: midY),
                        to: midPoint,
                        color: .systemBlue,
                        isInFilter: connection.isInFilter
                    )
                }
            }
            
        case .parent:
            if let fromNode = graphNodes[connection.fromId],
               let toNode = graphNodes[connection.toId] {
                // 父母连接线：从子女向上到父母
                let midY = (fromNode.position.y + toNode.position.y) / 2
                
                // 计算子女节点顶部的位置
                let childTopY = fromNode.position.y + 50 // 节点高度的一半
                
                // 计算父母节点底部的位置
                let parentBottomY = toNode.position.y - 50 // 节点高度的一半
                
                let midPoint = CGPoint(x: fromNode.position.x, y: midY)
                
                // 绘制从子女顶部到中点的垂直线
                drawLine(
                    from: CGPoint(x: fromNode.position.x, y: childTopY),
                    to: midPoint,
                    color: .systemGreen,
                    isInFilter: connection.isInFilter
                )
                
                // 绘制从中点到父母底部的垂直线
                drawLine(
                    from: CGPoint(x: toNode.position.x, y: midY),
                    to: CGPoint(x: toNode.position.x, y: parentBottomY),
                    color: .systemGreen,
                    isInFilter: connection.isInFilter
                )
                
                // 如果子女和父母不在同一垂直线上，绘制水平连接线
                if fromNode.position.x != toNode.position.x {
                    drawLine(
                        from: midPoint,
                        to: CGPoint(x: toNode.position.x, y: midY),
                        color: .systemGreen,
                        isInFilter: connection.isInFilter
                    )
                }
            }
            
        case .sibling:
            if let fromNode = graphNodes[connection.fromId],
               let toNode = graphNodes[connection.toId] {
                // 兄弟姐妹连接线：使用虚线
                drawDashedLine(
                    from: fromNode.position,
                    to: toNode.position,
                    color: .systemOrange,
                    isInFilter: connection.isInFilter
                )
            }
        }
    }
    
    // 创建人物节点的方法
    func createPersonNode(for person: Person, isCenter: Bool, isInFilter: Bool) -> SKNode {
        // 创建一个容器节点
        let containerNode = SKNode()
        containerNode.name = person.id.uuidString
        
        // 创建背景形状
        let backgroundSize = CGSize(width: 80, height: 100)
        let backgroundShape = SKShapeNode(rectOf: backgroundSize, cornerRadius: 10)
        
        // 设置背景颜色和样式
        if isCenter {
            backgroundShape.fillColor = .systemYellow
            backgroundShape.strokeColor = .systemOrange
            backgroundShape.lineWidth = 3
        } else if isInFilter {
            backgroundShape.fillColor = .white
            backgroundShape.strokeColor = .systemBlue
            backgroundShape.lineWidth = 2
        } else {
            // 非筛选范围内的节点使用灰色
            backgroundShape.fillColor = .lightGray
            backgroundShape.strokeColor = .gray
            backgroundShape.lineWidth = 1
        }
        
        // 添加阴影效果（使用单独的阴影节点）
        let shadowNode = SKShapeNode(rectOf: CGSize(width: backgroundSize.width + 4, height: backgroundSize.height + 4), cornerRadius: 10)
        shadowNode.fillColor = .black
        shadowNode.alpha = 0.3
        shadowNode.position = CGPoint(x: 2, y: -2)
        
        // 先添加阴影和背景到容器
        containerNode.addChild(shadowNode)
        containerNode.addChild(backgroundShape)
        
        // 设置最大宽度限制
        let maxWidth: CGFloat = 70 // 比背景宽度稍小
        
        // 创建名称标签
        let nameLabel = SKLabelNode(text: person.name)
        nameLabel.fontName = "PingFangSC-Semibold"
        nameLabel.fontSize = 14
        nameLabel.fontColor = .black
        nameLabel.position = CGPoint(x: 0, y: 15)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        
        // 确保名称不超出节点宽度
        let nameAttributes = [NSAttributedString.Key.font: UIFont(name: "PingFangSC-Semibold", size: 14) ?? UIFont.systemFont(ofSize: 14)]
        if (person.name as NSString).size(withAttributes: nameAttributes).width > maxWidth {
            var truncatedText = person.name
            while truncatedText.count > 1 {
                truncatedText = String(truncatedText.dropLast())
                let newText = truncatedText + "..."
                if (newText as NSString).size(withAttributes: nameAttributes).width <= maxWidth {
                    nameLabel.text = newText
                    break
                }
            }
        }
        
        containerNode.addChild(nameLabel)
        
        // 创建生日标签
        let birthYear = Calendar.current.component(.year, from: person.birthDate ?? Date())
        let birthText = "出生: \(birthYear)"
        let birthLabel = SKLabelNode(text: birthText)
        birthLabel.fontName = "PingFangSC-Regular"
        birthLabel.fontSize = 12
        birthLabel.fontColor = .darkGray
        birthLabel.position = CGPoint(x: 0, y: -15)
        birthLabel.verticalAlignmentMode = .center
        birthLabel.horizontalAlignmentMode = .center
        
        // 确保生日文本不超出节点宽度
        let birthAttributes = [NSAttributedString.Key.font: UIFont(name: "PingFangSC-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)]
        if (birthText as NSString).size(withAttributes: birthAttributes).width > maxWidth {
            var truncatedText = birthText
            while truncatedText.count > 1 {
                truncatedText = String(truncatedText.dropLast())
                let newText = truncatedText + "..."
                if (newText as NSString).size(withAttributes: birthAttributes).width <= maxWidth {
                    birthLabel.text = newText
                    break
                }
            }
        }
        
        containerNode.addChild(birthLabel)
        
        // 创建性别图标 - 直接使用SF Symbols
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let symbolName = person.gender == .male ? "male" : "female"
        let symbolColor = person.gender == .male ? UIColor.systemBlue : UIColor.systemPink
        
        if let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?.withTintColor(symbolColor, renderingMode: .alwaysOriginal) {
            let symbolTexture = SKTexture(image: symbolImage)
            let genderIcon = SKSpriteNode(texture: symbolTexture, size: CGSize(width: 24, height: 24))
            genderIcon.position = CGPoint(x: 0, y: -40)
            genderIcon.zPosition = 0.1
            containerNode.addChild(genderIcon)
        } else {
            // 如果SF Symbol无法加载，使用文本符号作为备选
            let genderText = person.gender == .male ? "♂" : "♀"
            let genderLabel = SKLabelNode(text: genderText)
            genderLabel.fontName = "PingFangSC-Regular"
            genderLabel.fontSize = 16
            genderLabel.fontColor = person.gender == .male ? .systemBlue : .systemPink
            genderLabel.position = CGPoint(x: 0, y: -40)
            genderLabel.verticalAlignmentMode = .center
            genderLabel.horizontalAlignmentMode = .center
            genderLabel.zPosition = 0.1
            containerNode.addChild(genderLabel)
        }
        
        // 添加用户交互
        containerNode.isUserInteractionEnabled = true
        
        return containerNode
    }
    
    // 辅助方法：截断文本以适应最大宽度
    private func truncateText(_ text: String, fontSize: CGFloat, maxWidth: CGFloat) -> String {
        let font = UIFont(name: "PingFangSC-Semibold", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        // 如果文本长度小于等于3，直接返回
        if text.count <= 3 {
            return text
        }
        
        // 检查文本是否需要分行显示
        if text.contains("(") && text.contains(")") {
            // 尝试在括号处分行
            let parts = text.split(separator: "(", maxSplits: 1)
            if parts.count == 2 {
                let firstPart = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var secondPart = String(parts[1])
                
                // 移除结尾的括号
                if secondPart.hasSuffix(")") {
                    secondPart = String(secondPart.dropLast())
                }
                
                // 检查每部分是否需要截断
                let truncatedFirst = truncatePart(firstPart, font: font, maxWidth: maxWidth)
                let truncatedSecond = truncatePart(secondPart, font: font, maxWidth: maxWidth)
                
                return "\(truncatedFirst)\n(\(truncatedSecond))"
            }
        }
        
        // 如果不需要分行，直接截断
        return truncatePart(text, font: font, maxWidth: maxWidth)
    }
    
    // 辅助方法：截断单个部分的文本
    private func truncatePart(_ text: String, font: UIFont, maxWidth: CGFloat) -> String {
        let attributes = [NSAttributedString.Key.font: font]
        
        if (text as NSString).size(withAttributes: attributes).width <= maxWidth {
            return text
        }
        
        // 逐字符减少直到适合宽度
        var truncatedText = text
        while truncatedText.count > 3 {
            truncatedText = String(truncatedText.dropLast())
            let size = (truncatedText + "..." as NSString).size(withAttributes: attributes)
            if size.width <= maxWidth {
                return truncatedText + "..."
            }
        }
        
        return truncatedText + "..."
    }
    
    // 绘制水平线方法
    func drawHorizontalLine(from: CGPoint, to: CGPoint, color: SKColor, isInFilter: Bool = true) {
        drawLine(from: from, to: to, color: color, isInFilter: isInFilter)
    }
    
    // 绘制虚线方法
    func drawDashedLine(from: CGPoint, to: CGPoint, color: SKColor, isInFilter: Bool = true) {
        // 创建线条的唯一标识符
        let lineId = createLineId(from: from, to: to)
        
        // 检查是否已经绘制过这条线
        if drawnLines.contains(lineId) {
            return
        }
        
        // 记录已绘制的线条
        drawnLines.insert(lineId)
        
        // 计算线条长度和方向
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // 设置虚线模式
        let dashLength: CGFloat = 6.0
        let gapLength: CGFloat = 4.0
        let dashCount = Int(distance / (dashLength + gapLength))
        
        // 计算每一段的增量
        let stepX = dx / CGFloat(dashCount) / (dashLength + gapLength) * dashLength
        let stepY = dy / CGFloat(dashCount) / (dashLength + gapLength) * dashLength
        
        // 绘制每一段虚线
        for i in 0..<dashCount {
            let startX = from.x + CGFloat(i) * (stepX + (stepX / dashLength) * gapLength)
            let startY = from.y + CGFloat(i) * (stepY + (stepY / dashLength) * gapLength)
            let endX = startX + stepX
            let endY = startY + stepY
            
            let dashStart = CGPoint(x: startX, y: startY)
            let dashEnd = CGPoint(x: endX, y: endY)
            
            // 创建路径
            let path = CGMutablePath()
            path.move(to: dashStart)
            path.addLine(to: dashEnd)
            
            // 创建形状节点
            let dash = SKShapeNode(path: path)
            dash.strokeColor = isInFilter ? color : .lightGray
            dash.lineWidth = isInFilter ? 2.0 : 1.0
            dash.zPosition = 5 // 确保线在节点下方，但在阴影上方
            
            // 添加到内容节点
            contentNode?.addChild(dash)
        }
    }
    
    // 创建线条唯一标识符的方法
    func createLineId(from: CGPoint, to: CGPoint) -> String {
        // 确保相同的两点无论顺序如何都生成相同的ID
        let point1 = from.x < to.x ? from : to
        let point2 = from.x < to.x ? to : from
        
        return "\(point1.x),\(point1.y)-\(point2.x),\(point2.y)"
    }
}
