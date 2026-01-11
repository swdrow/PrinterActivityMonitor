import ActivityKit
import WidgetKit
import SwiftUI

struct PrinterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrinterActivityAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "printer.fill")
                            .foregroundStyle(accentColor(for: context.attributes.accentColorName))
                        Text("\(context.state.progress)%")
                            .font(.title3.bold())
                            .foregroundStyle(accentColor(for: context.attributes.accentColorName))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(context.state.formattedTimeRemaining)
                            .font(.subheadline)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.fileName)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray4))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressGradient(for: context.attributes.accentColorName))
                                    .frame(width: geometry.size.width * Double(context.state.progress) / 100, height: 8)
                            }
                        }
                        .frame(height: 8)

                        // Stats row
                        HStack {
                            if context.attributes.showLayers {
                                Label(context.state.layerProgress, systemImage: "square.stack.3d.up")
                                    .font(.caption2)
                            }

                            Spacer()

                            if context.attributes.showNozzleTemp {
                                Label("\(Int(context.state.nozzleTemp))°", systemImage: "flame")
                                    .font(.caption2)
                            }

                            if context.attributes.showBedTemp {
                                Label("\(Int(context.state.bedTemp))°", systemImage: "bed.double")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading
                HStack(spacing: 4) {
                    Image(systemName: "printer.fill")
                        .foregroundStyle(accentColor(for: context.attributes.accentColorName))
                    Text("\(context.state.progress)%")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor(for: context.attributes.accentColorName))
                }
            } compactTrailing: {
                // Compact trailing
                Text(context.state.formattedTimeRemaining)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: "printer.fill")
                    .foregroundStyle(accentColor(for: context.attributes.accentColorName))
            }
        }
    }

    private func accentColor(for name: String) -> Color {
        switch name {
        case "cyan": return .cyan
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "rainbow": return .cyan
        default: return .cyan
        }
    }

    private func progressGradient(for colorName: String) -> LinearGradient {
        if colorName == "rainbow" {
            return LinearGradient(
                colors: [.blue, .cyan, .green, .yellow, .orange, .pink, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let color = accentColor(for: colorName)
            return LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "printer.fill")
                        .foregroundStyle(accentColor)

                    Text(context.attributes.fileName)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(context.state.formattedTimeRemaining)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress section
            HStack(spacing: 12) {
                // Progress bar with shimmer
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressGradient)
                            .frame(width: max(geometry.size.width * Double(context.state.progress) / 100, 12), height: 12)
                    }
                }
                .frame(height: 12)

                Text("\(context.state.progress)%")
                    .font(.title3.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 50, alignment: .trailing)
            }

            // Stats row
            HStack(spacing: 16) {
                if context.attributes.showLayers {
                    StatItem(icon: "square.stack.3d.up", value: context.state.layerProgress)
                }

                if context.attributes.showNozzleTemp {
                    StatItem(icon: "flame", value: "\(Int(context.state.nozzleTemp))°C")
                }

                if context.attributes.showBedTemp {
                    StatItem(icon: "bed.double", value: "\(Int(context.state.bedTemp))°C")
                }

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
    }

    private var accentColor: Color {
        switch context.attributes.accentColorName {
        case "cyan": return .cyan
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "rainbow": return .cyan
        default: return .cyan
        }
    }

    private var progressGradient: LinearGradient {
        if context.attributes.accentColorName == "rainbow" {
            return LinearGradient(
                colors: [.blue, .cyan, .green, .yellow, .orange, .pink, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [accentColor, accentColor.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var statusColor: Color {
        switch context.state.status {
        case "running": return .green
        case "pause": return .orange
        case "finish": return .blue
        case "failed": return .red
        default: return .gray
        }
    }

    private var statusText: String {
        switch context.state.status {
        case "running": return "Printing"
        case "pause": return "Paused"
        case "finish": return "Finished"
        case "failed": return "Failed"
        case "prepare": return "Preparing"
        default: return "Idle"
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: PrinterActivityAttributes.preview) {
    PrinterLiveActivity()
} contentStates: {
    PrinterActivityAttributes.ContentState.preview
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: PrinterActivityAttributes.preview) {
    PrinterLiveActivity()
} contentStates: {
    PrinterActivityAttributes.ContentState.preview
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: PrinterActivityAttributes.preview) {
    PrinterLiveActivity()
} contentStates: {
    PrinterActivityAttributes.ContentState.preview
}

extension PrinterActivityAttributes {
    static var preview: PrinterActivityAttributes {
        PrinterActivityAttributes(
            fileName: "benchy.gcode",
            startTime: Date(),
            showLayers: true,
            showNozzleTemp: true,
            showBedTemp: true,
            accentColorName: "cyan"
        )
    }
}

extension PrinterActivityAttributes.ContentState {
    static var preview: PrinterActivityAttributes.ContentState {
        PrinterActivityAttributes.ContentState(
            progress: 45,
            currentLayer: 123,
            totalLayers: 280,
            remainingMinutes: 84,
            status: "running",
            nozzleTemp: 215,
            bedTemp: 60
        )
    }
}
