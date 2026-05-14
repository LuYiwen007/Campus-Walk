import SwiftUI

/// 与「优化 UI 风格与详情页」原型（Tailwind / shadcn 浅色）对齐的语义色与圆角。
enum CampusWalkUITheme {
    /// Tailwind blue-500
    static let brandBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let brandBlueMutedBg = Color(red: 0.93, green: 0.95, blue: 1.0)
    static let brandBlueBorder = Color(red: 0.82, green: 0.89, blue: 0.98)

    static let textPrimary = Color.primary
    static let textSecondary = Color(red: 0.45, green: 0.48, blue: 0.52)
    static let textMuted = Color(red: 0.55, green: 0.58, blue: 0.62)

    static let borderSubtle = Color.black.opacity(0.06)
    static let cardStroke = Color(red: 0.92, green: 0.93, blue: 0.94)

    static let sectionTitle = Color(red: 0.55, green: 0.58, blue: 0.62)
    static let surfaceGray50 = Color(red: 0.97, green: 0.98, blue: 0.98)

    static let cornerCard: CGFloat = 10
    static let cornerPill: CGFloat = 8
    static let cornerHeroImage: CGFloat = 0
}
