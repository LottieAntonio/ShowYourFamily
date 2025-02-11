
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            if persons.isEmpty {
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
            } else {
                ZStack() {
                    RoundedRectangle(cornerRadius: 5)
                        .frame(height: 100)
                        .foregroundStyle(Color.gray.opacity(0.1))
                        .overlay(alignment: .topLeading) {
                                
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(persons) { person in
                                PersonCardCompact(
                                    person: person,
                                    isSelected: person.id == viewModel.selectedPerson?.id
                                )
                                .frame(width: 100, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .foregroundStyle(Color.gray.opacity(0.1))
                                )
                                .onTapGesture {
                                    onPersonTap(person)
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundStyle(Color.gray.opacity(0.1)))
                    .padding(.horizontal,15)
                    .padding(.top, 20)
                }
            }
        }
    }
}

// 修改紧凑型人物卡片视图
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
