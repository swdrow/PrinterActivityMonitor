# Printer Activity Monitor

A beautiful iOS app that displays 3D printer status via Live Activities on your Lock Screen and Dynamic Island. Connects to Home Assistant to fetch real-time printer data from Bambu Lab printers.

## Features

### Core Features
- **Live Activities** - Real-time print progress on Lock Screen and Dynamic Island
- **Multi-Printer Support** - Configure multiple printers with auto-discovery
- **AMS Integration** - Full Automatic Material System support with filament tracking
- **Print History** - Track completed prints with statistics
- **Local Notifications** - Get notified when prints complete, fail, or pause
- **Local Polling** - Works without push notifications ($0 account option)

### Design
- **Liquid Glass Aesthetic** - Premium frosted glass cards with depth and blur
- **AI-Style Glow Effects** - Subtle ambient auras and gradient animations
- **Rainbow Shimmer Mode** - Animated gradient effects throughout the app
- **11 Accent Colors** - Cyan, Blue, Purple, Pink, Orange, Green, Red, Yellow, Teal, Indigo, Amber, Mint
- **Fully Dark Mode Optimized** - Designed from the ground up for dark interfaces

## Screenshots

The app features a premium dark mode liquid glass design:
- Frosted glass cards with ambient glow effects
- Animated rainbow progress bars with shimmer
- Dynamic Island integration with glass styling
- AI-style ambient aura effects

## Requirements

- iOS 17.0+
- iPhone with Dynamic Island (iPhone 14 Pro+) for full experience
- Home Assistant with Bambu Lab integration
- Xcode 16+ for building

## Setup

### 1. Home Assistant Configuration

Create a Long-Lived Access Token:
1. Open Home Assistant web interface
2. Click your profile icon
3. Scroll to "Long-Lived Access Tokens"
4. Create a new token and copy it

### 2. Build & Install

```bash
# Clone the repository
git clone https://github.com/yourusername/PrinterActivityMonitor.git
cd PrinterActivityMonitor

# Open in Xcode
open PrinterActivityMonitor.xcodeproj

# Or build from command line
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  build
```

1. Select your development team in Signing & Capabilities
2. Change the bundle identifier if needed
3. Connect your iPhone and build

### 3. Configure the App

1. Open the app and go through the setup wizard
2. Enter your Home Assistant URL (e.g., `https://your-ha.local:8123`)
3. Paste your access token
4. Use auto-discovery to find your printers and AMS units
5. Test the connection

## Architecture

```
PrinterActivityMonitor/
├── PrinterActivityMonitorApp.swift      # App entry point with @StateObject injection
├── ContentView.swift                     # Main tab navigation
├── Models/
│   ├── PrinterState.swift                # Core printer data model with PrintStatus enum
│   ├── Settings.swift                    # App settings + NotificationSettings
│   ├── PrinterActivityAttributes.swift   # ActivityKit schema
│   ├── AMSState.swift                    # AMS slot/tray data models
│   └── DeviceConfiguration.swift         # Multi-printer configuration
├── Views/
│   ├── PrinterDashboardView.swift        # Main status dashboard
│   ├── SettingsView.swift                # Configuration options
│   ├── NotificationSettingsView.swift    # Notification preferences
│   ├── PrintHistoryView.swift            # Print history with statistics
│   ├── AMSView.swift                     # AMS filament management
│   ├── DeviceSetupView.swift             # Auto-discovery onboarding
│   ├── DebugView.swift                   # Debug/testing utilities
│   └── PrintControlView.swift            # Printer control actions
├── Services/
│   ├── HAAPIService.swift                # Home Assistant REST API client
│   ├── ActivityManager.swift             # Live Activity lifecycle
│   ├── NotificationManager.swift         # Local notification handling
│   ├── PrintHistoryService.swift         # Print history persistence
│   └── EntityDiscoveryService.swift      # Auto-discovery logic
├── Components/
│   ├── GlassCard.swift                   # Frosted glass card components
│   ├── RainbowShimmer.swift              # Animated shimmer + AI aura effects
│   ├── ProgressBar.swift                 # Beautiful progress bars
│   ├── DarkModeBackground.swift          # Unified dark backgrounds
│   └── PrinterIcon.swift                 # Printer model icons
└── Assets.xcassets/                      # App icons and colors

PrinterActivityMonitorWidget/
├── PrinterActivityMonitorWidgetBundle.swift
└── PrinterLiveActivityView.swift         # Lock Screen & Dynamic Island layouts
```

## Customization

### Accent Colors
Choose from 11 vibrant colors optimized for dark mode:
- **Cool**: Cyan, Blue, Purple, Indigo, Teal
- **Warm**: Pink, Orange, Red, Yellow, Amber
- **Fresh**: Green, Mint
- **Special**: Rainbow Shimmer (animated gradient)

### Display Options
Toggle visibility in Live Activities and dashboard:
- Progress percentage
- Layer count (current/total)
- Time remaining
- Nozzle temperature
- Bed temperature
- Chamber temperature
- Print speed
- Filament used

### Compact Mode
Enable for a minimal Live Activity display optimized for glanceable information.

## Sideloading Notes

### Free Apple Developer Account
- App must be re-signed every 7 days
- Use AltStore or SideStore to automate re-signing
- Live Activities work with local polling only
- Background refresh limited

### Paid Apple Developer Account ($99/year)
- Profile valid for 1 year
- Push notifications can be added for instant updates
- Background refresh fully functional
- TestFlight distribution available

## Entity Naming

The app uses entity prefix pattern matching. If your sensors are:
- `sensor.x1c_print_progress`
- `sensor.x1c_current_layer`
- `sensor.x1c_remaining_time`

Your entity prefix is `x1c`. The auto-discovery feature automatically detects:
- Printer entity prefixes from known sensor patterns
- Printer models (X1C, P1S, A1, etc.) from prefix names
- AMS units via `_tray_\d+` regex pattern

## Troubleshooting

### "Live Activities not enabled"
Go to iPhone Settings > Printer Monitor > Live Activities and enable them.

### Connection Failed
- Verify your Home Assistant URL is correct (include port if needed)
- Ensure you're on the same network as HA
- Check that the access token is valid and not expired

### No Data Showing
- Use the Discovery feature to find your entities
- Verify the Bambu Lab integration is working in HA
- Check Debug view for entity fetch results

### Live Activity Not Updating
- Ensure the app is running (foreground or background)
- Check that polling interval is set appropriately (default: 30s)
- Verify printer status is "printing" in Home Assistant

## Development

### Build Commands
```bash
# Build for simulator
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  build

# Run tests
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  test

# Clean build
xcodebuild -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor clean
```

### Debug Mode
The app includes a Debug view with:
- Entity discovery testing
- Mock Live Activity testing (test without actual print job)
- API response inspection
- Notification testing

## License

MIT License - Feel free to modify and distribute.

## Credits

Built with SwiftUI, ActivityKit, and lots of love for 3D printing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.
