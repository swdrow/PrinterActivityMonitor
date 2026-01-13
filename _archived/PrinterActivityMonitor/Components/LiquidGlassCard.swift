import SwiftUI

// MARK: - Liquid Glass Card
/// A refined glass morphism card with iOS-native dark mode aesthetic
/// Replaces the heavier GlassCard with a cleaner, lighter implementation

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var style: Style = .standard
    var cornerRadius: CGFloat = DS.Radius.large

    enum Style {
        case standard      // Default card
        case elevated      // More prominent with subtle glow
        case subtle        // More transparent, recessed
        case interactive   // For tappable items
        case accent        // With accent color tint
    }

    init(
        style: Style = .standard,
        cornerRadius: CGFloat = DS.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    // Style-specific overlay
                    switch style {
                    case .elevated:
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(DS.Colors.surfaceGlassElevated)
                    case .subtle:
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.black.opacity(0.2))
                    case .accent:
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(DS.Colors.accent.opacity(0.06))
                    case .interactive:
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(DS.Colors.surfaceGlass)
                    case .standard:
                        EmptyView()
                    }

                    // Top edge highlight (light source simulation)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(highlightOpacity),
                                    Color.white.opacity(highlightOpacity * 0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: DS.Stroke.hairline
                        )
                }
            }
            .shadow(DS.Shadows.subtle)
            .modifier(ElevatedGlowModifier(isElevated: style == .elevated))
    }

    private var highlightOpacity: Double {
        switch style {
        case .elevated: return 0.18
        case .subtle: return 0.08
        case .accent: return 0.15
        case .interactive: return 0.12
        case .standard: return 0.12
        }
    }
}

// MARK: - Elevated Glow Modifier

private struct ElevatedGlowModifier: ViewModifier {
    let isElevated: Bool

    func body(content: Content) -> some View {
        if isElevated {
            content
                .shadow(color: DS.Colors.accent.opacity(0.08), radius: 20, y: 0)
        } else {
            content
        }
    }
}

// MARK: - Active Glass Card
/// Animated glass card with subtle pulse for active/printing states

struct LiquidGlassCardActive<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = DS.Radius.large
    @State private var isPulsing = false

    init(
        cornerRadius: CGFloat = DS.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                ZStack {
                    // Base glass
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    // Pulsing accent tint
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DS.Colors.accent.opacity(isPulsing ? 0.08 : 0.04))

                    // Subtle inner glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [
                                    DS.Colors.accent.opacity(isPulsing ? 0.06 : 0.02),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )

                    // Top highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DS.Colors.accent.opacity(0.3),
                                    DS.Colors.accent.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: DS.Stroke.thin
                        )
                }
            }
            .shadow(DS.Shadows.subtle)
            .shadow(color: DS.Colors.accent.opacity(isPulsing ? 0.15 : 0.08), radius: 24, y: 0)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Compact Glass Card
/// Smaller glass card for badges, stats, and compact UI elements

struct LiquidGlassCompact<Content: View>: View {
    let content: Content
    var tint: Color?
    var cornerRadius: CGFloat = DS.Radius.medium

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = DS.Radius.medium,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tint.opacity(0.08))
                    }

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: DS.Stroke.hairline
                        )
                }
            }
    }
}

// MARK: - Glass Pill
/// Pill-shaped glass background for badges and status indicators

struct GlassPill<Content: View>: View {
    let content: Content
    var tint: Color?

    init(
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .background {
                Capsule()
                    .fill(tint?.opacity(0.12) ?? Color.white.opacity(0.08))
            }
    }
}

// MARK: - Preview

#Preview("Liquid Glass Cards") {
    ScrollView {
        VStack(spacing: DS.Spacing.lg) {
            // Standard Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Standard Card")
                        .font(DS.Typography.headline)
                    Text("Clean, light glass effect")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Elevated Card
            LiquidGlassCard(style: .elevated) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Elevated Card")
                        .font(DS.Typography.headline)
                    Text("Subtle accent glow")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Active Card
            LiquidGlassCardActive {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Active Card")
                        .font(DS.Typography.headline)
                    Text("Pulsing for active states")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Accent Card
            LiquidGlassCard(style: .accent) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Accent Card")
                        .font(DS.Typography.headline)
                    Text("With accent color tint")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Compact Cards
            HStack(spacing: DS.Spacing.sm) {
                LiquidGlassCompact {
                    Text("Compact")
                        .font(DS.Typography.label)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                }

                LiquidGlassCompact(tint: DS.Colors.accent) {
                    Text("Tinted")
                        .font(DS.Typography.label)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                }

                GlassPill(tint: DS.Colors.success) {
                    Text("Pill")
                        .font(DS.Typography.label)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(DS.Spacing.lg)
    }
    .background(DS.Colors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
