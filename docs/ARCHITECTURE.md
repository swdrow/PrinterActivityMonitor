# PrinterActivityMonitor Architecture Documentation

## 1. System Overview

**PrinterActivityMonitor** is an iOS 17+ application that provides real-time monitoring of Bambu Lab 3D printers through Home Assistant integration. The app displays printer status on the iPhone Lock Screen and Dynamic Island via iOS Live Activities.

### Key Technologies
- **SwiftUI** - Modern declarative UI framework
- **ActivityKit** - Live Activity display on Lock Screen and Dynamic Island
- **Combine** - Reactive state management via @Published
- **URLSession** - REST API communication with Home Assistant
- **UserNotifications** - Local push notifications
- **BackgroundTasks** - Background app refresh (requires paid Apple Developer Program)

### Target Platform
- iOS 17.0+
- iPhone (Lock Screen and Dynamic Island focus)

### Integration
- **Home Assistant** - Bambu Lab integration (REST API)
- Supports: X1 Carbon, X1E, P1P, P1S, A1, A1 Mini
- AMS (Automatic Material System) support

---

## 2. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      HOME ASSISTANT SERVER                      │
│  (Bambu Lab Integration - REST API endpoints)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP GET /api/states
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    HAAPIService                                 │
│  ├─ configure(with: AppSettings)                                │
│  ├─ fetchPrinterState() -> PrinterState                         │
│  ├─ fetchAMSTray(Int) -> AMSTrayData                            │
│  ├─ discoverAllDevices() -> (printers, amsUnits)                │
│  ├─ startPolling(interval: 30s)                                 │
│  └─ Service calls (pause, resume, stop, setTemp, etc.)          │
└────────────────────────┬────────────────────────────────────────┘
                         │ Concurrent async/await (~25 sensors)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DATA MODELS                                   │
│  ├─ PrinterState (45+ fields)                                   │
│  │  ├─ Core: progress, layers, remainingTime, status, fileName  │
│  │  ├─ Temps: nozzle, bed, chamber, targets                     │
│  │  ├─ Fans: auxFan, chamberFan, coolingFan                     │
│  │  └─ Status: isOnline, wifiSignal, printerModel               │
│  │                                                              │
│  ├─ PrinterActivityAttributes (LiveActivity schema)             │
│  │  ├─ Static: fileName, startTime, printerModel, settings      │
│  │  └─ Dynamic ContentState: progress, temps, status            │
│  │                                                              │
│  ├─ AppSettings (persisted to UserDefaults)                     │
│  │  ├─ HA Connection: baseURL, accessToken, entityPrefix        │
│  │  ├─ Display: UI toggles, accentColor                         │
│  │  └─ Notifications: NotificationSettings                      │
│  │                                                              │
│  └─ DeviceSetupConfiguration                                    │
│     ├─ PrinterConfiguration[] (enabled, primary, name)          │
│     └─ AMSConfiguration[] (trays, humidity, temperature)        │
└────┬─────────────────┬─────────────────┬────────────────────────┘
     │                 │                 │
     ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Activity     │  │ View Layers  │  │ Services     │
│ Manager      │  │              │  │              │
│              │  │ ├─Dashboard  │  │ ├─History    │
│ ├─startAtv   │  │ ├─Settings   │  │ ├─Notif Mgr  │
│ ├─updateAtv  │  │ ├─Controls   │  │ └─Discovery  │
│ └─endAtv     │  │ ├─AMS View   │  └──────────────┘
└──────────────┘  │ └─Debug      │
     │            └──────────────┘
     ▼
┌─────────────────────────────────────────┐
│     iOS LOCK SCREEN / DYNAMIC ISLAND    │
│  (Live Activity Display)                │
│  ├─ Minimal view (Dynamic Island)       │
│  ├─ Compact view (Dynamic Island)       │
│  └─ Expanded view (Lock Screen full)    │
└─────────────────────────────────────────┘
```

---

## 3. Dependency Injection Pattern

The app uses SwiftUI's `@StateObject` and `@EnvironmentObject` for dependency injection:

### App Root (`PrinterActivityMonitorApp`)

```swift
@StateObject instances (lifecycle managed by SwiftUI):
├─ SettingsManager (@Published settings)
├─ HAAPIService (@Published printerState, isConnected, lastError)
├─ ActivityManager (@Published isActivityActive)
├─ NotificationManager (@Published isAuthorized)
├─ PrintHistoryService (@Published history, statistics)
└─ DeviceConfigurationManager (@Published configuration)
   │
   └─ Injected via .environmentObject() ─────────┐
                                                 │
ContentView ◄────────────────────────────────────┘
├─ @EnvironmentObject var settingsManager
├─ @EnvironmentObject var haService
├─ @EnvironmentObject var historyService
│
├─ Tab: PrinterDashboardView
├─ Tab: PrintControlView
├─ Tab: AMSView
├─ Tab: PrintHistoryView
├─ Tab: SettingsView
└─ Tab: DebugView (DEBUG only)
```

---

## 4. Service Layer

### HAAPIService
**Responsibility**: Communicate with Home Assistant REST API

**Key Methods**:
- `configure(with: AppSettings)` - Set URL, token, prefix
- `fetchPrinterState() -> PrinterState` - Concurrent fetch of ~25 sensors
- `discoverAllDevices() -> (printers, ams)` - Auto-discovery
- `pausePrint()`, `resumePrint()`, `stopPrint()` - Control methods
- `setNozzleTemp()`, `setBedTemp()` - Temperature control

**Polling**: Timer-based at configurable interval (default 30s)

### ActivityManager
**Responsibility**: Manage iOS Live Activity lifecycle

**Key Methods**:
- `startActivity(fileName:, initialState:, settings:)`
- `updateActivity(with state:)`
- `endActivity(dismissalPolicy:)`

**Auto-end**: When status = finish|failed|idle

### EntityDiscoveryService
**Responsibility**: Auto-discover printers and AMS units

**Algorithm**:
1. Fetch all entities from `/api/states`
2. Find printers by known sensor suffixes
3. Find AMS units by tray patterns
4. Extract prefixes and build device objects

### NotificationManager
**Responsibility**: Local notifications for print events

**Categories**: Print status, completion, failure, milestones

### PrintHistoryService
**Responsibility**: Persist and analyze print history

**Storage**: JSON file in Documents directory

### DeviceConfigurationManager
**Responsibility**: Store discovered device configuration

**Persistence**: UserDefaults with Codable encoding

---

## 5. State Management

### Polling Cycle Flow
```
Timer (30s) → HAAPIService.fetchAndUpdate()
           → Update @Published printerState
           → SwiftUI re-renders views
           → ActivityManager.updateActivity()
           → NotificationManager.handleStateUpdate()
```

### Key Observable Objects

| Service | Published Properties | Purpose |
|---------|---------------------|---------|
| HAAPIService | printerState, isConnected, lastError | Printer state sync |
| ActivityManager | isActivityActive | Live Activity status |
| SettingsManager | settings | App configuration |
| PrintHistoryService | history, statistics | Historical data |
| DeviceConfigurationManager | configuration | Device setup |

---

## 6. Background Processing

### BGTaskScheduler Integration

**Registration** (PrinterActivityMonitorApp.swift):
```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.samduncan.PrinterActivityMonitor.refresh",
    using: nil
) { task in
    handleAppRefresh(task: task as! BGAppRefreshTask)
}
```

### Limitations

| Aspect | Limitation |
|--------|-----------|
| Minimum Interval | 15 minutes (iOS enforced) |
| Free Apple ID | Background refresh disabled |
| Current Config | Foreground polling only (free tier) |
| Live Activity Updates | Work with free account (local) |

---

## 7. Live Activity Architecture

### Data Structure
```swift
struct PrinterActivityAttributes: ActivityAttributes {
    // Static - set once at activity start
    var fileName: String
    var startTime: Date
    var printerModel: String
    var showLayers, showNozzleTemp, showBedTemp: Bool
    var accentColorName: String
    var compactMode: Bool

    // Dynamic - updated every poll
    struct ContentState: Codable, Hashable {
        var progress: Int
        var currentLayer, totalLayers: Int
        var remainingMinutes: Int
        var status: String
        var nozzleTemp, bedTemp, chamberTemp: Double
        var currentStage: String
        var coverImageURL: String?
    }
}
```

### Update Flow
```
Polling (30s) → HAAPIService.fetchAndUpdate()
             → ActivityManager.updateActivity()
             → activity.update(activityContent)
             → Lock Screen refreshes
```

### Stale Date Management
- Set at start: now + 2 minutes
- Extended each refresh
- Activity grayed out if no update for 2 min

---

## 8. Auto-Discovery System

### Discovery Workflow
```
1. User taps "Start Discovery"
   └─ deviceConfig.runDiscovery(using: haService)

2. Fetch all entities
   └─ GET /api/states

3. Find printers by sensor suffixes
   └─ print_progress, nozzle_temperature, etc.

4. Find AMS by tray patterns
   └─ sensor.*_tray_1, sensor.*_tray_2, etc.

5. User selects devices
   └─ Enable/disable, set primary

6. Save configuration
   └─ UserDefaults persistence
```

### Known Patterns

**Printer Suffixes**:
- print_progress, print_status, current_layer
- nozzle_temperature, bed_temperature
- remaining_time, subtask_name

**AMS Patterns**:
- `_tray_1`, `_tray_2`, `_tray_3`, `_tray_4`
- `_humidity`, `_temperature`

---

## 9. Module Organization

```
PrinterActivityMonitor/
├── PrinterActivityMonitorApp.swift  # Entry point, DI setup
├── ContentView.swift                # Tab navigation
├── Models/
│   ├── PrinterState.swift           # Core printer data
│   ├── Settings.swift               # App configuration
│   ├── PrinterActivityAttributes.swift
│   ├── DeviceConfiguration.swift    # Discovery config
│   └── AMSState.swift               # Filament data
├── Services/
│   ├── HAAPIService.swift           # REST client (~760 lines)
│   ├── ActivityManager.swift        # Live Activity
│   ├── EntityDiscoveryService.swift # Auto-discovery
│   ├── NotificationManager.swift    # Local notifications
│   └── PrintHistoryService.swift    # History persistence
├── Views/
│   ├── PrinterDashboardView.swift   # Main status
│   ├── SettingsView.swift           # Configuration
│   ├── PrintControlView.swift       # Controls
│   ├── AMSView.swift                # Filament management
│   ├── PrintHistoryView.swift       # History
│   ├── DeviceSetupView.swift        # Onboarding
│   └── DebugView.swift              # Testing
├── Components/
│   ├── GlassCard.swift              # Glass morphism
│   ├── ProgressBar.swift            # Progress display
│   └── RainbowShimmer.swift         # Gradient animation
└── PreviewContent/                  # Mock data
```

---

## 10. Key Design Patterns

1. **Entity Prefix System**: Single configurable prefix for all sensors
2. **Concurrent Async/Await**: Parallel sensor fetches with async let
3. **Stale Date Management**: Activity freshness enforcement
4. **Configuration Persistence**: UserDefaults with Codable
5. **Service Discovery**: Pattern matching for device detection

---

## Summary

| Technology | Usage |
|-----------|-------|
| SwiftUI | UI layer, reactive views |
| Combine | Publisher/Subscriber pattern |
| ActivityKit | Lock Screen Live Activities |
| URLSession | REST API communication |
| Codable | JSON serialization |
| UserDefaults | Settings persistence |
| Timer | Polling mechanism |
| BGTaskScheduler | Background refresh (optional) |
