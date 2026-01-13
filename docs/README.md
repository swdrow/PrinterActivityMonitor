# PrinterActivityMonitor Documentation

Comprehensive documentation for the PrinterActivityMonitor iOS app.

## Documentation Index

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System overview, data flow diagrams, service layer, state management |
| [MODELS.md](MODELS.md) | All data models, enums, relationships, serialization |
| [HOME_ASSISTANT_API.md](HOME_ASSISTANT_API.md) | REST API integration, entity patterns, service calls |
| [UI_COMPONENTS.md](UI_COMPONENTS.md) | Views, components, theming, Live Activity layouts |
| [DEVICE_DISCOVERY.md](DEVICE_DISCOVERY.md) | Auto-discovery system, onboarding flow, persistence |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Setup, building, common tasks, troubleshooting |

## Quick Start

1. **New to the project?** Start with [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
2. **Understanding the code?** Read [ARCHITECTURE.md](ARCHITECTURE.md)
3. **Working with data?** See [MODELS.md](MODELS.md)
4. **Home Assistant issues?** Check [HOME_ASSISTANT_API.md](HOME_ASSISTANT_API.md)
5. **UI development?** Review [UI_COMPONENTS.md](UI_COMPONENTS.md)
6. **Device setup?** See [DEVICE_DISCOVERY.md](DEVICE_DISCOVERY.md)

## Project Overview

PrinterActivityMonitor is an iOS 17+ app that displays Bambu Lab 3D printer status via:
- **Live Activities** on Lock Screen and Dynamic Island
- **Real-time polling** from Home Assistant REST API
- **Auto-discovery** of printers and AMS units
- **Local notifications** for print events

## Key Technologies

- SwiftUI + Combine
- ActivityKit (Live Activities)
- URLSession (REST API)
- UserDefaults (persistence)
- BackgroundTasks (optional)

## Architecture Summary

```
Home Assistant → HAAPIService → PrinterState → Views
                     ↓                           ↓
              ActivityManager ←──────── Live Activity
```

## File Structure

```
PrinterActivityMonitor/
├── Models/           # Data structures
├── Services/         # Business logic
├── Views/            # UI screens
├── Components/       # Reusable UI
└── docs/             # This documentation
```

---

*Last updated: January 2026*
