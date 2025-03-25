import SwiftUI

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
    }
}