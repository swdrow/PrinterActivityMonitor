import Foundation

/// Stored configuration for a discovered printer
struct PrinterConfiguration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var prefix: String              // Entity prefix (e.g., "h2s")
    var name: String                // User-friendly name
    var model: String?              // Detected model (e.g., "X1 Carbon")
    var isEnabled: Bool = true      // Whether to show this printer
    var isPrimary: Bool = false     // Primary printer for Live Activity

    // Associated AMS units (by their prefixes)
    var associatedAMSPrefixes: [String] = []
}

/// Stored configuration for a discovered AMS unit
struct AMSConfiguration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var prefix: String              // Entity prefix (e.g., "ams_2_pro")
    var name: String                // User-friendly name (e.g., "AMS 2 Pro")
    var trayCount: Int              // Number of trays (usually 4)
    var trayEntities: [String]      // Full entity IDs for trays
    var humidityEntity: String?     // Entity ID for humidity sensor
    var temperatureEntity: String?  // Entity ID for temperature sensor
    var isEnabled: Bool = true      // Whether to show this AMS

    // Associated printer prefix (if known)
    var associatedPrinterPrefix: String?
}

/// Complete device configuration for the app
struct DeviceSetupConfiguration: Codable, Equatable {
    var printers: [PrinterConfiguration] = []
    var amsUnits: [AMSConfiguration] = []
    var setupCompleted: Bool = false
    var lastDiscoveryDate: Date?

    /// Get the primary printer configuration
    var primaryPrinter: PrinterConfiguration? {
        printers.first { $0.isPrimary } ?? printers.first { $0.isEnabled }
    }

    /// Get enabled printers
    var enabledPrinters: [PrinterConfiguration] {
        printers.filter { $0.isEnabled }
    }

    /// Get enabled AMS units
    var enabledAMSUnits: [AMSConfiguration] {
        amsUnits.filter { $0.isEnabled }
    }

    /// Get AMS units for a specific printer
    func amsUnits(for printer: PrinterConfiguration) -> [AMSConfiguration] {
        amsUnits.filter { printer.associatedAMSPrefixes.contains($0.prefix) }
    }
}

/// Manager for device configuration persistence
@MainActor
class DeviceConfigurationManager: ObservableObject {
    @Published var configuration: DeviceSetupConfiguration = DeviceSetupConfiguration()
    @Published var isDiscovering: Bool = false
    @Published var discoveryError: String?

    private let configKey = "deviceConfiguration"

    /// Callback to notify when the primary printer changes
    var onPrimaryPrinterChanged: ((String) -> Void)?

    init() {
        loadConfiguration()
    }

    /// Get the entity prefix for the currently selected primary printer
    var selectedPrinterPrefix: String? {
        configuration.primaryPrinter?.prefix
    }

    /// Get the selected AMS configuration (first enabled AMS)
    var selectedAMSConfig: AMSConfiguration? {
        configuration.enabledAMSUnits.first
    }

    /// Load configuration from UserDefaults
    func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(DeviceSetupConfiguration.self, from: data) {
            configuration = config
        }
    }

    /// Save configuration to UserDefaults
    func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    /// Run auto-discovery and update configuration
    func runDiscovery(using haService: HAAPIService) async {
        isDiscovering = true
        discoveryError = nil

        do {
            let (printers, amsUnits) = try await haService.discoverAllDevices()

            // Convert discovered printers to configurations
            var printerConfigs: [PrinterConfiguration] = []
            for (index, printer) in printers.enumerated() {
                // Check if we already have this printer configured
                if let existing = configuration.printers.first(where: { $0.prefix == printer.prefix }) {
                    printerConfigs.append(existing)
                } else {
                    printerConfigs.append(PrinterConfiguration(
                        prefix: printer.prefix,
                        name: printer.name,
                        model: printer.model,
                        isEnabled: true,
                        isPrimary: index == 0  // First printer is primary by default
                    ))
                }
            }

            // Convert discovered AMS units to configurations
            var amsConfigs: [AMSConfiguration] = []
            for ams in amsUnits {
                // Check if we already have this AMS configured
                if let existing = configuration.amsUnits.first(where: { $0.prefix == ams.prefix }) {
                    amsConfigs.append(existing)
                } else {
                    amsConfigs.append(AMSConfiguration(
                        prefix: ams.prefix,
                        name: ams.name,
                        trayCount: ams.trayCount,
                        trayEntities: ams.trayEntities,
                        humidityEntity: ams.humidityEntity,
                        temperatureEntity: ams.temperatureEntity,
                        isEnabled: true
                    ))
                }
            }

            // Try to associate AMS units with printers (heuristic: same prefix base)
            for i in printerConfigs.indices {
                let printerPrefix = printerConfigs[i].prefix.lowercased()
                for ams in amsConfigs {
                    // Check if AMS might belong to this printer
                    // This is a heuristic - user can adjust later
                    if !printerConfigs[i].associatedAMSPrefixes.contains(ams.prefix) {
                        printerConfigs[i].associatedAMSPrefixes.append(ams.prefix)
                    }
                }
            }

            configuration.printers = printerConfigs
            configuration.amsUnits = amsConfigs
            configuration.lastDiscoveryDate = Date()

            saveConfiguration()

        } catch {
            discoveryError = error.localizedDescription
        }

        isDiscovering = false
    }

    /// Mark setup as completed
    func completeSetup() {
        configuration.setupCompleted = true
        saveConfiguration()
    }

    /// Reset configuration
    func resetConfiguration() {
        configuration = DeviceSetupConfiguration()
        saveConfiguration()
    }

    /// Toggle printer enabled state
    func togglePrinter(_ printer: PrinterConfiguration) {
        if let index = configuration.printers.firstIndex(where: { $0.id == printer.id }) {
            configuration.printers[index].isEnabled.toggle()
            saveConfiguration()
        }
    }

    /// Toggle AMS enabled state
    func toggleAMS(_ ams: AMSConfiguration) {
        if let index = configuration.amsUnits.firstIndex(where: { $0.id == ams.id }) {
            configuration.amsUnits[index].isEnabled.toggle()
            saveConfiguration()
        }
    }

    /// Set primary printer
    func setPrimaryPrinter(_ printer: PrinterConfiguration) {
        for i in configuration.printers.indices {
            configuration.printers[i].isPrimary = (configuration.printers[i].id == printer.id)
        }
        saveConfiguration()

        // Notify that the primary printer changed (for syncing entity prefix)
        onPrimaryPrinterChanged?(printer.prefix)
    }

    /// Update printer name
    func updatePrinterName(_ printer: PrinterConfiguration, name: String) {
        if let index = configuration.printers.firstIndex(where: { $0.id == printer.id }) {
            configuration.printers[index].name = name
            saveConfiguration()
        }
    }

    /// Update AMS name
    func updateAMSName(_ ams: AMSConfiguration, name: String) {
        if let index = configuration.amsUnits.firstIndex(where: { $0.id == ams.id }) {
            configuration.amsUnits[index].name = name
            saveConfiguration()
        }
    }
}
