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
            ScrollView {
                VStack(spacing: 20) {
                    // 家族徽章/图标区域
                    familyBadgeSection
                    
                    // 家族信息区域
                    familyInfoSection
                    
                    // 功能区域
                    featuresSection
                    
                    // 进入家谱按钮
                    enterFamilyTreeButton
                }
                .padding()
            }
            .navigationTitle(family.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFamilyEditor = true
                    }) {
                        Image(systemName: "pencil")
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
        VStack {
            // 这里可以是用户自定义的族徽
            // 暂时使用系统图标，后续可以替换为自定义图片
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
            }
            .padding()
            
            Text("家族徽章")
                .font(.headline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var familyInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("家族信息")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                Text("家族名称:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(family.name)
                    .bold()
            }
            
            Divider()
            
            HStack {
                Text("成员数量:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(appViewModel.familyManager.memberCount) 位成员")
            }
            
            Divider()
            
            HStack(alignment: .top) {
                Text("家族描述:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(family.description ?? "暂无描述")
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("家族服务")
                .font(.headline)
                .padding(.bottom, 5)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                featureButton(title: "族徽定制", icon: "paintbrush.fill", action: {
                    // 族徽定制功能
                })
                
                featureButton(title: "家族起名", icon: "text.book.closed.fill", action: {
                    // 家族起名功能
                })
                
                featureButton(title: "族谱定制", icon: "doc.text.fill", action: {
                    // 族谱定制功能
                })
                
                featureButton(title: "家族用品", icon: "gift.fill", action: {
                    // 家族用品功能
                })
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private func featureButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 5)
                
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var enterFamilyTreeButton: some View {
        Button(action: {
            showingContentView = true
        }) {
            HStack {
                Image(systemName: "person.2.fill")
                Text("进入家谱")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}