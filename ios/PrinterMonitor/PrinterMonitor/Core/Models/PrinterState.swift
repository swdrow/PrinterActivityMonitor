import Foundation

/// Represents the current state of a 3D printer
struct PrinterState: Codable, Equatable {
    // MARK: - Print Job Info

    let progress: Int              // 0-100
    let currentLayer: Int
    let totalLayers: Int
    let remainingSeconds: Int
    let filename: String?
    let status: PrintStatus

    // MARK: - Temperatures

    let nozzleTemp: Int
    let bedTemp: Int
    let chamberTemp: Int?

    // MARK: - Printer Info

    let printerName: String
    let printerModel: PrinterModel
    let isOnline: Bool

    // MARK: - Computed Properties

    var formattedTimeRemaining: String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var estimatedCompletion: Date {
        Date().addingTimeInterval(TimeInterval(remainingSeconds))
    }

    var formattedETA: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: estimatedCompletion)
    }

    var layerProgress: String {
        "\(currentLayer)/\(totalLayers)"
    }

    // MARK: - Static

    static let placeholder = PrinterState(
        progress: 0,
        currentLayer: 0,
        totalLayers: 0,
        remainingSeconds: 0,
        filename: nil,
        status: .idle,
        nozzleTemp: 0,
        bedTemp: 0,
        chamberTemp: nil,
        printerName: "Printer",
        printerModel: .unknown,
        isOnline: false
    )
}

// MARK: - Print Status

enum PrintStatus: String, Codable, CaseIterable {
    case idle
    case running
    case paused
    case completed = "complete"
    case failed
    case cancelled
    case preparing
    case unknown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Printing"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .preparing: return "Preparing"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "moon.zzz"
        case .running: return "printer.fill"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        case .preparing: return "gear"
        case .unknown: return "questionmark.circle"
        }
    }

    var isActive: Bool {
        self == .running || self == .paused || self == .preparing
    }
}

// MARK: - Printer Model

enum PrinterModel: String, Codable, CaseIterable {
    case x1Carbon = "X1 Carbon"
    case x1 = "X1"
    case p1s = "P1S"
    case p1p = "P1P"
    case a1 = "A1"
    case a1Mini = "A1 Mini"
    case h2s = "H2S"
    case h2d = "H2D"
    case unknown = "Unknown"

    var displayName: String { rawValue }
}
