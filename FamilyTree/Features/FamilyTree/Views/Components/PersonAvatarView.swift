import SwiftUI

struct PersonAvatarView: View {
    let person: Person
    let size: CGFloat
    let type: RelationType?
    let isEditable: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.familyTheme.gradientFor(.spouse))
                .overlay {
                    if let relationType = type {
                        Circle()
                            .fill(Color.familyTheme.gradientFor(relationType))
                    }
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            if isEditable {
                Image(systemName: "camera.circle.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: size * 0.5))
            } else {
                Text(person.name.prefix(1))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}
