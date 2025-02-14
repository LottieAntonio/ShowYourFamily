import SwiftUI

struct FamilyTreeEmptyStateView: View {
    let showAddPerson: () -> Void
    
    var body: some View {
        Button(action: { showAddPerson() }) {
            VStack(spacing: 16) {
                Image(systemName: "person.3")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.familyTheme.primary)
                
                Text("开始创建家谱")
                    .font(.title2)
                    .foregroundStyle(Color.familyTheme.secondary)
                
                Text("点击添加第一位家庭成员")
                    .font(.subheadline)
                    .foregroundStyle(Color.familyTheme.accent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.familyTheme.primary.opacity(0.2), radius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}
