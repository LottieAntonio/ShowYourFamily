import SwiftUI
import UIKit
import AVFoundation  // 添加这一行导入 AVFoundation

// 添加在文件顶部
struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ImageEditorView: View {
    @Binding var image: UIImage?
    var onCancel: () -> Void
    var onSave: (UIImage) -> Void
    
    // 裁剪相关状态变量
    @State private var showControls: Bool = true
    @State private var cropRect: CGRect = .zero
    @State private var initialCropRect: CGRect = .zero
    @State private var isCropping: Bool = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    // 添加图片拖动状态
    @State private var isDraggingImage: Bool = false
    @State private var dragStartLocation: CGPoint = .zero
    @State private var initialImageOffset: CGSize = .zero
    
    @Environment(\.dismiss) private var dismiss
    
    // 添加图片框架状态
    @State private var imageFrame: CGRect = .zero
    @State private var viewSize: CGSize = .zero
    
 
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let image = image {
                VStack {
                   
                    // 图片编辑区域
                    GeometryReader { geometry in
                        ZStack {
                            // 图片视图 - 添加缩放和偏移
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(imageScale)
                                .offset(imageOffset)
                                .animation(isCropping || isDraggingImage ? nil : .linear(duration: 0.2), value: imageScale)
                                .animation(isCropping || isDraggingImage ? nil : .linear(duration: 0.2), value: imageOffset)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(key: ImageFramePreferenceKey.self, value: geo.frame(in: .global))
                                            .onAppear {
                                                DispatchQueue.main.async {
                                                    self.imageFrame = geo.frame(in: .global)
                                                    // 初始化后立即确保图片覆盖裁剪框
                                                    self.ensureImageCoversCropRect()
                                                }
                                            }
                                    }
                                )
                                .onPreferenceChange(ImageFramePreferenceKey.self) { frame in
                                    self.imageFrame = frame
                                    // 当图片框架更新时确保覆盖裁剪框
                                    self.ensureImageCoversCropRect()
                                }
                            
                            // 透明的拖动层 - 用于接收拖动手势
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            // 处理图片拖动
                                            handleImageDrag(value)
                                        }
                                        .onEnded { _ in
                                            // 结束拖动
                                            isDraggingImage = false
                                            initialImageOffset = imageOffset
                                            // 拖动结束后确保图片覆盖裁剪框
                                            ensureImageCoversCropRect()
                                        }
                                )
                            
                            // 裁剪框视图 - 只负责显示和缩放
                            CropOverlayView(
                                cropRect: $cropRect,
                                initialCropRect: $initialCropRect,
                                isCropping: $isCropping,
                                scale: $imageScale,
                                imageOffset: $imageOffset,
                                imageFrame: $imageFrame
                            )
                            .onAppear {
                                // 保存视图尺寸
                                viewSize = geometry.size
                                // 初始化裁剪框
                                initializeCropRect(for: image, in: geometry.size)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 底部控制区域
                    if showControls {
                        cropControls
                            .padding()
                            .background(Color.black.opacity(0.7))
                    }
                }
                .overlay(alignment: .topLeading) {
                    // 顶部工具栏 - 添加安全区域
                    HStack {
                        Button(action: {
                            onCancel()
                            dismiss()
                        }) {
                            Text("取消")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // 应用裁剪
                            applyCrop(to: image)
                        }) {
                            Text("完成")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                }
                .onTapGesture {
                    if !isCropping && !isDraggingImage {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                }
            } else {
                Text("无法加载图片")
                    .foregroundColor(.white)
            }
        }
        
    }
    
    // 处理图片拖动
    private func handleImageDrag(_ value: DragGesture.Value) {
        if !isDraggingImage {
            isDraggingImage = true
            dragStartLocation = value.startLocation
            initialImageOffset = imageOffset
        }
        
        // 计算拖动偏移量
        let translation = CGSize(
            width: value.location.x - dragStartLocation.x,
            height: value.location.y - dragStartLocation.y
        )
        
        // 更新图片偏移量
        var newOffset = initialImageOffset
        newOffset.width += translation.width
        newOffset.height += translation.height
        
        // 限制图片不能拖出裁剪框 - 修正计算方式
        let scaledImageWidth = imageFrame.width * imageScale
        let scaledImageHeight = imageFrame.height * imageScale
        
        // 使用更精确的坐标计算方法
        let imageCenter = CGPoint(
            x: imageFrame.midX + newOffset.width,
            y: imageFrame.midY + newOffset.height
        )
        
        let safetyMargin: CGFloat = 2.0 // 添加安全边距
        let imageLeft = imageCenter.x - scaledImageWidth / 2 + safetyMargin
        let imageRight = imageCenter.x + scaledImageWidth / 2 - safetyMargin
        let imageTop = imageCenter.y - scaledImageHeight / 2 + safetyMargin
        let imageBottom = imageCenter.y + scaledImageHeight / 2 - safetyMargin
        
        // 添加额外的偏移量修正
        let offsetCorrection: CGFloat = 1.0
        
        // 确保图片边界不会超出裁剪框
        if imageLeft > cropRect.minX {
            newOffset.width -= (imageLeft - cropRect.minX + offsetCorrection)
        }
        if imageRight < cropRect.maxX {
            newOffset.width += (cropRect.maxX - imageRight + offsetCorrection)
        }
        if imageTop > cropRect.minY {
            newOffset.height -= (imageTop - cropRect.minY + offsetCorrection)
        }
        if imageBottom < cropRect.maxY {
            newOffset.height += (cropRect.maxY - imageBottom + offsetCorrection)
        }
        
        // 更新图片位置
        imageOffset = newOffset
    }
    
    // 修改初始化裁剪框的方法，确保在图片范围内
    private func initializeCropRect(for image: UIImage, in size: CGSize) {
        // 延迟初始化，确保imageFrame已经更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // 增加延迟时间
            // 计算裁剪框的大小（取视图较小边的80%）
            let cropSize = min(size.width, size.height) * 0.8
            
            // 计算裁剪框的位置（居中）
            let cropX = (size.width - cropSize) / 2
            let cropY = (size.height - cropSize) / 2
            
            // 设置裁剪框
            cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
            initialCropRect = cropRect
            
            // 重置图片位置和缩放
            imageScale = 1.0
            imageOffset = .zero
            
            // 确保图片完全覆盖裁剪框
            if !imageFrame.isEmpty {
                let imageAspect = image.size.width / image.size.height
                let cropAspect = cropSize / cropSize // 正方形，所以是1
                
                if imageAspect > cropAspect {
                    // 图片比裁剪框更宽，需要垂直缩放
                    let requiredHeight = cropSize
                    let currentHeight = imageFrame.height
                    if currentHeight < requiredHeight {
                        let scale = requiredHeight / currentHeight
                        imageScale = scale
                    }
                } else {
                    // 图片比裁剪框更高，需要水平缩放
                    let requiredWidth = cropSize
                    let currentWidth = imageFrame.width
                    if currentWidth < requiredWidth {
                        let scale = requiredWidth / currentWidth
                        imageScale = scale
                    }
                }
            }
        }
    }
    
    // 裁剪控制器
    private var cropControls: some View {
        HStack {
            Button(action: {
                // 重置裁剪框
                if let image = image {
                    imageScale = 1.0
                    imageOffset = .zero
                    initializeCropRect(for: image, in: viewSize)
                }
            }) {
                Text("重置裁剪")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button(action: {
                // 应用裁剪
                if let image = image {
                    applyCrop(to: image)
                }
            }) {
                Text("应用裁剪")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    // 应用裁剪的方法
    private func applyCrop(to image: UIImage) {
        // 计算裁剪区域在原始图片上的位置
        let imageSize = image.size
        
        // 计算图片在屏幕上的实际显示尺寸
        let displayRect = AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: viewSize))
        
        // 考虑缩放和偏移后的图片位置
        let scaledDisplayWidth = displayRect.width * imageScale
        let scaledDisplayHeight = displayRect.height * imageScale
        let scaledDisplayX = displayRect.minX + imageOffset.width
        let scaledDisplayY = displayRect.minY + imageOffset.height
        
        // 计算裁剪框相对于图片的位置
        let cropInImageX = (cropRect.minX - scaledDisplayX) / scaledDisplayWidth * imageSize.width
        let cropInImageY = (cropRect.minY - scaledDisplayY) / scaledDisplayHeight * imageSize.height
        let cropInImageWidth = cropRect.width / scaledDisplayWidth * imageSize.width
        let cropInImageHeight = cropRect.height / scaledDisplayHeight * imageSize.height
        
        // 确保裁剪区域在图片范围内
        let adjustedX = max(0, min(imageSize.width - cropInImageWidth, cropInImageX))
        let adjustedY = max(0, min(imageSize.height - cropInImageHeight, cropInImageY))
        let adjustedWidth = min(imageSize.width - adjustedX, cropInImageWidth)
        let adjustedHeight = min(imageSize.height - adjustedY, cropInImageHeight)
        
        // 创建裁剪区域
        let cropZone = CGRect(
            x: adjustedX,
            y: adjustedY,
            width: adjustedWidth,
            height: adjustedHeight
        )
        
        // 执行裁剪
        if let cgImage = image.cgImage?.cropping(to: cropZone) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // 更新图片并保存
            self.image = croppedImage
            onSave(croppedImage)
            dismiss()
        }
    }
    
    // 确保图片覆盖裁剪框
    private func ensureImageCoversCropRect() {
        if !imageFrame.isEmpty && !cropRect.isEmpty {
            // 计算图片当前显示区域
            let scaledImageWidth = imageFrame.width * imageScale
            let scaledImageHeight = imageFrame.height * imageScale
            
            // 使用更精确的坐标计算方法
            let imageCenter = CGPoint(
                x: imageFrame.midX + imageOffset.width,
                y: imageFrame.midY + imageOffset.height
            )
            
            let safetyMargin: CGFloat = 2.0 // 添加安全边距
            let imageLeft = imageCenter.x - scaledImageWidth / 2 + safetyMargin
            let imageRight = imageCenter.x + scaledImageWidth / 2 - safetyMargin
            let imageTop = imageCenter.y - scaledImageHeight / 2 + safetyMargin
            let imageBottom = imageCenter.y + scaledImageHeight / 2 - safetyMargin
            
            // 检查并调整水平方向
            var newOffset = imageOffset
            
            // 添加额外的偏移量修正
            let offsetCorrection: CGFloat = 1.0
            
            if imageLeft > cropRect.minX {
                newOffset.width -= (imageLeft - cropRect.minX + offsetCorrection)
            }
            if imageRight < cropRect.maxX {
                newOffset.width += (cropRect.maxX - imageRight + offsetCorrection)
            }
            
            // 检查并调整垂直方向
            if imageTop > cropRect.minY {
                newOffset.height -= (imageTop - cropRect.minY + offsetCorrection)
            }
            if imageBottom < cropRect.maxY {
                newOffset.height += (cropRect.maxY - imageBottom + offsetCorrection)
            }
            
            // 如果图片尺寸小于裁剪框，增加缩放
            if scaledImageWidth < cropRect.width || scaledImageHeight < cropRect.height {
                let requiredWidthScale = (cropRect.width + safetyMargin * 2) / imageFrame.width
                let requiredHeightScale = (cropRect.height + safetyMargin * 2) / imageFrame.height
                let requiredScale = max(requiredWidthScale, requiredHeightScale, imageScale)
                
                // 应用新的缩放
                withAnimation(.linear(duration: 0.2)) {
                    imageScale = requiredScale
                }
            }
            
            // 应用新的偏移
            withAnimation(.linear(duration: 0.2)) {
                imageOffset = newOffset
            }
        }
    }

}

