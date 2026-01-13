import SwiftUI

/// Gemini AI-style rainbow shimmer effect
/// A smooth, flowing horizontal gradient animation
struct RainbowShimmer: View {
    @State private var phase: CGFloat = 0
    var intensity: Double = 1.0

    // Gemini-inspired color palette
    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),   // Soft blue
        Color(red: 0.6, green: 0.4, blue: 1.0),   // Purple
        Color(red: 0.9, green: 0.4, blue: 0.8),   // Pink
        Color(red: 0.4, green: 0.8, blue: 0.9),   // Cyan
        Color(red: 0.4, green: 0.6, blue: 1.0),   // Back to blue (seamless loop)
    ]

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: colors.map { $0.opacity(intensity) },
                startPoint: UnitPoint(x: phase - 1, y: 0.5),
                endPoint: UnitPoint(x: phase, y: 0.5)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 3)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
        }
    }
}

/// Rainbow shimmer as a view modifier for backgrounds
struct RainbowShimmerModifier: ViewModifier {
    var intensity: Double = 0.8
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background {
                RainbowShimmer(intensity: intensity)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
    }
}

/// Rainbow shimmer border effect
struct RainbowBorderModifier: ViewModifier {
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 12
    @State private var phase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            colors: colors,
                            center: .center,
                            startAngle: .degrees(phase),
                            endAngle: .degrees(phase + 360)
                        ),
                        lineWidth: lineWidth
                    )
                    .onAppear {
                        withAnimation(
                            .linear(duration: 4)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 360
                        }
                    }
            }
    }
}

/// Rainbow glow effect for accent emphasis
struct RainbowGlowModifier: ViewModifier {
    var radius: CGFloat = 15
    var cornerRadius: CGFloat = 12
    @State private var phase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        AngularGradient(
                            colors: colors.map { $0.opacity(0.6) },
                            center: .center,
                            startAngle: .degrees(phase),
                            endAngle: .degrees(phase + 360)
                        )
                    )
                    .blur(radius: radius)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 4)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 360
                        }
                    }
            }
    }
}

/// Progress bar with rainbow shimmer fill
struct RainbowProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var height: CGFloat = 8
    var cornerRadius: CGFloat = 4
    @State private var phase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))

                // Rainbow fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                            endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
                    .shadow(color: colors[1].opacity(0.5), radius: 8, x: 0, y: 0)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
}

/// Text with animated rainbow gradient fill
struct ShimmeringText: View {
    let text: String
    var font: Font = .body
    @State private var phase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - AI Aura Modifier

/// AI-style ambient glow effect - creates a subtle, slowly moving radial gradient
/// Similar to the aura seen around AI assistant UI elements
struct AIAuraModifier: ViewModifier {
    var accentColor: Color
    var intensity: Double
    var cornerRadius: CGFloat
    @State private var phase: CGFloat = 0

    init(accentColor: Color, intensity: Double = 0.6, cornerRadius: CGFloat = 20) {
        self.accentColor = accentColor
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                // Animated glow that slowly moves around the content
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(intensity * 0.4),
                                accentColor.opacity(intensity * 0.15),
                                .clear
                            ],
                            center: UnitPoint(
                                x: 0.5 + 0.15 * sin(phase),
                                y: 0.5 + 0.15 * cos(phase)
                            ),
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .blur(radius: 35)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 4)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = .pi * 2
                }
            }
    }
}

/// Multi-color AI aura for rainbow mode - uses cycling colors
struct RainbowAuraModifier: ViewModifier {
    var intensity: Double
    var cornerRadius: CGFloat
    @State private var phase: CGFloat = 0
    @State private var colorPhase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
    ]

    init(intensity: Double = 0.5, cornerRadius: CGFloat = 20) {
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Multiple overlapping gradients for richer effect
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        colors[(index + Int(colorPhase)) % colors.count].opacity(intensity * 0.3),
                                        .clear
                                    ],
                                    center: UnitPoint(
                                        x: 0.5 + 0.2 * sin(phase + Double(index) * .pi * 0.67),
                                        y: 0.5 + 0.2 * cos(phase + Double(index) * .pi * 0.67)
                                    ),
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .blur(radius: 40)
                    }
                }
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 5)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = .pi * 2
                }
                withAnimation(
                    .linear(duration: 8)
                    .repeatForever(autoreverses: false)
                ) {
                    colorPhase = 4
                }
            }
    }
}

// MARK: - Gradient Shimmer for Loading States

/// Enhanced skeleton loading shimmer with smooth gradient sweep
struct GradientShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.25),
                            .white.opacity(0.4),
                            .white.opacity(0.25),
                            .clear
                        ],
                        startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                    )
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}

// MARK: - Button Style with Glow

/// Button style that adds a subtle glow effect on press
struct GlowingButtonStyle: ButtonStyle {
    var accentColor: Color
    var cornerRadius: CGFloat

    init(accentColor: Color = .cyan, cornerRadius: CGFloat = 12) {
        self.accentColor = accentColor
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(accentColor.opacity(0.2))
                        .blur(radius: 15)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply rainbow shimmer background
    func rainbowShimmer(intensity: Double = 0.8, cornerRadius: CGFloat = 12) -> some View {
        modifier(RainbowShimmerModifier(intensity: intensity, cornerRadius: cornerRadius))
    }

    /// Apply rainbow border
    func rainbowBorder(lineWidth: CGFloat = 2, cornerRadius: CGFloat = 12) -> some View {
        modifier(RainbowBorderModifier(lineWidth: lineWidth, cornerRadius: cornerRadius))
    }

    /// Apply rainbow glow effect
    func rainbowGlow(radius: CGFloat = 15, cornerRadius: CGFloat = 12) -> some View {
        modifier(RainbowGlowModifier(radius: radius, cornerRadius: cornerRadius))
    }

    /// Apply AI-style ambient aura glow
    func aiAura(color: Color, intensity: Double = 0.6, cornerRadius: CGFloat = 20) -> some View {
        modifier(AIAuraModifier(accentColor: color, intensity: intensity, cornerRadius: cornerRadius))
    }

    /// Apply rainbow AI aura for rainbow mode
    func rainbowAura(intensity: Double = 0.5, cornerRadius: CGFloat = 20) -> some View {
        modifier(RainbowAuraModifier(intensity: intensity, cornerRadius: cornerRadius))
    }

    /// Apply gradient shimmer for loading skeletons
    func gradientShimmer() -> some View {
        modifier(GradientShimmerModifier())
    }
}

// MARK: - Preview

#Preview("Rainbow Effects") {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        VStack(spacing: 30) {
            // Shimmer background
            Text("Rainbow Shimmer")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .rainbowShimmer(intensity: 0.3, cornerRadius: 12)

            // Border effect
            Text("Rainbow Border")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .rainbowBorder(lineWidth: 2, cornerRadius: 12)

            // Glow effect
            Text("Rainbow Glow")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .rainbowGlow(radius: 20, cornerRadius: 12)

            // Progress bars
            VStack(spacing: 16) {
                RainbowProgressBar(progress: 0.75)
                RainbowProgressBar(progress: 0.45)
                RainbowProgressBar(progress: 0.25)
            }
            .padding()
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("AI Aura Effects") {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        VStack(spacing: 40) {
            // Single color AI aura
            Text("AI Aura - Cyan")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aiAura(color: .cyan, intensity: 0.8, cornerRadius: 16)

            // Indigo aura
            Text("AI Aura - Indigo")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aiAura(color: Color(red: 0.39, green: 0.4, blue: 0.95), intensity: 0.8, cornerRadius: 16)

            // Rainbow AI aura
            Text("Rainbow Aura")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .rainbowAura(intensity: 0.6, cornerRadius: 16)

            // Loading skeleton with gradient shimmer
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 20)
                    .gradientShimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 150, height: 16)
                    .gradientShimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 180, height: 16)
                    .gradientShimmer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
