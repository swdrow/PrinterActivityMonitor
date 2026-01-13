import SwiftUI

/// Enhanced progress bar with glow effects
struct ProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var accentColor: Color = .cyan
    var isRainbow: Bool = false
    var style: ProgressBarStyle = .standard
    var showPercentage: Bool = false

    enum ProgressBarStyle {
        case standard   // Normal height with glow
        case minimal    // Thin bar, subtle glow
        case bold       // Larger bar, stronger glow
    }

    private var height: CGFloat {
        switch style {
        case .standard: return 8
        case .minimal: return 4
        case .bold: return 12
        }
    }

    private var cornerRadius: CGFloat {
        height / 2
    }

    private var glowRadius: CGFloat {
        switch style {
        case .standard: return 8
        case .minimal: return 4
        case .bold: return 12
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))

                // Progress fill
                if isRainbow {
                    RainbowProgressFill(
                        progress: progress,
                        height: height,
                        cornerRadius: cornerRadius,
                        glowRadius: glowRadius,
                        width: geometry.size.width
                    )
                } else {
                    StandardProgressFill(
                        progress: progress,
                        accentColor: accentColor,
                        height: height,
                        cornerRadius: cornerRadius,
                        glowRadius: glowRadius,
                        width: geometry.size.width
                    )
                }

                // Percentage overlay
                if showPercentage {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: height)
    }
}

/// Standard single-color progress fill with glow
private struct StandardProgressFill: View {
    let progress: Double
    let accentColor: Color
    let height: CGFloat
    let cornerRadius: CGFloat
    let glowRadius: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            // Glow layer (behind)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(accentColor)
                .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                .blur(radius: glowRadius)
                .opacity(0.5)

            // Main fill
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.9),
                            accentColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                .overlay {
                    // Highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

/// Rainbow animated progress fill
private struct RainbowProgressFill: View {
    let progress: Double
    let height: CGFloat
    let cornerRadius: CGFloat
    let glowRadius: CGFloat
    let width: CGFloat

    @State private var phase: CGFloat = 0

    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            // Glow layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                    )
                )
                .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                .blur(radius: glowRadius)
                .opacity(0.6)

            // Main fill
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                    )
                )
                .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                .overlay {
                    // Highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: width * CGFloat(min(max(progress, 0), 1)))
                }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
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

/// Circular progress indicator with glow
struct CircularProgressBar: View {
    let progress: Double
    var accentColor: Color = .cyan
    var isRainbow: Bool = false
    var lineWidth: CGFloat = 8
    var size: CGFloat = 60

    @State private var phase: CGFloat = 0

    private let rainbowColors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.4, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.9),
        Color(red: 0.4, green: 0.6, blue: 1.0),
    ]

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Glow
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    isRainbow ?
                        AnyShapeStyle(
                            AngularGradient(
                                colors: rainbowColors,
                                center: .center,
                                startAngle: .degrees(Double(phase) * 360),
                                endAngle: .degrees(Double(phase) * 360 + 360)
                            )
                        ) :
                        AnyShapeStyle(accentColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 6)
                .opacity(0.5)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    isRainbow ?
                        AnyShapeStyle(
                            AngularGradient(
                                colors: rainbowColors,
                                center: .center,
                                startAngle: .degrees(Double(phase) * 360),
                                endAngle: .degrees(Double(phase) * 360 + 360)
                            )
                        ) :
                        AnyShapeStyle(accentColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        .onAppear {
            if isRainbow {
                withAnimation(
                    .linear(duration: 4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        VStack(spacing: 30) {
            // Standard styles
            VStack(spacing: 16) {
                Text("Standard").font(.caption).foregroundStyle(.gray)
                ProgressBar(progress: 0.65, accentColor: .cyan)
                ProgressBar(progress: 0.45, accentColor: .purple)
                ProgressBar(progress: 0.80, accentColor: .orange)
            }

            // Rainbow
            VStack(spacing: 16) {
                Text("Rainbow").font(.caption).foregroundStyle(.gray)
                ProgressBar(progress: 0.70, isRainbow: true)
            }

            // Styles
            VStack(spacing: 16) {
                Text("Styles").font(.caption).foregroundStyle(.gray)
                ProgressBar(progress: 0.5, accentColor: .cyan, style: .minimal)
                ProgressBar(progress: 0.5, accentColor: .cyan, style: .standard)
                ProgressBar(progress: 0.5, accentColor: .cyan, style: .bold)
            }

            // With percentage
            ProgressBar(progress: 0.72, accentColor: .green, style: .bold, showPercentage: true)

            // Circular
            HStack(spacing: 20) {
                CircularProgressBar(progress: 0.65, accentColor: .cyan)
                CircularProgressBar(progress: 0.45, isRainbow: true)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
