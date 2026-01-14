import Foundation

struct PrintJob: Codable, Identifiable, Hashable {
    let id: String
    let deviceId: String
    let printerPrefix: String?
    let filename: String
    let startedAt: Date?
    let completedAt: Date?
    let durationSeconds: Int?
    let status: PrintJobStatus?
    let finalLayer: Int?
    let totalLayers: Int?
    let filamentUsedMm: Double?

    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "--" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDate: String {
        guard let date = startedAt else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var layerInfo: String? {
        guard let total = totalLayers, total > 0 else { return nil }
        if let final = finalLayer {
            return "\(final)/\(total)"
        }
        return "\(total) layers"
    }
}

enum PrintJobStatus: String, Codable {
    case running
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .running: return "printer.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
}

struct PrintStats: Codable {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let totalPrintTimeSeconds: Int
    let successRate: Double

    var formattedTotalTime: String {
        let hours = totalPrintTimeSeconds / 3600
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        let minutes = (totalPrintTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedSuccessRate: String {
        return String(format: "%.0f%%", successRate * 100)
    }
}
