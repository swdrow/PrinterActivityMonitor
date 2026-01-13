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

    // Notification settings
    var notificationSettings: NotificationSettings

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
            compactMode: false,
            notificationSettings: .default
        )
    }

    // Custom decoder for backwards compatibility with old saved settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        haServerURL = try container.decode(String.self, forKey: .haServerURL)
        haAccessToken = try container.decode(String.self, forKey: .haAccessToken)
        entityPrefix = try container.decode(String.self, forKey: .entityPrefix)
        refreshInterval = try container.decode(Int.self, forKey: .refreshInterval)
        accentColor = try container.decode(AccentColorOption.self, forKey: .accentColor)
        showProgress = try container.decode(Bool.self, forKey: .showProgress)
        showLayers = try container.decode(Bool.self, forKey: .showLayers)
        showTimeRemaining = try container.decode(Bool.self, forKey: .showTimeRemaining)
        showNozzleTemp = try container.decode(Bool.self, forKey: .showNozzleTemp)
        showBedTemp = try container.decode(Bool.self, forKey: .showBedTemp)
        showPrintSpeed = try container.decode(Bool.self, forKey: .showPrintSpeed)
        showFilamentUsed = try container.decode(Bool.self, forKey: .showFilamentUsed)

        // New fields with defaults for backwards compatibility
        compactMode = try container.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        notificationSettings = try container.decodeIfPresent(NotificationSettings.self, forKey: .notificationSettings) ?? .default
    }

    // Standard memberwise initializer
    init(
        haServerURL: String,
        haAccessToken: String,
        entityPrefix: String,
        refreshInterval: Int,
        accentColor: AccentColorOption,
        showProgress: Bool,
        showLayers: Bool,
        showTimeRemaining: Bool,
        showNozzleTemp: Bool,
        showBedTemp: Bool,
        showPrintSpeed: Bool,
        showFilamentUsed: Bool,
        compactMode: Bool,
        notificationSettings: NotificationSettings
    ) {
        self.haServerURL = haServerURL
        self.haAccessToken = haAccessToken
        self.entityPrefix = entityPrefix
        self.refreshInterval = refreshInterval
        self.accentColor = accentColor
        self.showProgress = showProgress
        self.showLayers = showLayers
        self.showTimeRemaining = showTimeRemaining
        self.showNozzleTemp = showNozzleTemp
        self.showBedTemp = showBedTemp
        self.showPrintSpeed = showPrintSpeed
        self.showFilamentUsed = showFilamentUsed
        self.compactMode = compactMode
        self.notificationSettings = notificationSettings
    }

    var isConfigured: Bool {
        !haServerURL.isEmpty && !haAccessToken.isEmpty
    }
}

/// Notification preferences
struct NotificationSettings: Codable, Equatable {
    var enabled: Bool
    var notifyOnPrintStart: Bool
    var notifyOnPrintComplete: Bool
    var notifyOnPrintFailed: Bool
    var notifyOnPrintPaused: Bool
    var notifyOnLayerMilestones: Bool
    var layerMilestoneInterval: Int       // e.g., every 25% (25, 50, 75, 100)
    var notifyOnTempAlerts: Bool
    var criticalAlertsEnabled: Bool       // bypass Do Not Disturb for failures

    static var `default`: NotificationSettings {
        NotificationSettings(
            enabled: true,
            notifyOnPrintStart: true,
            notifyOnPrintComplete: true,
            notifyOnPrintFailed: true,
            notifyOnPrintPaused: true,
            notifyOnLayerMilestones: false,
            layerMilestoneInterval: 25,
            notifyOnTempAlerts: false,
            criticalAlertsEnabled: false
        )
    }
}

enum AccentColorOption: String, Codable, CaseIterable {
    case cyan = "cyan"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case orange = "orange"
    case green = "green"
    case teal = "teal"
    case indigo = "indigo"
    case amber = "amber"
    case mint = "mint"
    case rainbow = "rainbow"

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .teal: return Color(red: 0, green: 0.79, blue: 0.65)           // Deep teal #00C9A7
        case .indigo: return Color(red: 0.39, green: 0.4, blue: 0.95)       // Electric indigo #6366F1
        case .amber: return Color(red: 0.96, green: 0.62, blue: 0.04)       // Warm amber #F59E0B
        case .mint: return Color(red: 0.2, green: 0.83, blue: 0.6)          // Fresh mint #34D399
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
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .amber: return "Amber"
        case .mint: return "Mint"
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
