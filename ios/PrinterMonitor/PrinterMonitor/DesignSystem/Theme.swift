import SwiftUI

/// Design system tokens for Printer Monitor
/// Based on "Liquid Aurora" design language
enum Theme {
    // MARK: - Colors

    enum Colors {
        // Primary accent - Celestial Cyan
        static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)

        // Aurora gradient colors
        static let auroraStart = Color(red: 0.35, green: 0.78, blue: 0.98)
        static let auroraMid = Color(red: 0.55, green: 0.6, blue: 0.95)
        static let auroraEnd = Color(red: 0.45, green: 0.85, blue: 0.75)

        // Semantic colors
        static let success = Color(red: 0.3, green: 0.75, blue: 0.55)
        static let warning = Color(red: 0.95, green: 0.7, blue: 0.35)
        static let error = Color(red: 0.9, green: 0.4, blue: 0.45)

        // Backgrounds (dark mode optimized)
        static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)
        static let backgroundCard = Color(red: 0.12, green: 0.12, blue: 0.14)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.5)
    }

    // MARK: - Typography

    enum Typography {
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let display = Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        static let label = Font.system(size: 13, weight: .medium)
        static let labelSmall = Font.system(size: 11, weight: .medium)
        static let numericLarge = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let numeric = Font.system(size: 28, weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Shadows

    enum Shadows {
        static let small = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Gradients

    enum Gradients {
        static let aurora = LinearGradient(
            colors: [Colors.auroraStart, Colors.auroraMid, Colors.auroraEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let auroraVertical = LinearGradient(
            colors: [Colors.auroraStart, Colors.auroraMid, Colors.auroraEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Animation

    enum Animation {
        static let fast: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.4

        static let spring = SwiftUI.Animation.spring(dampingFraction: 0.7)
    }
}

// MARK: - View Extensions

extension View {
    func cardBackground() -> some View {
        self
            .background(Theme.Colors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }

    func glassBackground() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }

    func shadow(_ shadow: Theme.Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}
