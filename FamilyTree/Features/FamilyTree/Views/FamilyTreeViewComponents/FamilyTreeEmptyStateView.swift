import SwiftUI

struct FamilyTreeEmptyStateView: View {
    let showAddPerson: () -> Void
    @State private var animating = false
    
    var body: some View {
        Button(action: showAddPerson) {
            // 只保留图标，去掉所有文字
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.familyTheme.primary, Color.familyTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(40)
                .background(
                    ZStack {
                        // 内部填充
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.familyTheme.primary.opacity(0.3), radius: 15, x: 0, y: 5)
                        
                        // 添加动画边框
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.familyTheme.accent, Color.familyTheme.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )
                            .scaleEffect(animating ? 1.2 : 1)
                            .opacity(animating ? 0.8 : 0.5)
                    }
                )
        }
        .buttonStyle(PressableButtonStyle())
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            // 启动呼吸动画
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }
}

// 添加一个可按压效果的按钮样式
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
