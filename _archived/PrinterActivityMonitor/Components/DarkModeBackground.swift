import SwiftUI

// MARK: - Dark Mode Background
/// Premium dark mode background using the Liquid Aurora design system

struct DarkModeBackground: View {
    var accentColor: Color?
    var style: BackgroundStyle

    enum BackgroundStyle {
        case standard      // Simple dark gradient
        case radialGlow    // Centered accent glow
        case topGlow       // Top-down accent wash
        case ambient       // Subtle corner glows
        case aurora        // Aurora gradient effect
    }

    init(accentColor: Color? = nil, style: BackgroundStyle = .standard) {
        self.accentColor = accentColor
        self.style = style
    }

    var body: some View {
        ZStack {
            // Base dark gradient using DS colors
            LinearGradient(
                colors: [
                    DS.Colors.backgroundSecondary,
                    DS.Colors.backgroundPrimary,
                    Color(red: 0.02, green: 0.02, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Accent glow layer
            if let accent = resolvedAccentColor {
                glowLayer(accent: accent)
            }
        }
        .ignoresSafeArea()
    }

    private var resolvedAccentColor: Color? {
        accentColor ?? (style != .standard ? DS.Colors.accent : nil)
    }

    @ViewBuilder
    private func glowLayer(accent: Color) -> some View {
        switch style {
        case .radialGlow:
            RadialGradient(
                colors: [
                    accent.opacity(0.12),
                    accent.opacity(0.04),
                    .clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 350
            )

        case .topGlow:
            LinearGradient(
                colors: [
                    accent.opacity(0.10),
                    accent.opacity(0.03),
                    .clear,
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        case .ambient:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 280
                )
                RadialGradient(
                    colors: [accent.opacity(0.04), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 220
                )
            }

        case .aurora:
            ZStack {
                RadialGradient(
                    colors: [DS.Colors.auroraStart.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                RadialGradient(
                    colors: [DS.Colors.auroraMid.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 250
                )
                RadialGradient(
                    colors: [DS.Colors.auroraEnd.opacity(0.04), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 200
                )
            }

        case .standard:
            EmptyView()
        }
    }
}

// MARK: - Animated Aurora Background
/// Subtle animated background with drifting aurora glow

struct AnimatedAuroraBackground: View {
    var intensity: Double
    @State private var phase: CGFloat = 0

    init(intensity: Double = 0.8) {
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            DS.Colors.backgroundPrimary

            // Drifting aurora glow
            RadialGradient(
                colors: [
                    DS.Colors.accent.opacity(0.10 * intensity),
                    DS.Colors.accentLight.opacity(0.04 * intensity),
                    .clear
                ],
                center: UnitPoint(
                    x: 0.3 + 0.15 * sin(phase * .pi * 2),
                    y: 0.25 + 0.08 * cos(phase * .pi * 2)
                ),
                startRadius: 40,
                endRadius: 320
            )

            // Secondary aurora wash
            RadialGradient(
                colors: [
                    DS.Colors.auroraMid.opacity(0.06 * intensity),
                    .clear
                ],
                center: UnitPoint(
                    x: 0.7 - 0.1 * cos(phase * .pi * 2),
                    y: 0.6 + 0.1 * sin(phase * .pi * 2)
                ),
                startRadius: 30,
                endRadius: 250
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 10)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply dark mode background with optional accent glow
    func darkBackground(
        accent: Color? = nil,
        style: DarkModeBackground.BackgroundStyle = .standard
    ) -> some View {
        background {
            DarkModeBackground(accentColor: accent, style: style)
        }
    }

    /// Apply animated aurora background
    func auroraBackground(intensity: Double = 0.8) -> some View {
        background {
            AnimatedAuroraBackground(intensity: intensity)
        }
    }
}

// MARK: - Preview

#Preview("Standard") {
    VStack {
        Text("Standard Background")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .darkBackground()
}

#Preview("Radial Glow") {
    VStack {
        Text("Radial Glow")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .darkBackground(style: .radialGlow)
}

#Preview("Top Glow") {
    VStack {
        Text("Top Glow")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .darkBackground(style: .topGlow)
}

#Preview("Aurora") {
    VStack {
        Text("Aurora Style")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .darkBackground(style: .aurora)
}

#Preview("Animated Aurora") {
    VStack {
        Text("Animated Aurora")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .auroraBackground()
}
