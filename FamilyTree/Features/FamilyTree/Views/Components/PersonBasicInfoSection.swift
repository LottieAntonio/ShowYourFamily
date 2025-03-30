import SwiftUI

// ReadOnlyPersonInfoView 组件
private struct ReadOnlyPersonInfoView: View {
    let viewModel: PersonCardViewModel
    let notes: String
    
    var body: some View {
        HStack(spacing: 10) {
            // 修改这里，移除Button，直接使用PersonAvatarView
            PersonAvatarView(
                person: viewModel.currentPerson ?? Person(
                    familyId: UUID(),
                    firstName: "",
                    lastName: "",
                    gender: .male
                ),
                size: 50,
                type: nil,
                isEditable: false
            )
            
            VStack(alignment: .leading) {
                Text("\(viewModel.state.basicInfo.lastName)\(viewModel.state.basicInfo.firstName)")
                    .font(.title2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 修改判断逻辑，确保正确识别"自己"
                if let person = viewModel.currentPerson, person.isSelf {
                    Text("自己")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !notes.isEmpty {
                    // 这里使用notes参数而不是viewModel.state.basicInfo.notes
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                } else {
                    // 优先使用appViewModel直接生成称谓，如果不可用则回退到displayTitle
                    Text(viewModel.appViewModel?.generateTitle(for: viewModel.currentPerson ?? Person(familyId: UUID(), firstName: "", lastName: "", gender: .male)) ?? viewModel.displayTitle)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.5))
              
        }
    }
}

// EditablePersonInfoView 组件
// 在EditablePersonInfoView中修改
private struct EditablePersonInfoView: View {
    let viewModel: PersonCardViewModel
    @Binding var lastName: String
    @Binding var firstName: String
    @Binding var gender: Person.Gender
    @Binding var birthDate: Date
    @Binding var birthDateText: String
    @Binding var notes: String
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(spacing: 24) {
            // 头像部分，移除动画效果，添加边框
            PersonAvatarView(
                person: viewModel.currentPerson ?? Person(
                    familyId: UUID(),
                    firstName: "",
                    lastName: "",
                    gender: .male
                ),
                size: 100, // 保持头像尺寸
                type: nil,
                isEditable: true,
                onPhotoSelected: { photoData in
                    Task {
                        print("开始更新照片到ViewModel")
                        await viewModel.updatePhoto(data: photoData)
                        print("照片已更新到ViewModel")
                    }
                }
            )
            .shadow(color: Color.familyTheme.primary.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // 姓名部分使用卡片式设计
            VStack(spacing: 16) {
                // 姓名部分
                HStack(spacing: 12) {
                    // 姓氏输入框
                    VStack(alignment: .leading, spacing: 6) {
                        Text("姓")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        TextField("姓", text: $lastName)
                            .font(.headline)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            )
                            .onChange(of: lastName) { _, newValue in
                                Task {
                                    await viewModel.updateLastName(newValue)
                                }
                            }
                    }
                    
                    // 名字输入框
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        TextField("名", text: $firstName)
                            .font(.headline)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            )
                            .onChange(of: firstName) { _, newValue in
                                Task {
                                    await viewModel.updateFirstName(newValue)
                                }
                            }
                    }
                }
                
                // 自定义称呼
                VStack(alignment: .leading, spacing: 6) {
                    Text("自定义称呼")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    TextField("留空则自动生成", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.headline)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                        )
                        .onChange(of: notes) { _, newValue in
                            Task {
                                await viewModel.updateNotes(newValue)
                            }
                        }
                }
            }
            .padding(.horizontal, 6)
            
            // 修复性别选择器
            VStack(alignment: .leading, spacing: 6) {
                Text("性别")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                // 使用简化版的选择器，确保可点击性
                Picker("性别", selection: $gender) {
                    Text("男").tag(Person.Gender.male)
                    Text("女").tag(Person.Gender.female)
                }
                .pickerStyle(.segmented)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                )
                .onChange(of: gender) { _, newValue in
                    Task {
                        await viewModel.updateGender(newValue)
                    }
                }
            }
            .padding(.horizontal, 6)
            
            // 出生日期
            VStack(alignment: .leading, spacing: 6) {
                Text("出生日期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    
                    TextField("如：2004年9月1日、2004.9.1或2004", text: $birthDateText)
                        .font(.headline)
                        .padding(.vertical, 12)
                        .onChange(of: birthDateText) { _, newValue in
                            if let date = parseDateString(newValue) {
                                birthDate = date
                                Task {
                                    await viewModel.updateBirthDate(date)
                                }
                            }
                        }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 6)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.familyTheme.primary.opacity(0.1), radius: 15, x: 0, y: 10)
        )
    }
    
    // 保留原有的日期解析函数
    private func parseDateString(_ dateString: String) -> Date? {
        let text = dateString.trimmingCharacters(in: .whitespaces)
        
        let patterns: [(String, String)] = [
            ("(\\d{4})年(\\d{1,2})月(\\d{1,2})日", "yyyy年MM月dd日"),
            ("(\\d{4})\\.(\\d{1,2})\\.(\\d{1,2})", "yyyy.MM.dd"),
            ("(\\d{4})-(\\d{1,2})-(\\d{1,2})", "yyyy-MM-dd"),
            ("(\\d{4})/(\\d{1,2})/(\\d{1,2})", "yyyy/MM/dd"),
            ("(\\d{4})年(\\d{1,2})月", "yyyy年MM月"),
            ("(\\d{4})\\.(\\d{1,2})", "yyyy.MM"),
            ("(\\d{4})年?", "yyyy")
        ]
        
        for (pattern, format) in patterns {
            if let _ = text.range(of: pattern, options: .regularExpression) {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "zh_CN")
                if let date = formatter.date(from: text) {
                    return date
                }
            }
        }
        
        return nil
    }
}

// 主视图
struct PersonBasicInfoSection: View {
    @ObservedObject var viewModel: PersonCardViewModel
    @State private var lastName: String
    @State private var firstName: String
    @State private var gender: Person.Gender
    @State private var birthDate: Date
    @State private var notes: String
    @State private var birthDateText: String = ""
    @State private var showingSetSelfAlert = false
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
    
    init(viewModel: PersonCardViewModel) {
        self.viewModel = viewModel
        _lastName = State(initialValue: viewModel.state.basicInfo.lastName)
        _firstName = State(initialValue: viewModel.state.basicInfo.firstName)
        _gender = State(initialValue: viewModel.state.basicInfo.gender)
        _birthDate = State(initialValue: viewModel.state.basicInfo.birthDate ?? Date())
        _notes = State(initialValue: viewModel.state.basicInfo.notes)
        
        if let date = viewModel.state.basicInfo.birthDate {
            _birthDateText = State(initialValue: dateFormatter.string(from: date))
        } else {
            _birthDateText = State(initialValue: "")
        }
    }
    
    var body: some View {
        let alignment: Alignment = viewModel.isEditable ? .top : .bottom
        
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
            VStack(alignment: .center, spacing: 20) {
                
                if viewModel.isEditable {
                    EditablePersonInfoView(
                        viewModel: viewModel,
                        lastName: $lastName,
                        firstName: $firstName,
                        gender: $gender,
                        birthDate: $birthDate,
                        birthDateText: $birthDateText,
                        notes: $notes,
                        dateFormatter: dateFormatter
                    )
                } else {
                    ReadOnlyPersonInfoView(
                        viewModel: viewModel,
                        notes: notes
                    )
                }
            }
        }
        .onReceive(viewModel.$state) { newState in
            lastName = newState.basicInfo.lastName
            firstName = newState.basicInfo.firstName
            gender = newState.basicInfo.gender
            if let date = newState.basicInfo.birthDate {
                birthDate = date
            }
            notes = newState.basicInfo.notes
        }
        .alert("设置为自己", isPresented: $showingSetSelfAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task {
                    try? await viewModel.setSelfPerson()
                    // 使用viewModel提供的刷新方法，而不是直接访问appViewModel
                    await viewModel.refreshData()
                }
            }
        } message: {
            Text("确定将此人设置为自己吗？这将重置所有亲属关系的称呼。")
        }
    }
}

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
