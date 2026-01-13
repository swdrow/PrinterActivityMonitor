import ActivityKit
import Foundation

/// Defines the data structure for the Live Activity
struct PrinterActivityAttributes: ActivityAttributes {
    /// Dynamic content that updates during the Live Activity
    public struct ContentState: Codable, Hashable {
        var progress: Int              // 0-100%
        var currentLayer: Int
        var totalLayers: Int
        var remainingMinutes: Int
        var status: String             // "running", "paused", "idle", etc.
        var nozzleTemp: Double
        var bedTemp: Double
        var chamberTemp: Double        // Chamber temperature
        var nozzleTargetTemp: Double   // Target nozzle temp
        var bedTargetTemp: Double      // Target bed temp
        var currentStage: String       // Current print stage
        var coverImageURL: String?     // Gcode preview thumbnail

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

        var isActive: Bool {
            status == "running" || status == "pause" || status == "prepare"
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
    }

    /// Static content set when the Live Activity starts
    var fileName: String
    var startTime: Date
    var printerModel: String           // Printer model name

    /// Display configuration (stored at start)
    var showLayers: Bool
    var showNozzleTemp: Bool
    var showBedTemp: Bool
    var accentColorName: String
    var compactMode: Bool
}
