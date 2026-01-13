import SwiftUI

// MARK: - Design System
/// Centralized design tokens for the Printer Activity Monitor app
/// Design Language: "Liquid Aurora" - iOS-native dark mode with soft gradients

enum DS {
    // MARK: - Colors

    enum Colors {
        // MARK: Primary Accent
        /// Celestial Cyan - the single primary accent color
        static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)
        static let accentLight = Color(red: 0.55, green: 0.85, blue: 1.0)
        static let accentDark = Color(red: 0.2, green: 0.55, blue: 0.75)

        // MARK: Aurora Gradient Colors
        /// Soft 3-color aurora for special elements (progress rings, highlights)
        static let auroraStart = Color(red: 0.35, green: 0.78, blue: 0.98)   // Cyan
        static let auroraMid = Color(red: 0.55, green: 0.6, blue: 0.95)      // Soft violet
        static let auroraEnd = Color(red: 0.45, green: 0.85, blue: 0.75)     // Mint

        static var auroraGradient: [Color] {
            [auroraStart, auroraMid, auroraEnd]
        }

        // MARK: Semantic Colors
        static let success = Color(red: 0.3, green: 0.75, blue: 0.55)    // Muted teal-green
        static let warning = Color(red: 0.95, green: 0.7, blue: 0.35)    // Warm amber
        static let error = Color(red: 0.9, green: 0.4, blue: 0.45)       // Soft coral
        static let neutral = Color(red: 0.55, green: 0.55, blue: 0.6)    // Cool gray

        // MARK: Background Colors
        /// Deep space backgrounds - NOT pure black
        static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)
        static let backgroundTertiary = Color(red: 0.12, green: 0.12, blue: 0.14)
        static let backgroundElevated = Color(red: 0.14, green: 0.14, blue: 0.16)

        // MARK: Surface Colors (Glass)
        static let surfaceGlass = Color.white.opacity(0.05)
        static let surfaceGlassElevated = Color.white.opacity(0.08)
        static let surfaceGlassHighlight = Color.white.opacity(0.12)

        // MARK: Text Colors
        static let textPrimary = Color.white.opacity(0.95)
        static let textSecondary = Color.white.opacity(0.6)
        static let textTertiary = Color.white.opacity(0.4)
        static let textDisabled = Color.white.opacity(0.25)

        // MARK: Border Colors
        static let borderSubtle = Color.white.opacity(0.08)
        static let borderLight = Color.white.opacity(0.15)
        static let borderAccent = accent.opacity(0.3)
    }

    // MARK: - Typography

    enum Typography {
        // Display - Screen titles only
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let display = Font.system(size: 28, weight: .bold, design: .rounded)

        // Headlines
        static let headline = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 17, weight: .semibold)

        // Body
        static let bodyLarge = Font.system(size: 17, weight: .regular)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyMedium = Font.system(size: 15, weight: .medium)
        static let bodySemibold = Font.system(size: 15, weight: .semibold)

        // Labels
        static let label = Font.system(size: 13, weight: .medium)
        static let labelSmall = Font.system(size: 11, weight: .medium)
        static let labelMicro = Font.system(size: 10, weight: .medium)

        // Numeric (for stats/progress)
        static let numericLarge = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let numeric = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let numericMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let numericSmall = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let numericMicro = Font.system(size: 14, weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing (8pt Grid)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radii

    enum Radius {
        static let xs: CGFloat = 4       // Progress bars
        static let small: CGFloat = 8    // Buttons, badges
        static let medium: CGFloat = 12  // Small cards, inputs
        static let large: CGFloat = 16   // Standard cards
        static let xl: CGFloat = 20      // Modal sheets
        static let xxl: CGFloat = 24     // Large cards
        static let full: CGFloat = 9999  // Pills, circular
    }

    // MARK: - Shadows

    enum Shadows {
        static let subtle = Shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        static let medium = Shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        static let elevated = Shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        static let glow = Shadow(color: Colors.accent.opacity(0.3), radius: 20, y: 0)
        static let glowSubtle = Shadow(color: Colors.accent.opacity(0.15), radius: 12, y: 0)
    }

    // MARK: - Animation

    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Stroke Widths

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let thin: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
        static let bold: CGFloat = 3
        static let heavy: CGFloat = 4
    }
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    var x: CGFloat { 0 }
}

// MARK: - Gradients

extension DS {
    enum Gradients {
        /// Aurora gradient for progress indicators
        static var aurora: AngularGradient {
            AngularGradient(
                colors: [
                    Colors.auroraStart,
                    Colors.accentLight,
                    Colors.auroraMid,
                    Colors.auroraEnd,
                    Colors.auroraStart
                ],
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        }

        /// Subtle aurora for progress (doesn't complete full circle)
        static func auroraProgress(progress: Double) -> AngularGradient {
            AngularGradient(
                colors: [
                    Colors.accent,
                    Colors.accentLight,
                    Colors.accent.opacity(0.8)
                ],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * progress)
            )
        }

        /// Linear aurora for progress bars
        static var auroraLinear: LinearGradient {
            LinearGradient(
                colors: Colors.auroraGradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        /// Accent gradient (single color variation)
        static var accent: LinearGradient {
            LinearGradient(
                colors: [Colors.accentDark, Colors.accent, Colors.accentLight],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        /// Glass card top highlight
        static var glassHighlight: LinearGradient {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Glass card edge highlight
        static var glassEdge: LinearGradient {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Background ambient glow
        static func ambientGlow(color: Color = Colors.accent) -> RadialGradient {
            RadialGradient(
                colors: [
                    color.opacity(0.15),
                    color.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
        }

        /// Dark background gradient
        static var background: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.backgroundPrimary,
                    Colors.backgroundSecondary,
                    Colors.backgroundPrimary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard shadow
    func shadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Apply accent glow
    func accentGlow(intensity: Double = 1.0) -> some View {
        self.shadow(color: DS.Colors.accent.opacity(0.3 * intensity), radius: 20, x: 0, y: 0)
    }

    /// Apply glass background
    func glassBackground(cornerRadius: CGFloat = DS.Radius.large) -> some View {
        self.background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DS.Gradients.glassEdge, lineWidth: DS.Stroke.hairline)
                }
        }
    }
}


// MARK: - Preview

#Preview("Design System Colors") {
    ScrollView {
        VStack(spacing: DS.Spacing.lg) {
            // Accent Colors
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Accent Colors")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                HStack(spacing: DS.Spacing.sm) {
                    ColorSwatch(color: DS.Colors.accentDark, name: "Dark")
                    ColorSwatch(color: DS.Colors.accent, name: "Accent")
                    ColorSwatch(color: DS.Colors.accentLight, name: "Light")
                }
            }

            // Aurora Colors
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Aurora Gradient")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                HStack(spacing: DS.Spacing.sm) {
                    ColorSwatch(color: DS.Colors.auroraStart, name: "Start")
                    ColorSwatch(color: DS.Colors.auroraMid, name: "Mid")
                    ColorSwatch(color: DS.Colors.auroraEnd, name: "End")
                }
            }

            // Semantic Colors
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Semantic Colors")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                HStack(spacing: DS.Spacing.sm) {
                    ColorSwatch(color: DS.Colors.success, name: "Success")
                    ColorSwatch(color: DS.Colors.warning, name: "Warning")
                    ColorSwatch(color: DS.Colors.error, name: "Error")
                    ColorSwatch(color: DS.Colors.neutral, name: "Neutral")
                }
            }

            // Typography
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Typography")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Display Large").font(DS.Typography.displayLarge)
                Text("Headline").font(DS.Typography.headline)
                Text("Body").font(DS.Typography.body)
                Text("Label").font(DS.Typography.label)
                Text("67%").font(DS.Typography.numeric)
            }
            .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(DS.Spacing.lg)
    }
    .background(DS.Colors.backgroundPrimary)
    .preferredColorScheme(.dark)
}

// Helper for preview
private struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(color)
                .frame(width: 60, height: 40)

            Text(name)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
