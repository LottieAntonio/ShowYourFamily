import SwiftUI

struct PersonTreeModeView: View {
    @ObservedObject var viewModel: MembersViewModel
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            // 找到根节点（没有父母的人）
            let rootPersons = viewModel.persons.filter { person in
                let parents = viewModel.getRelatedPersons(for: person, relationType: .father) +
                            viewModel.getRelatedPersons(for: person, relationType: .mother)
                return parents.isEmpty
            }
            
            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(rootPersons) { person in
                    FamilyNode(person: person, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}

struct FamilyNode: View {
    let person: Person
    @ObservedObject var viewModel: MembersViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 显示当前人物及其配偶
            HStack(spacing: 20) {
                PersonRow(person: person, isSelected: person.id == viewModel.selectedPerson?.id)
                    .onTapGesture {
                        viewModel.selectedPerson = person
                    }
                
                // 显示配偶
                if let spouse = viewModel.getRelatedPersons(for: person, relationType: .spouse).first {
                    Text("━")
                    PersonRow(person: spouse, isSelected: spouse.id == viewModel.selectedPerson?.id)
                        .onTapGesture {
                            viewModel.selectedPerson = spouse
                        }
                }
            }
            
            // 显示子女
            let children = viewModel.getRelatedPersons(for: person, relationType: .child)
            if !children.isEmpty {
                HStack(alignment: .top, spacing: 40) {
                    Rectangle()
                        .frame(width: 2, height: 20)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                    
                    LazyHStack(alignment: .top, spacing: 40) {
                        ForEach(children) { child in
                            FamilyNode(person: child, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
}

struct PersonTreeNode: View {
    let person: Person
    @ObservedObject var viewModel: MembersViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: person) {
                PersonRow(person: person, isSelected: person.id == viewModel.selectedPerson?.id)
            }
            
            if !viewModel.getRelatedPersons(for: person, relationType: .child).isEmpty {
                HStack {
                    Rectangle()
                        .frame(width: 2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.getRelatedPersons(for: person, relationType: .child)) { child in
                            PersonTreeNode(person: child, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
}