import SwiftUI
import UIKit

// 图片编辑视图
struct ImageEditorView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    
    // 裁剪框大小
    let cropSize: CGFloat = 300
    
    var onSave: ((UIImage) -> Void)?
    
    // 添加一个状态来跟踪是否正在处理图片
    @State private var isProcessing = false
    
    // 添加一个状态来跟踪当前的临时ID
    @State private var currentTempId: UUID?
    
    var body: some View {
        VStack {
            Text("调整图片")
                .font(.headline)
                .padding()
            
            if let image = image {
                ZStack {
                    // 图片显示区域
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .rotationEffect(rotation)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value.magnitude
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .simultaneousGesture(
                            RotationGesture()
                                .onChanged { value in
                                    rotation = lastRotation + value
                                }
                                .onEnded { _ in
                                    lastRotation = rotation
                                }
                        )
                    
                    // 裁剪框
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: cropSize - 4, height: cropSize - 4)
                        )
                        .background(
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .mask(
                                    Canvas { context, size in
                                        context.fill(
                                            Path(CGRect(origin: .zero, size: size)),
                                            with: .color(.black)
                                        )
                                        context.blendMode = .destinationOut
                                        context.fill(
                                            Path(ellipseIn: CGRect(x: (size.width - cropSize) / 2, y: (size.height - cropSize) / 2, width: cropSize, height: cropSize)),
                                            with: .color(.black)
                                        )
                                    }
                                )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                        .compositingGroup()
                        .luminanceToAlpha()
                    
                    // 添加处理指示器
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
            } else {
                Text("无法加载图片")
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 30) {
                Button(action: {
                    // 重置所有调整
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    rotation = .zero
                    lastRotation = .zero
                }) {
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 24))
                        Text("重置")
                            .font(.caption)
                    }
                }
                .disabled(isProcessing)
                
                Button(action: {
                    // 旋转90度
                    rotation += .degrees(90)
                    lastRotation = rotation
                }) {
                    VStack {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 24))
                        Text("旋转")
                            .font(.caption)
                    }
                }
                .disabled(isProcessing)
                
                Button(action: {
                    // 保存裁剪后的图片
                    if let image = image {
                        isProcessing = true
                        
                        // 使用后台线程处理图片裁剪，避免UI卡顿
                        DispatchQueue.global(qos: .userInitiated).async {
                            if let croppedImage = cropImage(image) {
                                // 回到主线程更新UI
                                DispatchQueue.main.async {
                                    print("图片裁剪完成，准备调用onSave回调")
                                    isProcessing = false
                                    
                                    // 如果有临时ID，直接更新ImagePickerManager
                                    if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
                                       let tempId = UUID(uuidString: tempIdString) {
                                        print("找到临时ID: \(tempId)，直接在编辑器中更新图片")
                                        currentTempId = tempId
                                        
                                        // 将编辑后的图片保存到ImagePickerManager
                                        if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
                                            // 直接更新ImagePickerManager
                                            ImagePickerManager.shared.setImage(for: tempId, image: croppedImage, data: imageData)
                                            print("编辑器中更新了临时ID的图片: \(tempId)")
                                            
                                            // 发送特殊通知，表明这是编辑器中编辑的图片
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("EditorImageUpdated"),
                                                object: nil,
                                                userInfo: ["tempId": tempId, "imageData": imageData]
                                            )
                                        }
                                    }
                                    
                                    // 调用onSave回调
                                    if let onSave = onSave {
                                        onSave(croppedImage)
                                    }
                                    
                                    // 关闭编辑器
                                    dismiss()
                                }
                            } else {
                                // 裁剪失败，回到主线程更新UI
                                DispatchQueue.main.async {
                                    isProcessing = false
                                    print("图片裁剪失败")
                                }
                            }
                        }
                    }
                }) {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                        Text("完成")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    dismiss()
                }) {
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("取消")
                            .font(.caption)
                    }
                }
                .disabled(isProcessing)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black)
        .foregroundColor(.white)
        .onAppear {
            // 检查是否有临时ID
            if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
               let tempId = UUID(uuidString: tempIdString) {
                print("ImageEditorView: 发现临时ID: \(tempIdString)")
                currentTempId = tempId
            }
        }
    }
    
    // 裁剪图片为圆形
    private func cropImage(_ inputImage: UIImage) -> UIImage? {
        // 创建一个与裁剪框大小相同的上下文
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cropSize, height: cropSize), false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // 获取当前上下文
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 创建圆形裁剪路径
        let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
        circlePath.addClip()
        
        // 获取图片的原始尺寸
        let imageSize = inputImage.size
        
        // 计算图片在视图中的实际显示尺寸
        let imageViewSize: CGSize
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.width / imageSize.height
            imageViewSize = CGSize(width: cropSize * aspectRatio, height: cropSize)
        } else {
            let aspectRatio = imageSize.height / imageSize.width
            imageViewSize = CGSize(width: cropSize, height: cropSize * aspectRatio)
        }
        
        // 计算缩放后的尺寸
        let scaledWidth = imageViewSize.width * scale
        let scaledHeight = imageViewSize.height * scale
        
        // 计算图片在裁剪框中的位置
        let centerX = cropSize / 2
        let centerY = cropSize / 2
        
        // 保存当前的图形状态
        context.saveGState()
        
        // 移动到裁剪框中心
        context.translateBy(x: centerX, y: centerY)
        
        // 应用旋转
        context.rotate(by: CGFloat(rotation.radians))
        
        // 计算绘制区域，考虑缩放和偏移
        let drawX = -scaledWidth / 2 + offset.width
        let drawY = -scaledHeight / 2 + offset.height
        let drawRect = CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight)
        
        // 绘制图片
        inputImage.draw(in: drawRect)
        
        // 恢复图形状态
        context.restoreGState()
        
        // 获取裁剪后的图片
        guard let croppedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // 确保返回的图像是圆形的
        return croppedImage
    }
}