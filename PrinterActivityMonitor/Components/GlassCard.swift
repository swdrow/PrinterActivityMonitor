import SwiftUI

/// A frosted glass card with the liquid glass aesthetic
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Base frosted glass
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay for depth
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Inner highlight stroke
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// A variant of GlassCard with rainbow shimmer border
struct GlassCardWithShimmer<Content: View>: View {
    let content: Content
    @State private var animationPhase: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Base frosted glass
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay for depth
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                // Animated rainbow border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: ([Color.blue, .purple, .pink, .orange,
                                      .yellow, .green, .cyan, .blue] as [Color]).map { $0.opacity(0.5) },
                            center: .center,
                            startAngle: .degrees(animationPhase),
                            endAngle: .degrees(animationPhase + 360)
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    animationPhase = 360
                }
            }
    }
}

/// A minimal glass effect for smaller elements
struct MiniGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func miniGlass() -> some View {
        modifier(MiniGlass())
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack {
                    Text("Glass Card")
                        .font(.headline)
                    Text("With liquid glass effect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            GlassCardWithShimmer {
                VStack {
                    Text("Shimmer Card")
                        .font(.headline)
                    Text("With rainbow border")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .padding()
    }
}
