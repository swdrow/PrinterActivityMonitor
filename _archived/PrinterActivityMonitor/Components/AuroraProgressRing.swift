import SwiftUI

// MARK: - Aurora Progress Ring
/// An elegant, thin progress ring with subtle aurora gradient
/// Designed for Live Activity and dashboard use

struct AuroraProgressRing: View {
    let progress: Double  // 0-100
    var size: CGFloat = 60
    var lineWidth: CGFloat = 4
    var showGlow: Bool = true

    var body: some View {
        ZStack {
            // Track (background ring)
            Circle()
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: lineWidth
                )

            // Progress ring with aurora gradient
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 100)) / 100)
                .stroke(
                    auroraGradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Subtle glow at progress tip
            if showGlow && progress > 0 {
                Circle()
                    .trim(from: max(0, CGFloat(progress) / 100 - 0.03), to: CGFloat(progress) / 100)
                    .stroke(
                        DS.Colors.accentLight,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .blur(radius: 4)
                    .opacity(0.6)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    private var auroraGradient: AngularGradient {
        AngularGradient(
            colors: [
                DS.Colors.accent,
                DS.Colors.accentLight,
                DS.Colors.auroraMid.opacity(0.8),
                DS.Colors.accent
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

// MARK: - Compact Progress Ring
/// Smaller variant for Dynamic Island and compact displays

struct CompactProgressRing: View {
    let progress: Double
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 100)) / 100)
                .stroke(
                    LinearGradient(
                        colors: [DS.Colors.accent, DS.Colors.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress Ring with Center Content
/// Progress ring that can contain an icon, image, or percentage

struct ProgressRingWithContent<Content: View>: View {
    let progress: Double
    let content: Content
    var size: CGFloat = 80
    var lineWidth: CGFloat = 5

    init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 5,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuroraProgressRing(
                progress: progress,
                size: size,
                lineWidth: lineWidth
            )

            content
        }
    }
}

// MARK: - Linear Aurora Progress Bar
/// Linear progress bar with aurora gradient for horizontal displays

struct AuroraProgressBar: View {
    let progress: Double  // 0-100
    var height: CGFloat = 6
    var showGlow: Bool = true
    var cornerRadius: CGFloat? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: cornerRadius ?? height / 2)
                    .fill(Color.white.opacity(0.08))

                // Glow layer
                if showGlow {
                    RoundedRectangle(cornerRadius: cornerRadius ?? height / 2)
                        .fill(auroraLinear)
                        .frame(width: max(0, geometry.size.width * CGFloat(min(progress, 100)) / 100))
                        .blur(radius: 4)
                        .opacity(0.5)
                }

                // Progress fill
                RoundedRectangle(cornerRadius: cornerRadius ?? height / 2)
                    .fill(auroraLinear)
                    .frame(width: max(0, geometry.size.width * CGFloat(min(progress, 100)) / 100))
            }
        }
        .frame(height: height)
    }

    private var auroraLinear: LinearGradient {
        LinearGradient(
            colors: [
                DS.Colors.accent,
                DS.Colors.accentLight,
                DS.Colors.auroraMid.opacity(0.9)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Simple Accent Progress Bar
/// Simpler single-color progress bar for less prominent displays

struct AccentProgressBar: View {
    let progress: Double
    var height: CGFloat = 4
    var color: Color = DS.Colors.accent

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * CGFloat(min(progress, 100)) / 100))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview

#Preview("Progress Rings") {
    VStack(spacing: DS.Spacing.xl) {
        // Large ring
        HStack(spacing: DS.Spacing.xl) {
            VStack {
                AuroraProgressRing(progress: 67, size: 80, lineWidth: 5)
                Text("67%")
                    .font(DS.Typography.label)
            }

            VStack {
                AuroraProgressRing(progress: 25, size: 80, lineWidth: 5)
                Text("25%")
                    .font(DS.Typography.label)
            }

            VStack {
                AuroraProgressRing(progress: 100, size: 80, lineWidth: 5)
                Text("100%")
                    .font(DS.Typography.label)
            }
        }

        // With center content
        ProgressRingWithContent(progress: 67, size: 100, lineWidth: 6) {
            VStack(spacing: 2) {
                Text("67")
                    .font(DS.Typography.numeric)
                Text("%")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }

        // Compact rings
        HStack(spacing: DS.Spacing.lg) {
            CompactProgressRing(progress: 45, size: 24)
            CompactProgressRing(progress: 67, size: 24)
            CompactProgressRing(progress: 90, size: 24)
        }

        // Progress bars
        VStack(spacing: DS.Spacing.md) {
            AuroraProgressBar(progress: 67)

            AccentProgressBar(progress: 45, color: DS.Colors.warning)

            AccentProgressBar(progress: 80, color: DS.Colors.success)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }
    .foregroundStyle(DS.Colors.textPrimary)
    .padding(DS.Spacing.xl)
    .background(DS.Colors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
