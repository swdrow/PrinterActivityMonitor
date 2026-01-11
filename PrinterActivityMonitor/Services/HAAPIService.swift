import Foundation
import Combine

/// Service for communicating with Home Assistant REST API
@MainActor
class HAAPIService: ObservableObject {
    @Published var printerState: PrinterState = .placeholder
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var isLoading: Bool = false

    private var baseURL: String = ""
    private var accessToken: String = ""
    private var entityPrefix: String = "h2s"
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 30

    func configure(with settings: AppSettings) {
        self.baseURL = settings.haServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accessToken = settings.haAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.entityPrefix = settings.entityPrefix
        self.refreshInterval = TimeInterval(settings.refreshInterval)

        // Restart polling if configured
        stopPolling()
        if settings.isConfigured {
            startPolling()
        }
    }

    func startPolling() {
        // Initial fetch
        Task {
            await fetchAndUpdate()
        }

        // Schedule periodic updates
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAndUpdate()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func fetchAndUpdate() async {
        do {
            let state = try await fetchPrinterState()
            self.printerState = state
            self.isConnected = true
            self.lastError = nil
        } catch {
            self.isConnected = false
            self.lastError = error.localizedDescription
        }
    }

    /// Fetch current printer state from Home Assistant
    func fetchPrinterState() async throws -> PrinterState {
        isLoading = true
        defer { isLoading = false }

        async let progress = fetchSensorState("print_progress")
        async let currentLayer = fetchSensorState("current_layer")
        async let totalLayers = fetchSensorState("total_layer_count")
        async let remainingTime = fetchSensorState("remaining_time")
        async let printStatus = fetchSensorState("print_status")
        async let subtaskName = fetchSensorState("subtask_name")
        async let nozzleTemp = fetchSensorState("nozzle_temperature")
        async let bedTemp = fetchSensorState("bed_temperature")
        async let printSpeed = fetchSensorState("speed_profile")
        async let filamentUsed = fetchSensorState("filament_used")

        let results = try await (
            progress, currentLayer, totalLayers, remainingTime,
            printStatus, subtaskName, nozzleTemp, bedTemp,
            printSpeed, filamentUsed
        )

        return PrinterState(
            progress: Int(Double(results.0) ?? 0),
            currentLayer: Int(results.1) ?? 0,
            totalLayers: Int(results.2) ?? 0,
            remainingMinutes: Int(results.3) ?? 0,
            status: PrinterState.PrintStatus(rawValue: results.4.lowercased()) ?? .unknown,
            fileName: results.5.isEmpty ? "No print" : results.5,
            nozzleTemp: Double(results.6) ?? 0,
            bedTemp: Double(results.7) ?? 0,
            printSpeed: Int(results.8) ?? 100,
            filamentUsed: Double(results.9) ?? 0
        )
    }

    private func fetchSensorState(_ sensorName: String) async throws -> String {
        let entityId = "sensor.\(entityPrefix)_\(sensorName)"
        let urlString = "\(baseURL)/api/states/\(entityId)"

        guard let url = URL(string: urlString) else {
            throw HAAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw HAAPIError.unauthorized
        }

        if httpResponse.statusCode == 404 {
            // Entity not found, return empty string
            return ""
        }

        guard httpResponse.statusCode == 200 else {
            throw HAAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(HAStateResponse.self, from: data)
        return decoded.state
    }

    /// Test connection to Home Assistant
    func testConnection() async -> (success: Bool, message: String) {
        guard !baseURL.isEmpty, !accessToken.isEmpty else {
            return (false, "Please enter server URL and access token")
        }

        let urlString = "\(baseURL)/api/"

        guard let url = URL(string: urlString) else {
            return (false, "Invalid URL format")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response")
            }

            if httpResponse.statusCode == 200 {
                return (true, "Connected successfully!")
            } else if httpResponse.statusCode == 401 {
                return (false, "Invalid access token")
            } else {
                return (false, "HTTP Error: \(httpResponse.statusCode)")
            }
        } catch {
            return (false, "Connection failed: \(error.localizedDescription)")
        }
    }
}

enum HAAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - check your access token"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .decodingError:
            return "Failed to parse server response"
        }
    }
}
