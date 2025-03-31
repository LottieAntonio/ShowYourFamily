import SwiftUI
import PhotosUI

struct FamilyEditorView: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    let family: Family
    
    @State private var name: String
    @State private var description: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    // 添加族徽相关状态
    @State private var badgeType: Family.BadgeType
    @State private var badgeImageName: String?
    @State private var customImage: UIImage?
    @State private var selectedBadgeIndex: Int = 0
    @State private var showingImagePicker = false
    
    // 默认族徽选项
    private let badgeOptions = Family.defaultBadgeOptions
    
    init(family: Family) {
        self.family = family
        _name = State(initialValue: family.name)
        _description = State(initialValue: family.description ?? "")
        _badgeType = State(initialValue: family.badgeType)
        _badgeImageName = State(initialValue: family.badgeImageName)
        _customImage = State(initialValue: family.badgeImage)
        
        // 设置初始选中的徽章索引
        if family.badgeType == .custom {
            _selectedBadgeIndex = State(initialValue: -1)
        } else if let imageName = family.badgeImageName {
            let index = Family.defaultBadgeOptions.firstIndex { $0.name == imageName && $0.type == family.badgeType } ?? 0
            _selectedBadgeIndex = State(initialValue: index)
        }
    }
    
    // 添加键盘相关状态
    @FocusState private var focusedField: FocusField?
    
    // 定义可聚焦的字段
    enum FocusField {
        case name, description
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("家族名称", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }
                    
                    TextField("家族描述", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                        .lineLimit(3...6)
                }
                
                Section(header: Text("家族徽章")) {
                    // 族徽选择器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {

                            // 自定义上传选项
                            // 修改 CustomBadgeOptionView 的 isSelected 条件
                            CustomBadgeOptionView(
                                image: customImage,
                                isSelected: badgeType == .custom && (customImage != nil || showingImagePicker),
                                action: {
                                    showingImagePicker = true
                                    badgeType = .custom
                                    badgeImageName = nil
                                    // 重置选中索引，确保其他选项不会显示为选中
                                    selectedBadgeIndex = -1
                                }
                            )
                            
                            // 默认族徽选项
                            ForEach(0..<badgeOptions.count, id: \.self) { index in
                                let option = badgeOptions[index]
                                BadgeOptionView(
                                    option: option,
                                    isSelected: selectedBadgeIndex == index && badgeType == option.type,
                                    action: {
                                        selectedBadgeIndex = index
                                        badgeType = option.type
                                        badgeImageName = option.name
                                        customImage = nil
                                    }
                                )
                            }
                           
                        }
                        .padding(.vertical, 10)
                    }
                    .frame(height: 100)
                    
                    // 预览区域
                    HStack {
                        Spacer()
                        BadgePreviewView(
                            badgeType: badgeType,
                            badgeImageName: badgeImageName,
                            customImage: customImage
                        )
                        Spacer()
                    }
                    .frame(height: 150)
                    .padding(.vertical, 10)
                }
                
                // 添加删除家谱的部分
                if !family.isDefault {
                    Section {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("删除家谱")
                                    .foregroundColor(Color.red)
                                Spacer()
                            }
                        }
                    }
                    .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("删除", role: .destructive) {
                            deleteFamily()
                        }
                    } message: {
                        Text("您确定要删除这个家谱吗？此操作不可撤销，所有家谱数据将被永久删除。")
                    }
                }
            }
            .navigationTitle("编辑家族信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
                
                // 修改键盘工具栏部分
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
//            .dismissKeyboardOnTap()
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotosPicker(selection: Binding<PhotosPickerItem?>(
                    get: { nil },
                    set: { item in
                        if let item = item {
                            loadTransferable(from: item)
                        }
                    }
                ), matching: .images) {
                    Text("选择图片")
                }
            }
        }
    }
    
    // 加载图片
    private func loadTransferable(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        // 添加图像压缩处理
                        let resizedImage = self.resizeImage(image, targetSize: CGSize(width: 300, height: 300))
                        self.customImage = resizedImage
                        self.badgeType = .custom
                        self.badgeImageName = nil
                    }
                case .failure(let error):
                    print("图片加载失败: \(error)")
                    self.errorMessage = "图片加载失败"
                    self.showingError = true
                }
            }
        }
    }
    
    // 添加图像压缩方法
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        // 计算缩放比例
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // 使用较小的比例，保持宽高比
        let scaleFactor = min(widthRatio, heightRatio)
        
        // 如果图像已经小于目标尺寸，不需要缩放
        if scaleFactor >= 1 {
            return image
        }
        
        // 计算新尺寸
        let scaledWidth  = size.width * scaleFactor
        let scaledHeight = size.height * scaleFactor
        let targetRect = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        
        // 绘制缩放后的图像
        UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
        image.draw(in: targetRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 压缩图像质量
        if let newImage = newImage,
           let compressedData = newImage.jpegData(compressionQuality: 0.7),
           let compressedImage = UIImage(data: compressedData) {
            return compressedImage
        }
        
        return newImage ?? image
    }
    
    private func saveChanges() {
        Task {
            do {
                var updatedFamily = family
                updatedFamily.name = name
                updatedFamily.description = description.isEmpty ? nil : description
                updatedFamily.badgeType = badgeType
                updatedFamily.badgeImageName = badgeImageName
                updatedFamily.badgeImage = customImage
                
                // 打印调试信息
                print("保存家谱信息 - ID: \(updatedFamily.id), 名称: \(updatedFamily.name), 族徽类型: \(updatedFamily.badgeType), 族徽名称: \(updatedFamily.badgeImageName ?? "无")")
                
                try await appViewModel.familyManager.updateFamily(updatedFamily)
                
                // 确保发送通知
                await MainActor.run {
                    // 手动发送通知，确保即使 FamilyManagementViewModel 中没有发送通知也能更新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("FamilyUpdated"),
                        object: nil,
                        userInfo: ["familyId": family.id]
                    )
                    
                    // 关闭当前编辑页面
                    dismiss()
                    
                    // 发送一个自定义通知，让 FamilyHomePage 也关闭并返回到 FamilySelectionView
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ReturnToFamilySelection"),
                        object: nil
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deleteFamily() {
        Task {
            do {
                try await appViewModel.familyManager.deleteFamily(family.id)
                await MainActor.run {
                    // 修改这里：不仅关闭当前编辑页面，还需要通知 FamilyHomePage 返回到选择页面
                    NotificationCenter.default.post(name: .familyDeleted, object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
