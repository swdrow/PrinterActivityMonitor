import SwiftUI

// MARK: - Stat Badge
/// A compact badge for displaying stats with icon and value
/// Used in Live Activity, Dashboard, and throughout the app

struct StatBadge: View {
    let icon: String
    let value: String
    var label: String? = nil
    var style: Style = .neutral

    enum Style {
        case neutral      // Default gray background
        case accent       // Accent color highlight
        case temperature  // Warm tint for temperatures
        case success      // Success/completed states
        case warning      // Warning states
        case subtle       // Very subtle, minimal
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)

            Text(value)
                .font(DS.Typography.numericMicro)
                .foregroundStyle(DS.Colors.textPrimary)

            if let label {
                Text(label)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs + 2)
        .background {
            Capsule()
                .fill(backgroundColor)
        }
    }

    private var iconColor: Color {
        switch style {
        case .neutral: return DS.Colors.textSecondary
        case .accent: return DS.Colors.accent
        case .temperature: return DS.Colors.warning.opacity(0.9)
        case .success: return DS.Colors.success
        case .warning: return DS.Colors.warning
        case .subtle: return DS.Colors.textTertiary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral: return Color.white.opacity(0.08)
        case .accent: return DS.Colors.accent.opacity(0.12)
        case .temperature: return DS.Colors.warning.opacity(0.1)
        case .success: return DS.Colors.success.opacity(0.1)
        case .warning: return DS.Colors.warning.opacity(0.1)
        case .subtle: return Color.white.opacity(0.05)
        }
    }
}

// MARK: - Status Indicator
/// A pill-shaped status indicator with dot and text

struct StatusIndicator: View {
    let status: Status
    var size: Size = .regular

    enum Status {
        case printing
        case paused
        case finished
        case failed
        case idle
        case preparing
        case offline

        var displayName: String {
            switch self {
            case .printing: return "Printing"
            case .paused: return "Paused"
            case .finished: return "Finished"
            case .failed: return "Failed"
            case .idle: return "Idle"
            case .preparing: return "Preparing"
            case .offline: return "Offline"
            }
        }

        var color: Color {
            switch self {
            case .printing: return DS.Colors.accent
            case .paused: return DS.Colors.warning
            case .finished: return DS.Colors.success
            case .failed: return DS.Colors.error
            case .idle: return DS.Colors.neutral
            case .preparing: return DS.Colors.accent.opacity(0.7)
            case .offline: return DS.Colors.error.opacity(0.7)
            }
        }

        var icon: String? {
            switch self {
            case .printing: return nil  // Dot is enough
            case .paused: return "pause.fill"
            case .finished: return "checkmark"
            case .failed: return "xmark"
            case .idle: return nil
            case .preparing: return "ellipsis"
            case .offline: return "wifi.slash"
            }
        }
    }

    enum Size {
        case compact  // For Live Activity
        case regular  // For cards
        case large    // For headers
    }

    var body: some View {
        HStack(spacing: dotTextSpacing) {
            // Status dot or icon
            if let icon = status.icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(status.color)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: dotSize, height: dotSize)
            }

            Text(status.displayName)
                .font(textFont)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
            Capsule()
                .fill(status.color.opacity(0.12))
        }
    }

    private var dotSize: CGFloat {
        switch size {
        case .compact: return 5
        case .regular: return 6
        case .large: return 7
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .compact: return 9
        case .regular: return 10
        case .large: return 12
        }
    }

    private var dotTextSpacing: CGFloat {
        switch size {
        case .compact: return 4
        case .regular: return 5
        case .large: return 6
        }
    }

    private var textFont: Font {
        switch size {
        case .compact: return DS.Typography.labelMicro
        case .regular: return DS.Typography.labelSmall
        case .large: return DS.Typography.label
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 6
        case .regular: return 8
        case .large: return 10
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .compact: return 3
        case .regular: return 4
        case .large: return 5
        }
    }
}

// MARK: - Connection Status
/// Simple connection indicator dot with label

struct ConnectionStatus: View {
    let isConnected: Bool
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(isConnected ? DS.Colors.success : DS.Colors.error)
                .frame(width: 6, height: 6)

            if showLabel {
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Temperature Badge
/// Specialized badge for temperature display

struct TemperatureBadge: View {
    let current: Int
    var target: Int? = nil
    var icon: String = "flame.fill"
    var style: TempStyle = .nozzle

    enum TempStyle {
        case nozzle
        case bed
        case chamber

        var color: Color {
            switch self {
            case .nozzle: return DS.Colors.warning
            case .bed: return DS.Colors.accent
            case .chamber: return Color.orange.opacity(0.8)
            }
        }

        var icon: String {
            switch self {
            case .nozzle: return "flame.fill"
            case .bed: return "bed.double.fill"
            case .chamber: return "thermometer.medium"
            }
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: style.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(style.color.opacity(0.9))

            if let target, target > 0 && target != current {
                Text("\(current)°→\(target)°")
                    .font(DS.Typography.numericMicro)
            } else {
                Text("\(current)°")
                    .font(DS.Typography.numericMicro)
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs + 2)
        .background {
            Capsule()
                .fill(style.color.opacity(0.1))
        }
    }
}

// MARK: - Preview

#Preview("Stat Badges") {
    VStack(spacing: DS.Spacing.lg) {
        // Stat Badges
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Stat Badges")
                .font(DS.Typography.headline)

            HStack(spacing: DS.Spacing.sm) {
                StatBadge(icon: "square.stack.3d.up", value: "142/280", style: .neutral)
                StatBadge(icon: "flame.fill", value: "220°", style: .temperature)
                StatBadge(icon: "bed.double.fill", value: "60°", style: .accent)
            }

            HStack(spacing: DS.Spacing.sm) {
                StatBadge(icon: "clock", value: "1h 24m", style: .subtle)
                StatBadge(icon: "checkmark.circle", value: "Done", style: .success)
            }
        }

        Divider().background(DS.Colors.borderSubtle)

        // Status Indicators
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Status Indicators")
                .font(DS.Typography.headline)

            HStack(spacing: DS.Spacing.sm) {
                StatusIndicator(status: .printing, size: .compact)
                StatusIndicator(status: .paused, size: .compact)
                StatusIndicator(status: .finished, size: .compact)
            }

            HStack(spacing: DS.Spacing.sm) {
                StatusIndicator(status: .printing, size: .regular)
                StatusIndicator(status: .failed, size: .regular)
            }

            StatusIndicator(status: .idle, size: .large)
        }

        Divider().background(DS.Colors.borderSubtle)

        // Temperature Badges
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Temperature Badges")
                .font(DS.Typography.headline)

            HStack(spacing: DS.Spacing.sm) {
                TemperatureBadge(current: 220, target: 220, style: .nozzle)
                TemperatureBadge(current: 55, target: 60, style: .bed)
                TemperatureBadge(current: 28, style: .chamber)
            }
        }

        Divider().background(DS.Colors.borderSubtle)

        // Connection Status
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Connection Status")
                .font(DS.Typography.headline)

            HStack(spacing: DS.Spacing.lg) {
                ConnectionStatus(isConnected: true)
                ConnectionStatus(isConnected: false)
            }
        }
    }
    .foregroundStyle(DS.Colors.textPrimary)
    .padding(DS.Spacing.lg)
    .background(DS.Colors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
