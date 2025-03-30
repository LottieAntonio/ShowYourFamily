import SwiftUI

struct MembersView: View {
    @EnvironmentObject private var appViewModel: FamilyAppViewModel
    @State private var selectedMode: PersonCardMode = .view
    // 使用包含模式的结构体来传递数据
    @State private var personToEdit: PersonWithMode?
    let family: Family
    
    var body: some View {
        NavigationStack {
            Group {
                if appViewModel.persons.isEmpty {
                    ContentUnavailableView("暂无成员", systemImage: "person.slash")
                } else {
                    List {
                        ForEach(appViewModel.persons) { person in
                            PersonRow(person: person, appViewModel: appViewModel)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 直接设置要编辑的人物，这会触发 sheet 显示
                                    if let fullPerson = appViewModel.persons.first(where: { $0.id == person.id }) {
                                        print("准备显示 - 人物: \(fullPerson.firstName)")
                                        // 创建包含人物和模式的结构体
                                        personToEdit = PersonWithMode(person: fullPerson, mode: .edit)
                                    } else {
                                        print("未找到完整的人物数据")
                                    }
                                }
                            }
                        }
                    .padding(.bottom, 68)
                }
            }
            // 使用 item-based sheet
            .sheet(item: $personToEdit) { personWithMode in
                NavigationStack {
                    PersonCard(
                        person: personWithMode.person,
                        mode: personWithMode.mode, 
                        stateManager: appViewModel.getStateManager(),
                        appViewModel: appViewModel
                    )
                    .onAppear {
                        print("PersonCard显示 - 人物: \(personWithMode.person.firstName), 模式: \(personWithMode.mode)")
                    }
                }
            }
        }
    }
}

// 创建一个包含人物和模式的结构体，用于 item-based sheet
struct PersonWithMode: Identifiable {
    let id = UUID()
    let person: Person
    let mode: PersonCardMode
}

// PersonRow 视图保持不变
struct PersonRow: View {
    let person: Person
    let appViewModel: FamilyAppViewModel
    @State private var title: String?
    
    var body: some View {
        HStack {
            Image(systemName: person.gender == .male ? "person.circle.fill" : "person.circle")
                .font(.title2)
                .foregroundStyle(person.gender == .male ? .blue : .pink)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(person.lastName)\(person.firstName)")
                    .font(.headline)
                
                if person.isSelf {
                    Text("自己")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(title ?? "生成称谓中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            if !person.isSelf && title == nil {
                title = appViewModel.generateTitle(for: person)
            }
        }
    }
}

