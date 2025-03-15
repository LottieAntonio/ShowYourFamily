import SwiftUI
import PhotosUI
import UIKit

// 简化图片选择管理器，只保留必要的状态
// 修改ImagePickerManager类
class ImagePickerManager: ObservableObject {
    static let shared = ImagePickerManager()
    
    // 使用字典存储每个人物的图片数据，避免状态混淆
    @Published var personImages: [UUID: UIImage] = [:]
    @Published var personImageData: [UUID: Data] = [:]
    
    // 添加一个更新通知的发布者
    @Published var lastUpdatedPersonId: UUID?
    
    // 添加一个时间戳来跟踪最后更新时间
    private var lastUpdateTimestamps: [UUID: Date] = [:]
    
    private init() {}
    
    func setImage(for personId: UUID, image: UIImage, data: Data) {
        personImages[personId] = image
        personImageData[personId] = data
        lastUpdateTimestamps[personId] = Date()
        
        // 发布更新通知
        lastUpdatedPersonId = personId
        print("ImagePickerManager: 已更新图片，personId: \(personId)")
    }
    
    func getImage(for personId: UUID) -> UIImage? {
        return personImages[personId]
    }
    
    func getImageData(for personId: UUID) -> Data? {
        return personImageData[personId]
    }
    
    // 添加清除特定人物图片缓存的方法
    func clearCache(for personId: UUID) {
        personImages.removeValue(forKey: personId)
        personImageData.removeValue(forKey: personId)
        lastUpdateTimestamps.removeValue(forKey: personId)
        print("ImagePickerManager: 已清除缓存，personId: \(personId)")
    }
    
    // 添加清除所有缓存的方法
    func clearAllCache() {
        personImages.removeAll()
        personImageData.removeAll()
        lastUpdateTimestamps.removeAll()
        print("ImagePickerManager: 已清除所有缓存")
    }
    
    // 添加一个方法来检查缓存是否过期
    func isCacheValid(for personId: UUID, maxAgeSeconds: TimeInterval = 5) -> Bool {
        guard let timestamp = lastUpdateTimestamps[personId] else {
            return false
        }
        
        let now = Date()
        let age = now.timeIntervalSince(timestamp)
        return age <= maxAgeSeconds
    }
}

// 修改PersonAvatarView结构体中的onAppear方法
struct PersonAvatarView: View {
    let person: Person
    let size: CGFloat
    let type: RelationType?
    let isEditable: Bool
    var onPhotoSelected: ((Data) -> Void)? = nil
    
    // 使用单例管理图片数据
    @StateObject private var pickerManager = ImagePickerManager.shared
    
    // 使用本地状态来控制PhotosPicker
    @State private var selectedItem: PhotosPickerItem?
    @State private var showPicker = false
    
    // 添加一个状态来存储拍照的图片
    @State private var capturedImage: UIImage?
    
    // 添加一个状态来控制图片编辑器的显示
    @State private var showImageEditor = false
    @State private var imageToEdit: UIImage?
    
    // 添加一个状态来强制刷新视图
    @State private var refreshID = UUID()
    
    // 添加一个环境对象来访问AppViewModel
    @EnvironmentObject private var appViewModel: FamilyAppViewModel
    
    var body: some View {
        Button(action: {
            if isEditable {
                print("头像被点击，准备显示图片选择器，personId: \(person.id)")
                showPicker = true
            }
        }) {
            // 在body中的ZStack内部修改图片显示逻辑
            ZStack {
                Circle()
                    .fill(Color.familyTheme.gradientFor(type ?? .spouse))
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // 优先使用选择的图片，其次是person.photo
                if let image = pickerManager.getImage(for: person.id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()  // 使用scaledToFill确保图像填满整个区域
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .onAppear {
                            print("显示personId的图片: \(person.id)")
                        }
                } else if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
                          let tempId = UUID(uuidString: tempIdString),
                          let image = pickerManager.getImage(for: tempId) {
                    // 在add模式下，尝试从临时ID获取图片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()  // 使用scaledToFill确保图像填满整个区域
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .onAppear {
                            print("使用临时ID显示图片: \(tempId)")
                        }
                } else if let photoData = person.photo, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if isEditable {
                    Image(systemName: "camera.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: size * 0.5))
                } else {
                    Text(person.name.prefix(1))
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                // 如果是可编辑状态，添加编辑指示器
                if isEditable {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: size * 0.3))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.blue))
                                .offset(x: 5, y: 5)
                        }
                    }
                    .frame(width: size, height: size)
                }
            }
            .id(refreshID) // 使用ID修饰符来强制刷新视图
        }
        .disabled(!isEditable)
        .sheet(isPresented: $showPicker) {
            PhotoPickerSheet(
                selectedItem: $selectedItem,
                onCameraCapture: { image in
                    // 拍照后直接进入编辑模式
                    imageToEdit = image
                    showPicker = false
                    showImageEditor = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showImageEditor) {
            ImageEditorView(image: $imageToEdit) { editedImage in
                print("图片编辑完成，personId: \(person.id)")
                
                if let imageData = editedImage.jpegData(compressionQuality: 0.8) {
                    // 判断是否是add模式
                    let isAddMode = person.id == UUID.init(uuidString: "00000000-0000-0000-0000-000000000000")
                    
                    if isAddMode {
                        // 在add模式下，检查是否已有临时ID
                        if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
                           let tempId = UUID(uuidString: tempIdString) {
                            // 使用现有的临时ID
                            print("Add模式: 使用现有临时ID: \(tempId)")
                            
                            // 保存到管理器
                            pickerManager.setImage(for: tempId, image: editedImage, data: imageData)
                            print("Add模式: 更新临时ID的图片: \(tempId)")
                            
                            // 调用回调
                            if let onPhotoSelected = onPhotoSelected {
                                print("调用onPhotoSelected回调")
                                onPhotoSelected(imageData)
                                
                                // 在回调完成后，手动触发一次数据刷新
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("手动触发数据刷新")
                                    refreshID = UUID() // 强制刷新当前视图
                                }
                            } else {
                                print("警告: onPhotoSelected回调为nil")
                            }
                        } else {
                            // 如果没有临时ID，创建一个新的
                            let tempId = UUID()
                            print("Add模式: 创建新的临时ID: \(tempId)")
                            
                            // 保存到管理器
                            pickerManager.setImage(for: tempId, image: editedImage, data: imageData)
                            
                            // 更新UserDefaults中的临时ID
                            UserDefaults.standard.set(tempId.uuidString, forKey: "TempPersonPhotoId")
                            print("Add模式: 更新临时ID到UserDefaults: \(tempId)")
                            
                            // 调用回调
                            if let onPhotoSelected = onPhotoSelected {
                                print("调用onPhotoSelected回调")
                                onPhotoSelected(imageData)
                                
                                // 在回调完成后，手动触发一次数据刷新
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("手动触发数据刷新")
                                    refreshID = UUID() // 强制刷新当前视图
                                }
                            } else {
                                print("警告: onPhotoSelected回调为nil")
                            }
                        }
                    } else {
                        // 正常模式，保存到person的ID
                        pickerManager.setImage(for: person.id, image: editedImage, data: imageData)
                        
                        // 调用回调
                        if let onPhotoSelected = onPhotoSelected {
                            print("调用onPhotoSelected回调")
                            onPhotoSelected(imageData)
                            
                            // 在回调完成后，手动触发一次数据刷新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("手动触发数据刷新")
                                refreshID = UUID() // 强制刷新当前视图
                            }
                        } else {
                            print("警告: onPhotoSelected回调为nil")
                        }
                    }
                }
                
                // 重置状态
                imageToEdit = nil
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                print("选择了新图片，开始加载，personId: \(person.id)")
                
                Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self) {
                            print("图片加载成功，大小: \(data.count) 字节")
                            
                            await MainActor.run {
                                if let image = UIImage(data: data) {
                                    // 从相册选择后进入编辑模式
                                    imageToEdit = image
                                    selectedItem = nil
                                    showPicker = false
                                    showImageEditor = true
                                }
                            }
                        }
                    } catch {
                        print("图片加载失败: \(error.localizedDescription)")
                        await MainActor.run {
                            selectedItem = nil
                            showPicker = false
                        }
                    }
                }
            }
        }
        .onChange(of: pickerManager.lastUpdatedPersonId) { _, updatedId in
            if let updatedId = updatedId, updatedId == person.id {
                print("检测到图片更新，刷新视图，personId: \(person.id)")
                refreshID = UUID()
            }
        }
        .onAppear {
            print("PersonAvatarView出现，isEditable: \(isEditable), personId: \(person.id)")
            
            // 修改这里的逻辑，确保缓存与数据库同步
            if let photoData = person.photo {
                // 如果person有照片数据
                if pickerManager.getImage(for: person.id) == nil || !pickerManager.isCacheValid(for: person.id) {
                    // 如果缓存中没有图片或缓存已过期，则从person加载
                    if let image = UIImage(data: photoData) {
                        pickerManager.setImage(for: person.id, image: image, data: photoData)
                        // 强制刷新视图
                        refreshID = UUID()
                        print("从数据库加载图片到缓存，personId: \(person.id)")
                    }
                } else {
                    print("使用缓存的图片，personId: \(person.id)")
                }
            } else {
                // 如果person没有照片数据，但缓存中有，则清除缓存
                if pickerManager.getImage(for: person.id) != nil {
                    pickerManager.clearCache(for: person.id)
                    refreshID = UUID()
                    print("清除过时的缓存图片，personId: \(person.id)")
                }
            }
        }
        // 添加一个onDisappear处理器来清理不需要的缓存
        .onDisappear {
            // 当视图消失时，考虑清除缓存以节省内存
            // 这是可选的，取决于你的应用需求
            print("PersonAvatarView消失，personId: \(person.id)")
        }
        // 修改onReceive方法
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TempPhotoUpdated"))) { notification in
        if let tempId = notification.userInfo?["tempId"] as? UUID {
            print("收到临时图片更新通知，tempId: \(tempId)")
            
            // 检查是否是编辑后的图片
            let isEdited = notification.userInfo?["isEdited"] as? Bool ?? false
            if isEdited {
                print("这是编辑后的图片，强制刷新视图")
            }
            
            // 强制刷新视图
            refreshID = UUID()
        }
        }
        // 在body中添加对新通知的监听
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EditorImageUpdated"))) { notification in
        if let tempId = notification.userInfo?["tempId"] as? UUID,
        let imageData = notification.userInfo?["imageData"] as? Data {
        print("收到编辑器更新的图片通知，tempId: \(tempId)")
        
        // 如果是add模式，直接使用这个图片数据
        let isAddMode = person.id == UUID.init(uuidString: "00000000-0000-0000-0000-000000000000")
        if isAddMode {
        // 调用回调
        if let onPhotoSelected = onPhotoSelected {
        print("调用onPhotoSelected回调，使用编辑器提供的图片数据")
        onPhotoSelected(imageData)
        
        // 强制刷新视图
        refreshID = UUID()
        }
        }
        }
        }
    }
}

// 单独的照片选择器视图
struct PhotoPickerSheet: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    // 添加一个回调函数来处理拍照结果
    var onCameraCapture: ((UIImage) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择照片")
                .font(.headline)
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                showCamera = true
            }) {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button("取消") {
                dismiss()
            }
            .padding()
        }
        .padding()
        .sheet(isPresented: $showCamera) {
            CameraView(capturedImage: $capturedImage, isShown: $showCamera)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                dismiss() // 关闭选择器
                onCameraCapture?(image) // 调用回调
                capturedImage = nil
            }
        }
    }
}

// 添加相机视图
struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isShown: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.isShown = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isShown = false
        }
    }
}
