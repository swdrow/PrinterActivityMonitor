import Foundation
import SwiftUI

/// App settings stored in UserDefaults
struct AppSettings: Codable, Equatable {
    var haServerURL: String
    var haAccessToken: String
    var entityPrefix: String              // e.g., "h2s" for sensor.h2s_print_progress
    var refreshInterval: Int              // seconds
    var accentColor: AccentColorOption

    // Display field toggles
    var showProgress: Bool
    var showLayers: Bool
    var showTimeRemaining: Bool
    var showNozzleTemp: Bool
    var showBedTemp: Bool
    var showPrintSpeed: Bool
    var showFilamentUsed: Bool

    // Compact mode for Live Activity
    var compactMode: Bool

    static var `default`: AppSettings {
        AppSettings(
            haServerURL: "",
            haAccessToken: "",
            entityPrefix: "h2s",
            refreshInterval: 30,
            accentColor: .cyan,
            showProgress: true,
            showLayers: true,
            showTimeRemaining: true,
            showNozzleTemp: true,
            showBedTemp: true,
            showPrintSpeed: false,
            showFilamentUsed: false,
            compactMode: false
        )
    }

    var isConfigured: Bool {
        !haServerURL.isEmpty && !haAccessToken.isEmpty
    }
}

enum AccentColorOption: String, Codable, CaseIterable {
    case cyan = "cyan"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case orange = "orange"
    case green = "green"
    case rainbow = "rainbow"

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .rainbow: return .cyan // Default for rainbow, shimmer handles animation
        }
    }

    var displayName: String {
        switch self {
        case .cyan: return "Cyan"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .orange: return "Orange"
        case .green: return "Green"
        case .rainbow: return "Rainbow Shimmer"
        }
    }
}

/// Observable object to manage settings persistence
@MainActor
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let userDefaultsKey = "PrinterMonitorSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func reset() {
        settings = .default
    }
}
