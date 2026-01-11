import SwiftUI

/// A beautiful progress bar with gradient fill and optional rainbow shimmer
struct ProgressBar: View {
    let progress: Double
    let accentColor: AccentColorOption
    let height: CGFloat

    @State private var shimmerPhase: CGFloat = 0

    init(progress: Double, accentColor: AccentColorOption = .cyan, height: CGFloat = 12) {
        self.progress = min(max(progress, 0), 1)
        self.accentColor = accentColor
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color(.systemGray5))

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(progressGradient)
                    .frame(width: max(geometry.size.width * progress, height))
                    .overlay(
                        // Shimmer effect on progress
                        shimmerOverlay
                            .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
                    )
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                // Glow effect behind the bar
                if progress > 0 {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(accentColor.color.opacity(0.3))
                        .frame(width: max(geometry.size.width * progress, height))
                        .blur(radius: 8)
                        .offset(y: 4)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            if accentColor == .rainbow {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
        }
    }

    private var progressGradient: LinearGradient {
        if accentColor == .rainbow {
            return LinearGradient(
                colors: [.blue, .cyan, .green, .yellow, .orange, .pink, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    accentColor.color,
                    accentColor.color.opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if accentColor == .rainbow {
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.4),
                    .clear
                ],
                startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0.5),
                endPoint: UnitPoint(x: shimmerPhase + 0.1, y: 0.5)
            )
        } else {
            // Subtle shine for non-rainbow colors
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.3),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Compact progress indicator for Live Activity
struct CompactProgressRing: View {
    let progress: Double
    let accentColor: AccentColorOption
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var rotation: Double = 0

    init(progress: Double, accentColor: AccentColorOption = .cyan, size: CGFloat = 44, lineWidth: CGFloat = 4) {
        self.progress = min(max(progress, 0), 1)
        self.accentColor = accentColor
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            // Percentage text
            Text("\(Int(progress * 100))")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .onAppear {
            if accentColor == .rainbow {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }

    private var ringGradient: AngularGradient {
        if accentColor == .rainbow {
            return AngularGradient(
                colors: [.blue, .cyan, .green, .yellow, .orange, .pink, .purple, .blue],
                center: .center,
                startAngle: .degrees(rotation),
                endAngle: .degrees(rotation + 360)
            )
        } else {
            return AngularGradient(
                colors: [accentColor.color, accentColor.color],
                center: .center
            )
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        VStack(spacing: 16) {
            Text("Progress Bars")
                .font(.headline)

            ProgressBar(progress: 0.45, accentColor: .cyan)
            ProgressBar(progress: 0.75, accentColor: .purple)
            ProgressBar(progress: 0.65, accentColor: .rainbow)
        }

        VStack(spacing: 16) {
            Text("Progress Rings")
                .font(.headline)

            HStack(spacing: 20) {
                CompactProgressRing(progress: 0.45, accentColor: .cyan)
                CompactProgressRing(progress: 0.75, accentColor: .purple)
                CompactProgressRing(progress: 0.65, accentColor: .rainbow)
            }
        }
    }
    .padding()
}
