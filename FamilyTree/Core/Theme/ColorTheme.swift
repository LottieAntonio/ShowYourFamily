import SwiftUI

extension Color {
    static let familyTheme = FamilyThemeColors()
}

struct FamilyThemeColors {
    // 主色调
    let primary = Color(hex: "6366F1")    // 靛蓝色
    let secondary = Color(hex: "A855F7")  // 紫色
    let accent = Color(hex: "EC4899")     // 粉色
    
    // 背景渐变
    let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "F5F3FF").opacity(0.8),
            Color(hex: "EDE9FE").opacity(0.5)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 关系卡片渐变色组
    let relationshipGradients: [RelationType: LinearGradient] = [
        .father: LinearGradient(
            colors: [Color(hex: "93C5FD"), Color(hex: "3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .mother: LinearGradient(
            colors: [Color(hex: "F9A8D4"), Color(hex: "EC4899")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .spouse: LinearGradient(
            colors: [Color(hex: "C084FC"), Color(hex: "8B5CF6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .child: LinearGradient(
            colors: [Color(hex: "6EE7B7"), Color(hex: "059669")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .brother: LinearGradient(
            colors: [Color(hex: "93C5FD"), Color(hex: "2563EB")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .sister: LinearGradient(
            colors: [Color(hex: "FCA5A5"), Color(hex: "EF4444")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ]
    
    // 获取关系对应的渐变色
    func gradientFor(_ type: RelationType) -> LinearGradient {
        relationshipGradients[type] ?? defaultGradient
    }
    
    // 添加自己身份的特殊渐变色
    func selfGradient() -> LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FDE68A"), Color(hex: "F59E0B")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // 默认渐变色
    let defaultGradient = LinearGradient(
        colors: [Color(hex: "CBD5E1"), Color(hex: "64748B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// 用于创建十六进制颜色的扩展
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
