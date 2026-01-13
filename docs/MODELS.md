# Models Documentation

## Model Overview

| Model | File | Purpose | Codable |
|-------|------|---------|---------|
| **PrinterState** | PrinterState.swift | Core printer status data | Yes |
| **PrinterModel** | PrinterState.swift | Printer model enumeration | Yes |
| **PrintStatus** | PrinterState.swift | Print state enumeration | Yes |
| **AppSettings** | Settings.swift | App configuration | Yes |
| **NotificationSettings** | Settings.swift | Notification preferences | Yes |
| **AccentColorOption** | Settings.swift | UI accent colors | Yes |
| **PrinterActivityAttributes** | PrinterActivityAttributes.swift | ActivityKit schema | Yes |
| **PrinterConfiguration** | DeviceConfiguration.swift | Discovered printer config | Yes |
| **AMSConfiguration** | DeviceConfiguration.swift | Discovered AMS config | Yes |
| **DeviceSetupConfiguration** | DeviceConfiguration.swift | Complete device config | Yes |
| **AMSSlot** | AMSState.swift | Individual filament tray | No |
| **AMSState** | AMSState.swift | Complete AMS state | No |

---

## PrinterState

Core model representing a 3D printer's current state.

### Properties

**Core Print Information**
```swift
var progress: Int               // 0-100%
var currentLayer: Int           // Current layer number
var totalLayers: Int            // Total layers in print
var remainingMinutes: Int       // Estimated minutes remaining
var status: PrintStatus         // Current state enum
var fileName: String            // G-code filename
var printSpeed: Int             // Speed percentage
var filamentUsed: Double        // Grams consumed
```

**Temperature Monitoring**
```swift
var nozzleTemp: Double          // Current nozzle °C
var nozzleTargetTemp: Double    // Target nozzle °C
var bedTemp: Double             // Current bed °C
var bedTargetTemp: Double       // Target bed °C
var chamberTemp: Double         // Chamber °C
```

**Fan Speeds**
```swift
var auxFanSpeed: Int            // 0-100%
var chamberFanSpeed: Int        // 0-100%
var coolingFanSpeed: Int        // 0-100%
```

**Device Status**
```swift
var isOnline: Bool              // Network connected
var wifiSignal: Int             // Signal strength (dBm)
var printerModel: PrinterModel  // Device model
var coverImageURL: String?      // G-code thumbnail URL
```

### PrinterModel Enum

```swift
enum PrinterModel: String, Codable {
    case x1c = "X1 Carbon"
    case x1e = "X1E"
    case p1p = "P1P"
    case p1s = "P1S"
    case a1 = "A1"
    case a1mini = "A1 Mini"
    case unknown = "Unknown"

    var icon: String       // SF Symbol name
    var color: Color       // Associated color
}
```

### PrintStatus Enum

```swift
enum PrintStatus: String, Codable {
    case idle = "idle"
    case running = "running"
    case paused = "pause"
    case finish = "finish"
    case failed = "failed"
    case prepare = "prepare"
    case slicing = "slicing"
    case unknown = "unknown"

    var displayName: String
    var color: Color
    var icon: String
}
```

### Computed Properties

```swift
var formattedTimeRemaining: String  // "Xh Ym" format
var layerProgress: String           // "X/Y" format
var formattedNozzleTemp: String     // "X°/Y°" or "X°C"
var formattedBedTemp: String        // "X°/Y°" or "X°C"
```

---

## Settings

### AppSettings

```swift
struct AppSettings: Codable, Equatable {
    // Home Assistant Connection
    var haServerURL: String         // Base URL
    var haAccessToken: String       // Long-lived token
    var entityPrefix: String        // Sensor prefix (default: "h2s")
    var refreshInterval: Int        // Polling seconds (default: 30)

    // UI Display Options
    var accentColor: AccentColorOption
    var showProgress: Bool
    var showLayers: Bool
    var showTimeRemaining: Bool
    var showNozzleTemp: Bool
    var showBedTemp: Bool
    var showPrintSpeed: Bool
    var showFilamentUsed: Bool
    var compactMode: Bool           // Condensed Live Activity

    // Notifications
    var notificationSettings: NotificationSettings

    // Computed
    var isConfigured: Bool          // URL and token set
}
```

### NotificationSettings

```swift
struct NotificationSettings: Codable, Equatable {
    var enabled: Bool
    var notifyOnPrintStart: Bool
    var notifyOnPrintComplete: Bool
    var notifyOnPrintFailed: Bool
    var notifyOnPrintPaused: Bool
    var notifyOnLayerMilestones: Bool
    var layerMilestoneInterval: Int   // 25%, 50%, etc.
    var notifyOnTempAlerts: Bool
    var criticalAlertsEnabled: Bool   // Bypass DND
}
```

### AccentColorOption

```swift
enum AccentColorOption: String, Codable, CaseIterable {
    case cyan, blue, purple, pink, orange, green, rainbow

    var color: Color
    var displayName: String
}
```

### SettingsManager

```swift
@MainActor
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings {
        didSet { save() }  // Auto-save
    }

    private let userDefaultsKey = "PrinterMonitorSettings"

    init()           // Loads from UserDefaults
    func reset()     // Resets to defaults
}
```

---

## PrinterActivityAttributes

ActivityKit schema for Live Activities.

```swift
struct PrinterActivityAttributes: ActivityAttributes {
    // Static - set once at activity start
    var fileName: String
    var startTime: Date
    var printerModel: String
    var showLayers: Bool
    var showNozzleTemp: Bool
    var showBedTemp: Bool
    var accentColorName: String
    var compactMode: Bool

    // Dynamic - updated every poll
    public struct ContentState: Codable, Hashable {
        var progress: Int
        var currentLayer: Int
        var totalLayers: Int
        var remainingMinutes: Int
        var status: String
        var nozzleTemp: Double
        var bedTemp: Double
        var chamberTemp: Double
        var nozzleTargetTemp: Double
        var bedTargetTemp: Double
        var currentStage: String
        var coverImageURL: String?

        // Computed
        var formattedTimeRemaining: String
        var layerProgress: String
        var isActive: Bool
    }
}
```

---

## DeviceConfiguration

### PrinterConfiguration

```swift
struct PrinterConfiguration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var prefix: String              // Entity prefix
    var name: String                // User-friendly name
    var model: String?              // Detected model
    var isEnabled: Bool = true      // Visibility toggle
    var isPrimary: Bool = false     // Primary for Live Activity
    var associatedAMSPrefixes: [String] = []
}
```

### AMSConfiguration

```swift
struct AMSConfiguration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var prefix: String              // Entity prefix
    var name: String                // User-friendly name
    var trayCount: Int              // Number of trays (1-4)
    var trayEntities: [String]      // Full entity IDs
    var humidityEntity: String?
    var temperatureEntity: String?
    var isEnabled: Bool = true
    var associatedPrinterPrefix: String?
}
```

### DeviceSetupConfiguration

```swift
struct DeviceSetupConfiguration: Codable, Equatable {
    var printers: [PrinterConfiguration] = []
    var amsUnits: [AMSConfiguration] = []
    var setupCompleted: Bool = false
    var lastDiscoveryDate: Date?

    var primaryPrinter: PrinterConfiguration?
    var enabledPrinters: [PrinterConfiguration]
    var enabledAMSUnits: [AMSConfiguration]
    func amsUnits(for printer: PrinterConfiguration) -> [AMSConfiguration]
}
```

### DeviceConfigurationManager

```swift
@MainActor
class DeviceConfigurationManager: ObservableObject {
    @Published var configuration: DeviceSetupConfiguration
    @Published var isDiscovering: Bool
    @Published var discoveryError: String?

    func loadConfiguration()
    func saveConfiguration()
    func runDiscovery(using haService: HAAPIService) async
    func togglePrinter(_ printer: PrinterConfiguration)
    func toggleAMS(_ ams: AMSConfiguration)
    func setPrimaryPrinter(_ printer: PrinterConfiguration)
    func completeSetup()
    func resetConfiguration()
}
```

---

## AMSState

### AMSSlot

```swift
struct AMSSlot: Identifiable, Equatable {
    let id: Int                     // Tray index 0-3
    var isActive: Bool              // Currently in use
    var color: Color                // Filament color
    var colorHex: String            // Hex code
    var materialType: String        // "PLA", "PETG", etc.
    var remaining: Double           // 0.0 to 1.0
    var nozzleTempMin: Int
    var nozzleTempMax: Int
    var isEmpty: Bool

    var displayName: String         // "Slot 1", etc.
    var remainingPercent: String    // "85%"
    var tempRange: String           // "190-220°C"

    static func empty(index: Int) -> AMSSlot
}
```

### AMSState

```swift
struct AMSState: Equatable {
    var slots: [AMSSlot]            // 4 tray slots
    var humidity: Int               // 0-100%
    var isDrying: Bool
    var dryingRemainingTime: Int    // Minutes
    var isConnected: Bool

    var humidityLevel: HumidityLevel
    var activeSlot: AMSSlot?
    var lowFilamentSlots: [AMSSlot] // < 20%

    static var placeholder: AMSState
    static var mockData: AMSState
}
```

### HumidityLevel

```swift
enum HumidityLevel {
    case low        // 0-30% (green)
    case moderate   // 30-60% (yellow)
    case high       // 60%+ (red)

    var color: Color
    var displayName: String
    var icon: String
}
```

---

## Model Relationships

```
AppSettings (Configuration)
    ├── AccentColorOption
    ├── NotificationSettings
    └── (persisted via SettingsManager)

PrinterState (Current Status)
    ├── PrintStatus (enum)
    ├── PrinterModel (enum)
    └── (fetched from Home Assistant)

PrinterActivityAttributes (Live Activity)
    ├── ContentState (dynamic updates)
    └── Display configuration

DeviceSetupConfiguration (Device Registry)
    ├── PrinterConfiguration[]
    │   └── associatedAMSPrefixes → AMSConfiguration
    ├── AMSConfiguration[]
    └── (persisted via DeviceConfigurationManager)

AMSState (Filament System)
    ├── AMSSlot[] (4 trays)
    └── HumidityLevel (enum)
```

---

## Serialization Summary

| Model | Codable | Persistence | Storage |
|-------|---------|-------------|---------|
| PrinterState | ✓ | No (transient) | In-memory |
| AppSettings | ✓ | UserDefaults | JSON |
| PrinterActivityAttributes | ✓ | ActivityKit | Activity payload |
| PrinterConfiguration | ✓ | UserDefaults | JSON |
| AMSConfiguration | ✓ | UserDefaults | JSON |
| AMSSlot | ✗ | No (transient) | Computed |
| AMSState | ✗ | No (transient) | In-memory |
