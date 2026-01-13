# Developer Guide

## Prerequisites

### Xcode Version
- **Required**: Xcode 15.0+
- **Recommended**: Xcode 16.2+

### iOS Deployment Target
- **iOS 17.0** minimum
- Live Activities require iOS 17.0+

### Apple Developer Account

| Account Type | Features |
|--------------|----------|
| Free Apple ID | 7-day signing, Live Activities work, NO background refresh |
| Paid ($99/yr) | Unlimited signing, background refresh, TestFlight |

### Home Assistant Setup
- Home Assistant 2023.12.0+
- ha-bambulab integration installed
- Long-lived access token
- Entity prefix configured (e.g., `h2s`)

---

## Project Setup

### Clone Repository

```bash
git clone <repository-url>
cd PrinterActivityMonitor
```

### Open in Xcode

```bash
open PrinterActivityMonitor.xcodeproj
```

### Bundle ID Configuration

Update in THREE locations:

1. **Xcode Build Settings** (both targets):
   ```
   PRODUCT_BUNDLE_IDENTIFIER = com.yourname.PrinterActivityMonitor
   ```

2. **PrinterActivityMonitorApp.swift** (lines 52, 78):
   ```swift
   "com.yourname.PrinterActivityMonitor.refresh"
   ```

3. **Info.plist** (BGTaskSchedulerPermittedIdentifiers):
   ```xml
   <string>com.yourname.PrinterActivityMonitor.refresh</string>
   ```

### Signing & Capabilities

1. Select Team: Xcode → Project → General → Team
2. Enable Background Modes (paid account only)
3. Automatic Code Signing: Build Settings → Automatic

---

## Project Structure

```
PrinterActivityMonitor/
├── PrinterActivityMonitorApp.swift    # Entry point
├── ContentView.swift                  # Tab navigation
├── Models/
│   ├── PrinterState.swift             # Core data
│   ├── Settings.swift                 # Configuration
│   ├── PrinterActivityAttributes.swift
│   ├── AMSState.swift
│   └── DeviceConfiguration.swift
├── Services/
│   ├── HAAPIService.swift             # REST client
│   ├── ActivityManager.swift          # Live Activity
│   ├── EntityDiscoveryService.swift   # Auto-discovery
│   ├── NotificationManager.swift
│   └── PrintHistoryService.swift
├── Views/
│   ├── PrinterDashboardView.swift
│   ├── SettingsView.swift
│   ├── PrintControlView.swift
│   ├── AMSView.swift
│   ├── PrintHistoryView.swift
│   ├── DeviceSetupView.swift
│   └── DebugView.swift
├── Components/
│   ├── GlassCard.swift
│   ├── ProgressBar.swift
│   └── RainbowShimmer.swift
└── PreviewContent/

PrinterActivityMonitorWidget/          # Live Activity widget
├── PrinterActivityMonitorWidgetBundle.swift
├── PrinterLiveActivityView.swift
└── Info.plist
```

---

## Building & Running

### Simulator

```bash
xcodebuild \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

### Device Deployment

1. Connect iPhone via USB
2. Trust device when prompted
3. Select device in Xcode
4. Press Cmd+R
5. Enable Live Activities: Settings → [App] → Live Activities

### Command Line

```bash
# Build
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor build

# Clean
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor clean
```

---

## Configuration

### Info.plist Keys

```xml
<!-- Allow HTTP for local HA -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- Live Activities -->
<key>NSSupportsLiveActivities</key>
<true/>

<!-- Background task ID -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourname.PrinterActivityMonitor.refresh</string>
</array>
```

---

## Testing

### Debug View

Navigate to Settings → Developer Options to:
- View mock printer state
- Force API calls
- Test sensor responses

### Mock Data

Use PreviewHelper for SwiftUI previews:

```swift
#Preview {
    PrinterDashboardView()
        .environmentObject(HAAPIService())
}
```

### Live Activity Testing

1. Build and run on iPhone 14+ simulator
2. Tap "Start Print" button
3. Lock screen (Cmd+L)
4. Verify activity appears

---

## Common Tasks

### Adding a New Sensor

1. **Add to PrinterState.swift**:
   ```swift
   var chamberHumidity: Int
   ```

2. **Add to HAAPIService.swift**:
   ```swift
   async let chamberHumidity = fetchSensorValue("chamber_humidity")
   ```

3. **Add to Settings.swift** (if optional):
   ```swift
   var showChamberHumidity: Bool = true
   ```

4. **Update UI** in relevant view

### Adding a New View

1. Create file in Views/
2. Add navigation from parent view
3. Inject EnvironmentObjects

### Modifying Live Activity

Edit `PrinterLiveActivityView.swift`:
- `LockScreenView` for lock screen
- `DynamicIsland` for Dynamic Island

---

## Troubleshooting

### Connection Issues

| Problem | Solution |
|---------|----------|
| Cannot reach HA | Verify URL format (include http://) |
| Unauthorized | Create new token in HA |
| Entity not found | Check prefix in HA Developer Tools |

### Live Activity Not Appearing

1. Check Settings → [App] → Live Activities
2. Verify ActivityManager.isAuthorized
3. Check Xcode console for errors
4. Ensure widget extension embedded

### Background Refresh Not Working

- Requires paid Apple Developer account
- Enable Background Modes capability
- Match bundle ID everywhere
- 15-minute minimum interval

---

## Code Style

### SwiftUI Patterns

```swift
// Environment Objects
@EnvironmentObject var settingsManager: SettingsManager

// Async/Await
.task {
    state = try await haService.fetchPrinterState()
}

// Error Handling
@Published var lastError: String?
```

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes/Structs | PascalCase | PrinterState |
| Functions | camelCase | fetchPrinterState() |
| Views | *View.swift | SettingsView.swift |
| Services | *Service.swift | HAAPIService.swift |

---

## Quick Start Checklist

- [ ] Clone and open in Xcode 15+
- [ ] Update bundle ID (3 locations)
- [ ] Select development team
- [ ] Configure HA connection in app
- [ ] Enable Live Activities on device
- [ ] Build and run
- [ ] Test with Debug View
- [ ] Review CLAUDE.md for architecture

---

## Resources

- **Architecture**: See `docs/ARCHITECTURE.md`
- **Models**: See `docs/MODELS.md`
- **API**: See `docs/HOME_ASSISTANT_API.md`
- **Discovery**: See `docs/DEVICE_DISCOVERY.md`
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)
- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Home Assistant REST API](https://developers.home-assistant.io/docs/api/rest/)
