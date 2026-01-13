import SwiftUI

/// Circular progress indicator with aurora gradient
struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, lineWidth: CGFloat = 12, size: CGFloat = 120) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Theme.Colors.backgroundCard,
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.auroraStart,
                            Theme.Colors.auroraMid,
                            Theme.Colors.auroraEnd,
                            Theme.Colors.auroraStart
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center content
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(Theme.Typography.numericLarge)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("%")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Theme.Colors.backgroundPrimary
            .ignoresSafeArea()

        VStack(spacing: 24) {
            ProgressRing(progress: 0.45)
            ProgressRing(progress: 0.75, lineWidth: 8, size: 80)
            ProgressRing(progress: 1.0, lineWidth: 16, size: 160)
        }
    }
}
