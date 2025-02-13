import SwiftUI

// 添加动画配置
private extension Animation {
    static let personTransition = spring(duration: 0.5, bounce: 0.3)
    static let cardTransition = spring(duration: 0.3)
    static let flyTransition = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 100,
        damping: 15,
        initialVelocity: 0.5
    )
}

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @StateObject private var personManager: PersonManagementViewModel
    @State private var showingPersonCard = false
    @State private var selectedMode: PersonCardMode = .view
    @State private var selectedPersonOffset: CGSize = .zero
    @State private var isTransitioning = false
    @State private var selectedPersonId: UUID?
    @State private var transitionOffset: CGSize = .zero
    
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
                            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                                // 第一行：父母
                                GridRow {
                                    // 父亲关系区域
                                    RelationshipSection(
                                        title: "父亲",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .father),
                                        onAddTap: {
                                            Task {
                                                await MainActor.run {
                                                    withAnimation(.spring(duration: 0.3)) {
                                                        showingPersonCard = true
                                                    }
                                                }
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .father,
                                                    defaultLastName: currentPerson.lastName,
                                                    defaultGender: .male
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
                                    
                                    // 母亲关系区域
                                    RelationshipSection(
                                        title: "母亲",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .mother),
                                        onAddTap: {
                                            Task {
                                                await MainActor.run {
                                                    withAnimation(.spring(duration: 0.3)) {
                                                        showingPersonCard = true
                                                    }
                                                }
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .mother,
                                                    defaultGender: .female
                                                )
                                            }
                                        },
                                        // 修改母亲关系区域的 onPersonTap
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
                                    .matchedGeometryEffect(
                                           id: "container-\(selectedPersonId ?? UUID())",
                                           in: animation,
                                           properties: .position,
                                           isSource: true
                                       )
                                }
                                
                                // 第二行：配偶
                                GridRow {
                                    RelationshipSection(
                                        title: "配偶",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .spouse),
                                        onAddTap: {
                                            Task {
                                                let defaultSpouseGender = currentPerson.gender == .male ? Person.Gender.female : .male
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .spouse,
                                                    defaultGender: defaultSpouseGender
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
                                    .gridCellColumns(2)
                                }
                                
                                // 第三行：当前人物
                                GridRow {
                                    ZStack(alignment: .center) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .foregroundStyle(Color.gray.opacity(0.1))
                                            .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                                        
                                        PersonCard(
                                            person: currentPerson,
                                            mode: .view,
                                            managementViewModel: personManager
                                        )
                                        .id(currentPerson.id)
                                    }
                                    .gridCellColumns(2)
                                    .opacity(isTransitioning ? 0.3 : 1)  // 修改透明度
                                    .scaleEffect(isTransitioning ? 0.8 : 1)  // 添加缩放效果
                                    .onTapGesture {
                                        withAnimation(.personTransition) {
                                            personManager.selectedPerson = currentPerson
                                            selectedMode = .edit
                                            showingPersonCard = true
                                        }
                                    }
                                }
                                
                                // 第四行：子女
                                GridRow {
                                    RelationshipSection(
                                        title: "子女",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .child),
                                        onAddTap: {
                                            Task {
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .child,
                                                    defaultLastName: currentPerson.lastName
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
                                    .gridCellColumns(2)
                                }
                                
                                // 第五行：兄弟姐妹
                                GridRow {
                                    RelationshipSection(
                                        title: "兄弟",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .brother),
                                        onAddTap: {
                                            Task {
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .brother,
                                                    defaultLastName: currentPerson.lastName,
                                                    defaultGender: .male
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
                                    
                                    RelationshipSection(
                                        title: "姐妹",
                                        persons: personManager.getRelatedPersons(for: currentPerson, relationType: .sister),
                                        onAddTap: {
                                            Task {
                                                await showAddRelation(
                                                    for: currentPerson,
                                                    type: .sister,
                                                    defaultLastName: currentPerson.lastName,
                                                    defaultGender: .female
                                                )
                                            }
                                        },
                                        onPersonTap: { person in
                                            selectedPersonId = person.id
                                            
                                            // 第一阶段：上升并缩小
                                            withAnimation(.flyTransition) {
                                                transitionOffset = CGSize(width: 0, height: -50)
                                                isTransitioning = true
                                            }
                                            
                                            // 第二阶段：水平移动
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = CGSize(width: UIScreen.main.bounds.width * 0.3, height: -50)
                                                }
                                            }
                                            
                                            // 第三阶段：下降到目标位置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation(.flyTransition) {
                                                    transitionOffset = .zero
                                                    personManager.selectedPerson = person
                                                    showingPersonCard = false
                                                    isTransitioning = false
                                                }
                                            }
                                        },
                                        viewModel: personManager
                                    )
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
