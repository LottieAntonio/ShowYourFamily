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
    
    // 添加图片用途标记，用于跟踪图片是否已被用作头像或背景
    private var imageUsage: [UUID: Set<String>] = [:]
    
    // 添加编辑状态跟踪
    private var editingStates: [UUID: Bool] = [:]
    // 添加编辑前的备份图片
    private var editBackupImages: [UUID: UIImage] = [:]
    private var editBackupData: [UUID: Data] = [:]
    
    // 添加图片来源标记，用于跟踪图片的来源（数据库或临时）
    private var imageSource: [UUID: String] = [:]
    
    private init() {}
    
    func setImage(for personId: UUID, image: UIImage, data: Data, source: String = "cache") {
        personImages[personId] = image
        personImageData[personId] = data
        lastUpdateTimestamps[personId] = Date()
        imageSource[personId] = source
        
        // 发布更新通知
        lastUpdatedPersonId = personId
        print("ImagePickerManager: 已更新图片，personId: \(personId), 来源: \(source)")
        
        // 发送通知，让所有依赖此图片的视图更新
        NotificationCenter.default.post(
            name: NSNotification.Name("ImageUpdated"),
            object: nil,
            userInfo: ["personId": personId, "source": source]
        )
    }
    
    // 标记图片用途
    func markImageUsage(for personId: UUID, usage: String) {
        if imageUsage[personId] == nil {
            imageUsage[personId] = []
        }
        imageUsage[personId]?.insert(usage)
    }
    
    // 检查图片用途
    func isImageUsedFor(personId: UUID, usage: String) -> Bool {
        return imageUsage[personId]?.contains(usage) ?? false
    }
    
    func getImage(for personId: UUID) -> UIImage? {
        if let image = personImages[personId] {
            print("使用缓存的图片，personId: \(personId)")
            return image
        }
        return nil
    }
    
    func getImageData(for personId: UUID) -> Data? {
        return personImageData[personId]
    }
    
    // 获取图片来源
    func getImageSource(for personId: UUID) -> String {
        return imageSource[personId] ?? "unknown"
    }
    
    // 添加开始编辑方法
    func beginEditing(for personId: UUID) {
        // 备份当前图片
        if let image = personImages[personId], let data = personImageData[personId] {
            editBackupImages[personId] = image
            editBackupData[personId] = data
            print("已备份编辑前的图片，personId: \(personId)")
        }
        
        editingStates[personId] = true
        print("开始编辑图片，personId: \(personId)")
    }
    
    // 添加取消编辑方法
    func cancelEditing(for personId: UUID) {
        // 恢复备份的图片
        if let image = editBackupImages[personId], let data = editBackupData[personId] {
            personImages[personId] = image
            personImageData[personId] = data
            print("已恢复编辑前的图片，personId: \(personId)")
            
            // 发送通知
            lastUpdatedPersonId = personId
            NotificationCenter.default.post(
                name: NSNotification.Name("ImageUpdated"),
                object: nil,
                userInfo: ["personId": personId, "restored": true]
            )
        }
        
        // 清除编辑状态
        editingStates[personId] = false
        editBackupImages.removeValue(forKey: personId)
        editBackupData.removeValue(forKey: personId)
        print("已取消编辑，personId: \(personId)")
    }
    
    // 添加完成编辑方法
    func finishEditing(for personId: UUID) {
        // 清除编辑状态和备份
        editingStates[personId] = false
        editBackupImages.removeValue(forKey: personId)
        editBackupData.removeValue(forKey: personId)
        print("已完成编辑，personId: \(personId)")
    }
    
    // 检查是否正在编辑
    func isEditing(personId: UUID) -> Bool {
        return editingStates[personId] ?? false
    }
    
    // 修改清除缓存方法，添加更多保护
    func clearCache(for personId: UUID) {
        // 如果正在编辑，不清除缓存
        if editingStates[personId] == true {
            print("正在编辑图片，跳过清除缓存: \(personId)")
            return
        }
        
        // 检查是否有最近更新的图片数据
        if let timestamp = lastUpdateTimestamps[personId], 
           Date().timeIntervalSince(timestamp) < 5.0 {
            print("图片刚刚更新，跳过清除缓存: \(personId)")
            return
        }
        
        personImages.removeValue(forKey: personId)
        personImageData.removeValue(forKey: personId)
        lastUpdateTimestamps.removeValue(forKey: personId)
        imageSource.removeValue(forKey: personId)
        imageUsage.removeValue(forKey: personId)
        print("ImagePickerManager: 已清除缓存，personId: \(personId)")
    }
    
    // 添加一个方法，从数据库强制刷新图片
    func refreshFromDatabase(for personId: UUID, photoData: Data?) {
        // 如果正在编辑，不刷新
        if editingStates[personId] == true {
            print("正在编辑图片，跳过从数据库刷新: \(personId)")
            return
        }
        
        // 如果有数据，更新缓存
        if let data = photoData, let image = UIImage(data: data) {
            setImage(for: personId, image: image, data: data, source: "database")
            print("从数据库刷新图片到缓存，personId: \(personId)")
        } else {
            // 如果没有数据，清除缓存
            clearCache(for: personId)
        }
    }
    
    // 添加一个方法检查缓存是否有效
    func isCacheValid(for personId: UUID) -> Bool {
        if let timestamp = lastUpdateTimestamps[personId] {
            // 如果缓存时间在30分钟内，认为有效
            return Date().timeIntervalSince(timestamp) < 1800.0
        }
        return false
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
        avatarButton
            .disabled(!isEditable)
            .sheet(isPresented: $showPicker, onDismiss: handlePickerDismiss) {
                PhotoPickerSheet(
                    selectedItem: $selectedItem,
                    gender: person.gender,
                    onCameraCapture: handleCameraCapture,
                    onDefaultAvatarSelected: handleDefaultAvatarSelected
                )
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showImageEditor, onDismiss: handleEditorDismiss) {
                ImageEditorView(image: $imageToEdit, onCancel: {
                    // 用户点击取消按钮
                    print("用户点击了取消按钮，恢复原始图片")
                    pickerManager.cancelEditing(for: person.id)
                    imageToEdit = nil
                    showImageEditor = false
                }) { editedImage in
                    handleEditedImage(editedImage)
                }
//                .edgesIgnoringSafeArea(.all)
            }
            .onChange(of: selectedItem) { _, newItem in
                handleSelectedItemChange(newItem)
            }
            .onChange(of: pickerManager.lastUpdatedPersonId) { _, updatedId in
                handleImageUpdate(updatedId)
            }
            .onAppear {
                handleOnAppear()
            }
            .onDisappear {
                print("PersonAvatarView消失，personId: \(person.id)")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TempPhotoUpdated"))) { notification in
                handleTempPhotoUpdate(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EditorImageUpdated"))) { notification in
                handleEditorImageUpdate(notification)
            }
    }

    // 添加处理编辑后图片的方法
    private func handleEditedImage(_ editedImage: UIImage) {
        print("图片编辑完成，personId: \(person.id)")
        
        if let imageData = editedImage.jpegData(compressionQuality: 0.8) {
            // 判断是否是add模式
            let isAddMode = person.id == UUID.init(uuidString: "00000000-0000-0000-0000-000000000000")
            
            if isAddMode {
                handleAddModeImageEdit(editedImage, imageData)
            } else {
                handleNormalModeImageEdit(editedImage, imageData)
            }
        }
        
        // 重置状态
        imageToEdit = nil
        showImageEditor = false
    }
    
    private func handleAddModeImageEdit(_ editedImage: UIImage, _ imageData: Data) {
        // 在add模式下，检查是否已有临时ID
        if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
           let tempId = UUID(uuidString: tempIdString) {
            // 使用现有的临时ID
            print("Add模式: 使用现有临时ID: \(tempId)")
            
            // 保存到管理器
            pickerManager.setImage(for: tempId, image: editedImage, data: imageData)
            print("Add模式: 更新临时ID的图片: \(tempId)")
            
            callPhotoSelectedCallback(imageData)
        } else {
            // 如果没有临时ID，创建一个新的
            let tempId = UUID()
            print("Add模式: 创建新的临时ID: \(tempId)")
            
            // 保存到管理器
            pickerManager.setImage(for: tempId, image: editedImage, data: imageData)
            
            // 更新UserDefaults中的临时ID
            UserDefaults.standard.set(tempId.uuidString, forKey: "TempPersonPhotoId")
            print("Add模式: 更新临时ID到UserDefaults: \(tempId)")
            
            callPhotoSelectedCallback(imageData)
        }
    }
    
    private func handleNormalModeImageEdit(_ editedImage: UIImage, _ imageData: Data) {
        // 正常模式，保存到person的ID
        pickerManager.setImage(for: person.id, image: editedImage, data: imageData)
        
        // 标记编辑完成
        pickerManager.finishEditing(for: person.id)
        
        callPhotoSelectedCallback(imageData)
    }
    
    private func callPhotoSelectedCallback(_ imageData: Data) {
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

    // 添加处理默认头像选择的方法
    private func handleDefaultAvatarSelected(_ image: UIImage) {
        print("选择了默认头像，personId: \(person.id)")
        
        // 直接处理默认头像，跳过编辑器
        if let imageData = image.pngData() {  // 使用PNG格式保留透明度
            // 判断是否是add模式
            let isAddMode = person.id == UUID.init(uuidString: "00000000-0000-0000-0000-000000000000")
            
            if isAddMode {
                // 在add模式下，检查是否已有临时ID
                if let tempIdString = UserDefaults.standard.string(forKey: "TempPersonPhotoId"),
                let tempId = UUID(uuidString: tempIdString) {
                    // 使用现有的临时ID
                    print("Add模式: 使用现有临时ID: \(tempId)")
                    
                    // 保存到管理器
                    pickerManager.setImage(for: tempId, image: image, data: imageData, source: "default")
                    print("Add模式: 更新临时ID的默认头像: \(tempId)")
                    
                    callPhotoSelectedCallback(imageData)
                } else {
                    // 如果没有临时ID，创建一个新的
                    let tempId = UUID()
                    print("Add模式: 创建新的临时ID: \(tempId)")
                    
                    // 保存到管理器
                    pickerManager.setImage(for: tempId, image: image, data: imageData, source: "default")
                    
                    // 更新UserDefaults中的临时ID
                    UserDefaults.standard.set(tempId.uuidString, forKey: "TempPersonPhotoId")
                    print("Add模式: 更新临时ID到UserDefaults: \(tempId)")
                    
                    callPhotoSelectedCallback(imageData)
                }
            } else {
                // 正常模式，保存到person的ID
                pickerManager.setImage(for: person.id, image: image, data: imageData, source: "default")
                
                // 标记编辑完成
                pickerManager.finishEditing(for: person.id)
                
                callPhotoSelectedCallback(imageData)
            }
        }
    }
    
    // MARK: - 子视图
    
    private var avatarButton: some View {
        Button(action: {
            if isEditable {
                print("头像被点击，准备显示图片选择器，personId: \(person.id)")
                pickerManager.beginEditing(for: person.id)
                showPicker = true
            }
        }) {
            avatarContent
        }
    }
    
    private var avatarContent: some View {
        ZStack {
            Circle()
                .fill(Color.familyTheme.gradientFor(type ?? .spouse))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            avatarImage
            
            // 如果是可编辑状态，添加编辑指示器
            if isEditable {
                editIndicator
            }
        }
        .id(refreshID) // 使用ID修饰符来强制刷新视图
    }
    
    // MARK: - 事件处理方法 (将在后续步骤实现)
    
    private func handlePickerDismiss() {
        // 如果没有进入编辑器，说明用户取消了选择，需要恢复原始图片
        if !showImageEditor {
            print("用户取消了图片选择，恢复原始图片")
            pickerManager.cancelEditing(for: person.id)
        }
    }
    
    private func handleEditorDismiss() {
        // 如果 imageToEdit 仍然存在，说明用户取消了编辑，需要恢复原始图片
        if imageToEdit != nil {
            print("用户取消了图片编辑，恢复原始图片")
            pickerManager.cancelEditing(for: person.id)
            imageToEdit = nil
        }
    }
    
    private func handleCameraCapture(_ image: UIImage) {
        // 拍照后直接进入编辑模式
        imageToEdit = image
        showPicker = false
        showImageEditor = true
    }
    
    private func handleSelectedItemChange(_ newItem: PhotosPickerItem?) {
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
    private func handleImageUpdate(_ updatedId: UUID?) {
        if let updatedId = updatedId, updatedId == person.id {
            print("检测到图片更新，刷新视图，personId: \(person.id)")
            refreshID = UUID()
        }
    }
    
    private func handleOnAppear() {
        print("PersonAvatarView出现，isEditable: \(isEditable), personId: \(person.id)")
        
        // 确保缓存与数据库同步
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
    
    private func handleTempPhotoUpdate(_ notification: Notification) {
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
    
    private func handleEditorImageUpdate(_ notification: Notification) {
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
    // 在 PersonAvatarView 结构体内添加
        
    private var avatarImage: some View {
        Group {
            if let image = pickerManager.getImage(for: person.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
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
                    .scaledToFill()
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
                // 根据性别显示不同的默认头像
                if let defaultImage = UIImage(named: person.gender == .male ? "person1" : "person5") {
                    Image(uiImage: defaultImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    // 如果默认头像加载失败，显示名字首字母作为备选
                    Text(person.name.prefix(1))
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var editIndicator: some View {
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

// 单独的照片选择器视图
struct PhotoPickerSheet: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    let gender: Person.Gender // 添加性别参数，用于筛选合适的默认头像
    
    // 添加一个回调函数来处理拍照结果
    var onCameraCapture: ((UIImage) -> Void)?
    // 添加一个回调函数来处理默认头像选择
    var onDefaultAvatarSelected: ((UIImage) -> Void)?
    
    // 默认头像名称列表
    private let defaultAvatarNames = [
        "person1", "person2", "person3",
        "person4", "person5", "person6",
        "emoji4", "emoji7", "emoji8", "emoji9"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("选择照片")
                    .font(.headline)
                
                // 添加默认头像选择区域
                VStack(alignment: .leading, spacing: 10) {
                    Text("默认头像")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        // 显示所有默认头像
                        ForEach(defaultAvatarNames, id: \.self) { imageName in
                            if let image = UIImage(named: imageName) {
                                Button {
                                    onDefaultAvatarSelected?(image)
                                    dismiss()
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical)
                
                // 原有的相册和拍照选项
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
        }
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


