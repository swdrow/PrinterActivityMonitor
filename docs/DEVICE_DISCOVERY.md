# Device Auto-Discovery System Documentation

## Problem Statement

### The Challenge

In the original architecture, users had to manually specify a single entity prefix. This had critical limitations:

1. **Separate Prefixes**: Printers (`h2s`) and AMS units (`ams_2_pro`) use different prefixes
2. **Multiple Devices**: Tedious manual setup for multiple printers/AMS
3. **Discovery Barrier**: Users unfamiliar with HA entity naming
4. **No Correlation**: No automatic AMS-to-printer association

### Solution

**Work backwards from known entity suffixes** to auto-discover all devices.

---

## Discovery Algorithm

### Step 1: Fetch All Entities

```
GET /api/states
```

Returns array of 1000+ entity objects.

### Step 2: Find Printers by Sensor Suffixes

**Known Suffixes**:
```
print_progress, print_status, current_layer,
total_layer_count, remaining_time, subtask_name,
nozzle_temperature, bed_temperature, current_stage
```

**Algorithm**:
```
FOR each sensor entity:
    IF entity_id ends with known suffix:
        Extract prefix
        Add to printerPrefixes set
```

**Example**:
- `sensor.h2s_print_progress` → prefix: `h2s`

### Step 3: Find AMS by Tray Patterns

**Pattern**: `_tray_\d+$`

**Algorithm**:
```
FOR each sensor entity:
    IF entity_id matches tray pattern:
        Extract prefix up to "_tray_"
        Add to amsPrefixes set
```

**Example**:
- `sensor.ams_2_pro_tray_1` → prefix: `ams_2_pro`

### Step 4: Build Device Objects

For each prefix:
1. Count matching entities across all domains
2. Extract friendly names from attributes
3. Detect printer model from prefix patterns
4. Find optional sensors (humidity, temperature)

---

## Known Entity Patterns

### Printer Sensor Suffixes

| Suffix | Purpose |
|--------|---------|
| `print_progress` | Current percentage |
| `print_status` | Print state |
| `current_layer` | Layer number |
| `nozzle_temperature` | Nozzle temp |
| `bed_temperature` | Bed temp |

### AMS Patterns

**Trays**:
```
sensor.{prefix}_tray_1
sensor.{prefix}_tray_2
sensor.{prefix}_tray_3
sensor.{prefix}_tray_4
```

**Environmental**:
```
sensor.{prefix}_humidity
sensor.{prefix}_temperature
```

### Model Detection

| Prefix Contains | Model |
|-----------------|-------|
| x1c, x1carbon | X1 Carbon |
| x1e | X1E |
| p1p | P1P |
| p1s | P1S |
| a1mini | A1 Mini |
| a1 (not ams) | A1 |

---

## Data Structures

### DiscoveredPrinter (Transient)

```swift
struct DiscoveredPrinter: Identifiable {
    let prefix: String      // "h2s"
    let name: String        // "H2S"
    let model: String?      // "X1 Carbon"
    var entityCount: Int    // 35
}
```

### DiscoveredAMS (Transient)

```swift
struct DiscoveredAMS: Identifiable {
    let prefix: String              // "ams_2_pro"
    let name: String                // "AMS 2 Pro"
    let trayCount: Int              // 4
    var trayEntities: [String]      // Full entity IDs
    var humidityEntity: String?
    var temperatureEntity: String?
}
```

### PrinterConfiguration (Persistent)

```swift
struct PrinterConfiguration: Codable, Identifiable {
    var id: UUID
    var prefix: String
    var name: String
    var model: String?
    var isEnabled: Bool = true
    var isPrimary: Bool = false
    var associatedAMSPrefixes: [String] = []
}
```

### AMSConfiguration (Persistent)

```swift
struct AMSConfiguration: Codable, Identifiable {
    var id: UUID
    var prefix: String
    var name: String
    var trayCount: Int
    var trayEntities: [String]
    var humidityEntity: String?
    var temperatureEntity: String?
    var isEnabled: Bool = true
    var associatedPrinterPrefix: String?
}
```

### DeviceSetupConfiguration

```swift
struct DeviceSetupConfiguration: Codable {
    var printers: [PrinterConfiguration] = []
    var amsUnits: [AMSConfiguration] = []
    var setupCompleted: Bool = false
    var lastDiscoveryDate: Date?

    var primaryPrinter: PrinterConfiguration?
    var enabledPrinters: [PrinterConfiguration]
    var enabledAMSUnits: [AMSConfiguration]
}
```

---

## Onboarding Flow

### Step 1: Welcome

- Large printer icon
- "Auto-Discover Devices" title
- Warning if HA not configured
- "Start Discovery" button

### Step 2: Discovering

- Progress spinner
- "Scanning Home Assistant..."
- Error display with Retry

### Step 3: Select Devices

- Printer list with toggles
- AMS list with toggles
- "Set Primary" button
- Re-scan button
- Continue button

### Step 4: Complete

- Green checkmark
- Summary of enabled devices
- "Get Started" button

---

## Persistence

### Storage

**Key**: `"deviceConfiguration"` in UserDefaults
**Format**: JSON (Codable)

### Loading

```swift
func loadConfiguration() {
    if let data = UserDefaults.standard.data(forKey: configKey),
       let config = try? JSONDecoder().decode(...) {
        configuration = config
    }
}
```

### Saving

```swift
func saveConfiguration() {
    if let data = try? JSONEncoder().encode(configuration) {
        UserDefaults.standard.set(data, forKey: configKey)
    }
}
```

**Triggers**: Toggle, setPrimary, complete, discovery

---

## Usage in App

### AMSView Example

```swift
guard let amsConfig = deviceConfig.configuration.enabledAMSUnits.first else {
    await fetchAMSStateFallback()
    return
}

for entityId in amsConfig.trayEntities {
    let trayData = try await haService.fetchAMSTrayByEntityId(entityId)
    slots.append(trayData.toAMSSlot())
}
```

### App Initialization

```swift
.onAppear {
    if !deviceConfig.configuration.setupCompleted &&
       settingsManager.settings.isConfigured {
        showDeviceSetup = true
    }
}
```

---

## Edge Cases

### No Devices Found

- Show empty list message
- Prompt to re-scan or check HA

### Multiple Printers

- First printer is primary by default
- User can change via "Set Primary"
- All enabled by default

### Multiple AMS Units

- All associated with all printers (heuristic)
- User can toggle each
- AMSView uses first enabled

### Re-discovery

- Existing configs preserved by prefix
- New devices added
- Removed devices deleted

---

## Future Improvements

1. **Re-discovery Diff**: Show added/removed devices
2. **Manual Prefix Entry**: Fallback for edge cases
3. **Explicit AMS Association**: Drag/drop to assign
4. **Sensor Validation**: Confidence scoring
5. **Model Detection Fallback**: Query HA attributes
6. **Discovery Caching**: Avoid re-query on launch

---

## Implementation Files

- `EntityDiscoveryService.swift` - Core discovery logic
- `DeviceConfiguration.swift` - Data models + manager
- `DeviceSetupView.swift` - Onboarding UI
- `PrinterActivityMonitorApp.swift` - Injection + trigger
- `AMSView.swift` - Usage example

---

## Summary

The auto-discovery system solves the "multiple prefix problem" by:

1. Querying all HA entities
2. Pattern matching known suffixes
3. Extracting device prefixes
4. Persisting user selections
5. Enabling flexible multi-device support
