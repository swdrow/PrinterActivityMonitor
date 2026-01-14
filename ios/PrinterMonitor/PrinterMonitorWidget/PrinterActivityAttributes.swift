import ActivityKit
import Foundation

struct PrinterActivityAttributes: ActivityAttributes {
    // Static data - set when activity starts, never changes
    let filename: String
    let startTime: Date
    let printerName: String
    let printerModel: String
    let entityPrefix: String

    struct ContentState: Codable, Hashable {
        // Dynamic data - updated via push
        let progress: Int           // 0-100
        let currentLayer: Int
        let totalLayers: Int
        let remainingSeconds: Int
        let status: String          // running, paused, failed, complete
        let nozzleTemp: Int
        let bedTemp: Int

        // Computed helpers
        var formattedTimeRemaining: String {
            let hours = remainingSeconds / 3600
            let minutes = (remainingSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        var estimatedCompletion: Date {
            Date().addingTimeInterval(TimeInterval(remainingSeconds))
        }

        var layerProgress: String {
            "\(currentLayer)/\(totalLayers)"
        }
    }
}
