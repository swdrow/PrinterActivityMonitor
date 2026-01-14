import Foundation

@MainActor
@Observable
final class HistoryViewModel {
    var jobs: [PrintJob] = []
    var stats: PrintStats?
    var isLoading = false
    var error: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    func loadHistory() async {
        guard !settings.serverURL.isEmpty else {
            error = "Server not configured"
            return
        }

        guard !settings.deviceId.isEmpty else {
            error = "Device not registered"
            return
        }

        isLoading = true
        error = nil

        do {
            try apiClient.configure(serverURL: settings.serverURL)

            // Load history and stats in parallel
            async let historyTask = apiClient.fetchHistory(
                deviceId: settings.deviceId,
                limit: 100
            )
            async let statsTask = apiClient.fetchStats(deviceId: settings.deviceId)

            let (history, fetchedStats) = try await (historyTask, statsTask)

            jobs = history
            stats = fetchedStats
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadHistory()
    }
}
