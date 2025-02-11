import SwiftUI
import Combine

@MainActor
class MembersViewModel: ObservableObject {
    @Published private(set) var persons: [Person] = []
    @Published var selectedPerson: Person?
    @Published var errorMessage: String?  // 添加错误消息属性
    private let familyTreeViewModel: FamilyTreeViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        self.familyTreeViewModel = familyTreeViewModel
        
        // 监听 FamilyTreeViewModel 的变化
        familyTreeViewModel.$persons
            .sink { [weak self] persons in
                self?.persons = persons
            }
            .store(in: &cancellables)
    }
    
    func loadData() async {
        do {
            try await familyTreeViewModel.loadData()
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
        }
    }
    
    private func getParents(for person: Person) -> (father: Person?, mother: Person?) {
        let father = getRelatedPersons(for: person, relationType: .father).first
        let mother = getRelatedPersons(for: person, relationType: .mother).first
        return (father, mother)
    }
    
    func getRelatedPersons(for person: Person, relationType: RelationType) -> [Person] {
        switch relationType {
        case .father, .mother, .child, .spouse:
            let relationships = familyTreeViewModel.relationships.filter { relationship in
                switch relationType {
                case .father:
                    return relationship.fromPerson == person.id && relationship.type == .father
                case .mother:
                    return relationship.fromPerson == person.id && relationship.type == .mother
                case .child:
                    return (relationship.toPerson == person.id && relationship.type == .father) ||
                           (relationship.toPerson == person.id && relationship.type == .mother)
                case .spouse:
                    return (relationship.fromPerson == person.id && relationship.type == .spouse) ||
                           (relationship.toPerson == person.id && relationship.type == .spouse)
                default:
                    return false
                }
            }
            
            return relationships.compactMap { relationship in
                if relationship.fromPerson == person.id {
                    return persons.first { $0.id == relationship.toPerson }
                } else {
                    return persons.first { $0.id == relationship.fromPerson }
                }
            }
            
        case .brother, .sister:
            let parents = getParents(for: person)
            let fatherChildren = parents.father.map { getRelatedPersons(for: $0, relationType: .child) } ?? []
            let motherChildren = parents.mother.map { getRelatedPersons(for: $0, relationType: .child) } ?? []
            let allChildren = Array(Set(fatherChildren.compactMap { $0 } + motherChildren.compactMap { $0 }))
            
            return allChildren.filter { sibling in
                let correctGender = relationType == .brother ? sibling.gender == .male : sibling.gender == .female
                return correctGender && sibling.id != person.id
            }
        }
    }
    
    func updateSelectedPerson(_ person: Person) async {
        await familyTreeViewModel.updateSelectedPerson(person)
    }
}
