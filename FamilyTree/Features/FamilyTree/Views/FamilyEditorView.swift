import SwiftUI

struct FamilyEditorView: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    let family: Family
    
    @State private var name: String
    @State private var description: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    init(family: Family) {
        self.family = family
        _name = State(initialValue: family.name)
        _description = State(initialValue: family.description ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("家族名称", text: $name)
                    
                    TextField("家族描述", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("家族徽章")) {
                    // 这里可以添加图片选择器
                    // 暂时使用占位符
                    HStack {
                        Spacer()
                        VStack {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                            
                            Text("点击选择图片")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
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
                                    .foregroundColor(.red)
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
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                var updatedFamily = family
                updatedFamily.name = name
                updatedFamily.description = description.isEmpty ? nil : description
                
                try await appViewModel.familyManager.updateFamily(updatedFamily)
                await MainActor.run {
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