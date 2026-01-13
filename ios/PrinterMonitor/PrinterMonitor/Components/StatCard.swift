import SwiftUI

/// Card displaying a single statistic with icon
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let secondaryValue: String?

    init(icon: String, label: String, value: String, secondaryValue: String? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)

                Text(label)
                    .font(Theme.Typography.labelSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let secondary = secondaryValue {
                    Text(secondary)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .cardBackground()
    }
}

/// Grid of stat cards
struct StatGrid: View {
    let stats: [StatItem]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(stats) { stat in
                StatCard(
                    icon: stat.icon,
                    label: stat.label,
                    value: stat.value,
                    secondaryValue: stat.secondaryValue
                )
            }
        }
    }
}

struct StatItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let secondaryValue: String?

    init(icon: String, label: String, value: String, secondaryValue: String? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
    }
}

#Preview {
    ZStack {
        Theme.Colors.backgroundPrimary
            .ignoresSafeArea()

        VStack(spacing: Theme.Spacing.md) {
            StatCard(icon: "timer", label: "Time Left", value: "1h 23m", secondaryValue: "~3:45 PM")
            StatCard(icon: "square.stack.3d.up", label: "Layer", value: "142", secondaryValue: "of 300")

            StatGrid(stats: [
                StatItem(icon: "thermometer.high", label: "Nozzle", value: "220°C"),
                StatItem(icon: "thermometer.low", label: "Bed", value: "60°C"),
                StatItem(icon: "gauge.with.dots.needle.bottom.50percent", label: "Speed", value: "Standard"),
                StatItem(icon: "square.stack.3d.up", label: "Layer", value: "142/300")
            ])
        }
        .padding()
    }
}
