import SwiftUI

struct MembersView: View {
    @StateObject private var viewModel: MembersViewModel
    @EnvironmentObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        _viewModel = StateObject(wrappedValue: MembersViewModel(familyTreeViewModel: familyTreeViewModel))
    }
    
    var body: some View {
        NavigationStack {
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
            
            .onAppear {
                Task {
                    await viewModel.loadData()
                }
            }
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
            // 首次加载时获取称谓
            if !person.isSelf {
                title = await viewModel.getRelativeTitle(for: person)
            }
        }
        .onReceive(viewModel.$persons) { _ in
            // 数据更新时重新获取称谓
            if !person.isSelf {
                Task {
                    title = await viewModel.getRelativeTitle(for: person)
                }
            }
        }
    }
}

// 修改 MembersView 中的 PersonRow 使用

