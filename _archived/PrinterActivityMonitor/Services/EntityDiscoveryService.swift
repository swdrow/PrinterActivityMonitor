import Foundation

/// Discovered printer device with its entity prefix
struct DiscoveredPrinter: Identifiable, Equatable {
    let id = UUID()
    let prefix: String           // e.g., "h2s", "bambu_x1c"
    let name: String             // Friendly name from HA
    let model: String?           // Detected model if available
    var entityCount: Int         // Number of entities found
}

/// Discovered AMS unit with its entity prefix
struct DiscoveredAMS: Identifiable, Equatable {
    let id = UUID()
    let prefix: String           // e.g., "ams_2_pro", "bambu_x1c_ams_1"
    let name: String             // Friendly name
    let trayCount: Int           // Number of trays found (usually 4)
    var trayEntities: [String]   // Full entity IDs for trays
    var humidityEntity: String?  // Entity ID for humidity
    var temperatureEntity: String? // Entity ID for temperature
}

/// Service to auto-discover printers and AMS units from Home Assistant
class EntityDiscoveryService {

    // Known printer sensor suffixes (what we expect to find)
    static let printerSensorSuffixes = [
        "print_progress",
        "print_status",
        "current_layer",
        "total_layer_count",
        "remaining_time",
        "subtask_name",
        "nozzle_temperature",
        "bed_temperature",
        "current_stage",
    ]

    // Known AMS entity suffixes
    static let amsTrayPattern = "tray_"  // tray_1, tray_2, tray_3, tray_4
    static let amsHumidityPatterns = ["humidity", "humidity_index"]
    static let amsTemperaturePatterns = ["temperature", "ams_temperature"]

    /// Discover all printers and AMS units from Home Assistant
    static func discoverDevices(from allEntities: [[String: Any]]) -> (printers: [DiscoveredPrinter], amsUnits: [DiscoveredAMS]) {
        var printers: [DiscoveredPrinter] = []
        var amsUnits: [DiscoveredAMS] = []
        var printerPrefixes: Set<String> = []
        var amsPrefixes: Set<String> = []

        // Build a map of entity_id -> entity data
        var entityMap: [String: [String: Any]] = [:]
        for entity in allEntities {
            if let entityId = entity["entity_id"] as? String {
                entityMap[entityId] = entity
            }
        }

        // Step 1: Find printer prefixes by looking for known sensor patterns
        for (entityId, _) in entityMap {
            // Only look at sensors
            guard entityId.hasPrefix("sensor.") else { continue }
            let sensorPart = String(entityId.dropFirst(7)) // Remove "sensor."

            for suffix in printerSensorSuffixes {
                if sensorPart.hasSuffix("_\(suffix)") {
                    // Extract prefix: everything before "_suffix"
                    let prefix = String(sensorPart.dropLast(suffix.count + 1))
                    if !prefix.isEmpty {
                        printerPrefixes.insert(prefix)
                    }
                    break
                }
            }
        }

        // Step 2: Find AMS prefixes by looking for tray entities
        for (entityId, entity) in entityMap {
            guard entityId.hasPrefix("sensor.") else { continue }
            let sensorPart = String(entityId.dropFirst(7))

            // Look for tray patterns: xxx_tray_1, xxx_tray_2, etc.
            if let range = sensorPart.range(of: "_tray_\\d+$", options: .regularExpression) {
                let prefix = String(sensorPart[..<range.lowerBound])
                if !prefix.isEmpty {
                    amsPrefixes.insert(prefix)
                }
            }
        }

        // Step 3: Build printer objects
        for prefix in printerPrefixes {
            // Count how many entities match this prefix
            let matchingEntities = entityMap.keys.filter {
                $0.hasPrefix("sensor.\(prefix)_") ||
                $0.hasPrefix("button.\(prefix)_") ||
                $0.hasPrefix("light.\(prefix)_") ||
                $0.hasPrefix("switch.\(prefix)_") ||
                $0.hasPrefix("number.\(prefix)_") ||
                $0.hasPrefix("image.\(prefix)_")
            }

            // Try to get a friendly name from one of the entities
            var friendlyName = prefix.replacingOccurrences(of: "_", with: " ").capitalized
            if let firstEntity = entityMap["sensor.\(prefix)_print_status"],
               let attrs = firstEntity["attributes"] as? [String: Any],
               let name = attrs["friendly_name"] as? String {
                // Extract printer name from "H2S Print status" -> "H2S"
                friendlyName = name.replacingOccurrences(of: " Print status", with: "")
                    .replacingOccurrences(of: " print status", with: "")
            }

            // Detect model from prefix
            let model = detectModel(from: prefix)

            printers.append(DiscoveredPrinter(
                prefix: prefix,
                name: friendlyName,
                model: model,
                entityCount: matchingEntities.count
            ))
        }

        // Step 4: Build AMS objects
        for prefix in amsPrefixes {
            // Find all tray entities for this prefix
            var trayEntities: [String] = []
            for i in 1...4 {
                let entityId = "sensor.\(prefix)_tray_\(i)"
                if entityMap[entityId] != nil {
                    trayEntities.append(entityId)
                }
            }

            // Find humidity entity
            var humidityEntity: String?
            for pattern in amsHumidityPatterns {
                let entityId = "sensor.\(prefix)_\(pattern)"
                if entityMap[entityId] != nil {
                    humidityEntity = entityId
                    break
                }
            }

            // Find temperature entity
            var temperatureEntity: String?
            for pattern in amsTemperaturePatterns {
                let entityId = "sensor.\(prefix)_\(pattern)"
                if entityMap[entityId] != nil {
                    temperatureEntity = entityId
                    break
                }
            }

            // Get friendly name
            var friendlyName = prefix.replacingOccurrences(of: "_", with: " ").uppercased()
            if let firstTray = trayEntities.first,
               let entity = entityMap[firstTray],
               let attrs = entity["attributes"] as? [String: Any],
               let name = attrs["friendly_name"] as? String {
                // Extract AMS name from "AMS 2 Pro Tray 1" -> "AMS 2 Pro"
                friendlyName = name.replacingOccurrences(of: " Tray 1", with: "")
                    .replacingOccurrences(of: " tray 1", with: "")
            }

            if !trayEntities.isEmpty {
                amsUnits.append(DiscoveredAMS(
                    prefix: prefix,
                    name: friendlyName,
                    trayCount: trayEntities.count,
                    trayEntities: trayEntities,
                    humidityEntity: humidityEntity,
                    temperatureEntity: temperatureEntity
                ))
            }
        }

        return (printers: printers.sorted { $0.entityCount > $1.entityCount },
                amsUnits: amsUnits.sorted { $0.trayCount > $1.trayCount })
    }

    /// Detect printer model from prefix
    private static func detectModel(from prefix: String) -> String? {
        let lower = prefix.lowercased()
        if lower.contains("x1c") || lower.contains("x1_c") || lower.contains("x1carbon") {
            return "X1 Carbon"
        } else if lower.contains("x1e") {
            return "X1E"
        } else if lower.contains("p1p") {
            return "P1P"
        } else if lower.contains("p1s") {
            return "P1S"
        } else if lower.contains("a1mini") || lower.contains("a1_mini") {
            return "A1 Mini"
        } else if lower.contains("a1") && !lower.contains("ams") {
            return "A1"
        } else if lower.contains("h2s") || lower.contains("h2d") {
            return "H2S/H2D"
        }
        return nil
    }
}

// MARK: - HAAPIService Extension for Discovery

extension HAAPIService {

    /// Fetch all entities and discover printers/AMS units
    func discoverAllDevices() async throws -> (printers: [DiscoveredPrinter], amsUnits: [DiscoveredAMS]) {
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

        return EntityDiscoveryService.discoverDevices(from: allEntities)
    }

    /// Fetch AMS tray data using discovered entity ID
    func fetchAMSTrayByEntityId(_ entityId: String) async throws -> AMSTrayData {
        let entity = try await fetchEntityWithAttributes(entityId)

        // Extract tray number from entity ID (e.g., "sensor.ams_2_pro_tray_1" -> 1)
        var trayNumber = 1
        if let range = entityId.range(of: "_tray_(\\d+)$", options: .regularExpression) {
            let numberPart = entityId[range].dropFirst(6) // Drop "_tray_"
            trayNumber = Int(numberPart) ?? 1
        }

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
    }
}
