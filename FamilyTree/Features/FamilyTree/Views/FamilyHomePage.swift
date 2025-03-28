import SwiftUI

struct FamilyHomePage: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    // 将 family 改为 @State 属性，以便可以更新
    let initialFamily: Family
    @State private var family: Family
    
    @State private var showingContentView = false
    @State private var showingFamilyEditor = false
    @State private var shouldDismiss = false
    @State private var refreshID = UUID() // 添加刷新ID
    
    // 修改初始化方法
    init(family: Family) {
        self.initialFamily = family
        self._family = State(initialValue: family)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 内容区域
                ScrollView {
                    VStack(spacing: 25) {
                        // 家族徽章/图标区域
                        familyBadgeSection
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.25)
                        
                        // 家族信息区域
                        familyInfoSection
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                        
                        // 添加底部空间，确保内容不被按钮遮挡
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
                
                // 固定在底部的按钮
                VStack {
                    enterFamilyTreeButton
                        .background(
                            Rectangle()
                                .fill(Color(.clear))
                                .shadow(color: .black.opacity(0.1), radius: 3, y: -2)
                                .edgesIgnoringSafeArea(.bottom)
                        )
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle(family.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true) // 隐藏默认的返回按钮
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.accentColor)
                            .imageScale(.large)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFamilyEditor = true
                    }) {
                        Text("编辑")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingFamilyEditor, onDismiss: {
                // 在编辑页面关闭后，主动刷新数据
                Task {
                    if let updatedFamily = appViewModel.familyManager.families.first(where: { $0.id == family.id }) {
                        await MainActor.run {
                            self.family = updatedFamily
                            self.refreshID = UUID() // 强制视图刷新
                            print("家谱编辑后刷新 - 名称: \(updatedFamily.name), 描述: \(updatedFamily.description ?? "无"), 徽章类型: \(updatedFamily.badgeType), 徽章名称: \(updatedFamily.badgeImageName ?? "无")")
                        }
                    }
                }
            }) {
                // 修改这里，传递当前最新的 family 对象
                FamilyEditorView(family: appViewModel.familyManager.families.first(where: { $0.id == family.id }) ?? family)
                    .environmentObject(appViewModel)
            }
            .navigationDestination(isPresented: $showingContentView) {
                ContentView()
                    .environmentObject(appViewModel)
                    .navigationBarBackButtonHidden()
                    .interactiveDismissDisabled()
                    .onAppear {
                        Task {
                            await appViewModel.familyManager.switchFamily(family)
                        }
                    }
            }
            .onReceive(NotificationCenter.default.publisher(for: .familyDeleted)) { _ in
                // 收到家谱删除通知时，返回到选择页面
                dismiss()
            }
        }
        .id(refreshID) // 添加 id 修饰符，用于强制刷新视图
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FamilyUpdated"))) { notification in
            if let familyId = notification.userInfo?["familyId"] as? UUID, familyId == family.id {
                // 当家谱更新时，刷新视图
                Task {
                    if let updatedFamily = appViewModel.familyManager.families.first(where: { $0.id == family.id }) {
                        // 更新 family 状态变量
                        await MainActor.run {
                            self.family = updatedFamily
                            self.refreshID = UUID() // 更新刷新ID，强制视图重新渲染
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReturnToFamilySelection"))) { _ in
            // 收到返到家谱选择页面的通知时，关闭当前页面
            dismiss()
        }
    }
    
    private var familyBadgeSection: some View {
        // 这里可以是用户自定义的族徽
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 200, height: 200)
            
            if family.badgeType == .custom, let image = family.badgeImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
            } else if family.badgeType == .sfSymbol, let name = family.badgeImageName {
                Image(systemName: name)
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
            } else if family.badgeType == .emoji, let emoji = family.badgeImageName {
                Text(emoji)
                    .font(.system(size: 80))
            } else {
                // 默认图标
                Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, 10)
    }
    
    private var familyInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("家族信息")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.bottom, 5)
            
            HStack {
                Text("家族名称:")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Text(family.name)
                    .bold()
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            HStack {
                Text("成员数量:")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Text("\(appViewModel.familyManager.memberCount) 位成员")
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("家族描述:")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                ScrollView {
                    Text(family.description ?? "暂无描述")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 5)
                }
                .frame(maxHeight: 120)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var enterFamilyTreeButton: some View {
        Button(action: {
            showingContentView = true
        }) {
            HStack {
                Text("进入家谱")
                    .font(.headline)
                    .fontWeight(.bold)
                Image(systemName: "chevron.right.circle.fill")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(25)
            .shadow(color: Color.accentColor.opacity(0.4), radius: 5, x: 0, y: 3)
        }
    }
}

// 添加预览视图
#Preview {
    FamilyHomePage(family: Family.mockFamily)
        .environmentObject(FamilyAppViewModel.preview)
}

// 为了支持预览，在Family模型中添加一个模拟数据
extension Family {
    static var mockFamily: Family {
        var family = Family(name: "张氏家族", description: "这是一个有着悠久历史的家族，始于明朝初年，传承至今已有数百年历史。家族成员遍布全国各地，以诚信、勤劳著称。")
        family.isDefault = false
        return family
    }
}

// 为了支持预览，在FamilyAppViewModel中添加一个预览实例
extension FamilyAppViewModel {
    static var preview: FamilyAppViewModel {
        let viewModel = FamilyAppViewModel()
        // 可以在这里设置一些预览数据
        return viewModel
    }
}
