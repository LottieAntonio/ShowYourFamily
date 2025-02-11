import SwiftUI

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    
    init() {
        let familyViewModel = FamilyTreeViewModel()
        _viewModel = StateObject(wrappedValue: familyViewModel)
        _personManager = StateObject(wrappedValue: PersonManagementViewModel(familyTreeViewModel: familyViewModel))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if personManager.persons.isEmpty {
                    Button(action: { showAddPerson() }) {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("开始创建家谱")
                                .font(.title2)
                                .foregroundStyle(.primary)
                            
                            Text("点击添加第一位家庭成员")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 20) {
                        // 修改这里，使用 personManager 中的 selectedPerson
                        if let currentPerson = personManager.selectedPerson {
                            // 添加 id 强制刷新整个内容
                            Group {
                                VStack(alignment: .center) {
                                    HStack(alignment: .top) {
                                        // 父亲关系区域
                                        RelationshipSection(
                                            title: "父亲",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.father),
                                            onAddTap: {
                                                Task {
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.father,
                                                        defaultLastName: currentPerson.lastName,
                                                        defaultGender: Person.Gender.male
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                personManager.selectedPerson = person
                                                showingPersonCard = false
                                            },
                                            viewModel: personManager
                                        )
                                        
                                        // 母亲关系区域
                                        RelationshipSection(
                                            title: "母亲",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.mother),
                                            onAddTap: {
                                                Task {
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.mother,
                                                        defaultGender: Person.Gender.female
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                personManager.selectedPerson = person
                                                showingPersonCard = false
                                            },
                                            viewModel: personManager
                                        )
                                    }
                                    // 配偶关系区域
                                    RelationshipSection(
                                        title: "配偶",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.spouse),
                                        onAddTap: {
                                            Task {
                                                let defaultSpouseGender = currentPerson.gender == .male ? Person.Gender.female : Person.Gender.male
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: RelationType.spouse,
                                                    defaultGender: defaultSpouseGender
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            personManager.selectedPerson = person
                                            showingPersonCard = false
                                        },
                                        viewModel: personManager
                                    )
                                }
                                
                                // 当前人物卡片
                                ZStack(alignment: .center) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .foregroundStyle(Color.gray.opacity(0.1))
                                        
                                    PersonCard(
                                        person: currentPerson,  // 直接使用 currentPerson
                                        mode: .view,
                                        managementViewModel: personManager
                                    )
                                    .id(currentPerson.id)  // 添加 id 确保视图更新
                                    .onTapGesture {
                                        personManager.selectedPerson = currentPerson
                                        selectedMode = .edit
                                        showingPersonCard = true
                                    }
                                }
                                .padding(.vertical, -10)
                                
                                VStack() {
                                    // 子女关系区域
                                    RelationshipSection(
                                        title: "子女",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.child),
                                        onAddTap: {
                                            Task {
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: RelationType.child,
                                                    defaultLastName: currentPerson.lastName
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            personManager.selectedPerson = person
                                            showingPersonCard = false
                                        },
                                        viewModel: personManager
                                    )
                                    HStack(alignment: .top) {
                                        RelationshipSection(
                                            title: "兄弟",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.brother),
                                            onAddTap: {
                                                Task {
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.brother,
                                                        defaultLastName: currentPerson.lastName,
                                                        defaultGender: Person.Gender.male
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                personManager.selectedPerson = person
                                                showingPersonCard = false
                                            },
                                            viewModel: personManager
                                        )
                                        
                                        RelationshipSection(
                                            title: "姐妹",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.sister),
                                            onAddTap: {
                                                Task {
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.sister,
                                                        defaultLastName: currentPerson.lastName,
                                                        defaultGender: Person.Gender.female
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                personManager.selectedPerson = person
                                                showingPersonCard = false
                                            },
                                            viewModel: personManager
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
//            .navigationTitle("我的家谱")
//            .background(Color.indigo)
            .sheet(isPresented: $showingPersonCard) {
                NavigationStack {
                    PersonCard(
                        person: {
                            if case .add = selectedMode {
                                return nil
                            }
                            return personManager.selectedPerson
                        }(),
                        mode: selectedMode,  // 直接传递 selectedMode
                        managementViewModel: personManager
                    )
                }
            }
        }
        .onAppear {
            Task {
                await personManager.loadData()
            }
        }
    }
    
    private func showAddPerson() {
        selectedMode = .add(relationType: nil)
        showingPersonCard = true
        personManager.selectedPerson = nil
    }
    
    private func showAddRelation(
        for person: Person,
        type: RelationType,  // 修改这里，直接使用 RelationType
        defaultLastName: String? = nil,
        defaultGender: Person.Gender? = nil
    ) async {
        personManager.selectedPerson = person
        await personManager.setDefaultValues(lastName: defaultLastName, gender: defaultGender)
        selectedMode = .add(relationType: type)
        showingPersonCard = true
    }
    
    // 删除第二个重复的 showAddRelation 方法
}

#Preview("家谱") {
    FamilyTreeView()
}

#Preview("家谱-深色") {
    FamilyTreeView()
        .preferredColorScheme(.dark)
}
