# Printer Activity Monitor

A beautiful iOS app that displays 3D printer status via Live Activities on your Lock Screen and Dynamic Island. Connects to Home Assistant to fetch real-time printer data from your Bambu Lab (or other) printers.

## Features

- **Live Activities** - Real-time print progress on Lock Screen and Dynamic Island
- **Liquid Glass Design** - Modern frosted glass aesthetic with smooth animations
- **Rainbow Shimmer Effect** - Optional Gemini-style animated gradient effects
- **Configurable Display** - Choose which fields to show (progress, layers, temps, etc.)
- **Multi-Printer Support** - Configure entity prefix for different printers
- **Local Polling** - Works without push notifications ($0 account option)

## Screenshots

The app features a beautiful liquid glass aesthetic:
- Frosted glass cards with depth gradients
- Animated rainbow progress bars
- Dynamic Island integration
- Dark/Light mode support

## Requirements

- iOS 17.0+
- iPhone with Dynamic Island (iPhone 14 Pro+) for full experience
- Home Assistant with Bambu Lab integration
- Xcode 15+ for building

## Setup

### 1. Home Assistant Configuration

Create a Long-Lived Access Token:
1. Open Home Assistant web interface
2. Click your profile icon
3. Scroll to "Long-Lived Access Tokens"
4. Create a new token and copy it

### 2. Entity Prefix

The app expects sensors with a prefix. For example, if your printer sensors are:
- `sensor.h2s_print_progress`
- `sensor.h2s_current_layer`
- `sensor.h2s_remaining_time`

Your entity prefix is `h2s`.

### 3. Build & Install

1. Open `PrinterActivityMonitor.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Change the bundle identifier if needed
4. Connect your iPhone and build

### 4. Configure the App

1. Open the app on your iPhone
2. Go to Settings tab
3. Enter your Home Assistant URL (e.g., `https://your-ha.local:8123`)
4. Paste your access token
5. Set the entity prefix
6. Test the connection

## Sideloading Notes

### Free Apple Developer Account
- App must be re-signed every 7 days
- Use AltStore to automate re-signing
- Live Activities work with local polling only

### Paid Apple Developer Account ($99/year)
- Profile valid for 1 year
- Push notifications can be added for instant updates
- TestFlight distribution available

## Architecture

```
PrinterActivityMonitor/
├── PrinterActivityMonitorApp.swift    # App entry point
├── ContentView.swift                   # Main tab view
├── Models/
│   ├── PrinterState.swift              # Printer data model
│   ├── Settings.swift                  # App settings
│   └── PrinterActivityAttributes.swift # Live Activity data
├── Views/
│   ├── PrinterDashboardView.swift      # Main dashboard
│   └── SettingsView.swift              # Configuration
├── Services/
│   ├── HAAPIService.swift              # Home Assistant API
│   └── ActivityManager.swift           # Live Activity lifecycle
├── Components/
│   ├── GlassCard.swift                 # Frosted glass cards
│   ├── RainbowShimmer.swift            # Animated shimmer
│   └── ProgressBar.swift               # Beautiful progress bars
└── Assets.xcassets/                    # App icons and colors

PrinterActivityMonitorWidget/
├── PrinterActivityMonitorWidgetBundle.swift
└── PrinterLiveActivityView.swift       # Lock Screen & Dynamic Island
```

## Customization

### Accent Colors
Choose from: Cyan, Blue, Purple, Pink, Orange, Green, or Rainbow Shimmer

### Display Fields
Toggle visibility of:
- Progress percentage
- Layer count
- Time remaining
- Nozzle temperature
- Bed temperature
- Print speed
- Filament used

### Compact Mode
Enable for a more minimal Live Activity display

## Future Enhancements

With a $99/year Apple Developer account, you can add:
- Push notifications for instant updates via APNs
- Background refresh while app is closed
- TestFlight beta distribution

## Troubleshooting

### "Live Activities not enabled"
Go to iPhone Settings > Printer Monitor > Live Activities and enable them.

### Connection Failed
- Verify your Home Assistant URL is correct
- Ensure you're on the same network as HA
- Check that the access token is valid

### No Data Showing
- Verify entity prefix matches your sensor names
- Check that the Bambu Lab integration is working in HA

## License

MIT License - Feel free to modify and distribute.

## Credits

Built with SwiftUI, ActivityKit, and lots of love for 3D printing.
