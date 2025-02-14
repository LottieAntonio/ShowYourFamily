
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(title: title, onAddTap: onAddTap)
            
            if persons.isEmpty {
                EmptyStateView(title: title, onAddTap: onAddTap)
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
                    Text(person.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(person.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "未设置生日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
//                Image(systemName: "chevron.right")
//                    .foregroundStyle(.secondary)
            }
            .padding(10)
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
}

// MARK: - Subviews
private struct HeaderView: View {
    let title: String
    let onAddTap: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.familyTheme.primary)
            Spacer()
            Button(action: onAddTap) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.familyTheme.primary)
                    .font(.callout)
            }
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let onAddTap: () -> Void
    
    var body: some View {
        Button(action: onAddTap) {
            HStack {
                Text("点击添加\(title)")
                    .font(.caption)
                    .foregroundStyle(Color.familyTheme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
           
        }
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
