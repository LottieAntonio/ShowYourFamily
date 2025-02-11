import SwiftUI

struct PersonRow: View {
    let person: Person
    let isSelected: Bool
    let onTap: () -> Void  // 添加点击回调
    
    var body: some View {
        HStack {
            Image(systemName: person.gender == .male ? "person.circle.fill" : "person.circle")
                .foregroundStyle(person.gender == .male ? .blue : .pink)
            
            VStack(alignment: .leading) {
                Text("\(person.lastName)\(person.firstName)")
                    .font(.headline)
                if let birthDate = person.birthDate {
                    Text(birthDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 添加右侧箭头指示器
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .opacity(0.5)
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())  // 确保整行都可以点击
        .onTapGesture(perform: onTap)
    }
}