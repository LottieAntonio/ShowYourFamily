
/*
 * RelationshipSection 视图
 * 作用：显示特定类型的关系部分
 * - 显示关系列表
 * - 处理添加新关系
 * - 处理人物选择
 */

import SwiftUI

// 修改 RelationshipSection 的布局和尺寸计算
struct RelationshipSection: View {
    let title: String
    let persons: [Person]
    let onAddTap: () -> Void
    let onPersonTap: (Person) -> Void
    @EnvironmentObject var appViewModel: FamilyAppViewModel  // 修改这里
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    let type: RelationType
    
    // 调整区域大小计算
    private var sectionSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 40
        let minWidth: CGFloat = 150
        
        switch type {
        case .spouse, .child:
            return CGSize(width: screenWidth, height: 120) // 增加高度
        default:
            let calculatedWidth = max((screenWidth - padding) / 2, minWidth)
            return CGSize(width: calculatedWidth, height: 120) // 增加高度
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HeaderView(
                title: title,
                onAddTap: onAddTap,
                type: type,
                localPersons: persons
            )
            
            if persons.isEmpty || appViewModel.getStateManager().state.isLoading {  // 修改这里
                EmptyStateView(
                    title: title,
                    onAddTap: onAddTap,
                    type: type
                )
            } else {
                // 计算唯一人数
                let uniqueCount = type == .spouse ? 
                    Set(persons.map { $0.id }).count : persons.count
                
                if uniqueCount == 1 {
                    PersonListView(
                        persons: persons,
                        animation: animation,
                        selectedPersonId: $selectedPersonId,
                        onPersonTap: onPersonTap,
                        type: type
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) { // 增加间距
                            PersonListView(
                                persons: persons,
                                animation: animation,
                                selectedPersonId: $selectedPersonId,
                                onPersonTap: onPersonTap,
                                type: type
                            )
                        }
                    }
                }
            }
        }
        .padding(15) // 增加整体内边距
        .frame(
            width: type == .spouse || type == .child ? nil : sectionSize.width, // 修改这里
            height: sectionSize.height,
            alignment: .top
        )
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16) // 增加圆角
                    .fill(.regularMaterial)
            }
            .shadow(
                color: Color.familyTheme.primary.opacity(0.15),
                radius: 8,
                x: 0,
                y: 4
            )
        )
       
    }
}

// 修改 PersonItemView 以确保内容紧凑
// 在 PersonItemView 中添加关系标识
// 添加关系类型枚举
enum RelationshipType {
    case fullSibling    // 同父同母
    case paternalSibling // 同父异母
    case maternalSibling // 同母异父
    
    var description: String {
        switch self {
        case .fullSibling: return "同父同母"
        case .paternalSibling: return "同父异母"
        case .maternalSibling: return "同母异父"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .fullSibling: return .green.opacity(0.2)
        case .paternalSibling: return .blue.opacity(0.2)
        case .maternalSibling: return .purple.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch self {
        case .fullSibling: return .green
        case .paternalSibling: return .blue
        case .maternalSibling: return .purple
        }
    }
}

// 添加关系标识组件
struct RelationshipBadge: View {
    let type: RelationshipType
    
    var body: some View {
        Text(type.description)
            .font(.system(size: 8)) // 减小字体
            .foregroundColor(type.textColor)
            .padding(.horizontal, 3) // 减小水平内边距
            .padding(.vertical, 1) // 减小垂直内边距
            .background(type.backgroundColor)
            .cornerRadius(3) // 减小圆角
    }
}

// 在 PersonItemView 中添加 getRelationshipType 方法
private struct PersonItemView: View {
    let person: Person
    @EnvironmentObject var appViewModel: FamilyAppViewModel  // 修改为 @EnvironmentObject
    let animation: Namespace.ID
    let isSelected: Bool
    let type: RelationType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) { // 减小间距
                // 修改头像视图
                ZStack {
                    PersonAvatarView(
                        person: person,
                        size: 36, // 增加头像尺寸
                        type: type,
                        isEditable: false
                    )
                    // 添加一个透明的覆盖层来确保点击事件正确传递
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(person.name)
                            .font(.subheadline) // 调整字体
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        // 添加关系标识
                        if let relationshipType = getRelationshipType() {
                            RelationshipBadge(type: relationshipType)
                        }
                    }
                    
                    Text(person.birthDate.map { date in
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "zh_CN")
                        formatter.dateFormat = "yyyy年M月d日"
                        return formatter.string(from: date)
                    } ?? "未设置生日")
                        .font(.caption2) // 减小字体
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4) // 设置最小间距
            }
            .padding(8) // 减小内边距
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        Color.familyTheme.gradientFor(type)
                            .opacity(0.15)
                    )
                    .shadow(
                        color: Color.familyTheme.primary.opacity(0.1),
                        radius: 4, // 减小阴影
                        x: 0,
                        y: 2
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .matchedGeometryEffect(
            id: "\(type.rawValue)_\(person.id)",
            in: animation,
            isSource: !isSelected
        )
    }
    
    private func getRelationshipType() -> RelationshipType? {
        // 只有兄弟姐妹关系才需要显示标识
        guard type == .brother || type == .sister else { return nil }
        
        // 获取当前选中人物
        guard let currentPerson = appViewModel.getStateManager().state.selectedPerson else { return nil }
        
        // 获取双方的父母
        let currentFather = appViewModel.getStateManager().getRelatedPersons(for: currentPerson, relationType: .father).first
        let currentMother = appViewModel.getStateManager().getRelatedPersons(for: currentPerson, relationType: .mother).first
        
        let personFather = appViewModel.getStateManager().getRelatedPersons(for: person, relationType: .father).first
        let personMother = appViewModel.getStateManager().getRelatedPersons(for: person, relationType: .mother).first
        
        // 判断关系类型
        let hasSameFather = currentFather?.id == personFather?.id && currentFather != nil
        let hasSameMother = currentMother?.id == personMother?.id && currentMother != nil
        
        // 如果是同父同母的兄弟姐妹，不显示标识
        if hasSameFather && hasSameMother {
            return nil
        } else if hasSameFather {
            return .paternalSibling
        } else if hasSameMother {
            return .maternalSibling
        }
        
        return nil
    }
}

// MARK: - Subviews

// 修改 HeaderView 和 EmptyStateView 中的调用
private struct HeaderView: View {
    let title: String
    let onAddTap: () -> Void
    let type: RelationType
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @State private var showingPotentialParents = false
    @State private var processingParentId: UUID?
    let localPersons: [Person]
    
    @State private var canAdd: Bool = true
    
    // 为不同关系类型添加对应的emoji
    private var relationshipEmoji: String {
        switch type {
        case .father: return "👨"
        case .mother: return "👩"
        case .spouse: return "💑"
        case .child: return "👶"
        case .brother: return "👦"
        case .sister: return "👧"
        }
    }
    
    private var uniquePersonCount: Int {
        if type == .spouse {
            return Set(localPersons.map { $0.id }).count
        }
        return localPersons.count
    }
    
    var body: some View {
        HStack {
            // 标题部分增加emoji和动画效果
            titleView
            
            
            // 添加人数指示器
            if uniquePersonCount > 1 {
                Text("\(uniquePersonCount)")
                    .font(.caption)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.familyTheme.accent.opacity(0.2))
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()

            // 菜单按钮
            menuButton
        }
        
    }
    
    // 标题视图
    private var titleView: some View {
        HStack() {
            // 添加emoji
//            Text(relationshipEmoji)
//                .font(.system(size: 14))
//                .padding(4)
//                .background(
//                    Circle()
//                        .fill(Color.familyTheme.primary.opacity(0.3))
//                )
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.familyTheme.primary)
        }
        .padding(.horizontal ,3)
        .padding(.vertical ,4)
        
    }
    
    // 菜单按钮
    private var menuButton: some View {
        Menu {
            // 兄弟姐妹关系的菜单项
            siblingMenuItems
            
            // 父母关系的菜单项
            parentMenuItems
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .foregroundStyle(Color.familyTheme.primary)
                .font(.callout)
                .symbolEffect(.pulse, options: .repeating, value: canAdd)
        }
        .disabled(processingParentId != nil)
        .task {
            if type == .brother || type == .sister {
                canAdd = await canAddSibling(type: type, stateManager: appViewModel.getStateManager())
            }
        }
        .onChange(of: appViewModel.getStateManager().state.persons) { oldValue, newValue in
            if type == .brother || type == .sister {
                Task {
                    canAdd = await canAddSibling(type: type, stateManager: appViewModel.getStateManager())
                }
            }
        }
    }
    
    // 兄弟姐妹关系的菜单项
    @ViewBuilder
    private var siblingMenuItems: some View {
        if type == .brother || type == .sister {
            if canAdd {
                Button(action: onAddTap) {
                    Label("添加新\(title)", systemImage: "person.badge.plus")
                }
            } else {
                Label("需要先添加父母才能添加\(title)", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.secondary)
            }
        } else {
            // 非兄弟姐妹关系，直接显示添加按钮
            Button(action: onAddTap) {
                Label("添加新\(title)", systemImage: "person.badge.plus")
            }
        }
    }
    
    // 父母关系的菜单项 - 保持不变
    @ViewBuilder
    private var parentMenuItems: some View {
        // 只在父母关系中显示选择现有人物选项
        if (type == .father || type == .mother),
           let currentPerson = appViewModel.getStateManager().state.selectedPerson {
            let potentialParents = getPotentialParents(
                for: currentPerson,
                type: type
            )
            
            if !potentialParents.isEmpty {
                Divider()
                ForEach(potentialParents) { parent in
                    parentButton(for: parent)
                }
            }
        }
    }
    
    // 父母按钮 - 保持不变
    private func parentButton(for parent: Person) -> some View {
        Button(action: {
            processingParentId = parent.id
            Task {
                await MainActor.run {
                    appViewModel.getStateManager().updateLoadingState(true)
                }
                
                do {
                    try await appViewModel.getStateManager().addRelationship(
                        from: appViewModel.getStateManager().state.selectedPerson!,
                        to: parent,
                        type: type
                    )
                    await appViewModel.refreshData()
                } catch {
                    print("添加关系失败：\(error.localizedDescription)")
                }
                processingParentId = nil
                
                await MainActor.run {
                    appViewModel.getStateManager().updateLoadingState(false)
                }
            }
        }) {
            Label("选择 \(parent.name)", systemImage: "person.fill")
            if processingParentId == parent.id {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .disabled(processingParentId != nil)
    }
    
    // 获取潜在父母的方法 - 保持不变
    private func getPotentialParents(for person: Person, type: RelationType) -> [Person] {
        let otherParentType: RelationType = type == .father ? .mother : .father
        guard let otherParent = appViewModel.getStateManager().getRelatedPersons(for: person, relationType: otherParentType).first else {
            return []
        }
        
        return appViewModel.getStateManager().getRelatedPersons(for: otherParent, relationType: .spouse)
            .filter { $0.gender == (type == .father ? .male : .female) }
    }
}

// 修改 canAddSibling 函数的实现
@MainActor
private func canAddSibling(type: RelationType, stateManager: StateManager) async -> Bool {
    // 如果不是兄弟姐妹关系，直接返回 true
    guard type == .brother || type == .sister else { return true }
    
    // 获取当前选中的人物
    guard let currentPerson = stateManager.state.selectedPerson else { return false }
    
    // 检查是否有父亲或母亲
    let hasFather = !stateManager.getRelatedPersons(for: currentPerson, relationType: .father).isEmpty
    let hasMother = !stateManager.getRelatedPersons(for: currentPerson, relationType: .mother).isEmpty
    
    // 只要有一个父母就可以添加兄弟姐妹
    return hasFather || hasMother
}

// 修改 EmptyStateView 中的相关部分
private struct EmptyStateView: View {
    let title: String
    let onAddTap: () -> Void
    let type: RelationType
    // 移除这一行，不再需要直接传入 stateManager
    // @ObservedObject var stateManager: StateManager
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @State private var processingParentId: UUID?
    
    @State private var canAdd: Bool = true
    
    var body: some View {
        Menu {
            // 添加按钮部分
            addButtonSection
            
            // 父母选择部分
            parentSelectionSection
        } label: {
            emptyStateLabel
        }
        .disabled(!canAdd)
        .task {
            // 使用 appViewModel.getStateManager() 替代 stateManager
            canAdd = await canAddSibling(type: type, stateManager: appViewModel.getStateManager())
        }
        .onChange(of: appViewModel.getStateManager().state.persons) { oldValue, newValue in
            Task {
                canAdd = await canAddSibling(type: type, stateManager: appViewModel.getStateManager())
            }
        }
        .onChange(of: appViewModel.getStateManager().state.selectedPerson) { oldValue, newValue in
            Task {
                canAdd = await canAddSibling(type: type, stateManager: appViewModel.getStateManager())
            }
        }
    }
        
        // 空状态标签
    private var emptyStateLabel: some View {
        HStack {
            Text(canAdd ? "点击添加\(title)" : "需要先添加父母")
                .font(.caption2) // 减小字体
                .foregroundStyle(Color.familyTheme.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 36) // 减小最小高度
    }
        
    // 添加按钮部分
    @ViewBuilder
    private var addButtonSection: some View {
        if canAdd {
            Button(action: onAddTap) {
                Label("添加新\(title)", systemImage: "person.badge.plus")
            }
        } else {
            Text("需要先添加父母才能添加\(title)")
                .foregroundColor(.secondary)
        }
    }
        
    // 父母选择部分
    @ViewBuilder
    private var parentSelectionSection: some View {
        // 只在父母关系中显示选择现有人物选项
        if (type == .father || type == .mother),
           let currentPerson = appViewModel.getStateManager().state.selectedPerson {
            let potentialParents = getPotentialParents(
                for: currentPerson,
                type: type
            )
            
            if !potentialParents.isEmpty {
                Divider()
                ForEach(potentialParents) { parent in
                    parentButton(for: parent, currentPerson: currentPerson)
                }
            }
        }
    }
        
    // 父母按钮
    private func parentButton(for parent: Person, currentPerson: Person) -> some View {
        Button(action: {
            processingParentId = parent.id
            // 使用 appViewModel 而不是直接访问 stateManager
            appViewModel.getStateManager().updateLoadingState(true)
            
            Task {
                do {
                    try await appViewModel.getStateManager().addRelationship(
                        from: currentPerson,
                        to: parent,
                        type: type
                    )
                    await appViewModel.refreshData()  // 添加刷新
                } catch {
                    print("添加关系失败：\(error.localizedDescription)")
                }
                processingParentId = nil
                // 使用 appViewModel 而不是直接访问 stateManager
                appViewModel.getStateManager().updateLoadingState(false)
            }
        }) {
            Label("选择 \(parent.name)", systemImage: "person.fill")
            if processingParentId == parent.id {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .disabled(processingParentId != nil)
    }
    
    // 添加获取潜在父母的方法
    private func getPotentialParents(for person: Person, type: RelationType) -> [Person] {
        let otherParentType: RelationType = type == .father ? .mother : .father
        guard let otherParent = appViewModel.getStateManager().getRelatedPersons(for: person, relationType: otherParentType).first else {
            return []
        }
        
        return appViewModel.getStateManager().getRelatedPersons(for: otherParent, relationType: .spouse)
            .filter { $0.gender == (type == .father ? .male : .female) }
    }
}

private struct PersonListView: View {
    let persons: [Person]
    @EnvironmentObject var appViewModel: FamilyAppViewModel  // 修改这里
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    let onPersonTap: (Person) -> Void
    let type: RelationType
    
    var body: some View {
        // 对配偶类型进行特殊处理，确保唯一性
        let uniquePersons = type == .spouse ? 
            Array(Set(persons.map { $0.id }).compactMap { id in
                persons.first { $0.id == id }
            }) : persons
        
        ForEach(uniquePersons) { person in
            PersonItemView(
                person: person,
                animation: animation,  // 移除 stateManager 参数
                isSelected: selectedPersonId == person.id,
                type: type,
                onTap: { handlePersonTap(person) }
            )
            .id("\(type.rawValue)_\(person.id)")
        }
    }
    
    private func handlePersonTap(_ person: Person) {
        withAnimation(.spring(duration: 0.5)) {
            selectedPersonId = person.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedPersonId = nil
            onPersonTap(person)
        }
    }
}

