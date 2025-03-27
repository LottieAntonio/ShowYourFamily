import SwiftUI

struct FamilyHomePage: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Environment(\.dismiss) private var dismiss
    let family: Family
    
    @State private var showingContentView = false
    @State private var showingFamilyEditor = false
    @State private var shouldDismiss = false
    
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
            .sheet(isPresented: $showingFamilyEditor) {
                FamilyEditorView(family: family)
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
    }
    
    private var familyBadgeSection: some View {
        // 这里可以是用户自定义的族徽
        // 暂时使用系统图标，后续可以替换为自定义图片
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 200, height: 200)
            
            Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
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
