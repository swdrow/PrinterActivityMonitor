import SwiftUI

struct DiscoveredPrinter: Identifiable, Codable {
    let id = UUID()
    let entityPrefix: String
    let displayName: String
    let model: String
    let entityCount: Int

    enum CodingKeys: String, CodingKey {
        case entityPrefix, displayName, model, entityCount
    }
}

struct PrinterSelectionView: View {
    let haURL: String
    let haToken: String

    @State private var isScanning = true
    @State private var printers: [DiscoveredPrinter] = []
    @State private var selectedPrinter: DiscoveredPrinter?
    @State private var scanError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning for printers...")
                            .padding(.leading, 8)
                    }
                }
            } else if let error = scanError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)

                    Button("Retry") {
                        scanForPrinters()
                    }
                }
            } else if printers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "printer.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No printers found")
                            .font(.headline)
                        Text("Make sure ha_bambulab is installed and configured in Home Assistant")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            } else {
                Section("Select Your Printer") {
                    ForEach(printers) { printer in
                        Button(action: { selectPrinter(printer) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(printer.displayName)
                                        .font(.headline)
                                    Text(printer.entityPrefix)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedPrinter?.entityPrefix == printer.entityPrefix {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Printer")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    // TODO: Save selection and dismiss
                    dismiss()
                }
                .disabled(selectedPrinter == nil)
            }
        }
        .onAppear {
            scanForPrinters()
        }
    }

    private func scanForPrinters() {
        isScanning = true
        scanError = nil

        // TODO: Call API to discover printers
        // For now, simulate with mock data
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                isScanning = false

                // Mock data for development
                printers = [
                    DiscoveredPrinter(
                        entityPrefix: "h2s",
                        displayName: "Bambu Lab H2S",
                        model: "H2S",
                        entityCount: 15
                    )
                ]
            }
        }
    }

    private func selectPrinter(_ printer: DiscoveredPrinter) {
        selectedPrinter = printer
    }
}

#Preview {
    NavigationStack {
        PrinterSelectionView(haURL: "http://localhost:8123", haToken: "test")
    }
}
