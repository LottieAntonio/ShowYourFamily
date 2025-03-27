import SwiftUI

struct FamilyCard: View {
    let family: Family
    let memberCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // 图标 - 后续可以支持自定义图片
            Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                )
            
            // 标题
            Text(family.name)
                .font(.headline)
            
            // 描述
            Text(family.description ?? "暂无描述")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // 成员数量
            Text("\(memberCount) 位成员")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160, height: 180)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 3)
        )
    }
}

// 预览
struct FamilyCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 默认家谱预览
            FamilyCard(
                family: Family(id: UUID(), name: "默认家谱", description: "这是一个默认家谱", isDefault: true),
                memberCount: 5
            )
            .previewLayout(.sizeThatFits)
            .padding()
            
            // 自定义家谱预览
            FamilyCard(
                family: Family(id: UUID(), name: "我的家谱", description: "这是我创建的家谱，包含了我的家族成员", isDefault: false),
                memberCount: 12
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
        }
    }
}