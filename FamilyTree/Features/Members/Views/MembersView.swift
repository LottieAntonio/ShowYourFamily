import SwiftUI

struct MembersView: View {
    @EnvironmentObject private var appViewModel: FamilyAppViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    @State private var selectedPerson: Person?
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
                                    selectedPerson = person
                                    selectedMode = .edit
                                    showingPersonCard = true
                                }
                            }
                        }
                    .padding(.bottom, 68)
                    
                }
            }
            .sheet(isPresented: $showingPersonCard) {
                NavigationStack {
                    PersonCard(
                        person: selectedPerson,
                        mode: selectedMode, 
                        stateManager: appViewModel.getStateManager(),
                        appViewModel: appViewModel
                    )
                }
            }
        }
        // 不再需要 onAppear 逻辑，因为我们直接使用 appViewModel
    }
}

// 修改 PersonRow 视图
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

