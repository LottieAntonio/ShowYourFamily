import SwiftUI

struct PersonListView: View {
    @ObservedObject var viewModel: MembersViewModel
    @State private var displayMode: DisplayMode = .list
    @State private var isLoading = false
    @State private var searchText = ""  // 添加搜索文本
    
    enum DisplayMode {
        case list
        case tree
    }
    
    var filteredPersons: [Person] {
        if searchText.isEmpty {
            return viewModel.persons
        }
        return viewModel.persons.filter { person in
            person.lastName.contains(searchText) ||
            person.firstName.contains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            Picker("显示模式", selection: $displayMode) {
                Label("列表", systemImage: "list.bullet")
                    .tag(DisplayMode.list)
                Label("树状", systemImage: "rectangle.3.group")
                    .tag(DisplayMode.tree)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isLoading {
                ProgressView()
            } else {
                if displayMode == .list {
                    List {
                        ForEach(filteredPersons) { person in
                            PersonRow(
                                person: person,
                                isSelected: viewModel.selectedPerson?.id == person.id,
                                onTap: {
                                    viewModel.selectPerson(person)
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deletePerson(person)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "搜索成员")
                } else {
                    PersonTreeModeView(viewModel: viewModel)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        Task {
            await viewModel.loadData()
            isLoading = false
        }
    }
}