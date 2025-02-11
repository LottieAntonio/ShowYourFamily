import SwiftUI

struct MembersView: View {
    @StateObject private var viewModel: MembersViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        _viewModel = StateObject(wrappedValue: MembersViewModel(familyTreeViewModel: familyTreeViewModel))
    }
    
    var body: some View {
        NavigationStack {
            PersonListView(viewModel: viewModel)
                .navigationTitle("家庭成员")
                .onChange(of: viewModel.selectedPerson) { person in
                    if let person = person {
                        // 通过 ViewModel 更新选中的人物
                        Task {
                            await viewModel.updateSelectedPerson(person)
                            dismiss()
                        }
                    }
                }
        }
    }
}
