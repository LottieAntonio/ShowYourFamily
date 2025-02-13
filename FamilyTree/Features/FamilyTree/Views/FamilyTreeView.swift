import SwiftUI

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    @State private var selectedPersonOffset: CGSize = .zero
    @State private var isTransitioning = false
    @Namespace private var animation
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
                        if let currentPerson = personManager.selectedPerson {
                            Group {
                                // 添加切换动画
                                VStack(alignment: .center) {
                                    HStack(alignment: .top) {
                                        // 父亲关系区域
                                        RelationshipSection(
                                            title: "父亲",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.father),
                                            onAddTap: {
                                                Task {
                                                    await MainActor.run {
                                                        withAnimation(.spring(duration: 0.3)) {
                                                            showingPersonCard = true
                                                        }
                                                    }
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.father,
                                                        defaultLastName: currentPerson.lastName,
                                                        defaultGender: Person.Gender.male
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                withAnimation(.spring(duration: 0.3)) {
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                }
                                            },
                                            viewModel: personManager
                                        )
                                        
                                        // 母亲关系区域
                                        RelationshipSection(
                                            title: "母亲",
                                            persons: personManager.getRelatedPersons(for: currentPerson, relationType: RelationType.mother),
                                            onAddTap: {
                                                Task {
                                                    await MainActor.run {
                                                        withAnimation(.spring(duration: 0.3)) {
                                                            showingPersonCard = true
                                                        }
                                                    }
                                                    await showAddRelation(
                                                        for: currentPerson,
                                                        type: RelationType.mother,
                                                        defaultGender: Person.Gender.female
                                                    )
                                                }
                                            },
                                            onPersonTap: { person in
                                                withAnimation(.spring(duration: 0.5)) {
                                                    isTransitioning = true
                                                }
                                                
                                                // 延迟切换人物，等待动画完成
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    withAnimation(.spring(duration: 0.3)) {
                                                        personManager.selectedPerson = person
                                                        showingPersonCard = false
                                                        isTransitioning = false
                                                    }
                                                }
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
                                        person: currentPerson,
                                        mode: .view,
                                        managementViewModel: personManager
                                    )
                                    .id(currentPerson.id)
                                }
                                .matchedGeometryEffect(id: currentPerson.id, in: animation, isSource: true)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        .scaleEffect(currentPerson.isSelf ? 1.02 : 1.0)
                                        .opacity(currentPerson.isSelf ? 0.8 : 0.3)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(), value: currentPerson.isSelf)
                                }
                                .padding(.vertical, -10)
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.3)) {
                                        personManager.selectedPerson = currentPerson
                                        selectedMode = .edit
                                        showingPersonCard = true
                                    }
                                }
                                
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
                            .transition(.asymmetric(
                               insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                               .animation(.spring(duration: 0.3), value: currentPerson.id)
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
                // 找到并设置"自己"为选中的人物
                if let selfPerson = personManager.persons.first(where: { $0.isSelf }) {
                    await MainActor.run {
                        personManager.selectedPerson = selfPerson
                    }
                }
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
