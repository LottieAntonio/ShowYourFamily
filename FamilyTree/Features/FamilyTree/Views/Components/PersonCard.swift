
/*
 * PersonCard 视图
 * 作用：人物信息卡片的主视图
 * - 显示完整的人物信息
 * - 处理编辑和删除操作
 * - 管理设置自己的功能
 */

import SwiftUI

struct PersonCard: View {
    @StateObject private var viewModel: PersonCardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingSetSelfAlert = false  // 添加设置自己的 alert 状态
    @State private var showingSetSelfSuccessAlert = false  // 添加设置成功的 alert 状态
    @State private var isSettingSelf = false  // 添加设置中状态
    
    // 删除 showingConfirmation
    
    init(person: Person?, mode: PersonCardMode, managementViewModel: PersonManagementViewModel) {
        _viewModel = StateObject(wrappedValue: PersonCardViewModel(
            person: person,
            mode: mode,
            managementViewModel: managementViewModel
        ))
    }
    
    var body: some View {
        VStack() {
            PersonBasicInfoSection(viewModel: viewModel)

            if viewModel.mode == .edit {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("删除人物", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .padding(.top)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.mode != .view {
                    Button("保存", action: save)
                        .disabled(!viewModel.isValid)
                }
            }
            
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.mode != .view {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        // 删除确认设置的 alert
        .alert("错误", isPresented: $showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        
        // 添加删除确认对话框
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if viewModel.currentPerson != nil {
                    Task {
                        do {
                            try await viewModel.deletePerson()
                            dismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("删除后将无法恢复，是否确认删除？")
        }
        
        // 修改设置自己的确认对话框
        .alert("设置为自己", isPresented: $showingSetSelfAlert) {
            Button("取消", role: .cancel) { 
                print("❌ 取消设置自己")
            }
            Button("确定") {
                print("✅ 确认设置自己")
                Task {
                    print("⏳ 开始执行 setSelfPerson")
                    try? await viewModel.setSelfPerson()
                    print("⏳ 重新加载数据")
                    await viewModel.reloadData()  // 修改这行，使用 viewModel 的方法
                    print("✅ setSelfPerson 执行完成")
                    dismiss()
                }
            }
        } message: {
            Text("确认将此人设置为自己吗？\n所有的自定义称呼都被将重置")
        }
        
        // 添加设置成功的提示对话框
        .alert("设置成功", isPresented: $showingSetSelfSuccessAlert) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("已成功将此人设置为自己")
        }
        
        // 添加删除确认对话框
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if viewModel.currentPerson != nil {
                    Task {
                        do {
                            try await viewModel.deletePerson()
                            dismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("删除后将无法恢复，是否确认删除？")
        }
    }
    
    private var navigationTitle: String {
        switch viewModel.mode {
        case .view:
            return "个人信息"
        case .edit:
            return "编辑信息"
        case .add:
            return "添加成员"
        }
    }
    
    private func save() {
        Task {
            do {
                try await viewModel.save()
                dismiss()
            } catch {
                showingAlert = true
            }
        }
    }
    
    private func deletePerson() {
        Task {
            do {
                try await viewModel.deletePerson()  // 修改这里，使用 deletePerson 而不是 delete
                dismiss()
            } catch {
                showingAlert = true
            }
        }
    }
}




