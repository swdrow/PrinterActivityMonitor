import Foundation

/// View model for printer state and polling
@MainActor
@Observable
final class PrinterViewModel {
    // MARK: - Published State

    private(set) var printerState: PrinterState?
    private(set) var isLoading = false
    private(set) var isConnected = false
    private(set) var error: String?

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let settings: SettingsStorage
    private var pollingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    // MARK: - Public Methods

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task {
            while !Task.isCancelled {
                await fetchState()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        await fetchState()
    }

    // MARK: - Private Methods

    private func fetchState() async {
        guard let printerPrefix = settings.selectedPrinterPrefix else {
            error = "No printer selected"
            return
        }

        do {
            isLoading = printerState == nil // Only show loading on first fetch
            let response = try await apiClient.getPrinterState(prefix: printerPrefix)

            printerState = PrinterState(
                progress: response.progress,
                currentLayer: response.currentLayer,
                totalLayers: response.totalLayers,
                remainingSeconds: response.remainingSeconds,
                filename: response.subtaskName,
                status: PrintStatus(rawValue: response.status) ?? .unknown,
                nozzleTemp: response.nozzleTemp,
                bedTemp: response.bedTemp,
                chamberTemp: nil,
                printerName: settings.selectedPrinterName ?? printerPrefix,
                printerModel: detectModel(from: printerPrefix),
                isOnline: response.isOnline
            )
            isConnected = true
            self.error = nil
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isConnected = false
            isLoading = false
        }
    }

    private nonisolated func detectModel(from prefix: String) -> PrinterModel {
        let lowercased = prefix.lowercased()
        if lowercased.contains("x1c") { return .x1Carbon }
        if lowercased.contains("x1") { return .x1 }
        if lowercased.contains("p1s") { return .p1s }
        if lowercased.contains("p1p") { return .p1p }
        if lowercased.contains("a1m") { return .a1Mini }
        if lowercased.contains("a1") { return .a1 }
        if lowercased.contains("h2s") { return .h2s }
        if lowercased.contains("h2d") { return .h2d }
        return .unknown
    }
}
