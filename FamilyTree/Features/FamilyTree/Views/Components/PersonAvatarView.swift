import SwiftUI

struct PersonAvatarView: View {
    let person: Person
    let size: CGFloat
    let type: RelationType?
    let isEditable: Bool
    
    init(
        person: Person,
        size: CGFloat = 60,
        type: RelationType? = nil,
        isEditable: Bool = false
    ) {
        self.person = person
        self.size = size
        self.type = type
        self.isEditable = isEditable
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.familyTheme.gradientFor(type ?? .spouse))
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
