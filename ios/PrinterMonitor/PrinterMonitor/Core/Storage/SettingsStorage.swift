import Foundation

/// Manages persistent storage of app settings
@MainActor
@Observable
final class SettingsStorage: Sendable {
    // MARK: - Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let haURL = "haURL"
        static let haToken = "haToken"
        static let selectedPrinterPrefix = "selectedPrinterPrefix"
        static let selectedPrinterName = "selectedPrinterName"
        static let isOnboardingComplete = "isOnboardingComplete"
        static let temperatureUnit = "temperatureUnit"
        static let use24HourTime = "use24HourTime"
    }

    // MARK: - Properties

    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Keys.serverURL) }
    }

    var haURL: String {
        didSet { defaults.set(haURL, forKey: Keys.haURL) }
    }

    var haToken: String {
        didSet {
            // Store token in Keychain in production
            // For now, use UserDefaults (not secure, but fine for dev)
            defaults.set(haToken, forKey: Keys.haToken)
        }
    }

    var selectedPrinterPrefix: String? {
        didSet { defaults.set(selectedPrinterPrefix, forKey: Keys.selectedPrinterPrefix) }
    }

    var selectedPrinterName: String? {
        didSet { defaults.set(selectedPrinterName, forKey: Keys.selectedPrinterName) }
    }

    var isOnboardingComplete: Bool {
        didSet { defaults.set(isOnboardingComplete, forKey: Keys.isOnboardingComplete) }
    }

    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    var use24HourTime: Bool {
        didSet { defaults.set(use24HourTime, forKey: Keys.use24HourTime) }
    }

    // MARK: - Private

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted values
        self.serverURL = defaults.string(forKey: Keys.serverURL) ?? ""
        self.haURL = defaults.string(forKey: Keys.haURL) ?? ""
        self.haToken = defaults.string(forKey: Keys.haToken) ?? ""
        self.selectedPrinterPrefix = defaults.string(forKey: Keys.selectedPrinterPrefix)
        self.selectedPrinterName = defaults.string(forKey: Keys.selectedPrinterName)
        self.isOnboardingComplete = defaults.bool(forKey: Keys.isOnboardingComplete)
        self.temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Keys.temperatureUnit) ?? "") ?? .celsius
        self.use24HourTime = defaults.bool(forKey: Keys.use24HourTime)
    }

    // MARK: - Methods

    func reset() {
        serverURL = ""
        haURL = ""
        haToken = ""
        selectedPrinterPrefix = nil
        selectedPrinterName = nil
        isOnboardingComplete = false
        temperatureUnit = .celsius
        use24HourTime = false
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !haURL.isEmpty && !haToken.isEmpty && selectedPrinterPrefix != nil
    }
}

// MARK: - Temperature Unit

enum TemperatureUnit: String, CaseIterable {
    case celsius = "C"
    case fahrenheit = "F"

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    func convert(_ celsius: Int) -> Int {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return Int(Double(celsius) * 9/5 + 32)
        }
    }
}
