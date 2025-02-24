import SwiftUI

struct FamilyCard: View {
    let family: Family
    let memberCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // 图标
            Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            // 标题
            Text(family.name)
                .font(.headline)
            
            // 描述
            Text(family.description ?? "暂无描述")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
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