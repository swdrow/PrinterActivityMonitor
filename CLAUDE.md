# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printer Activity Monitor is an iOS app that displays 3D printer status via Live Activities on iPhone Lock Screen and Dynamic Island. It fetches real-time data from Home Assistant's Bambu Lab integration using REST API polling.

## Build Commands

### Building and Running
```bash
# Open project in Xcode
open PrinterActivityMonitor.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Clean build folder
xcodebuild -project PrinterActivityMonitor.xcodeproj -scheme PrinterActivityMonitor clean
```

### Testing on Device
- Connect iPhone via USB
- Select device in Xcode
- Update bundle identifier if using personal Apple ID
- Build & Run (Cmd+R)
- Enable Live Activities in Settings > [App Name] on device

## Architecture

### Data Flow
1. **HAAPIService** polls Home Assistant REST API at configurable intervals (default: 30s)
2. **PrinterState** model aggregates sensor data from multiple HA entities (using entity prefix pattern)
3. **ActivityManager** creates/updates Live Activities using ActivityKit
4. **SettingsManager** persists configuration to UserDefaults

### Key Patterns

**Entity Prefix System**: All HA sensors use a common prefix (e.g., `h2s` → `sensor.h2s_print_progress`, `sensor.h2s_current_layer`). The app queries ~10 different sensor entities to construct the full printer state.

**Live Activity Lifecycle**:
- Created when print starts (via manual button in dashboard)
- Updated every 30s via local polling (no push notifications)
- Auto-ends when status is `finish`, `failed`, or `idle`
- Supports only one active activity at a time

**State Management**: Uses SwiftUI's `@StateObject` and `@EnvironmentObject` pattern. Three main observable objects injected at app root:
- `SettingsManager` - UserDefaults persistence
- `HAAPIService` - API client with polling timer
- `ActivityManager` - Live Activity controller

### Module Responsibilities

**Models/**
- `PrinterState.swift` - Core data model with 10+ fields (progress, layers, temps, etc.) and `PrintStatus` enum
- `Settings.swift` - App configuration including HA credentials, display toggles, and accent color
- `PrinterActivityAttributes.swift` - ActivityKit schema (static attributes + dynamic ContentState)

**Services/**
- `HAAPIService.swift` - REST API client using async/await. Fetches ~10 sensors concurrently using `async let`. Handles Timer-based polling.
- `ActivityManager.swift` - ActivityKit wrapper. Manages single activity lifecycle, checks authorization, handles auto-end conditions.

**Views/**
- `PrinterDashboardView.swift` - Main app UI showing current print status
- `SettingsView.swift` - Configuration screen for HA connection, entity prefix, display options

**Components/**
- `GlassCard.swift` - Frosted glass aesthetic with depth gradients
- `ProgressBar.swift` - Animated progress bar with optional rainbow shimmer
- `RainbowShimmer.swift` - Gemini-style gradient animation overlay

**Widget Target (PrinterActivityMonitorWidget/)**
- `PrinterLiveActivityView.swift` - Defines Lock Screen and Dynamic Island layouts. Has three presentation modes: minimal, compact, expanded.

### Bundle Identifier Note
The background task identifier in `PrinterActivityMonitorApp.swift:31` uses hardcoded `com.yourname.PrinterActivityMonitor.refresh`. When changing bundle IDs, update this string and the matching entry in Info.plist.

## Common Tasks

### Adding New Sensor Fields
1. Add property to `PrinterState.swift`
2. Add corresponding `async let` fetch in `HAAPIService.fetchPrinterState()`
3. Update tuple destructuring and model initialization
4. Add UI toggle to `Settings.swift` if optional
5. Update `PrinterActivityAttributes.ContentState` if shown in Live Activity
6. Modify `PrinterLiveActivityView.swift` to display new field

### Modifying API Polling Behavior
- Polling logic in `HAAPIService.swift:31-43`
- Interval configurable via `Settings.refreshInterval`
- Background refresh uses BGTaskScheduler (15min minimum, requires paid Apple Developer account)

### Changing Live Activity Layout
- Lock Screen: `LockScreenView` in `PrinterLiveActivityView.swift:132`
- Dynamic Island: `DynamicIsland` configuration in `PrinterLiveActivityView.swift:11`
- Update `PrinterActivityAttributes` if new static data needed (set at activity start)
- Update `ContentState` for dynamic data (updated during polling)

## Important Constraints

### Sideloading Limitations
- Free Apple ID: 7-day re-signing required, use AltStore for automation
- Background refresh (BGTaskScheduler) only works with paid Apple Developer Program
- Live Activities work with free account using foreground/local polling only

### Home Assistant API
- Uses REST API (`/api/states/{entity_id}`), not WebSocket
- Requires Long-Lived Access Token
- Entity naming convention: `sensor.{prefix}_{sensor_name}`
- Returns 404 for missing entities (gracefully handled)

### ActivityKit Behavior
- Activities auto-expire after staleDate (set to 2 minutes from last update)
- Maximum 1 activity per app recommended (enforced in ActivityManager)
- Requires "Supports Live Activities" in Info.plist
- User must enable in Settings > [App] > Live Activities
