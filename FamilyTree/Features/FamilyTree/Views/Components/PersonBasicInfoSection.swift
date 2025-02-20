
/*
 * PersonBasicInfoSection 视图
 * 作用：显示和编辑人物基本信息
 * - 显示人物头像和姓名
 * - 编辑基本信息
 * - 显示称谓
 */

import SwiftUI

struct PersonBasicInfoSection: View {
    @ObservedObject var viewModel: PersonCardViewModel
    @State private var lastName: String
    @State private var firstName: String
    @State private var gender: Person.Gender
    @State private var birthDate: Date
    @State private var notes: String
    
    // 将 dateFormatter 移到这里
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
    
    init(viewModel: PersonCardViewModel) {
        self.viewModel = viewModel
        // 使用 State 初始化
        _lastName = State(initialValue: viewModel.state.basicInfo.lastName)
        _firstName = State(initialValue: viewModel.state.basicInfo.firstName)
        _gender = State(initialValue: viewModel.state.basicInfo.gender)
        _birthDate = State(initialValue: viewModel.state.basicInfo.birthDate ?? Date())
        _notes = State(initialValue: viewModel.state.basicInfo.notes)
    }
    
    // 添加状态变量
    @State private var showingSetSelfAlert = false
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    var body: some View {
        ZStack(alignment: viewModel.isEditable ? .top : .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
            VStack (alignment: .center, spacing: 20) {
                if !viewModel.isEditable {
                    FamilySealView(
                        lastName: viewModel.state.basicInfo.lastName,
                        totalMembers: viewModel.personManagementViewModel.persons.count
                    )
                }

                VStack {
                    
                    if !viewModel.isEditable {
                        HStack(spacing: 10) {
                            Button {
                                // 后续添加头像选择功能
                            } label: {
                                PersonAvatarView(
                                    person: viewModel.currentPerson ?? Person(firstName: "", lastName: "", gender: .male),
                                    size: 60,
                                    type: nil,
                                    isEditable: false
                                )
                            }
                            
                            VStack(alignment: .leading) {
                                Text("\(viewModel.state.basicInfo.lastName)\(viewModel.state.basicInfo.firstName)")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                if viewModel.isSelfPerson {
                                    let notes = "自己"
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else if !notes.isEmpty {
                                    Text(viewModel.state.basicInfo.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(nil)
                                } else {
                                    Text(viewModel.displayTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(nil)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.familyTheme.secondary.opacity(0.3))
                                .shadow(
                                    color: Color.familyTheme.primary.opacity(0.10),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        }
                    } else {
                        VStack{
                            Button {
                                // 后续添加头像选择功能
                            } label: {
                                PersonAvatarView(
                                    person: viewModel.currentPerson ?? Person(firstName: "", lastName: "", gender: .male),
                                    size: 80,
                                    type: nil,
                                    isEditable: true
                                )
                            }
                            HStack {
                                VStack(alignment: .leading) {
                                    TextField("姓", text: $lastName)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: lastName) { _, newValue in
                                            Task {
                                                await viewModel.updateLastName(newValue)
                                            }
                                        }
                                    TextField("名", text: $firstName)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: firstName) { _, newValue in
                                            Task {
                                                await viewModel.updateFirstName(newValue)
                                            }
                                        }
                                }
                                TextField("自定义称呼（留空则自动生成）", text: $notes, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .onChange(of: notes) { _, newValue in
                                        Task {
                                            await viewModel.updateNotes(newValue)
                                        }
                                    }
                                
                            }
                            
                            Picker("性别", selection: $gender) {
                                Text("男").tag(Person.Gender.male)
                                Text("女").tag(Person.Gender.female)
                            }
                            .pickerStyle(.segmented)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: gender) { _, newValue in
                                Task {
                                    await viewModel.updateGender(newValue)
                                }
                            }
                            
                            DatePicker(
                                "出生日期",
                                selection: $birthDate,
                                displayedComponents: .date
                            )
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: birthDate) { _, newValue in
                                Task {
                                    await viewModel.updateBirthDate(newValue)
                                }
                            }
                        }
                        .padding(30)
                    }
                    
                }
            }
        }
        .onReceive(viewModel.$state) { newState in
            // 当 ViewModel 状态更新时，同步本地状态
            lastName = newState.basicInfo.lastName
            firstName = newState.basicInfo.firstName
            gender = newState.basicInfo.gender
            if let date = newState.basicInfo.birthDate {
                birthDate = date
            }
            notes = newState.basicInfo.notes
        }
        // 删除 objectWillChange 监听器
        .alert("设置为自己", isPresented: $showingSetSelfAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task {
                    try await viewModel.setSelfPerson()  // 修改这里：移除 $ 并添加 ()
                }
            }
        } message: {
            Text("确定将此人设置为自己吗？这将重置所有亲属关系的称呼。")
        }
    }
}

// 添加 Toast 组件
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.top, 20)
    }
}

#Preview("基本信息") {
    let familyViewModel = FamilyTreeViewModel()
    PersonBasicInfoSection(
        viewModel: PersonCardViewModel(
            person: Person(firstName: "三", lastName: "张", gender: .male),
            mode: .edit,
            managementViewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel)
        )
    )
    .padding()
}

#Preview("基本信息-查看模式") {
    let familyViewModel = FamilyTreeViewModel()
    PersonBasicInfoSection(
        viewModel: PersonCardViewModel(
            person: Person(firstName: "三", lastName: "张", gender: .male),
            mode: .view,
            managementViewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel)
        )
    )
    .padding()
}
