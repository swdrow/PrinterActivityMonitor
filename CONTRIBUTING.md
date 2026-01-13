# Contributing to Printer Activity Monitor

Thank you for your interest in contributing to Printer Activity Monitor! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- macOS with Xcode 16 or later
- iOS 17.0+ device or simulator (iPhone 17 Pro recommended for testing)
- Home Assistant instance with Bambu Lab integration (for full testing)
- Basic knowledge of SwiftUI and Swift

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PrinterActivityMonitor.git
   cd PrinterActivityMonitor
   ```
3. Open in Xcode:
   ```bash
   open PrinterActivityMonitor.xcodeproj
   ```
4. Build and run on the simulator

### Testing Without a Printer

The app includes a Debug view with mock Live Activity testing:
1. Build and run the app
2. Navigate to the Debug tab
3. Use "Mock Live Activity" section to test without an actual printer

## Code Style

### SwiftUI Best Practices

- Use `@StateObject` for owned observable objects at injection point
- Use `@EnvironmentObject` for shared objects passed down the view hierarchy
- Prefer composition over inheritance for views
- Extract reusable components to the `Components/` directory

### File Organization

```
Models/          # Data structures and enums
Views/           # SwiftUI views (one view per file)
Services/        # Business logic and API clients
Components/      # Reusable UI components
```

### Naming Conventions

- Views: `*View.swift` (e.g., `PrinterDashboardView.swift`)
- Services: `*Service.swift` or `*Manager.swift`
- Models: Descriptive names without suffix (e.g., `PrinterState.swift`)
- Components: Descriptive component names (e.g., `GlassCard.swift`)

### Design Guidelines

The app follows a **liquid glass dark mode** aesthetic:

1. **Glass Cards**: Use `GlassCard` or `GlassCardCompact` for content containers
2. **Backgrounds**: Use `DarkModeBackground` for view backgrounds
3. **Colors**: Use accent colors from `AccentColorOption` enum
4. **Animations**: Prefer smooth, subtle animations using `withAnimation`
5. **Glow Effects**: Use `aiAura()` or `rainbowAura()` modifiers sparingly

## Making Changes

### Branch Naming

- Features: `feature/description`
- Bug fixes: `fix/description`
- Documentation: `docs/description`

### Commit Messages

Use clear, descriptive commit messages:
```
Add mock Live Activity testing to debug menu

- Add state variables for mock print parameters
- Create UI controls for adjusting mock values
- Implement createMockPrinterState() helper
- Add preset buttons for quick testing
```

### Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commits
3. Ensure the project builds without warnings
4. Test on simulator and device if possible
5. Update documentation if needed
6. Submit a pull request with:
   - Clear description of changes
   - Screenshots for UI changes
   - Testing notes

## Architecture Overview

### Data Flow

```
HAAPIService (polling) → PrinterState → Views
                      ↓
            ActivityManager → Live Activity
                      ↓
            NotificationManager → Local Notifications
                      ↓
            PrintHistoryService → JSON persistence
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `HAAPIService` | Fetches data from Home Assistant REST API |
| `ActivityManager` | Manages Live Activity lifecycle |
| `NotificationManager` | Handles local notifications |
| `PrintHistoryService` | Persists print history to JSON |
| `EntityDiscoveryService` | Auto-discovers printers and AMS units |

### Live Activity Constraints

- Maximum 1 activity per app
- Activities expire after `staleDate` (set to 5 minutes)
- Limited animation support in Lock Screen widgets
- Must update via `ActivityContent` struct

## Testing

### Build Verification

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
```

### Manual Testing Checklist

- [ ] App builds without warnings
- [ ] Dashboard displays correctly
- [ ] Settings save and persist
- [ ] Live Activity starts/stops properly
- [ ] Mock Live Activity works in Debug view
- [ ] Dark mode appearance is consistent
- [ ] Animations run smoothly (60fps)

## Reporting Issues

When reporting bugs, please include:

1. iOS version and device model
2. Steps to reproduce
3. Expected vs actual behavior
4. Screenshots or screen recordings if applicable
5. Relevant log output from Debug view

## Feature Requests

Feature requests are welcome! Please:

1. Check existing issues first
2. Describe the use case
3. Explain how it benefits users
4. Consider implementation complexity

## Questions?

Feel free to open an issue for questions about the codebase or contribution process.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
