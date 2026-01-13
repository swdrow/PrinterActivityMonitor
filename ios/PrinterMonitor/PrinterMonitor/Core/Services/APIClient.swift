import Foundation

/// API client for communicating with the Printer Monitor server
@Observable
final class APIClient {
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
        case delete = "DELETE"
    }

    enum APIError: LocalizedError {
        case invalidURL
        case notConfigured
        case invalidResponse
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid server URL"
            case .notConfigured: return "API client not configured"
            case .invalidResponse: return "Invalid response from server"
            case .httpError(let code): return "HTTP error: \(code)"
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
}
