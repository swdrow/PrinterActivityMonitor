import Foundation

/// API client for communicating with the Printer Monitor server
@MainActor
@Observable
final class APIClient: Sendable {
    // MARK: - Properties

    private(set) var isConnected = false
    private(set) var lastError: Error?

    private var baseURL: URL?
    private var session: URLSession

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func configure(serverURL: String) throws {
        guard let url = URL(string: serverURL) else {
            throw APIError.invalidURL
        }
        self.baseURL = url
    }

    // MARK: - Health Check

    func checkHealth() async throws -> HealthResponse {
        let data = try await request(endpoint: "/health", method: .get)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    // MARK: - Auth

    func validateHAConnection(haURL: String, haToken: String) async throws -> ValidationResponse {
        let body = ValidateRequest(haUrl: haURL, haToken: haToken)
        let data = try await request(endpoint: "/api/auth/validate", method: .post, body: body)
        return try JSONDecoder().decode(ValidationResponse.self, from: data)
    }

    // MARK: - Discovery

    func discoverPrinters(haURL: String, haToken: String) async throws -> DiscoveryResponse {
        let body = DiscoveryRequest(haUrl: haURL, haToken: haToken)
        let data = try await request(endpoint: "/api/discovery/scan", method: .post, body: body)
        return try JSONDecoder().decode(DiscoveryResponse.self, from: data)
    }

    // MARK: - Printer State

    func getPrinterState(prefix: String) async throws -> PrinterStateResponse {
        let data = try await request(endpoint: "/api/printers/state/\(prefix)", method: .get)
        let wrapper = try JSONDecoder().decode(PrinterStateWrapper.self, from: data)
        return wrapper.printer
    }

    func getAllPrinterStates() async throws -> [PrinterStateResponse] {
        let data = try await request(endpoint: "/api/printers/state", method: .get)
        let wrapper = try JSONDecoder().decode(AllPrinterStatesWrapper.self, from: data)
        return wrapper.printers
    }

    // MARK: - Monitor Control

    func startMonitor(haURL: String, haToken: String, printerPrefixes: [String]) async throws -> MonitorStartResponse {
        let body = MonitorStartRequest(haUrl: haURL, haToken: haToken, printerPrefixes: printerPrefixes)
        let data = try await request(endpoint: "/api/monitor/start", method: .post, body: body)
        return try JSONDecoder().decode(MonitorStartResponse.self, from: data)
    }

    func stopMonitor() async throws {
        _ = try await request(endpoint: "/api/monitor/stop", method: .post)
    }

    func getMonitorStatus() async throws -> MonitorStatusResponse {
        let data = try await request(endpoint: "/api/monitor/status", method: .get)
        return try JSONDecoder().decode(MonitorStatusResponse.self, from: data)
    }

    // MARK: - Device Registration

    func registerDevice(
        apnsToken: String,
        haUrl: String,
        printerPrefix: String?,
        printerName: String?
    ) async throws -> DeviceRegistrationResponse {
        let body = DeviceRegistrationRequest(
            apnsToken: apnsToken,
            haUrl: haUrl,
            printerPrefix: printerPrefix,
            printerName: printerName
        )
        let data = try await request(endpoint: "/api/devices/register", method: .post, body: body)
        return try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data)
    }

    func updateNotificationSettings(
        deviceId: String,
        settings: NotificationSettingsUpdate
    ) async throws {
        _ = try await request(
            endpoint: "/api/devices/\(deviceId)/settings",
            method: .patch,
            body: settings
        )
    }

    // MARK: - Activity Token Registration

    func registerActivityToken(
        activityToken: String,
        printerPrefix: String
    ) async throws {
        let body = ActivityTokenRequest(
            activityToken: activityToken,
            printerPrefix: printerPrefix
        )
        _ = try await request(endpoint: "/api/devices/activity-token", method: .post, body: body)
    }

    // MARK: - Print History

    func fetchHistory(deviceId: String, limit: Int = 50) async throws -> [PrintJob] {
        let data = try await request(
            endpoint: "/api/history?deviceId=\(deviceId)&limit=\(limit)",
            method: .get
        )
        let response = try historyDecoder.decode(HistoryResponse.self, from: data)
        guard response.success, let jobs = response.data else {
            throw APIError.serverError(response.error ?? "Unknown error")
        }
        return jobs
    }

    func fetchStats(deviceId: String) async throws -> PrintStats {
        let data = try await request(
            endpoint: "/api/history/stats?deviceId=\(deviceId)",
            method: .get
        )
        let response = try JSONDecoder().decode(StatsResponse.self, from: data)
        guard response.success, let stats = response.data else {
            throw APIError.serverError(response.error ?? "Unknown error")
        }
        return stats
    }

    private var historyDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Debug

    func simulatePrintStart(printerPrefix: String, filename: String = "Test Print.gcode") async throws {
        struct Request: Codable {
            let printerPrefix: String
            let filename: String
        }
        _ = try await request(
            endpoint: "/api/debug/simulate/start",
            method: .post,
            body: Request(printerPrefix: printerPrefix, filename: filename)
        )
    }

    func simulatePrintComplete(printerPrefix: String, status: String = "complete") async throws {
        struct Request: Codable {
            let printerPrefix: String
            let status: String
        }
        _ = try await request(
            endpoint: "/api/debug/simulate/complete",
            method: .post,
            body: Request(printerPrefix: printerPrefix, status: status)
        )
    }

    func simulateProgress(printerPrefix: String, progress: Int) async throws {
        struct Request: Codable {
            let printerPrefix: String
            let progress: Int
        }
        _ = try await request(
            endpoint: "/api/debug/simulate/progress",
            method: .post,
            body: Request(printerPrefix: printerPrefix, progress: progress)
        )
    }

    // MARK: - Private Helpers

    private func request<T: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: T? = nil as Empty?
    ) async throws -> Data {
        guard let baseURL else {
            throw APIError.notConfigured
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        isConnected = true
        lastError = nil
        return data
    }
}

// MARK: - Supporting Types

extension APIClient {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    enum APIError: LocalizedError {
        case invalidURL
        case notConfigured
        case invalidResponse
        case httpError(statusCode: Int)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid server URL"
            case .notConfigured: return "API client not configured"
            case .invalidResponse: return "Invalid response from server"
            case .httpError(let code): return "HTTP error: \(code)"
            case .serverError(let message): return message
            }
        }
    }

    struct Empty: Codable {}

    // Health
    struct HealthResponse: Codable {
        let status: String
        let timestamp: String
        let environment: String
    }

    // Auth
    struct ValidateRequest: Codable {
        let haUrl: String
        let haToken: String
    }

    struct ValidationResponse: Codable {
        let valid: Bool
        let message: String
    }

    // Discovery
    struct DiscoveryRequest: Codable {
        let haUrl: String
        let haToken: String
    }

    struct DiscoveryResponse: Codable {
        let success: Bool
        let printers: [DiscoveredPrinterDTO]
        let amsUnits: [DiscoveredAMSDTO]
        let totalEntities: Int
    }

    struct DiscoveredPrinterDTO: Codable, Identifiable {
        var id: String { entityPrefix }
        let entityPrefix: String
        let displayName: String
        let model: String
        let entityCount: Int
    }

    struct DiscoveredAMSDTO: Codable, Identifiable {
        var id: String { entityPrefix }
        let entityPrefix: String
        let displayName: String
        let trayCount: Int
        let associatedPrinter: String?
    }

    // Printer State
    struct PrinterStateWrapper: Codable {
        let success: Bool
        let printer: PrinterStateResponse
    }

    struct AllPrinterStatesWrapper: Codable {
        let success: Bool
        let printers: [PrinterStateResponse]
    }

    struct PrinterStateResponse: Codable {
        let entityPrefix: String
        let progress: Int
        let currentLayer: Int
        let totalLayers: Int
        let remainingSeconds: Int
        let status: String
        let nozzleTemp: Int
        let bedTemp: Int
        let subtaskName: String?
        let speedProfile: String?
        let isOnline: Bool
    }

    // Monitor Control
    struct MonitorStartRequest: Codable {
        let haUrl: String
        let haToken: String
        let printerPrefixes: [String]
    }

    struct MonitorStartResponse: Codable {
        let success: Bool
        let message: String
        let monitoringPrefixes: [String]
    }

    struct MonitorStatusResponse: Codable {
        let running: Bool
        let states: [PrinterStateResponse]
    }

    // Device Registration
    struct DeviceRegistrationRequest: Codable {
        let apnsToken: String
        let haUrl: String
        let printerPrefix: String?
        let printerName: String?
    }

    struct DeviceRegistrationResponse: Codable {
        let success: Bool
        let deviceId: String
        let message: String
    }

    struct NotificationSettingsUpdate: Codable {
        var notificationsEnabled: Bool?
        var onStart: Bool?
        var onComplete: Bool?
        var onFailed: Bool?
        var onPaused: Bool?
        var onMilestone: Bool?
    }

    // Activity Token
    struct ActivityTokenRequest: Codable {
        let activityToken: String
        let printerPrefix: String
    }

    // History
    struct HistoryResponse: Codable {
        let success: Bool
        let data: [PrintJob]?
        let error: String?
    }

    struct StatsResponse: Codable {
        let success: Bool
        let data: PrintStats?
        let error: String?
    }
}
