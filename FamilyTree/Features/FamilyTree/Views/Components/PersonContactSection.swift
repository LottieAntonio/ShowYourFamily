import SwiftUI
import Foundation  // 如果需要的话

// 在文件顶部确保导入了 ContactInfo
// 如果 ContactInfo 在同一个模块中，可能不需要额外导入

struct PersonContactSection: View {
    @ObservedObject var viewModel: PersonCardViewModel
    @State private var showingContactEditor = false
    @State private var tempContacts: PersonCardState.ContactInfo
    @State private var isContactEnabled: Bool
    
    init(viewModel: PersonCardViewModel) {
        self.viewModel = viewModel
        _tempContacts = State(initialValue: viewModel.state.contacts)
        _isContactEnabled = State(initialValue: viewModel.state.contacts.isEnabled)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.red.opacity(0.1))
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.isEditable {
                    Toggle("添加联系方式", isOn: $isContactEnabled)
                        .font(.headline)
                        .onChange(of: isContactEnabled) { oldValue, newValue in
                            Task {
                                await viewModel.updateContactsEnabled(newValue)
                            }
                        }
                    
                    if viewModel.state.contacts.isEnabled {
                        Button(action: {
                            tempContacts = viewModel.state.contacts
                            showingContactEditor = true
                        }) {
                            Text(viewModel.state.contacts.isEmpty ? "添加联系信息" : "编辑联系信息")
                        }
                    }
                } else {
                    Text("联系方式")
                        .font(.headline)
                    
                    if viewModel.state.contacts.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            ContactItem(label: "电话", value: viewModel.state.contacts.phone)
                            ContactItem(label: "微信", value: viewModel.state.contacts.wechat)
                            ContactItem(label: "地址", value: viewModel.state.contacts.address)
                            ContactItem(label: "邮箱", value: viewModel.state.contacts.email)
                            ContactItem(label: "QQ", value: viewModel.state.contacts.qq)
                        }
                    } else {
                        Text("未添加联系方式")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(30)
            .sheet(isPresented: $showingContactEditor) {
                NavigationView {
                    Form {
                        Section {
                            TextField("手机号码", text: $tempContacts.phone)
                                .keyboardType(.phonePad)
                            TextField("微信", text: $tempContacts.wechat)
                            TextField("地址", text: $tempContacts.address)
                            TextField("邮箱", text: $tempContacts.email)
                                .keyboardType(.emailAddress)
                            TextField("QQ", text: $tempContacts.qq)
                                .keyboardType(.numberPad)
                        }
                    }
                    .navigationTitle("编辑联系方式")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                // 取消时重置临时数据
                                tempContacts = viewModel.state.contacts
                                showingContactEditor = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                Task {
                                    // 使用异步方法更新
                                    await viewModel.updateContacts(tempContacts)
                                    showingContactEditor = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// 删除这里的 ContactInfo 结构体定义

private struct ContactItem: View {
    let label: String
    let value: String
    
    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(value)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}


