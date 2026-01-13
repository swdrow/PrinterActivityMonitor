import Foundation
import SwiftUI

/// Represents a single AMS filament slot
struct AMSSlot: Identifiable, Equatable {
    let id: Int                    // Slot index (0-3)
    var isActive: Bool             // Currently being used
    var color: Color               // Filament color
    var colorHex: String           // Hex code for display
    var materialType: String       // PLA, PETG, ABS, TPU, etc.
    var remaining: Double          // 0.0 to 1.0 (percentage remaining)
    var nozzleTempMin: Int         // Minimum recommended nozzle temp
    var nozzleTempMax: Int         // Maximum recommended nozzle temp
    var isEmpty: Bool              // No filament loaded
    var hasValidRFIDData: Bool     // True if remaining data is from RFID (Bambu Lab filament)

    /// Display name for the slot
    var displayName: String {
        "Slot \(id + 1)"
    }

    /// Formatted remaining percentage
    var remainingPercent: String {
        "\(Int(remaining * 100))%"
    }

    /// Temperature range string
    var tempRange: String {
        "\(nozzleTempMin)-\(nozzleTempMax)°C"
    }

    /// Placeholder for empty/unknown slot
    static func empty(index: Int) -> AMSSlot {
        AMSSlot(
            id: index,
            isActive: false,
            color: .gray,
            colorHex: "#808080",
            materialType: "Empty",
            remaining: 0,
            nozzleTempMin: 0,
            nozzleTempMax: 0,
            isEmpty: true,
            hasValidRFIDData: false
        )
    }
}

/// Represents the entire AMS unit state
struct AMSState: Equatable {
    var slots: [AMSSlot]
    var humidity: Int              // Current humidity percentage
    var temperature: Int           // Current AMS temperature in Celsius
    var isDrying: Bool             // Drying mode active
    var dryingRemainingTime: Int   // Minutes remaining for drying
    var dryingTargetTemp: Int      // Target drying temperature
    var isConnected: Bool          // AMS unit detected

    /// Humidity level indicator
    var humidityLevel: HumidityLevel {
        switch humidity {
        case 0..<30: return .low
        case 30..<60: return .moderate
        default: return .high
        }
    }

    enum HumidityLevel {
        case low, moderate, high

        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .red
            }
        }

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            }
        }

        var icon: String {
            switch self {
            case .low: return "checkmark.circle.fill"
            case .moderate: return "exclamationmark.triangle.fill"
            case .high: return "xmark.octagon.fill"
            }
        }
    }

    /// Currently active slot (if any)
    var activeSlot: AMSSlot? {
        slots.first { $0.isActive }
    }

    /// Slots with low filament (< 20%) - only for slots with valid RFID data
    var lowFilamentSlots: [AMSSlot] {
        slots.filter { !$0.isEmpty && $0.hasValidRFIDData && $0.remaining < 0.2 }
    }

    /// Default/placeholder state
    static var placeholder: AMSState {
        AMSState(
            slots: (0..<4).map { AMSSlot.empty(index: $0) },
            humidity: 0,
            temperature: 0,
            isDrying: false,
            dryingRemainingTime: 0,
            dryingTargetTemp: 0,
            isConnected: false
        )
    }

    /// Mock data for previews/testing
    static var mockData: AMSState {
        AMSState(
            slots: [
                AMSSlot(
                    id: 0,
                    isActive: true,
                    color: Color(hex: "FFFFFF") ?? .white,
                    colorHex: "#FFFFFF",
                    materialType: "PLA",
                    remaining: 0.85,
                    nozzleTempMin: 190,
                    nozzleTempMax: 220,
                    isEmpty: false,
                    hasValidRFIDData: true  // Bambu Lab filament with RFID
                ),
                AMSSlot(
                    id: 1,
                    isActive: false,
                    color: Color(hex: "FF0000") ?? .red,
                    colorHex: "#FF0000",
                    materialType: "PETG",
                    remaining: 0.42,
                    nozzleTempMin: 220,
                    nozzleTempMax: 260,
                    isEmpty: false,
                    hasValidRFIDData: true  // Bambu Lab filament with RFID
                ),
                AMSSlot(
                    id: 2,
                    isActive: false,
                    color: Color(hex: "000000") ?? .black,
                    colorHex: "#000000",
                    materialType: "ABS",
                    remaining: 0,
                    nozzleTempMin: 240,
                    nozzleTempMax: 270,
                    isEmpty: false,
                    hasValidRFIDData: false  // Third-party filament, no RFID
                ),
                AMSSlot.empty(index: 3)
            ],
            humidity: 45,
            temperature: 28,
            isDrying: false,
            dryingRemainingTime: 0,
            dryingTargetTemp: 0,
            isConnected: true
        )
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r, g, b: Double

        switch hexSanitized.count {
        case 8:
            // 8-digit format: RRGGBBAA (Bambu Lab format - ignore alpha at end)
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            // Alpha (rgb & 0x000000FF) is ignored

        case 6:
            // Standard 6-digit format: RRGGBB
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0

        case 3:
            // Short 3-digit format: RGB -> RRGGBB
            r = Double((rgb & 0xF00) >> 8) / 15.0
            g = Double((rgb & 0x0F0) >> 4) / 15.0
            b = Double(rgb & 0x00F) / 15.0

        default:
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Print History Entry

/// Represents a completed print in history
struct PrintHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var startDate: Date
    var endDate: Date
    var status: PrintResult
    var progress: Int                  // Final progress percentage
    var totalLayers: Int
    var printDuration: TimeInterval    // Actual print time in seconds
    var estimatedDuration: TimeInterval // Originally estimated time
    var filamentUsed: Double           // Grams
    var thumbnailData: Data?           // Cached thumbnail image

    enum PrintResult: String, Codable {
        case success = "success"
        case failed = "failed"
        case cancelled = "cancelled"

        var displayName: String {
            switch self {
            case .success: return "Completed"
            case .failed: return "Failed"
            case .cancelled: return "Cancelled"
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .cancelled: return "stop.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .failed: return .red
            case .cancelled: return .orange
            }
        }
    }

    /// Formatted print duration
    var formattedDuration: String {
        let hours = Int(printDuration) / 3600
        let minutes = (Int(printDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatted start date
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    /// Relative date string (e.g., "2 days ago")
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: Date())
    }

    /// Accuracy percentage (actual vs estimated)
    var accuracy: Double {
        guard estimatedDuration > 0 else { return 0 }
        return min(1.0, printDuration / estimatedDuration)
    }
}

// MARK: - Print Statistics

/// Aggregated print statistics
struct PrintStatistics {
    var totalPrints: Int
    var successfulPrints: Int
    var failedPrints: Int
    var cancelledPrints: Int
    var totalPrintTime: TimeInterval      // Seconds
    var totalFilamentUsed: Double         // Grams
    var averagePrintTime: TimeInterval
    var successRate: Double               // 0.0 to 1.0

    /// Formatted total print time
    var formattedTotalTime: String {
        let hours = Int(totalPrintTime) / 3600
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else {
            return "\(hours)h"
        }
    }

    /// Formatted filament used
    var formattedFilament: String {
        if totalFilamentUsed >= 1000 {
            return String(format: "%.1f kg", totalFilamentUsed / 1000)
        } else {
            return String(format: "%.0f g", totalFilamentUsed)
        }
    }

    /// Default empty statistics
    static var empty: PrintStatistics {
        PrintStatistics(
            totalPrints: 0,
            successfulPrints: 0,
            failedPrints: 0,
            cancelledPrints: 0,
            totalPrintTime: 0,
            totalFilamentUsed: 0,
            averagePrintTime: 0,
            successRate: 0
        )
    }

    /// Calculate from history entries
    static func calculate(from entries: [PrintHistoryEntry]) -> PrintStatistics {
        guard !entries.isEmpty else { return .empty }

        let successful = entries.filter { $0.status == .success }.count
        let failed = entries.filter { $0.status == .failed }.count
        let cancelled = entries.filter { $0.status == .cancelled }.count
        let totalTime = entries.reduce(0) { $0 + $1.printDuration }
        let totalFilament = entries.reduce(0) { $0 + $1.filamentUsed }

        return PrintStatistics(
            totalPrints: entries.count,
            successfulPrints: successful,
            failedPrints: failed,
            cancelledPrints: cancelled,
            totalPrintTime: totalTime,
            totalFilamentUsed: totalFilament,
            averagePrintTime: totalTime / Double(entries.count),
            successRate: Double(successful) / Double(entries.count)
        )
    }
}
