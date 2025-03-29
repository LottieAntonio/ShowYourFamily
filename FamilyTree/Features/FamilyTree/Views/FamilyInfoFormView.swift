import SwiftUI
import PhotosUI

struct FamilyInfoFormView: View {
    @Binding var isPresented: Bool
    let onComplete: (String, String, String?, Family.BadgeType, UIImage?) -> Void
    
    @State private var familyName: String = ""
    @State private var familyDescription: String = ""
    @State private var selectedBadgeIndex: Int = 0
    @State private var badgeType: Family.BadgeType = .sfSymbol
    @State private var badgeImageName: String? = "book.closed.fill"
    @State private var customImage: UIImage? = nil
    @State private var showingImagePicker = false
    
    // 默认族徽选项
    private let badgeOptions = Family.defaultBadgeOptions
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("家谱名称", text: $familyName)
                    TextField("家谱描述", text: $familyDescription)
                }
                
                Section(header: Text("选择族徽")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            // 自定义上传选项
                            CustomBadgeOptionView(
                                image: customImage,
                                isSelected: badgeType == .custom,
                                action: {
                                    showingImagePicker = true
                                    badgeType = .custom
                                    badgeImageName = nil
                                }
                            )
                            
                            // 默认族徽选项
                            ForEach(0..<badgeOptions.count, id: \.self) { index in
                                let option = badgeOptions[index]
                                BadgeOptionView(
                                    option: option,
                                    isSelected: selectedBadgeIndex == index && badgeType != .custom,
                                    action: {
                                        selectedBadgeIndex = index
                                        badgeType = option.type
                                        badgeImageName = option.name
                                        customImage = nil
                                        
                                        // 添加调试信息
                                        print("选择了族徽: \(index), 类型: \(option.type), 名称: \(option.name)")
                                    }
                                )
                            }
                            
                            
                        }
                        .padding(.vertical, 10)
                    }
                    .frame(height: 100)
                }
                
                Section(header: Text("预览")) {
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
            }
            .navigationTitle("创建家谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(Color.familyTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        // 添加调试信息
                        print("提交表单 - 族徽类型: \(badgeType), 族徽名称: \(badgeImageName ?? "无"), 选中索引: \(selectedBadgeIndex)")
                        
                        onComplete(familyName, familyDescription, badgeImageName, badgeType, customImage)
                        isPresented = false
                    }
                    .disabled(familyName.isEmpty)
                    .foregroundColor(Color.familyTheme.primary)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $customImage, sourceType: .photoLibrary)
            }
        }
        .onAppear {
            // 重置为默认值，确保每次打开表单时都是初始状态
            selectedBadgeIndex = 0
            badgeType = .sfSymbol
            badgeImageName = "book.closed.fill"
            customImage = nil
        }
    }
}

// 族徽选项视图
struct BadgeOptionView: View {
    let option: (name: String, type: Family.BadgeType)
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.familyTheme.primary.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                if option.type == .custom {
                    // 从Assets加载自定义图片
                    Image(option.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else if option.type == .sfSymbol {
                    Image(systemName: option.name)
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? Color.familyTheme.primary : .gray)
                } else if option.type == .emoji {
                    Text(option.name)
                        .font(.system(size: 30))
                }
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.familyTheme.primary, lineWidth: 2)
                        .frame(width: 70, height: 70)
                }
            }
        }
    }
}

// 自定义上传族徽选项
struct CustomBadgeOptionView: View {
    let image: UIImage?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.familyTheme.primary.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? Color.familyTheme.primary : .gray)
                }
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.familyTheme.primary, lineWidth: 2)
                        .frame(width: 70, height: 70)
                }
            }
        }
    }
}

// 族徽预览视图
struct BadgePreviewView: View {
    let badgeType: Family.BadgeType
    let badgeImageName: String?
    let customImage: UIImage?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.familyTheme.primary.opacity(0.1))
                .frame(width: 120, height: 120)
            
            if badgeType == .custom {
                if let image = customImage {
                    // 显示上传的自定义图片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let name = badgeImageName {
                    // 从Assets加载自定义图片
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
            } else if badgeType == .sfSymbol, let name = badgeImageName {
                Image(systemName: name)
                    .font(.system(size: 60))
                    .foregroundColor(Color.familyTheme.primary)
            } else if badgeType == .emoji, let emoji = badgeImageName {
                Text(emoji)
                    .font(.system(size: 60))
            }
        }
    }
}

// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
