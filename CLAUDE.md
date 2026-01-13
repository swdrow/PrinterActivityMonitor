# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printer Activity Monitor is an iOS 17+ app that displays 3D printer status via Live Activities on iPhone Lock Screen and Dynamic Island. It fetches real-time data from Home Assistant's Bambu Lab integration using REST API polling.

## Build Commands

```bash
# Build for simulator
xcodebuild -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build

# Clean build
xcodebuild clean build -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Lint (SwiftLint configured in .swiftlint.yml)
swiftlint lint --strict

# Run tests
xcodebuild test -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Run specific test class
xcodebuild test -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:PrinterActivityMonitorTests/PrinterStateTests

# Static analysis
xcodebuild analyze -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

## Architecture

### Data Flow
1. **HAAPIService** polls Home Assistant REST API at configurable intervals (default: 30s)
2. **PrinterState** model aggregates sensor data from multiple HA entities (using entity prefix pattern)
3. **ActivityManager** creates/updates Live Activities using ActivityKit
4. **NotificationManager** sends local notifications on print status changes
5. **PrintHistoryService** persists completed prints to JSON file in Documents directory
6. **DeviceConfigurationManager** stores discovered printers/AMS units in UserDefaults

### State Management
Six `@StateObject` observable objects injected at app root in `PrinterActivityMonitorApp.swift`:
- `SettingsManager` - UserDefaults persistence for app settings
- `HAAPIService` - API client with polling timer
- `ActivityManager` - Live Activity controller
- `NotificationManager` - Local notification handling
- `PrintHistoryService` - Print history persistence
- `DeviceConfigurationManager` - Multi-device configuration

### Entity Prefix System
All HA sensors use a common prefix (e.g., `h2s`). Core printer sensors:
- `sensor.{prefix}_print_progress`, `_current_layer`, `_total_layer_count`
- `sensor.{prefix}_remaining_time`, `_print_status`, `_subtask_name`
- `sensor.{prefix}_nozzle_temperature`, `_bed_temperature`
- `sensor.{prefix}_speed_profile`, `_filament_used`

AMS sensors use tray pattern: `sensor.{ams_prefix}_tray_1` through `_tray_4`

### Auto-Discovery System
`EntityDiscoveryService.swift` discovers printers and AMS units by:
1. Fetching all entities via `/api/states`
2. Pattern matching known sensor suffixes to extract entity prefixes
3. Detecting printer models from prefix names (X1C, P1S, A1, etc.)
4. Finding AMS trays via `_tray_\d+` regex pattern

### Key Files
- `HAAPIService.swift` - REST API client using `async let` for concurrent sensor fetches
- `ActivityManager.swift` - Single Live Activity lifecycle (max 1 per app)
- `EntityDiscoveryService.swift` - Auto-discovery via pattern matching on `/api/states`
- `PrinterLiveActivityView.swift` - Lock Screen and Dynamic Island layouts (Widget target)

## Common Tasks

### Adding New Sensor Fields
1. Add property to `PrinterState.swift`
2. Add `async let` fetch in `HAAPIService.fetchPrinterState()`
3. Update tuple destructuring and model initialization
4. Add UI toggle to `Settings.swift` if optional
5. Update `PrinterActivityAttributes.ContentState` if shown in Live Activity
6. Modify `PrinterLiveActivityView.swift` to display

### Adding New Notification Types
1. Add setting toggle to `NotificationSettings` in `Settings.swift`
2. Handle state change in `NotificationManager.handleStatusChange()`
3. Create `sendXxxNotification()` method with `UNMutableNotificationContent`
4. Add test notification type to `TestNotificationType` enum

### Changing Live Activity Layout
- Lock Screen: `LockScreenView` struct in `PrinterLiveActivityView.swift`
- Dynamic Island: `DynamicIsland` configuration in `ActivityConfiguration` body
- Static data: Update `PrinterActivityAttributes` (set at activity start)
- Dynamic data: Update `ContentState` (updated during polling)

## Important Constraints

### Bundle Identifier
Background task identifier `com.samduncan.PrinterActivityMonitor.refresh` must match:
- `PrinterActivityMonitorApp.swift:52` (registration)
- `Info.plist` `BGTaskSchedulerPermittedIdentifiers` array

### Home Assistant API
- Uses REST API (`/api/states/{entity_id}`), not WebSocket
- Requires Long-Lived Access Token
- Returns 404 for missing entities (gracefully handled)
- Discovery endpoint: `/api/states` returns all entities as JSON array

### ActivityKit Behavior
- Activities auto-expire after staleDate (set to 2 minutes from last update)
- Maximum 1 activity per app (enforced in ActivityManager)
- Requires `NSSupportsLiveActivities` = true in Info.plist

### Sideloading Limitations
- Free Apple ID: 7-day re-signing, use AltStore for automation
- BGTaskScheduler only works with paid Apple Developer Program
- Live Activities work with free account using foreground polling only
