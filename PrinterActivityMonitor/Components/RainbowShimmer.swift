import SwiftUI

/// Animated rainbow shimmer effect inspired by Gemini
struct RainbowShimmer: View {
    @State private var phase: CGFloat = 0
    let opacity: CGFloat

    init(opacity: CGFloat = 0.3) {
        self.opacity = opacity
    }

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: rainbowColors,
                startPoint: UnitPoint(x: phase - 0.5, y: 0),
                endPoint: UnitPoint(x: phase + 0.5, y: 1)
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
        }
    }

    private var rainbowColors: [Color] {
        [Color.blue, .cyan, .green, .yellow,
         .orange, .pink, .purple, .blue].map { $0.opacity(opacity) }
    }
}

/// Modifier to add rainbow shimmer overlay to any view
struct RainbowShimmerOverlay: ViewModifier {
    let opacity: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RainbowShimmer(opacity: opacity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
        )
    }
}

/// Animated rainbow border for views
struct RainbowBorder: ViewModifier {
    @State private var rotation: Double = 0
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let opacity: CGFloat

    init(lineWidth: CGFloat = 2, cornerRadius: CGFloat = 24, opacity: CGFloat = 0.5) {
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: ([Color.blue, .cyan, .green, .yellow,
                                  .orange, .pink, .purple, .blue] as [Color]).map { $0.opacity(opacity) },
                        center: .center,
                        startAngle: .degrees(rotation),
                        endAngle: .degrees(rotation + 360)
                    ),
                    lineWidth: lineWidth
                )
                .onAppear {
                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        )
    }
}

/// Shimmer text effect
struct ShimmeringText: View {
    let text: String
    let font: Font
    @State private var phase: CGFloat = 0

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .primary,
                        .cyan.opacity(0.8),
                        .purple.opacity(0.8),
                        .primary
                    ],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    /// Add a rainbow shimmer overlay
    func rainbowShimmer(opacity: CGFloat = 0.2, cornerRadius: CGFloat = 24) -> some View {
        modifier(RainbowShimmerOverlay(opacity: opacity, cornerRadius: cornerRadius))
    }

    /// Add an animated rainbow border
    func rainbowBorder(lineWidth: CGFloat = 2, cornerRadius: CGFloat = 24, opacity: CGFloat = 0.5) -> some View {
        modifier(RainbowBorder(lineWidth: lineWidth, cornerRadius: cornerRadius, opacity: opacity))
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack(spacing: 30) {
            // Rainbow shimmer fill
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(height: 100)
                .rainbowShimmer(opacity: 0.3)

            // Rainbow border
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(height: 100)
                .rainbowBorder()

            // Shimmering text
            ShimmeringText(text: "Rainbow Shimmer", font: .largeTitle.bold())
        }
        .padding()
    }
}
