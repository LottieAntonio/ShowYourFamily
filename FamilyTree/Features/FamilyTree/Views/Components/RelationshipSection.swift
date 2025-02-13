
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
    @Namespace private var animation
    @State private var selectedPersonId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if persons.isEmpty {
                EmptyRelationView(title: title, onAddTap: onAddTap)
            } else {
                FilledRelationView(
                    title: title,
                    persons: persons,
                    onAddTap: onAddTap,
                    onPersonTap: onPersonTap,
                    viewModel: viewModel,
                    animation: animation,
                    selectedPersonId: $selectedPersonId
                )
            }
        }
    }
}

// 空状态视图
private struct EmptyRelationView: View {
    let title: String
    let onAddTap: () -> Void
    
    var body: some View {
        Button(action: onAddTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .frame(height: 100)
                    .foregroundStyle(Color.gray.opacity(0.1))
                    .overlay(alignment: .topLeading) {
                        VStack {
                            HStack {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: onAddTap) {
                                    Image(systemName: "plus.circle")
                                        .font(.callout)
                                        .foregroundColor(.clear)
                                }
                            }
                            .padding(10)
                            Text("点击添加\(title)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
            }
        }
    }
}

// 有内容状态视图
private struct FilledRelationView: View {
    let title: String
    let persons: [Person]
    let onAddTap: () -> Void
    let onPersonTap: (Person) -> Void
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(height: 100)
                .foregroundStyle(Color.gray.opacity(0.1))
                .overlay(alignment: .topLeading) {
                    HeaderView(title: title, onAddTap: onAddTap)
                }
            
            PersonListView(
                persons: persons,
                viewModel: viewModel,
                animation: animation,
                selectedPersonId: $selectedPersonId,  // 修改参数名，移除多余的's'
                onPersonTap: onPersonTap
            )
        }
    }
}

// 头部视图
private struct HeaderView: View {
    let title: String
    let onAddTap: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: onAddTap) {
                Image(systemName: "plus.circle")
                    .font(.callout)
            }
        }
        .padding(10)
    }
}

// 人物列表视图
private struct PersonListView: View {
    let persons: [Person]
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?  // 修改变量名，移除多余的's'
    let onPersonTap: (Person) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            PersonRowView(
                persons: persons,
                viewModel: viewModel,
                animation: animation,
                selectedPersonId: $selectedPersonId,  // 现在可以正确引用
                onPersonTap: onPersonTap
            )
        }
        .background(RoundedRectangle(cornerRadius: 5)
            .foregroundStyle(Color.gray.opacity(0.1)))
        .padding(.horizontal,15)
        .padding(.top, 20)
    }
}

// 新增人物行视图
private struct PersonRowView: View {
    let persons: [Person]
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    @Binding var selectedPersonId: UUID?
    let onPersonTap: (Person) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(persons) { person in
                PersonItemView(
                    person: person,
                    viewModel: viewModel,
                    animation: animation,
                    isSelected: selectedPersonId == person.id,
                    onTap: {
                        handlePersonTap(person)
                    }
                )
            }
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

// 新增单个人物项视图
private struct PersonItemView: View {
    let person: Person
    @ObservedObject var viewModel: PersonManagementViewModel
    let animation: Namespace.ID
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        PersonCardCompact(
            person: person,
            isSelected: person.id == viewModel.selectedPerson?.id
        )
        .frame(width: 100, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .foregroundStyle(Color.gray.opacity(0.1))
        )
        .matchedGeometryEffect(
            id: person.id,
            in: animation,
            isSource: !isSelected
        )
        .onTapGesture(perform: onTap)
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

// PersonCardCompact 保持不变
private struct PersonCardCompact: View {
    let person: Person
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: person.gender == .male ? "person.circle.fill" : "person.circle")
                .font(.title2)
                .foregroundStyle(person.gender == .male ? .blue : .pink)
            
            Text("\(person.lastName)\(person.firstName)")
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .contentTransition(.identity)  // 添加内容过渡
    }
}

// 预览代码
#Preview("关系区域") {
    let familyViewModel = FamilyTreeViewModel()
    RelationshipSection(
        title: "父亲",  // 修改标题
        persons: [
            Person(firstName: "三", lastName: "张", gender: .male)  // 只保留一个示例人物
        ],
        onAddTap: {},
        onPersonTap: { _ in },
        viewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel)
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
        viewModel: PersonManagementViewModel(familyTreeViewModel: familyViewModel)
    )
    .padding()
}
