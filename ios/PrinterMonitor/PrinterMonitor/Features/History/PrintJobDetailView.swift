import SwiftUI

struct PrintJobDetailView: View {
    let job: PrintJob

    var body: some View {
        List {
            Section("Print Info") {
                LabeledContent("Filename", value: job.filename)
                LabeledContent("Status", value: job.status?.displayName ?? "Unknown")
                if let startedAt = job.startedAt {
                    LabeledContent("Started") {
                        Text(startedAt, style: .date)
                        Text(" at ")
                        Text(startedAt, style: .time)
                    }
                }
                if let completedAt = job.completedAt {
                    LabeledContent("Completed") {
                        Text(completedAt, style: .date)
                        Text(" at ")
                        Text(completedAt, style: .time)
                    }
                }
            }

            Section("Statistics") {
                LabeledContent("Duration", value: job.formattedDuration)
                if let layers = job.totalLayers {
                    LabeledContent("Total Layers", value: "\(layers)")
                }
                if let finalLayer = job.finalLayer, let total = job.totalLayers {
                    LabeledContent("Final Layer", value: "\(finalLayer)/\(total)")
                }
                if let filament = job.filamentUsedMm {
                    LabeledContent("Filament Used", value: String(format: "%.1f mm", filament))
                }
            }

            if let printerPrefix = job.printerPrefix {
                Section("Printer") {
                    LabeledContent("Prefix", value: printerPrefix)
                }
            }
        }
        .navigationTitle("Print Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
