import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Design Tokens
/// Lightweight design tokens for Live Activity (subset of main app's DS)

private enum LA {
    // MARK: Colors
    enum Colors {
        // Primary Accent - Celestial Cyan
        static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)
        static let accentLight = Color(red: 0.55, green: 0.85, blue: 1.0)

        // Aurora gradient colors
        static let auroraMid = Color(red: 0.55, green: 0.6, blue: 0.95)

        // Semantic
        static let success = Color(red: 0.3, green: 0.75, blue: 0.55)
        static let warning = Color(red: 0.95, green: 0.7, blue: 0.35)
        static let error = Color(red: 0.9, green: 0.4, blue: 0.45)

        // Text
        static let textPrimary = Color.white.opacity(0.95)
        static let textSecondary = Color.white.opacity(0.6)
        static let textTertiary = Color.white.opacity(0.4)

        // Surface
        static let surfaceGlass = Color.white.opacity(0.08)
        static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)
    }

    // MARK: Typography
    enum Typography {
        static let numericLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let numeric = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let numericSmall = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13, weight: .medium)
        static let label = Font.system(size: 11, weight: .medium)
        static let labelMicro = Font.system(size: 10, weight: .medium)
    }
}

// MARK: - Printer Live Activity Widget

struct PrinterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrinterActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.progress)%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(resolveAccentColor(context.attributes.accentColorName))
                        .contentTransition(.numericText())
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedTimeRemaining)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LA.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.fileName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(LA.Colors.textSecondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Aurora progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)

                                // Progress with aurora gradient
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(auroraLinearGradient(for: context.attributes.accentColorName))
                                    .frame(width: max(geometry.size.width * Double(context.state.progress) / 100, 4), height: 4)
                            }
                        }
                        .frame(height: 4)

                        // Stats row - compact inline
                        HStack(spacing: 12) {
                            if context.attributes.showLayers {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.stack.3d.up")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(LA.Colors.textSecondary)
                                    Text(context.state.layerProgress)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(LA.Colors.textPrimary)
                                }
                            }

                            Spacer()

                            if context.attributes.showNozzleTemp {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(LA.Colors.warning)
                                    Text("\(Int(context.state.nozzleTemp))°")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(LA.Colors.textPrimary)
                                }
                            }

                            if context.attributes.showBedTemp {
                                HStack(spacing: 2) {
                                    Image(systemName: "bed.double.fill")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(LA.Colors.accent)
                                    Text("\(Int(context.state.bedTemp))°")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(LA.Colors.textPrimary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                // Compact leading - Clean progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        .frame(width: 18, height: 18)

                    Circle()
                        .trim(from: 0, to: Double(context.state.progress) / 100)
                        .stroke(
                            auroraAngularGradient(for: context.attributes.accentColorName),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }
            } compactTrailing: {
                // Compact trailing - Just percentage (time shown in expanded)
                Text("\(context.state.progress)%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(resolveAccentColor(context.attributes.accentColorName))
                    .contentTransition(.numericText())
            } minimal: {
                // Minimal - Clean progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        .frame(width: 18, height: 18)

                    Circle()
                        .trim(from: 0, to: Double(context.state.progress) / 100)
                        .stroke(
                            auroraAngularGradient(for: context.attributes.accentColorName),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }

    // MARK: - Color Resolution

    private func resolveAccentColor(_ name: String) -> Color {
        switch name {
        case "cyan": return LA.Colors.accent
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return LA.Colors.success
        case "teal": return Color(red: 0, green: 0.79, blue: 0.65)
        case "indigo": return Color(red: 0.39, green: 0.4, blue: 0.95)
        case "amber": return LA.Colors.warning
        case "mint": return Color(red: 0.2, green: 0.83, blue: 0.6)
        case "rainbow", "aurora": return LA.Colors.accent  // Aurora replaces rainbow
        default: return LA.Colors.accent
        }
    }

    private func auroraLinearGradient(for colorName: String) -> LinearGradient {
        let accent = resolveAccentColor(colorName)
        return LinearGradient(
            colors: [accent, LA.Colors.accentLight, LA.Colors.auroraMid.opacity(0.9)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func auroraAngularGradient(for colorName: String) -> AngularGradient {
        let accent = resolveAccentColor(colorName)
        return AngularGradient(
            colors: [accent, LA.Colors.accentLight, LA.Colors.auroraMid.opacity(0.8), accent],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        if context.attributes.compactMode {
            compactLayout
        } else {
            fullLayout
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 14) {
            // Progress percentage
            HStack(spacing: 4) {
                Text("\(context.state.progress)")
                    .font(LA.Typography.numeric)
                    .foregroundStyle(accentColor)
                Text("%")
                    .font(LA.Typography.label)
                    .foregroundStyle(LA.Colors.textSecondary)
                    .offset(y: 2)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(auroraLinear)
                        .frame(width: max(geometry.size.width * Double(context.state.progress) / 100, 6), height: 6)
                }
            }
            .frame(height: 6)

            // Time and status
            HStack(spacing: 8) {
                Text(context.state.formattedTimeRemaining)
                    .font(LA.Typography.body)
                    .foregroundStyle(LA.Colors.textSecondary)

                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(compactBackground)
    }

    // MARK: - Full Layout

    private var fullLayout: some View {
        HStack(spacing: 16) {
            // Left: Aurora Progress Ring
            ZStack {
                // Subtle ambient glow
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .blur(radius: 16)
                    .frame(width: 70, height: 70)

                // Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 60, height: 60)

                // Progress ring with aurora gradient
                Circle()
                    .trim(from: 0, to: Double(context.state.progress) / 100)
                    .stroke(
                        auroraAngular,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Glow at tip
                if context.state.progress > 0 {
                    Circle()
                        .trim(from: max(0, Double(context.state.progress) / 100 - 0.03), to: Double(context.state.progress) / 100)
                        .stroke(
                            LA.Colors.accentLight,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .blur(radius: 3)
                        .opacity(0.6)
                }

                // Center content
                centerContent
            }

            // Right: Details
            VStack(alignment: .leading, spacing: 8) {
                // File name and status
                HStack {
                    Text(context.attributes.fileName)
                        .font(LA.Typography.headline)
                        .lineLimit(1)
                        .foregroundStyle(LA.Colors.textPrimary)

                    Spacer()

                    // Status indicator
                    statusIndicator
                }

                // Time row
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor.opacity(0.8))
                        Text(context.state.formattedTimeRemaining)
                            .font(LA.Typography.body)
                            .foregroundStyle(LA.Colors.textPrimary)
                    }

                    if context.state.remainingMinutes > 0 {
                        Text("ETA \(estimatedCompletionTime)")
                            .font(LA.Typography.labelMicro)
                            .foregroundStyle(LA.Colors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                // Stats row
                HStack(spacing: 6) {
                    if context.attributes.showLayers {
                        LSStatBadge(
                            icon: "square.stack.3d.up",
                            value: context.state.layerProgress
                        )
                    }

                    if context.attributes.showNozzleTemp {
                        LSStatBadge(
                            icon: "flame.fill",
                            value: "\(Int(context.state.nozzleTemp))°",
                            tint: LA.Colors.warning.opacity(0.9)
                        )
                    }

                    if context.attributes.showBedTemp {
                        LSStatBadge(
                            icon: "bed.double.fill",
                            value: "\(Int(context.state.bedTemp))°",
                            tint: LA.Colors.accent
                        )
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(fullBackground)
    }

    // MARK: - Center Content (Progress Ring)

    @ViewBuilder
    private var centerContent: some View {
        if let imageURL = context.state.coverImageURL,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } placeholder: {
                percentageDisplay
            }
        } else {
            percentageDisplay
        }
    }

    private var percentageDisplay: some View {
        VStack(spacing: -2) {
            Text("\(context.state.progress)")
                .font(LA.Typography.numeric)
                .foregroundStyle(accentColor)
            Text("%")
                .font(LA.Typography.labelMicro)
                .foregroundStyle(LA.Colors.textSecondary)
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            if let icon = statusIcon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
            }

            Text(statusText)
                .font(LA.Typography.labelMicro)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Backgrounds

    private var compactBackground: some View {
        ZStack {
            LA.Colors.backgroundSecondary

            LinearGradient(
                colors: [accentColor.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .center
            )

            // Top edge highlight
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 0.5)
                Spacer()
            }
        }
    }

    private var fullBackground: some View {
        ZStack {
            // Base
            LinearGradient(
                colors: [
                    LA.Colors.backgroundSecondary,
                    LA.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient accent glow
            RadialGradient(
                colors: [accentColor.opacity(0.12), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 180
            )

            // Top edge highlight
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 0.5)
                Spacer()
            }
        }
    }

    // MARK: - Gradients

    private var auroraLinear: LinearGradient {
        LinearGradient(
            colors: [accentColor, LA.Colors.accentLight, LA.Colors.auroraMid.opacity(0.9)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var auroraAngular: AngularGradient {
        AngularGradient(
            colors: [accentColor, LA.Colors.accentLight, LA.Colors.auroraMid.opacity(0.8), accentColor],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        switch context.attributes.accentColorName {
        case "cyan": return LA.Colors.accent
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return LA.Colors.success
        case "teal": return Color(red: 0, green: 0.79, blue: 0.65)
        case "indigo": return Color(red: 0.39, green: 0.4, blue: 0.95)
        case "amber": return LA.Colors.warning
        case "mint": return Color(red: 0.2, green: 0.83, blue: 0.6)
        case "rainbow", "aurora": return LA.Colors.accent
        default: return LA.Colors.accent
        }
    }

    private var statusColor: Color {
        switch context.state.status {
        case "running": return LA.Colors.success
        case "pause": return LA.Colors.warning
        case "finish": return LA.Colors.accent
        case "failed": return LA.Colors.error
        default: return LA.Colors.textSecondary
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

    private var statusIcon: String? {
        switch context.state.status {
        case "pause": return "pause.fill"
        case "finish": return "checkmark"
        case "failed": return "xmark"
        case "prepare": return "ellipsis"
        default: return nil  // Use dot for printing/idle
        }
    }

    private var estimatedCompletionTime: String {
        let completionDate = Date().addingTimeInterval(TimeInterval(context.state.remainingMinutes * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: completionDate)
    }
}

// MARK: - Stat Badge Components

/// Lock Screen stat badge
private struct LSStatBadge: View {
    let icon: String
    let value: String
    var tint: Color = LA.Colors.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(tint)

            Text(value)
                .font(LA.Typography.numericSmall)
                .foregroundStyle(LA.Colors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

/// Dynamic Island stat badge
private struct DIStatBadge: View {
    let icon: String
    let value: String
    var tint: Color = LA.Colors.textSecondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(LA.Colors.textPrimary.opacity(0.8))
        }
    }
}

// MARK: - Preview Support

extension PrinterActivityAttributes {
    static var preview: PrinterActivityAttributes {
        PrinterActivityAttributes(
            fileName: "benchy.gcode",
            startTime: Date(),
            printerModel: "X1 Carbon",
            showLayers: true,
            showNozzleTemp: true,
            showBedTemp: true,
            accentColorName: "cyan",
            compactMode: false
        )
    }
}

extension PrinterActivityAttributes.ContentState {
    static var preview: PrinterActivityAttributes.ContentState {
        PrinterActivityAttributes.ContentState(
            progress: 67,
            currentLayer: 142,
            totalLayers: 280,
            remainingMinutes: 84,
            status: "running",
            nozzleTemp: 220,
            bedTemp: 60,
            chamberTemp: 35,
            nozzleTargetTemp: 220,
            bedTargetTemp: 60,
            currentStage: "Printing",
            coverImageURL: nil
        )
    }
}
