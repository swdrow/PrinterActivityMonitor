import SwiftUI

/// Enhanced liquid glass card with dark mode optimization
struct GlassCard<Content: View>: View {
    let content: Content
    var accentColor: Color?
    var isActive: Bool
    var cornerRadius: CGFloat

    init(
        accentColor: Color? = nil,
        isActive: Bool = false,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.accentColor = accentColor
        self.isActive = isActive
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background {
                ZStack {
                    // Base dark glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    // Accent color tint (subtle)
                    if let accent = accentColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(accent.opacity(0.08))
                    }

                    // Inner depth gradient (top-left light source)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    .white.opacity(0.05),
                                    .clear,
                                    .black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Edge highlight (top and left)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.1),
                                    .clear,
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )

                    // Accent glow border (when active or has accent)
                    if isActive, let accent = accentColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(accent.opacity(0.5), lineWidth: 1.5)
                            .blur(radius: 2)
                    }
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            .shadow(color: accentColor?.opacity(isActive ? 0.2 : 0) ?? .clear, radius: 20, x: 0, y: 5)
    }
}

/// Animated glass card with pulse effect for active states
struct GlassCardActive<Content: View>: View {
    let content: Content
    let accentColor: Color
    var cornerRadius: CGFloat

    @State private var isPulsing = false

    init(
        accentColor: Color,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.accentColor = accentColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background {
                ZStack {
                    // Base glass
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    // Pulsing accent glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(accentColor.opacity(isPulsing ? 0.12 : 0.06))
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)

                    // Inner gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    .white.opacity(0.04),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Glowing border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.6),
                                    accentColor.opacity(0.3),
                                    accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .blur(radius: isPulsing ? 3 : 1)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            .shadow(color: accentColor.opacity(0.25), radius: 25, x: 0, y: 5)
            .onAppear { isPulsing = true }
    }
}

/// Compact glass card for smaller UI elements
struct GlassCardCompact<Content: View>: View {
    let content: Content
    var accentColor: Color?
    var cornerRadius: CGFloat

    init(
        accentColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.accentColor = accentColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    if let accent = accentColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(accent.opacity(0.06))
                    }

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        // Dark gradient background
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.02, green: 0.02, blue: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard(accentColor: .cyan, isActive: true) {
                VStack(alignment: .leading) {
                    Text("Active Print")
                        .font(.headline)
                    Text("benchy.3mf")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCardActive(accentColor: .cyan) {
                Text("Pulsing Active Card")
                    .padding()
                    .frame(maxWidth: .infinity)
            }

            GlassCard {
                Text("Default Glass Card")
                    .padding()
                    .frame(maxWidth: .infinity)
            }

            GlassCardCompact(accentColor: .orange) {
                Text("Compact")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
