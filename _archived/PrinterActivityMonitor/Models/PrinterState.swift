import Foundation
import SwiftUI

/// Represents the current state of a 3D printer
struct PrinterState: Codable, Equatable {
    // Core print info
    var progress: Int              // 0-100%
    var currentLayer: Int
    var totalLayers: Int
    var remainingMinutes: Int
    var status: PrintStatus
    var fileName: String
    var printSpeed: Int            // Percentage of normal speed
    var filamentUsed: Double       // grams

    // Temperatures
    var nozzleTemp: Double
    var nozzleTargetTemp: Double
    var bedTemp: Double
    var bedTargetTemp: Double
    var chamberTemp: Double

    // Additional info
    var currentStage: String       // Current print stage
    var printWeight: Double        // Estimated weight in grams
    var printLength: Double        // Filament length in meters
    var bedType: String            // Plate type
    var startTime: Date?           // Print start time
    var endTime: Date?             // Estimated end time

    // Fans
    var auxFanSpeed: Int           // 0-100%
    var chamberFanSpeed: Int
    var coolingFanSpeed: Int

    // Status
    var isOnline: Bool
    var wifiSignal: Int            // dBm
    var hmsErrors: String          // Error messages

    // Images
    var coverImageURL: String?     // Gcode preview thumbnail URL

    // Printer info
    var printerModel: PrinterModel

    enum PrinterModel: String, Codable {
        case x1c = "X1 Carbon"
        case x1e = "X1E"
        case p1p = "P1P"
        case p1s = "P1S"
        case a1 = "A1"
        case a1mini = "A1 Mini"
        case h2s = "H2S"
        case h2d = "H2D"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .x1c, .x1e: return "cube.fill"
            case .p1p, .p1s: return "printer.fill"
            case .a1, .a1mini: return "printer.fill"
            case .h2s, .h2d: return "printer.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .x1c: return .orange
            case .x1e: return .purple
            case .p1p: return .blue
            case .p1s: return .cyan
            case .a1: return .green
            case .a1mini: return .mint
            case .h2s: return .teal
            case .h2d: return .indigo
            case .unknown: return .gray
            }
        }
    }

    enum PrintStatus: String, Codable {
        case idle = "idle"
        case running = "running"
        case paused = "pause"
        case finish = "finish"
        case failed = "failed"
        case prepare = "prepare"
        case slicing = "slicing"
        case unknown = "unknown"

        var displayName: String {
            switch self {
            case .idle: return "Idle"
            case .running: return "Printing"
            case .paused: return "Paused"
            case .finish: return "Finished"
            case .failed: return "Failed"
            case .prepare: return "Preparing"
            case .slicing: return "Slicing"
            case .unknown: return "Unknown"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .gray
            case .running: return .green
            case .paused: return .orange
            case .finish: return .blue
            case .failed: return .red
            case .prepare: return .yellow
            case .slicing: return .purple
            case .unknown: return .gray
            }
        }

        var icon: String {
            switch self {
            case .idle: return "moon.zzz.fill"
            case .running: return "play.circle.fill"
            case .paused: return "pause.circle.fill"
            case .finish: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .prepare: return "arrow.triangle.2.circlepath"
            case .slicing: return "scissors"
            case .unknown: return "questionmark.circle.fill"
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

    var formattedNozzleTemp: String {
        if nozzleTargetTemp > 0 {
            return "\(Int(nozzleTemp))°/\(Int(nozzleTargetTemp))°"
        }
        return "\(Int(nozzleTemp))°C"
    }

    var formattedBedTemp: String {
        if bedTargetTemp > 0 {
            return "\(Int(bedTemp))°/\(Int(bedTargetTemp))°"
        }
        return "\(Int(bedTemp))°C"
    }

    var formattedChamberTemp: String {
        return "\(Int(chamberTemp))°C"
    }

    static var placeholder: PrinterState {
        PrinterState(
            progress: 0,
            currentLayer: 0,
            totalLayers: 0,
            remainingMinutes: 0,
            status: .idle,
            fileName: "No print",
            printSpeed: 100,
            filamentUsed: 0,
            nozzleTemp: 0,
            nozzleTargetTemp: 0,
            bedTemp: 0,
            bedTargetTemp: 0,
            chamberTemp: 0,
            currentStage: "",
            printWeight: 0,
            printLength: 0,
            bedType: "",
            startTime: nil,
            endTime: nil,
            auxFanSpeed: 0,
            chamberFanSpeed: 0,
            coolingFanSpeed: 0,
            isOnline: false,
            wifiSignal: 0,
            hmsErrors: "",
            coverImageURL: nil,
            printerModel: .unknown
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
