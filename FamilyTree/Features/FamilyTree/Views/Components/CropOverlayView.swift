import SwiftUI
import UIKit

struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    @Binding var initialCropRect: CGRect
    @Binding var isCropping: Bool
    @Binding var scale: CGFloat
    @Binding var imageOffset: CGSize
    @Binding var imageFrame: CGRect
    
    // 拖动状态
    @State private var dragState: DragState = .none
    @State private var dragStartLocation: CGPoint = .zero
    @State private var initialDragRect: CGRect = .zero
    
    enum DragState {
        case none, resizing
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明遮罩 - 确保与裁剪框完全重合
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay(
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(x: cropRect.midX, y: cropRect.midY)
                            )
                            .compositingGroup()
                            .luminanceToAlpha()
                    )
                    .allowsHitTesting(false) // 禁止遮罩接收手势
                
                // 裁剪框和网格线组合在一起
                ZStack {
                    // 裁剪框
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: cropRect.width, height: cropRect.height)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: cropRect.width, height: cropRect.height)
                    
                    // 网格线
                    // 水平线
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: cropRect.width, height: 1)
                    
                    // 垂直线
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1, height: cropRect.height)
                }
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false) // 禁止裁剪框接收手势
                
                // 使用ZStack和相对定位来放置缩放手柄
                ZStack(alignment: .bottomTrailing) {
                    // 透明背景，与裁剪框大小相同
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: cropRect.width, height: cropRect.height)
                    
                    // 缩放手柄 - 增加点击区域并调整位置
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30) // 增加手柄大小
                        .padding(-10) // 调整内边距
                }
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(
                    DragGesture(minimumDistance: 1) // 降低最小拖动距离
                        .onChanged { value in
                            if dragState == .none {
                                // 首次缩放时记录初始状态
                                dragState = .resizing
                                isCropping = true
                                dragStartLocation = value.startLocation
                                initialDragRect = cropRect
                            }
                            
                            // 使用相对于起始位置的偏移量计算新大小
                            let translation = CGSize(
                                width: value.location.x - dragStartLocation.x,
                                height: value.location.y - dragStartLocation.y
                            )
                            
                            // 计算新的裁剪框大小（保持正方形）
                            let newWidth = initialDragRect.width + max(translation.width, translation.height)
                            let newHeight = newWidth // 保持正方形
                            
                            // 更新裁剪框
                            var newRect = initialDragRect
                            newRect.size = CGSize(width: newWidth, height: newHeight)
                            
                            // 确保裁剪框不会超出视图范围
                            if newRect.maxX > geometry.size.width {
                                let adjustedWidth = geometry.size.width - newRect.minX
                                newRect.size = CGSize(width: adjustedWidth, height: adjustedWidth)
                            }
                            if newRect.maxY > geometry.size.height {
                                let adjustedHeight = geometry.size.height - newRect.minY
                                newRect.size = CGSize(width: adjustedHeight, height: adjustedHeight)
                            }
                            
                            // 保持正方形
                            let minSize = min(newRect.width, newRect.height)
                            newRect.size = CGSize(width: minSize, height: minSize)
                            
                            // 确保裁剪框不小于最小尺寸
                            let minAllowedSize: CGFloat = 100
                            if newRect.width < minAllowedSize {
                                newRect.size = CGSize(width: minAllowedSize, height: minAllowedSize)
                            }
                            
                            // 确保裁剪框不会超出图片边界
                            let scaledImageWidth = imageFrame.width * scale
                            let scaledImageHeight = imageFrame.height * scale
                            
                            // 修正图片边界计算，添加安全边距
                            let safetyMargin: CGFloat = 2.0 // 添加安全边距
                            
                            // 使用更精确的坐标计算方法
                            let imageCenter = CGPoint(
                                x: imageFrame.midX + imageOffset.width,
                                y: imageFrame.midY + imageOffset.height
                            )
                            
                            let imageLeft = imageCenter.x - scaledImageWidth / 2 + safetyMargin
                            let imageRight = imageCenter.x + scaledImageWidth / 2 - safetyMargin
                            let imageTop = imageCenter.y - scaledImageHeight / 2 + safetyMargin
                            let imageBottom = imageCenter.y + scaledImageHeight / 2 - safetyMargin
                            
                            // 限制裁剪框不能超出图片
                            if newRect.minX < imageLeft {
                                newRect.origin.x = imageLeft
                                // 调整大小时保持正方形
                                newRect.size = CGSize(width: min(newRect.width, imageRight - imageLeft), height: min(newRect.width, imageRight - imageLeft))
                            }
                            if newRect.maxX > imageRight {
                                let adjustedWidth = imageRight - newRect.minX
                                newRect.size = CGSize(width: adjustedWidth, height: adjustedWidth)
                            }
                            if newRect.minY < imageTop {
                                newRect.origin.y = imageTop
                                // 调整大小时保持正方形
                                newRect.size = CGSize(width: min(newRect.width, imageBottom - imageTop), height: min(newRect.width, imageBottom - imageTop))
                            }
                            if newRect.maxY > imageBottom {
                                let adjustedHeight = imageBottom - newRect.minY
                                newRect.size = CGSize(width: adjustedHeight, height: adjustedHeight)
                            }
                            
                            // 使用简单动画更新裁剪框
                            withAnimation(.linear(duration: 0.1)) {
                                cropRect = newRect
                                
                                // 调整图片缩放以适应新的裁剪框
                                adjustImageToFitCropRect()
                            }
                        }
                        // 在 DragGesture().onEnded 中修改
                        .onEnded { _ in
                            // 保存当前裁剪框的信息
                            let selectedCropRect = cropRect
                            
                            // 恢复裁剪框到初始大小和位置
                            withAnimation(.easeInOut(duration: 0.3)) {
                                cropRect = initialCropRect
                                
                                // 调整图片以适应新的裁剪框，但保持选中的内容
                                adjustImageToFitSelectedArea(selectedRect: selectedCropRect)
                            }
                            
                            dragState = .none
                            isCropping = false
                        }
                )
            }
        }
    }
    
    // 添加新方法来调整图片以适应选中区域
    private func adjustImageToFitSelectedArea(selectedRect: CGRect) {
        if !imageFrame.isEmpty {
            // 计算选中区域相对于初始裁剪框的比例
            let scaleX = initialCropRect.width / selectedRect.width
            let scaleY = initialCropRect.height / selectedRect.height
            
            // 使用相同的缩放比例（保持宽高比）
            let newScale = scale * min(scaleX, scaleY)
            
            // 计算选中区域中心点相对于初始裁剪框中心点的偏移
            let selectedCenterX = selectedRect.midX
            let selectedCenterY = selectedRect.midY
            let initialCenterX = initialCropRect.midX
            let initialCenterY = initialCropRect.midY
            
            // 修改：调整计算偏移量的方式，考虑图片实际位置
            let offsetX = imageOffset.width + (initialCenterX - selectedCenterX) * (newScale / scale)
            let offsetY = imageOffset.height + (initialCenterY - selectedCenterY) * (newScale / scale)
            
            // 应用新的缩放和偏移
            scale = newScale
            imageOffset = CGSize(
                width: offsetX,
                height: offsetY
            )
            
            // 添加：确保图片不会超出裁剪框边界
            ensureImageCoversCropRect()
        }
    }
    
    // 添加新方法确保图片覆盖裁剪框
    private func ensureImageCoversCropRect() {
        if !imageFrame.isEmpty {
            // 计算图片当前显示区域
            let currentImageWidth = imageFrame.width * scale
            let currentImageHeight = imageFrame.height * scale
            
            // 使用更精确的坐标计算方法
            let imageCenter = CGPoint(
                x: imageFrame.midX + imageOffset.width,
                y: imageFrame.midY + imageOffset.height
            )
            
            let safetyMargin: CGFloat = 2.0 // 添加安全边距
            let imageLeft = imageCenter.x - currentImageWidth / 2 + safetyMargin
            let imageRight = imageCenter.x + currentImageWidth / 2 - safetyMargin
            let imageTop = imageCenter.y - currentImageHeight / 2 + safetyMargin
            let imageBottom = imageCenter.y + currentImageHeight / 2 - safetyMargin
            
            // 检查并调整水平方向
            var newOffset = imageOffset
            
            // 添加额外的偏移量修正
            let offsetCorrection: CGFloat = 1.0
            
            if imageLeft > initialCropRect.minX {
                newOffset.width -= (imageLeft - initialCropRect.minX + offsetCorrection)
            }
            if imageRight < initialCropRect.maxX {
                newOffset.width += (initialCropRect.maxX - imageRight + offsetCorrection)
            }
            
            // 检查并调整垂直方向
            if imageTop > initialCropRect.minY {
                newOffset.height -= (imageTop - initialCropRect.minY + offsetCorrection)
            }
            if imageBottom < initialCropRect.maxY {
                newOffset.height += (initialCropRect.maxY - imageBottom + offsetCorrection)
            }
            
            // 应用新的偏移
            imageOffset = newOffset
        }
    }
    
    // 调整图片以适应裁剪框
    private func adjustImageToFitCropRect() {
        // 确保图片至少覆盖裁剪框
        if !imageFrame.isEmpty {
            // 计算图片当前显示区域
            let currentImageWidth = imageFrame.width * scale
            let currentImageHeight = imageFrame.height * scale
            
            // 检查图片是否完全覆盖裁剪框
            let isCoveringHorizontally = currentImageWidth >= cropRect.width
            let isCoveringVertically = currentImageHeight >= cropRect.height
            
            // 如果图片不能完全覆盖裁剪框，调整缩放
            if !isCoveringHorizontally || !isCoveringVertically {
                let requiredWidthScale = cropRect.width / imageFrame.width
                let requiredHeightScale = cropRect.height / imageFrame.height
                let requiredScale = max(requiredWidthScale, requiredHeightScale)
                
                // 应用新的缩放比例
                let newScale = scale * requiredScale
                
                // 调整图片位置，使其居中于裁剪框
                let newImageWidth = currentImageWidth * requiredScale
                let newImageHeight = currentImageHeight * requiredScale
                
                // 修正偏移量计算
                let offsetX = (cropRect.midX - imageFrame.midX) * (newScale / scale)
                let offsetY = (cropRect.midY - imageFrame.midY) * (newScale / scale)
                
                // 应用新的缩放和偏移
                scale = newScale
                imageOffset = CGSize(
                    width: imageOffset.width + offsetX,
                    height: imageOffset.height + offsetY
                )
            }
            
            // 确保图片边界不会超出裁剪框
            ensureImageCoversCropRect()
        }
    }
}
