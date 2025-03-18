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
                
                if viewModel.isSelfPerson == true {
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
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThickMaterial.opacity(0.5))
                .shadow(
                    color: Color.familyTheme.primary.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
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
    
    // 移除这个状态，避免不必要的视图重建
    // @State private var photoUpdateCounter = UUID()
    
    var body: some View {
        VStack {
            // 修改PersonAvatarView的使用方式
            PersonAvatarView(
                person: viewModel.currentPerson ?? Person(
                    familyId: UUID(),
                    firstName: "",
                    lastName: "",
                    gender: .male
                ),
                size: 80,
                type: nil,
                isEditable: true,
                onPhotoSelected: { photoData in
                    Task {
                        print("开始更新照片到ViewModel")
                        await viewModel.updatePhoto(data: photoData)
                        print("照片已更新到ViewModel")
                        // 不再增加计数器强制刷新
                    }
                }
            )
            // 移除动态ID，避免视图重建
            // .id("avatar-\(viewModel.currentPerson?.id.uuidString ?? UUID().uuidString)-\(photoUpdateCounter)")
            
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("出生日期")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                
                TextField("直接输入（如：2004年9月1日、2004.9.1或2004）", text: $birthDateText)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: birthDateText) { _, newValue in
                        if let date = parseDateString(newValue) {
                            birthDate = date
                            Task {
                                await viewModel.updateBirthDate(date)
                            }
                        }
                    }
            }
        }
        .padding(30)
    }
    
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
