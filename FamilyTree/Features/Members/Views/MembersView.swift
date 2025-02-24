import SwiftUI

struct MembersView: View {
    @StateObject private var viewModel: MembersViewModel
    @EnvironmentObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    let family: Family  // 添加当前家谱属性
    
    init(familyTreeViewModel: FamilyTreeViewModel, family: Family) {
        self.family = family
        let membersViewModel = MembersViewModel(familyTreeViewModel: familyTreeViewModel)
        _viewModel = StateObject(wrappedValue: membersViewModel)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.persons.isEmpty {
                    ContentUnavailableView("暂无成员", systemImage: "person.slash")
                } else {
                    List {
                        ForEach(viewModel.persons) { person in
                            PersonRow(person: person, viewModel: viewModel)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedPerson = person
                                    personManager.selectedPerson = person
                                    selectedMode = .edit
                                    showingPersonCard = true
                                }
                        }
                    }
                }
            }
            .navigationTitle("家庭成员")
            .sheet(isPresented: $showingPersonCard) {
                NavigationStack {
                    PersonCard(
                        person: viewModel.selectedPerson,
                        mode: selectedMode,
                        managementViewModel: personManager
                    )
                }
            }
        }
        .task {
            print("开始加载[\(family.name)]成员数据")
            // 确保先切换到正确的家谱
            await viewModel.switchFamily(family)
            await viewModel.loadData()
            print("[\(family.name)]成员数据加载完成：\(viewModel.persons.count) 个成员")
        }
    }
}

// 添加一个简单的 PersonRow 视图
struct PersonRow: View {
    let person: Person
    @ObservedObject var viewModel: MembersViewModel
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
            if !person.isSelf {
                title = await viewModel.getRelativeTitle(for: person)
            }
        }
        // 移除 onReceive，因为 titleCache 的更新已经会触发 UI 刷新
    }
}

// 修改 MembersView 中的 PersonRow 使用

