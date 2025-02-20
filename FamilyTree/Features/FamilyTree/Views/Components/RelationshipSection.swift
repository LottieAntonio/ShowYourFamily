
/*
 * RelationshipSection 视图
 * 作用：显示特定类型的关系部分
 * - 显示关系列表
 * - 处理添加新关系
 * - 处理人物选择
 */

import SwiftUI

struct RelationshipSection: View {
    let title: String
    let persons: [Person]
    let onAddTap: () -> Void
    let onPersonTap: (Person) -> Void
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    let type: RelationType
    
    // MARK: - Body
    
    // 添加计算属性来确定区域大小
    private var sectionSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 40
        let minWidth: CGFloat = 150 // 设置最小宽度
        
        switch type {
        case .spouse, .child:
            return CGSize(width: max(screenWidth, minWidth), height: 100)
        default:
            let calculatedWidth = (screenWidth - padding) / 2
            return CGSize(width: max(calculatedWidth, minWidth), height: 100)
        }
    }
    
    @State private var showingPotentialParents = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(
                title: title,
                onAddTap: onAddTap,
                type: type,
                viewModel: viewModel, localPersons: persons
            )
            
            if persons.isEmpty || viewModel.isProcessing {
                EmptyStateView(
                    title: title,
                    onAddTap: onAddTap,
                    type: type,
                    viewModel: viewModel
                )
            } else {
                ScrollView(persons.count == 1 ? .vertical : .horizontal, showsIndicators: false) {
                    HStack {
                        PersonListView(
                            persons: persons,
                            viewModel: viewModel,
                            animation: animation,
                            selectedPersonId: $selectedPersonId,
                            onPersonTap: onPersonTap,
                            type: type
                        )
                    }
                }
            }
        }
        .padding(8)
        .frame(
            width: type == .spouse || type == .child ? .infinity : sectionSize.width,
            height: sectionSize.height,
            alignment: .top
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
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
            .font(.system(size: 10))
            .foregroundColor(type.textColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(type.backgroundColor)
            .cornerRadius(4)
    }
}

// 在 PersonItemView 中添加 getRelationshipType 方法
private struct PersonItemView: View {
    let person: Person
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    let isSelected: Bool
    let type: RelationType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 添加头像
                Circle()
                    .fill(Color.familyTheme.gradientFor(type))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(person.name.prefix(1))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(person.name)
                            .font(.headline)
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
//                Image(systemName: "chevron.right")
//                    .foregroundStyle(.secondary)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        Color.familyTheme.gradientFor(type)
                            .opacity(0.15)
                    )
                    .shadow(
                        color: Color.familyTheme.primary.opacity(0.1),
                        radius: 5,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(
            id: person.id,
            in: animation,
            isSource: !isSelected
        )
    }
    
    private func getRelationshipType() -> RelationshipType? {
        // 只有兄弟姐妹关系才需要显示标识
        guard type == .brother || type == .sister else { return nil }
        
        // 获取当前选中人物
        guard let currentPerson = viewModel.selectedPerson else { return nil }
        
        // 获取双方的父母
        let currentFather = viewModel.relationshipService.getRelatedPersons(for: currentPerson, relationType: .father).first
        let currentMother = viewModel.relationshipService.getRelatedPersons(for: currentPerson, relationType: .mother).first
        
        let personFather = viewModel.relationshipService.getRelatedPersons(for: person, relationType: .father).first
        let personMother = viewModel.relationshipService.getRelatedPersons(for: person, relationType: .mother).first
        
        // 判断关系类型
        let hasSameFather = currentFather?.id == personFather?.id && currentFather != nil
        let hasSameMother = currentMother?.id == personMother?.id && currentMother != nil
        
        if hasSameFather && hasSameMother {
            return .fullSibling
        } else if hasSameFather {
            return .paternalSibling
        } else if hasSameMother {
            return .maternalSibling
        }
        
        return nil
    }
}

// MARK: - Subviews
private struct HeaderView: View {
    let title: String
    let onAddTap: () -> Void
    let type: RelationType
    @ObservedObject var viewModel: PersonManagementViewModel
    @State private var showingPotentialParents = false
    @State private var processingParentId: UUID?
    let localPersons: [Person]
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.familyTheme.primary)
                    
                    // 当人物数量大于1时显示数量
                if localPersons.count > 1 {
                    Text("(\(localPersons.count))")
                            .font(.caption)
                            .foregroundStyle(Color.familyTheme.primary.opacity(0.6))
                    }
            }
            Spacer()
            Menu {
                // 添加新人物按钮
                Button(action: onAddTap) {
                    Label("添加新\(title)", systemImage: "person.badge.plus")
                }
                
                // 只在父母关系中显示选择现有人物选项
                if (type == .father || type == .mother),
                   let currentPerson = viewModel.selectedPerson {
                    let potentialParents = viewModel.relationshipService.getPotentialParents(
                        for: currentPerson,
                        type: type
                    )
                    
                    if !potentialParents.isEmpty {
                        Divider()
                        ForEach(potentialParents) { parent in
                            Button(action: {
                                processingParentId = parent.id
                                viewModel.isProcessing = true  // 设置处理状态
                                
                                // 后台处理数据更新
                                Task {
                                    do {
                                        try await viewModel.relationshipService.addRelationship(
                                            from: currentPerson,
                                            to: parent,
                                            type: type
                                        )
                                    } catch {
                                        print("添加关系失败：\(error.localizedDescription)")
                                    }
                                    processingParentId = nil
                                    viewModel.isProcessing = false  // 重置处理状态
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
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(Color.familyTheme.primary)
                    .font(.callout)
            }
            .disabled(processingParentId != nil)
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let onAddTap: () -> Void
    let type: RelationType
    @ObservedObject var viewModel: PersonManagementViewModel
    @State private var processingParentId: UUID?
    
    var body: some View {
        Menu {
            // 添加新人物按钮
            Button(action: onAddTap) {
                Label("添加新\(title)", systemImage: "person.badge.plus")
            }
            
            // 只在父母关系中显示选择现有人物选项
            if (type == .father || type == .mother),
               let currentPerson = viewModel.selectedPerson {
                let potentialParents = viewModel.relationshipService.getPotentialParents(
                    for: currentPerson,
                    type: type
                )
                
                if !potentialParents.isEmpty {
                    Divider()
                    ForEach(potentialParents) { parent in
                        Button(action: {
                            processingParentId = parent.id
                            viewModel.isProcessing = true
                            
                            Task {
                                do {
                                    try await viewModel.relationshipService.addRelationship(
                                        from: currentPerson,
                                        to: parent,
                                        type: type
                                    )
                                } catch {
                                    print("添加关系失败：\(error.localizedDescription)")
                                }
                                processingParentId = nil
                                viewModel.isProcessing = false
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
                }
            }
        } label: {
            HStack {
                Text("点击添加\(title)")
                    .font(.caption)
                    .foregroundStyle(Color.familyTheme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(processingParentId != nil)
    }
}

private struct PersonListView: View {
    let persons: [Person]
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    let onPersonTap: (Person) -> Void
    let type: RelationType
    
    var body: some View {
        ForEach(persons) { person in
            PersonItemView(
                person: person,
                viewModel: viewModel,
                animation: animation,
                isSelected: selectedPersonId == person.id,
                type: type,
                onTap: { handlePersonTap(person) }
            )
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

// MARK: - Previews
#Preview("关系区域") {
    let familyViewModel = FamilyTreeViewModel()
    RelationshipSection(
        title: "父亲",
        persons: [
            Person(firstName: "三", lastName: "张", gender: .male)
        ],
        onAddTap: {},
        onPersonTap: { _ in },
        viewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel),
        animation: Namespace().wrappedValue,
        selectedPersonId: .constant(nil),
        type: .father
    )
    .padding()
}

#Preview("空关系区域") {
    let familyViewModel = FamilyTreeViewModel()
    RelationshipSection(
        title: "父母",
        persons: [],
        onAddTap: {},
        onPersonTap: { _ in },
        viewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel),
        animation: Namespace().wrappedValue,
        selectedPersonId: .constant(nil),
        type: .father
    )
    .padding()
}
