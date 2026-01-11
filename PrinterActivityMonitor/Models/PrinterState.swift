import Foundation

/// Represents the current state of a 3D printer
struct PrinterState: Codable, Equatable {
    var progress: Int              // 0-100%
    var currentLayer: Int
    var totalLayers: Int
    var remainingMinutes: Int
    var status: PrintStatus
    var fileName: String
    var nozzleTemp: Double
    var bedTemp: Double
    var printSpeed: Int            // Percentage of normal speed
    var filamentUsed: Double       // grams

    enum PrintStatus: String, Codable {
        case idle = "idle"
        case running = "running"
        case paused = "pause"
        case finish = "finish"
        case failed = "failed"
        case prepare = "prepare"
        case unknown = "unknown"

        var displayName: String {
            switch self {
            case .idle: return "Idle"
            case .running: return "Printing"
            case .paused: return "Paused"
            case .finish: return "Finished"
            case .failed: return "Failed"
            case .prepare: return "Preparing"
            case .unknown: return "Unknown"
            }
        }

        var color: String {
            switch self {
            case .idle: return "gray"
            case .running: return "green"
            case .paused: return "orange"
            case .finish: return "blue"
            case .failed: return "red"
            case .prepare: return "yellow"
            case .unknown: return "gray"
            }
        }
    }

    var formattedTimeRemaining: String {
        let hours = remainingMinutes / 60
        let minutes = remainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var layerProgress: String {
        return "\(currentLayer)/\(totalLayers)"
    }

    static var placeholder: PrinterState {
        PrinterState(
            progress: 0,
            currentLayer: 0,
            totalLayers: 0,
            remainingMinutes: 0,
            status: .idle,
            fileName: "No print",
            nozzleTemp: 0,
            bedTemp: 0,
            printSpeed: 100,
            filamentUsed: 0
        )
    }
}

/// Response structure from Home Assistant REST API
struct HAStateResponse: Codable {
    let entityId: String
    let state: String
    let attributes: [String: AnyCodable]?
    let lastChanged: String?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }
}

/// Helper to decode arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        }
    }
}
