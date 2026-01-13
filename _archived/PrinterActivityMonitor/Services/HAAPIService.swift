import Foundation
import Combine
import SwiftUI

/// Delegate that bypasses SSL certificate validation for local/development use
class InsecureURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accept any server certificate (for self-signed certs / local development)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// Service for communicating with Home Assistant REST API
@MainActor
class HAAPIService: ObservableObject {
    @Published var printerState: PrinterState = .placeholder
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var isLoading: Bool = false

    private(set) var baseURL: String = ""
    private(set) var accessToken: String = ""
    private(set) var entityPrefix: String = "h2s"
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 30
    private var lastKnownFileName: String = ""

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

        // Core print sensors
        async let progress = fetchSensorState("print_progress")
        async let currentLayer = fetchSensorState("current_layer")
        async let totalLayers = fetchSensorState("total_layer_count")
        async let remainingTime = fetchSensorState("remaining_time")
        async let printStatus = fetchSensorState("print_status")
        async let subtaskName = fetchSensorState("subtask_name")
        async let printSpeed = fetchSensorState("speed_profile")
        async let filamentUsed = fetchSensorState("filament_used")

        // Temperature sensors
        async let nozzleTemp = fetchSensorState("nozzle_temperature")
        async let nozzleTargetTemp = fetchSensorState("target_nozzle_temperature")
        async let bedTemp = fetchSensorState("bed_temperature")
        async let bedTargetTemp = fetchSensorState("target_bed_temperature")
        async let chamberTemp = fetchSensorState("chamber_temperature")

        // Additional info
        async let currentStage = fetchSensorState("current_stage")
        async let printWeight = fetchSensorState("print_weight")
        async let printLength = fetchSensorState("print_length")
        async let bedType = fetchSensorState("print_bed_type")
        async let startTimeStr = fetchSensorState("start_time")
        async let endTimeStr = fetchSensorState("end_time")

        // Fan sensors
        async let auxFan = fetchSensorState("aux_fan")
        async let chamberFan = fetchSensorState("chamber_fan")
        async let coolingFan = fetchSensorState("cooling_fan")

        // Status sensors
        async let isOnline = fetchSensorState("online")
        async let wifiSignal = fetchSensorState("wifi_signal")
        async let hmsErrors = fetchSensorState("hms_errors")

        // Fetch cover image URL (image entity) and cache it for Live Activity
        var coverImageURL: String? = nil
        if let remoteImageURL = try? await fetchImageEntity("image.\(entityPrefix)_cover_image") {
            // Cache the image for Live Activity access (widget can't access authenticated URLs)
            if let cachedURL = await SharedImageCache.shared.cacheCoverImage(from: remoteImageURL, accessToken: accessToken) {
                coverImageURL = cachedURL.absoluteString
            } else {
                // Fallback to remote URL if caching fails
                coverImageURL = remoteImageURL
            }
        }

        // Wait for all async fetches
        let core = try await (progress, currentLayer, totalLayers, remainingTime, printStatus, subtaskName, printSpeed, filamentUsed)
        let temps = try await (nozzleTemp, nozzleTargetTemp, bedTemp, bedTargetTemp, chamberTemp)
        let info = try await (currentStage, printWeight, printLength, bedType, startTimeStr, endTimeStr)
        let fans = try await (auxFan, chamberFan, coolingFan)
        let status = try await (isOnline, wifiSignal, hmsErrors)

        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        let startDate = dateFormatter.date(from: info.4)
        let endDate = dateFormatter.date(from: info.5)

        // Detect printer model from device name or attributes
        let printerModel = detectPrinterModel()

        // Get current filename, preserving last known if current is empty during active print
        let currentFileName: String
        let rawFileName = core.5  // subtask_name sensor value
        let parsedStatus = PrinterState.PrintStatus(rawValue: core.4.lowercased()) ?? .unknown

        if !rawFileName.isEmpty {
            currentFileName = rawFileName
            lastKnownFileName = rawFileName  // Remember valid filename
        } else if parsedStatus == .running || parsedStatus == .paused || parsedStatus == .prepare {
            // During active/preparing print, use last known filename
            currentFileName = lastKnownFileName.isEmpty ? "Starting..." : lastKnownFileName
        } else {
            currentFileName = "No print"
            lastKnownFileName = ""  // Clear when truly idle
        }

        return PrinterState(
            progress: Int(Double(core.0) ?? 0),
            currentLayer: Int(core.1) ?? 0,
            totalLayers: Int(core.2) ?? 0,
            remainingMinutes: parseRemainingTime(core.3),
            status: parsedStatus,
            fileName: currentFileName,
            printSpeed: Int(core.6) ?? 100,
            filamentUsed: parseFilamentUsed(core.7),
            nozzleTemp: Double(temps.0) ?? 0,
            nozzleTargetTemp: Double(temps.1) ?? 0,
            bedTemp: Double(temps.2) ?? 0,
            bedTargetTemp: Double(temps.3) ?? 0,
            chamberTemp: Double(temps.4) ?? 0,
            currentStage: info.0,
            printWeight: Double(info.1) ?? 0,
            printLength: Double(info.2) ?? 0,
            bedType: info.3,
            startTime: startDate,
            endTime: endDate,
            auxFanSpeed: Int(fans.0) ?? 0,
            chamberFanSpeed: Int(fans.1) ?? 0,
            coolingFanSpeed: Int(fans.2) ?? 0,
            isOnline: status.0.lowercased() == "on" || status.0.lowercased() == "true",
            wifiSignal: Int(status.1) ?? 0,
            hmsErrors: status.2,
            coverImageURL: coverImageURL,
            printerModel: printerModel
        )
    }

    /// Detect printer model from entity prefix or device info
    func detectPrinterModel() -> PrinterState.PrinterModel {
        let prefix = entityPrefix.lowercased()

        // Check H2S/H2D first (before generic checks)
        if prefix.contains("h2s") {
            return .h2s
        } else if prefix.contains("h2d") {
            return .h2d
        } else if prefix.contains("x1c") || prefix.contains("x1_c") || prefix.contains("x1carbon") {
            return .x1c
        } else if prefix.contains("x1e") {
            return .x1e
        } else if prefix.contains("p1p") {
            return .p1p
        } else if prefix.contains("p1s") {
            return .p1s
        } else if prefix.contains("a1mini") || prefix.contains("a1_mini") {
            return .a1mini
        } else if prefix.contains("a1") && !prefix.contains("ams") {
            return .a1
        }
        return .unknown
    }

    /// Parse remaining time from various Home Assistant formats
    func parseRemainingTime(_ timeString: String) -> Int {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Try direct integer conversion first (minutes as plain number)
        if let minutes = Int(trimmed) {
            return minutes
        }

        // Try double conversion (decimal minutes)
        if let doubleValue = Double(trimmed) {
            return Int(doubleValue)
        }

        // Parse "1h 30m", "90m", "1h30m" formats
        var totalMinutes = 0

        // Extract hours
        if let hourRange = trimmed.range(of: "(\\d+)\\s*h", options: .regularExpression) {
            let hourStr = trimmed[hourRange].filter { $0.isNumber }
            totalMinutes += (Int(hourStr) ?? 0) * 60
        }

        // Extract minutes
        if let minRange = trimmed.range(of: "(\\d+)\\s*m", options: .regularExpression) {
            let minStr = trimmed[minRange].filter { $0.isNumber }
            totalMinutes += Int(minStr) ?? 0
        }

        // If we found time components, return them
        if totalMinutes > 0 {
            return totalMinutes
        }

        // Last resort: extract any number
        let numbers = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers) ?? 0
    }

    /// Parse filament usage from various Home Assistant formats
    func parseFilamentUsed(_ filamentString: String) -> Double {
        let trimmed = filamentString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Remove common unit suffixes
        var valueString = trimmed
            .replacingOccurrences(of: "grams", with: "")
            .replacingOccurrences(of: "gram", with: "")
            .replacingOccurrences(of: "mm", with: "")  // Must check mm before m
            .replacingOccurrences(of: " ", with: "")

        // Check if it's in meters (convert to grams: ~2.96g per meter for 1.75mm PLA)
        if trimmed.hasSuffix("m") && !trimmed.hasSuffix("mm") {
            valueString = valueString.replacingOccurrences(of: "m", with: "")
            if let meters = Double(valueString) {
                return meters * 2.96
            }
        }

        // Remove trailing 'g' for grams
        valueString = valueString.replacingOccurrences(of: "g", with: "")

        // Try double conversion
        if let grams = Double(valueString) {
            return grams
        }

        return 0
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

    // MARK: - Service Calls (Printer Controls)

    /// Generic method to call a Home Assistant service
    func callService(domain: String, service: String, data: [String: Any] = [:]) async throws {
        let urlString = "\(baseURL)/api/services/\(domain)/\(service)"

        guard let url = URL(string: urlString) else {
            throw HAAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !data.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw HAAPIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw HAAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Pause the current print
    func pausePrint() async throws {
        // Using button entity to trigger pause
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_pause"
        ])
    }

    /// Resume the current print
    func resumePrint() async throws {
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_resume"
        ])
    }

    /// Stop/cancel the current print
    func stopPrint() async throws {
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_stop"
        ])
    }

    /// Set nozzle temperature
    func setNozzleTemp(_ temp: Double) async throws {
        try await callService(domain: "number", service: "set_value", data: [
            "entity_id": "number.\(entityPrefix)_nozzle_temperature",
            "value": temp
        ])
    }

    /// Set bed temperature
    func setBedTemp(_ temp: Double) async throws {
        try await callService(domain: "number", service: "set_value", data: [
            "entity_id": "number.\(entityPrefix)_bed_temperature",
            "value": temp
        ])
    }

    /// Toggle chamber light
    func toggleLight(_ on: Bool) async throws {
        let service = on ? "turn_on" : "turn_off"
        try await callService(domain: "light", service: service, data: [
            "entity_id": "light.\(entityPrefix)_chamber_light"
        ])
    }

    /// Send arbitrary GCODE command
    func sendGcode(_ gcode: String, deviceId: String) async throws {
        try await callService(domain: "bambu_lab", service: "send_command", data: [
            "device_id": deviceId,
            "command": gcode
        ])
    }

    /// Set print speed (50-150%)
    func setPrintSpeed(_ speed: Int, deviceId: String) async throws {
        // Speed is set via GCODE M220 S{speed}
        try await sendGcode("M220 S\(speed)", deviceId: deviceId)
    }

    // MARK: - Sensor Testing

    /// Test a single sensor and return detailed result
    func testSensor(_ sensorName: String) async -> SensorResult {
        let startTime = Date()
        let entityId = "sensor.\(entityPrefix)_\(sensorName)"
        let urlString = "\(baseURL)/api/states/\(entityId)"

        guard let url = URL(string: urlString) else {
            return SensorResult(
                sensorName: sensorName,
                status: .error,
                value: nil,
                error: "Invalid URL",
                responseTime: "0ms"
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            let responseTime = String(format: "%.0fms", elapsed * 1000)

            guard let httpResponse = response as? HTTPURLResponse else {
                return SensorResult(
                    sensorName: sensorName,
                    status: .error,
                    value: nil,
                    error: "Invalid response",
                    responseTime: responseTime
                )
            }

            if httpResponse.statusCode == 404 {
                return SensorResult(
                    sensorName: sensorName,
                    status: .notFound,
                    value: nil,
                    error: "Entity not found: \(entityId)",
                    responseTime: responseTime
                )
            }

            if httpResponse.statusCode == 401 {
                return SensorResult(
                    sensorName: sensorName,
                    status: .error,
                    value: nil,
                    error: "Unauthorized",
                    responseTime: responseTime
                )
            }

            guard httpResponse.statusCode == 200 else {
                return SensorResult(
                    sensorName: sensorName,
                    status: .error,
                    value: nil,
                    error: "HTTP \(httpResponse.statusCode)",
                    responseTime: responseTime
                )
            }

            let decoded = try JSONDecoder().decode(HAStateResponse.self, from: data)
            return SensorResult(
                sensorName: sensorName,
                status: .success,
                value: decoded.state,
                error: nil,
                responseTime: responseTime
            )
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            let responseTime = String(format: "%.0fms", elapsed * 1000)
            return SensorResult(
                sensorName: sensorName,
                status: .error,
                value: nil,
                error: error.localizedDescription,
                responseTime: responseTime
            )
        }
    }

    // MARK: - Entity Fetching with Attributes

    /// Fetch a full entity including all attributes
    func fetchEntityWithAttributes(_ entityId: String) async throws -> HAEntityData {
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

        if httpResponse.statusCode == 404 {
            throw HAAPIError.entityNotFound(entityId)
        }

        guard httpResponse.statusCode == 200 else {
            throw HAAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse raw JSON to extract attributes properly
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HAAPIError.decodingError
        }

        let state = json["state"] as? String ?? ""
        let attributes = json["attributes"] as? [String: Any] ?? [:]

        return HAEntityData(entityId: entityId, state: state, attributes: attributes)
    }

    /// Fetch image entity and return base64 data or URL
    func fetchImageEntity(_ entityId: String) async throws -> String? {
        let entity = try await fetchEntityWithAttributes(entityId)
        // Image entities typically have entity_picture attribute
        if let picture = entity.attributes["entity_picture"] as? String {
            // Return the full URL
            return baseURL + picture
        }
        return nil
    }

    // MARK: - AMS Sensors

    /// Fetch AMS tray data
    /// The ha-bambulab integration uses: sensor.{prefix}_ams_1_tray_1 through _tray_4
    /// (with AMS unit number, typically "1" for first/only AMS)
    func fetchAMSTray(_ trayNumber: Int, amsUnit: Int = 1) async throws -> AMSTrayData {
        // Try multiple naming patterns
        let patterns = [
            "sensor.\(entityPrefix)_ams_\(amsUnit)_tray_\(trayNumber)",  // With AMS unit (most common)
            "sensor.\(entityPrefix)_ams_tray_\(trayNumber)",             // Without AMS unit
        ]

        var lastError: Error = HAAPIError.entityNotFound("AMS tray \(trayNumber)")

        for entityId in patterns {
            do {
                let entity = try await fetchEntityWithAttributes(entityId)

                // Determine if this tray is active
                let isActive = entity.boolAttribute("active") ?? (entity.state.lowercased() == "active")

                // Multi-factor isEmpty detection for better compatibility with non-Bambu filament
                let explicitEmpty = entity.boolAttribute("empty")
                let remainingAmount = entity.doubleAttribute("remaining") ?? entity.doubleAttribute("remain") ?? -1
                let filamentType = entity.stringAttribute("type") ?? entity.state
                let filamentName = entity.stringAttribute("name") ?? ""
                let colorHex = entity.stringAttribute("color") ?? ""

                let isEmpty: Bool
                if let explicitEmpty = explicitEmpty {
                    // If explicit empty attribute exists and remaining is not positive, trust it
                    // But if remaining > 0 or we have type info, filament is likely present
                    if !explicitEmpty {
                        isEmpty = false
                    } else if remainingAmount > 0 {
                        // Has remaining filament, not empty despite attribute
                        isEmpty = false
                    } else if !filamentType.isEmpty && filamentType.lowercased() != "empty" && filamentType.lowercased() != "unknown" {
                        // Has a valid filament type, likely not empty
                        isEmpty = false
                    } else {
                        isEmpty = true
                    }
                } else {
                    // No explicit attribute - use heuristics
                    let hasType = !filamentType.isEmpty && filamentType.lowercased() != "empty" && filamentType.lowercased() != "unknown"
                    let hasName = !filamentName.isEmpty
                    let hasRemaining = remainingAmount > 0
                    let hasColor = !colorHex.isEmpty && colorHex != "#808080" && colorHex.lowercased() != "808080"

                    // Empty only if we have no indicators of filament presence
                    isEmpty = !hasType && !hasName && !hasRemaining && !hasColor
                }

                // Detect RFID validity: kValue > 0 indicates successful RFID read
                // Also consider if remaining has a meaningful positive value (not just 0 default)
                let kValue = entity.doubleAttribute("k") ?? 0
                let hasValidRFIDData = kValue > 0 || (remainingAmount > 0 && remainingAmount <= 100)

                return AMSTrayData(
                    trayNumber: trayNumber,
                    color: entity.stringAttribute("color") ?? "#808080",
                    isEmpty: isEmpty,
                    kValue: kValue,
                    name: entity.stringAttribute("name") ?? "",
                    nozzleTempMin: entity.intAttribute("nozzle_temp_min") ?? 0,
                    nozzleTempMax: entity.intAttribute("nozzle_temp_max") ?? 0,
                    remaining: remainingAmount >= 0 ? remainingAmount : 0,
                    type: entity.stringAttribute("type") ?? entity.state,
                    isActive: isActive,
                    hasValidRFIDData: hasValidRFIDData
                )
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    /// Fetch AMS unit status
    func fetchAMSStatus(amsUnit: Int = 1) async throws -> AMSUnitData {
        // Try multiple naming patterns for humidity sensor (indicates AMS is connected)
        let humidityPatterns = [
            "sensor.\(entityPrefix)_ams_\(amsUnit)_humidity",
            "sensor.\(entityPrefix)_ams_humidity",
            "sensor.\(entityPrefix)_humidity_index",
        ]

        var humidity = 0
        var isConnected = false

        for entityId in humidityPatterns {
            if let humidityEntity = try? await fetchEntityWithAttributes(entityId) {
                humidity = Int(humidityEntity.state) ?? 0
                isConnected = true
                break
            }
        }

        // If no humidity sensor found, try to detect via tray sensor
        if !isConnected {
            // Try to fetch first tray - if it exists, AMS is connected
            let trayPatterns = [
                "sensor.\(entityPrefix)_ams_\(amsUnit)_tray_1",
                "sensor.\(entityPrefix)_ams_tray_1",
            ]
            for entityId in trayPatterns {
                if let _ = try? await fetchEntityWithAttributes(entityId) {
                    isConnected = true
                    break
                }
            }
        }

        guard isConnected else {
            return AMSUnitData(isConnected: false, humidity: 0, activeTrayIndex: 0, isDrying: false, dryingRemainingMinutes: 0)
        }

        // Fetch active tray
        var activeTray = 0
        let activePatterns = [
            "sensor.\(entityPrefix)_active_tray",
            "sensor.\(entityPrefix)_active_tray_index",
            "sensor.\(entityPrefix)_ams_\(amsUnit)_active_tray",
        ]
        for entityId in activePatterns {
            if let activeEntity = try? await fetchEntityWithAttributes(entityId) {
                activeTray = Int(activeEntity.state) ?? 0
                break
            }
        }

        // Fetch drying status
        var isDrying = false
        var dryingRemaining = 0
        let dryingPatterns = [
            "sensor.\(entityPrefix)_ams_\(amsUnit)_drying",
            "sensor.\(entityPrefix)_ams_drying",
            "switch.\(entityPrefix)_ams_drying",
        ]
        for entityId in dryingPatterns {
            if let dryingEntity = try? await fetchEntityWithAttributes(entityId) {
                isDrying = dryingEntity.state.lowercased() == "on" || dryingEntity.state == "true"
                break
            }
        }

        let remainingPatterns = [
            "sensor.\(entityPrefix)_ams_\(amsUnit)_remaining_drying_time",
            "sensor.\(entityPrefix)_ams_remaining_drying_time",
        ]
        for entityId in remainingPatterns {
            if let remainingEntity = try? await fetchEntityWithAttributes(entityId) {
                dryingRemaining = Int(remainingEntity.state) ?? 0
                break
            }
        }

        return AMSUnitData(
            isConnected: true,
            humidity: humidity,
            activeTrayIndex: activeTray,
            isDrying: isDrying,
            dryingRemainingMinutes: dryingRemaining
        )
    }

    /// Fetch ALL entities from Home Assistant and filter by keyword
    /// This helps discover entity naming conventions
    func discoverEntities(containing keywords: [String]) async throws -> [String: Any] {
        let urlString = "\(baseURL)/api/states"

        guard let url = URL(string: urlString) else {
            throw HAAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw HAAPIError.invalidResponse
        }

        guard let allEntities = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HAAPIError.decodingError
        }

        var results: [String: Any] = [:]

        for entity in allEntities {
            guard let entityId = entity["entity_id"] as? String else { continue }

            // Check if entity ID contains any of the keywords
            let lowerId = entityId.lowercased()
            let matches = keywords.contains { lowerId.contains($0.lowercased()) }

            if matches {
                let state = entity["state"] as? String ?? ""
                let attributes = entity["attributes"] as? [String: Any] ?? [:]

                // Convert attributes to string representation for display
                var attrsDict: [String: String] = [:]
                for (key, value) in attributes {
                    attrsDict[key] = "\(value)"
                }

                results[entityId] = [
                    "state": state,
                    "attributes": attrsDict
                ]
            }
        }

        return results
    }

    /// Legacy method for backwards compatibility
    func fetchAMSSensor(_ sensorName: String) async throws -> String {
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

        if httpResponse.statusCode == 404 {
            return ""
        }

        guard httpResponse.statusCode == 200 else {
            throw HAAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(HAStateResponse.self, from: data)
        return decoded.state
    }

    // MARK: - AMS Controls

    /// Load filament from AMS slot
    func loadFilament(slot: Int) async throws {
        try await callService(domain: "bambu_lab", service: "load_filament", data: [
            "device_id": entityPrefix,
            "slot": slot
        ])
    }

    /// Unload filament from AMS
    func unloadFilament(slot: Int) async throws {
        try await callService(domain: "bambu_lab", service: "unload_filament", data: [
            "device_id": entityPrefix,
            "slot": slot
        ])
    }

    /// Retract filament to AMS
    func retractFilament() async throws {
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_retract_filament"
        ])
    }

    /// Read RFID tag from AMS slot
    func readAMSRFID(slot: Int) async throws {
        try await callService(domain: "bambu_lab", service: "read_ams_rfid", data: [
            "device_id": entityPrefix,
            "slot": slot
        ])
    }

    /// Start filament drying in AMS
    func startFilamentDrying() async throws {
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_start_drying"
        ])
    }

    /// Stop filament drying in AMS
    func stopFilamentDrying() async throws {
        try await callService(domain: "button", service: "press", data: [
            "entity_id": "button.\(entityPrefix)_stop_drying"
        ])
    }

    /// Set drying temperature for AMS
    /// - Parameter temperature: Target temperature in Celsius (typically 40-70)
    func setDryingTemperature(_ temperature: Int) async throws {
        // Try common entity patterns for drying temperature
        let patterns = [
            "number.\(entityPrefix)_drying_temperature",
            "number.\(entityPrefix)_ams_drying_temperature",
        ]

        for entityId in patterns {
            do {
                try await callService(domain: "number", service: "set_value", data: [
                    "entity_id": entityId,
                    "value": temperature
                ])
                return  // Success
            } catch {
                continue  // Try next pattern
            }
        }
    }

    /// Set drying duration for AMS
    /// - Parameter duration: Duration in minutes
    func setDryingDuration(_ duration: Int) async throws {
        // Try common entity patterns for drying duration
        let patterns = [
            "number.\(entityPrefix)_drying_duration",
            "number.\(entityPrefix)_ams_drying_duration",
            "number.\(entityPrefix)_drying_time",
        ]

        for entityId in patterns {
            do {
                try await callService(domain: "number", service: "set_value", data: [
                    "entity_id": entityId,
                    "value": duration
                ])
                return  // Success
            } catch {
                continue  // Try next pattern
            }
        }
    }
}

enum HAAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError
    case entityNotFound(String)

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
        case .entityNotFound(let entity):
            return "Entity not found: \(entity)"
        }
    }
}

// MARK: - HA Data Types

/// Represents a Home Assistant entity with its attributes
struct HAEntityData {
    let entityId: String
    let state: String
    let attributes: [String: Any]

    func stringAttribute(_ key: String) -> String? {
        attributes[key] as? String
    }

    func intAttribute(_ key: String) -> Int? {
        if let intVal = attributes[key] as? Int {
            return intVal
        }
        if let doubleVal = attributes[key] as? Double {
            return Int(doubleVal)
        }
        if let strVal = attributes[key] as? String {
            return Int(strVal)
        }
        return nil
    }

    func doubleAttribute(_ key: String) -> Double? {
        if let doubleVal = attributes[key] as? Double {
            return doubleVal
        }
        if let intVal = attributes[key] as? Int {
            return Double(intVal)
        }
        if let strVal = attributes[key] as? String {
            return Double(strVal)
        }
        return nil
    }

    func boolAttribute(_ key: String) -> Bool? {
        if let boolVal = attributes[key] as? Bool {
            return boolVal
        }
        if let strVal = attributes[key] as? String {
            return strVal.lowercased() == "true" || strVal == "1"
        }
        if let intVal = attributes[key] as? Int {
            return intVal != 0
        }
        return nil
    }
}

/// AMS tray data from Home Assistant
struct AMSTrayData {
    let trayNumber: Int
    let color: String           // Hex color code
    let isEmpty: Bool
    let kValue: Double
    let name: String            // Filament name/brand
    let nozzleTempMin: Int
    let nozzleTempMax: Int
    let remaining: Double       // 0-100 percentage
    let type: String            // PLA, PETG, ABS, etc.
    let isActive: Bool
    let hasValidRFIDData: Bool  // True if RFID data was successfully read (Bambu Lab filament)

    /// Convert to AMSSlot for display
    func toAMSSlot() -> AMSSlot {
        AMSSlot(
            id: trayNumber - 1,  // Convert 1-based to 0-based
            isActive: isActive,
            color: Color(hex: color) ?? .gray,
            colorHex: color.hasPrefix("#") ? color : "#\(color)",
            materialType: isEmpty ? "Empty" : type,
            remaining: remaining / 100.0,  // Convert to 0-1 range
            nozzleTempMin: nozzleTempMin,
            nozzleTempMax: nozzleTempMax,
            isEmpty: isEmpty,
            hasValidRFIDData: hasValidRFIDData
        )
    }
}

/// AMS unit status data
struct AMSUnitData {
    let isConnected: Bool
    let humidity: Int
    let activeTrayIndex: Int
    let isDrying: Bool
    let dryingRemainingMinutes: Int
}
