import SwiftUI

struct FamilySealView: View {
    let lastName: String
    let totalMembers: Int
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 外圈装饰
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.familyTheme.primary.opacity(0.2),
                            Color.familyTheme.primary.opacity(0.5),
                            Color.familyTheme.primary.opacity(0.2)
                        ]),
                        center: .center
                    ),
                    lineWidth: 5
                )
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            // 内圈印章效果
//            VStack(spacing: 4) {
//                Text(lastName)
//                    .font(.system(size: 20, weight: .bold))
//                    .foregroundStyle(Color.familyTheme.primary)
//                
//                Text("家")
//                    .font(.system(size: 20, weight: .medium))
//                    .foregroundStyle(Color.familyTheme.primary.opacity(0.8))
//                
//                Text("\(totalMembers)人")
//                    .font(.system(size: 20))
//                    .foregroundStyle(Color.familyTheme.primary.opacity(0.6))
//            }
//            .padding(20)
//            .background(
//                Circle()
//                    .fill(Color.familyTheme.primary.opacity(0.1))
//            )
        }
    }
}
