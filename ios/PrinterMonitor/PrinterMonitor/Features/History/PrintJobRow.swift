import SwiftUI

struct PrintJobRow: View {
    let job: PrintJob

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: job.status?.iconName ?? "questionmark.circle")
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(job.formattedDate)
                    if let layers = job.layerInfo {
                        Text("•")
                        Text(layers)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration and status
            VStack(alignment: .trailing, spacing: 2) {
                Text(job.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(job.status?.displayName ?? "Unknown")
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .running: return .blue
        case .none: return .secondary
        }
    }
}
