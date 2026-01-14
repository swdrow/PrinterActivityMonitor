import ActivityKit
import SwiftUI
import WidgetKit

struct PrinterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrinterActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact leading - progress ring
                CompactProgressRing(progress: Double(context.state.progress) / 100)
            } compactTrailing: {
                // Compact trailing - time remaining
                Text(context.state.formattedTimeRemaining)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } minimal: {
                // Minimal - just progress ring
                CompactProgressRing(progress: Double(context.state.progress) / 100)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(context.state.progress) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .purple, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(context.state.progress)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(width: 50, height: 50)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(context.state.formattedTimeRemaining, systemImage: "clock")
                    Label(context.state.layerProgress, systemImage: "square.stack.3d.up")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Temps
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "flame")
                        .font(.caption2)
                    Text("\(context.state.nozzleTemp)°")
                }
                .foregroundStyle(.orange)

                HStack(spacing: 2) {
                    Image(systemName: "bed.double")
                        .font(.caption2)
                    Text("\(context.state.bedTemp)°")
                }
                .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Dynamic Island Components

struct CompactProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            Text(context.attributes.filename)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Text("\(context.state.progress)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Spacer()

                VStack(alignment: .trailing) {
                    Text(context.state.formattedTimeRemaining)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        HStack {
            Label(context.state.layerProgress, systemImage: "square.stack.3d.up")

            Spacer()

            HStack(spacing: 8) {
                Label("\(context.state.nozzleTemp)°", systemImage: "flame")
                    .foregroundStyle(.orange)
                Label("\(context.state.bedTemp)°", systemImage: "bed.double")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: PrinterActivityAttributes(
    filename: "benchy.3mf",
    startTime: Date(),
    printerName: "H2S",
    printerModel: "H2S",
    entityPrefix: "h2s"
)) {
    PrinterLiveActivity()
} contentStates: {
    PrinterActivityAttributes.ContentState(
        progress: 45,
        currentLayer: 142,
        totalLayers: 300,
        remainingSeconds: 4980,
        status: "running",
        nozzleTemp: 220,
        bedTemp: 60
    )
}
