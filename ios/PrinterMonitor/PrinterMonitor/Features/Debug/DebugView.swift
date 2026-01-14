import SwiftUI

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss

    let apiClient: APIClient
    let settings: SettingsStorage

    @State private var serverStatus: String = "Unknown"
    @State private var isLoading = false
    @State private var showClearConfirm = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Server") {
                LabeledContent("URL") {
                    Text(settings.serverURL.isEmpty ? "Not configured" : settings.serverURL)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(serverStatus)
                            .foregroundStyle(serverStatus == "Connected" ? .green : .secondary)
                    }
                }

                Button("Check Connection") {
                    Task { await checkServerHealth() }
                }
                .disabled(isLoading || settings.serverURL.isEmpty)
            }

            Section("Device Info") {
                LabeledContent("Device ID") {
                    Text(settings.deviceId.isEmpty ? "Not registered" : String(settings.deviceId.prefix(8)) + "...")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Printer Prefix") {
                    Text(settings.selectedPrinterPrefix ?? "None")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("HA URL") {
                    Text(settings.haURL.isEmpty ? "Not configured" : settings.haURL)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Section("Test Notifications") {
                Button("Simulate Print Start") {
                    Task { await simulateStart() }
                }
                .disabled(settings.selectedPrinterPrefix == nil || isLoading)

                Button("Simulate 50% Progress") {
                    Task { await simulateProgress(50) }
                }
                .disabled(settings.selectedPrinterPrefix == nil || isLoading)

                Button("Simulate Print Complete") {
                    Task { await simulateComplete("complete") }
                }
                .disabled(settings.selectedPrinterPrefix == nil || isLoading)

                Button("Simulate Print Failed") {
                    Task { await simulateComplete("failed") }
                }
                .disabled(settings.selectedPrinterPrefix == nil || isLoading)

                if let message = statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                Button("Clear All Settings", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear All Settings?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) {
                settings.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all app settings and require reconfiguration.")
        }
        .task {
            await checkServerHealth()
        }
    }

    private func checkServerHealth() async {
        guard !settings.serverURL.isEmpty else {
            serverStatus = "Not configured"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            let health = try await apiClient.checkHealth()
            serverStatus = health.status == "ok" ? "Connected" : "Error: \(health.status)"
        } catch {
            serverStatus = "Error"
        }
    }

    private func simulateStart() async {
        guard let prefix = settings.selectedPrinterPrefix else { return }
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            try await apiClient.simulatePrintStart(printerPrefix: prefix)
            statusMessage = "Sent print start notification"
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func simulateProgress(_ progress: Int) async {
        guard let prefix = settings.selectedPrinterPrefix else { return }
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            try await apiClient.simulateProgress(printerPrefix: prefix, progress: progress)
            statusMessage = "Sent \(progress)% progress notification"
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func simulateComplete(_ status: String) async {
        guard let prefix = settings.selectedPrinterPrefix else { return }
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            try await apiClient.simulatePrintComplete(printerPrefix: prefix, status: status)
            statusMessage = "Sent print \(status) notification"
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugView(apiClient: APIClient(), settings: SettingsStorage())
    }
}
#endif
