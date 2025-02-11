import SwiftUI

struct PersonListModeView: View {
    @ObservedObject var viewModel: MembersViewModel
    
    var body: some View {
        List(viewModel.persons) { person in
            NavigationLink(value: person) {
                PersonRow(
                    person: person,
                    isSelected: person.id == viewModel.selectedPerson?.id,
                    onTap: { viewModel.selectPerson(person) }
                )
            }
        }
    }
}