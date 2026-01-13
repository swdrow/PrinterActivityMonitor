# Printer Activity Monitor - Complete Rebuild Design

**Date:** 2026-01-13
**Status:** Approved
**Author:** Collaborative brainstorm session

---

## Executive Summary

A full-stack rebuild of Printer Activity Monitor as a **Bambu Handy replacement** for LAN-only/developer mode users. Uses Home Assistant's ha_bambulab integration - no Bambu Cloud required.

**Architecture:** iOS app + Node.js backend server with real-time WebSocket connection to Home Assistant and APNs push notifications.

---

## System Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  Node.js Server │────▶│ Home Assistant  │
│   (SwiftUI)     │◀────│  (Express)      │◀────│ (ha_bambulab)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │                       ▼
        │               ┌─────────────────┐
        │               │   Apple APNs    │
        │◀──────────────│                 │
        └───────────────┴─────────────────┘
```

**Data Flow:**
1. User configures HA connection in iOS app
2. iOS app registers with server, passing HA credentials
3. Server establishes WebSocket connection to HA
4. Server subscribes to printer entity state changes
5. On state change → Server sends APNs push/Live Activity update
6. iOS app displays notifications, updates UI

**Key Design Decisions:**
- Server-mediated architecture (not direct iOS→HA polling)
- WebSocket for real-time HA events
- HA token passthrough authentication
- Server stores print history, iOS caches locally
- iOS 26 with `@Observable` pattern
- Monorepo structure

---

## Feature Tiers

### Tier 1 (v1 - Core)
- Rich Push Notifications
- Live Activities + Dynamic Island
- Print History
- Dashboard

### Tier 2 (v1.5 - Enhancement)
- Printer Controls (pause/resume/cancel)
- Auto-Discovery
- AMS Filament Tracking

### Tier 3 (v2 - Advanced)
- Multi-Printer Support
- Advanced Controls
- Camera Feed (investigate LAN streaming)
- Home Screen Widgets

### Future (v3+)
- Print Cost Estimation (requires filament database)
- AI failure detection (research H2S LAN capabilities)

---

## Node.js Server Architecture

**Tech Stack:**
- Runtime: Node.js 20+ (LTS)
- Framework: Express.js
- Database: SQLite
- WebSocket Client: `ws` or `home-assistant-js-websocket`
- APNs: `@parse/node-apn` or `apns2`

**Directory Structure:**
```
server/
├── src/
│   ├── index.ts              # Entry point
│   ├── config/               # Environment, constants
│   ├── routes/               # Express API routes
│   │   ├── auth.ts           # /api/auth - HA token validation
│   │   ├── devices.ts        # /api/devices - token registration
│   │   ├── history.ts        # /api/history - print history CRUD
│   │   └── printers.ts       # /api/printers - printer state
│   ├── services/
│   │   ├── HomeAssistant.ts  # WebSocket connection manager
│   │   ├── APNsService.ts    # Push notification sender
│   │   ├── LiveActivityService.ts  # Activity token management
│   │   └── PrintMonitor.ts   # State change detection logic
│   ├── models/               # Database models
│   │   ├── Device.ts         # Registered iOS devices
│   │   ├── PrintJob.ts       # Print history records
│   │   └── UserConfig.ts     # Per-user HA connection config
│   └── utils/                # Helpers, logging
├── package.json
├── tsconfig.json
└── .env.example
```

**API Endpoints (v1):**
- `POST /api/auth/validate` - Verify HA token works
- `POST /api/devices/register` - Register device + APNs token
- `POST /api/discovery/scan` - Discover printers/AMS from HA
- `GET /api/history` - Fetch print history
- `POST /api/history` - Record completed print
- `GET /api/printers/state` - Current printer state (fallback)

---

## iOS App Architecture

**Target:** iOS 26+ (Swift 6, SwiftUI)

**Directory Structure:**
```
ios/
├── PrinterMonitor/
│   ├── App/
│   │   └── PrinterMonitorApp.swift    # @main entry point
│   │
│   ├── Core/
│   │   ├── Models/                    # Data structures
│   │   │   ├── PrinterState.swift
│   │   │   ├── PrintJob.swift
│   │   │   └── AppSettings.swift
│   │   ├── Services/                  # Business logic
│   │   │   ├── APIClient.swift        # Server communication
│   │   │   ├── ActivityManager.swift  # Live Activity lifecycle
│   │   │   └── NotificationHandler.swift
│   │   └── Storage/                   # Local persistence
│   │       └── SettingsStorage.swift  # UserDefaults wrapper
│   │
│   ├── Features/                      # Feature modules
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── DashboardViewModel.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   └── HistoryViewModel.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Setup/
│   │   │   └── ConnectionSetupView.swift
│   │   └── Debug/
│   │       └── DebugView.swift
│   │
│   ├── Components/                    # Reusable UI
│   │   ├── ProgressRing.swift
│   │   ├── StatCard.swift
│   │   └── GlassCard.swift
│   │
│   └── DesignSystem/
│       └── Theme.swift                # Colors, fonts, spacing
│
├── PrinterMonitorWidget/              # Widget extension
│   ├── LiveActivityView.swift
│   └── PrinterActivityAttributes.swift
│
└── PrinterMonitor.xcodeproj
```

**Key Patterns:**
- `@Observable` ViewModels (not `ObservableObject`)
- Feature-based organization (not layer-based)
- Single `APIClient` for all server communication
- Thin views, logic in ViewModels

**Assets to Preserve:**
- `AppIcon.appiconset/` - Full icon set
- `PrinterImages/h2s.imageset` - H2S printer image
- `PrinterImages/h2s-with-ams.imageset` - H2S with AMS
- `PrinterImages/ams-2-pro.imageset` - AMS unit image

---

## Data Flow & State Management

**Server → iOS Push Flow:**
```
HA Entity Change (e.g., print_progress: 50→51)
    │
    ▼
Server WebSocket receives state_changed event
    │
    ▼
PrintMonitor service evaluates change
    │
    ├─► Significant? (progress milestone, status change)
    │       │
    │       ▼
    │   APNsService.sendNotification() ─► Standard Push
    │
    └─► Live Activity active?
            │
            ▼
        LiveActivityService.sendUpdate() ─► Activity Update
```

**iOS State Management:**
```swift
@Observable
final class PrinterViewModel {
    var printerState: PrinterState?
    var isConnected: Bool = false
    var error: AppError?

    private let apiClient: APIClient

    func handlePushPayload(_ payload: [String: Any]) { ... }
}
```

**Push Payload Structure:**
```json
{
  "aps": {
    "alert": { "title": "Print Complete", "body": "benchy.3mf finished" },
    "sound": "default"
  },
  "printerState": {
    "progress": 100,
    "status": "completed",
    "filename": "benchy.3mf"
  }
}
```

---

## Home Assistant WebSocket Integration

**Connection Lifecycle:**
```
Server Startup
    │
    ▼
For each registered user:
    │
    ▼
Connect to ws://{ha_url}/api/websocket
    │
    ▼
Auth message: { "type": "auth", "access_token": "..." }
    │
    ▼
Subscribe: { "type": "subscribe_events", "event_type": "state_changed" }
    │
    ▼
Filter events for printer entities (sensor.{prefix}_*)
    │
    ▼
On relevant state change → trigger notification logic
```

**Monitored Entities (from ha_bambulab):**
```
sensor.{prefix}_print_progress     # 0-100
sensor.{prefix}_print_status       # idle, running, paused, failed, etc.
sensor.{prefix}_current_layer      # current layer number
sensor.{prefix}_total_layer_count  # total layers
sensor.{prefix}_remaining_time     # seconds remaining
sensor.{prefix}_nozzle_temperature # celsius
sensor.{prefix}_bed_temperature    # celsius
sensor.{prefix}_subtask_name       # filename being printed
```

**Notification Triggers:**
| Event | Notification Type |
|-------|------------------|
| `print_status`: idle → running | "Print Started" |
| `print_status`: running → complete | "Print Complete" |
| `print_status`: running → failed | "Print Failed" (critical) |
| `print_status`: running → paused | "Print Paused" |
| `print_progress`: crosses 25/50/75% | "Progress Milestone" |

**Reconnection Strategy:**
- Exponential backoff (1s, 2s, 4s, 8s... max 60s)
- Heartbeat ping every 30s
- Full reconnect on auth failure

---

## Dynamic Entity Discovery

**Problem:** HA entity names vary by setup. Can't hardcode prefixes.

**Discovery Flow:**
```
On user registration / periodic refresh:
    │
    ▼
GET /api/states (all HA entities)
    │
    ▼
Pattern match known suffixes:
  - _print_progress
  - _print_status
  - _nozzle_temperature
  - _current_layer
    │
    ▼
Extract unique prefixes → candidate printers
    │
    ▼
For each prefix, check for AMS trays:
  - sensor.{ams_prefix}_tray_1 through _tray_4
    │
    ▼
Return discovered devices to iOS app for user confirmation
```

**Server Storage:**
```typescript
interface DiscoveredPrinter {
  entityPrefix: string;        // "h2s", "bambu_p1s", etc.
  displayName: string;         // User-editable friendly name
  model: string;               // Detected model (X1C, P1S, H2S, A1)
  associatedAMS: string[];     // AMS prefixes linked to this printer
  entityCount: number;         // How many entities found (confidence)
}
```

---

## Live Activities & Dynamic Island

**Activity Lifecycle (Server-Driven):**
```
Print Starts (detected via WebSocket)
    ↓
Server sends APNs "start" push with activity attributes
    ↓
iOS receives push → creates Live Activity
    ↓
iOS sends Activity Token back to server
    ↓
Server stores token, sends updates via APNs
    ↓
Print completes/fails → Server sends "end" push
    ↓
Live Activity dismissed
```

**ActivityAttributes Schema:**
```swift
struct PrinterActivityAttributes: ActivityAttributes {
    // Static (set at start, never changes)
    let filename: String
    let startTime: Date
    let printerName: String
    let printerModel: String

    struct ContentState: Codable, Hashable {
        // Dynamic (updated via push)
        let progress: Int           // 0-100
        let currentLayer: Int
        let totalLayers: Int
        let remainingSeconds: Int
        let status: String          // running, paused, etc.
        let nozzleTemp: Int
        let bedTemp: Int
    }
}
```

**Dynamic Island Layouts:**

| Region | Content |
|--------|---------|
| Compact Leading | Progress ring (shows % visually) |
| Compact Trailing | Time remaining (e.g., "1h 23m") |
| Minimal | Progress ring only |
| Expanded | Filename, progress bar, ETA, temps |

**Lock Screen Layout:**
```
┌─────────────────────────────────────┐
│  [Progress Ring]    filename.3mf    │
│      (visual %)     ● Running       │
│                                     │
│     ⏱ 1h 23m left  │  🏁 ~3:45 PM  │
│                                     │
│     Layer 142/300  │  🌡 220°/60°  │
└─────────────────────────────────────┘
```

**Priority Order for Limited Space:**
1. Progress ring (visual percentage)
2. Time remaining
3. ETA (completion time)
4. Status indicator
5. Layer count
6. Temperatures (if space allows)

---

## iOS Screens & User Flow

**App Navigation:**
```
TabView (3 tabs)
├── Dashboard (default)
├── History
└── Settings
    └── Debug Menu (dev builds only)
```

**1. Dashboard View**
- Primary status display when print active
- Shows: progress ring, time remaining, ETA, temps, layer count
- "Idle" state when no print (shows printer info, last print summary)
- Pull-to-refresh for manual state sync

**2. History View**
- List of past prints (fetched from server)
- Each row: filename, date, duration, status (success/failed)
- Tap for detail view
- Statistics header: total prints, success rate, total print time

**3. Settings View**
- Connection section: HA URL, status indicator, re-scan printers
- Notifications section: toggle which events trigger notifications
- Display section: temp units (C/F), 12/24hr time
- About section: version, support link

**4. Onboarding Flow (first launch)**
```
Welcome Screen → Enter HA URL + Token → Auto-discover printers
    → Select your printer → Enable notifications → Dashboard
```

**5. Debug Menu**
```
Debug View
├── Mock Print Simulation
│   ├── Start Mock Print
│   ├── Progress Slider (0-100%)
│   ├── Status Selector (running/paused/failed/complete)
│   └── Stop Mock Print
│
├── Test Notifications
│   ├── Send "Print Started"
│   ├── Send "Print Complete"
│   ├── Send "Print Failed"
│   ├── Send "Print Paused"
│   ├── Send "Progress Milestone"
│   └── Send Custom
│
├── Live Activity Testing
│   ├── Start Test Activity
│   ├── Update with Mock Data
│   └── End Activity
│
├── Connection Testing
│   ├── Test HA Connection
│   ├── Test Server Connection
│   └── Force Reconnect
│
└── Data Management
    ├── Clear Local Cache
    └── Reset Onboarding
```

**Access:** Settings → tap version number 5 times (or `#if DEBUG`)

---

## Server Database Schema

**Database:** SQLite

```sql
-- User/Device registration
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    apns_token TEXT,
    activity_token TEXT,
    ha_url TEXT NOT NULL,
    ha_token TEXT NOT NULL,        -- encrypted
    entity_prefix TEXT,
    created_at DATETIME,
    last_seen DATETIME
);

-- Discovered printers (cached)
CREATE TABLE printers (
    id TEXT PRIMARY KEY,
    device_id TEXT REFERENCES devices(id),
    entity_prefix TEXT NOT NULL,
    display_name TEXT,
    model TEXT,
    is_primary BOOLEAN DEFAULT 0,
    discovered_at DATETIME
);

-- Print history
CREATE TABLE print_jobs (
    id TEXT PRIMARY KEY,
    device_id TEXT REFERENCES devices(id),
    printer_prefix TEXT,
    filename TEXT NOT NULL,
    started_at DATETIME,
    completed_at DATETIME,
    duration_seconds INTEGER,
    status TEXT,
    final_layer INTEGER,
    total_layers INTEGER,
    filament_used_mm REAL
);

-- Notification preferences
CREATE TABLE notification_settings (
    device_id TEXT PRIMARY KEY REFERENCES devices(id),
    on_start BOOLEAN DEFAULT 1,
    on_complete BOOLEAN DEFAULT 1,
    on_failed BOOLEAN DEFAULT 1,
    on_paused BOOLEAN DEFAULT 1,
    on_milestone BOOLEAN DEFAULT 1
);
```

---

## Implementation Phases

### Phase 1: Foundation
**Server:**
- Express app skeleton with TypeScript
- SQLite database setup + migrations
- Basic REST endpoints (/health, /api/auth/validate)
- Environment config (.env)

**iOS:**
- Xcode project with monorepo structure
- Basic tab navigation (Dashboard, History, Settings)
- APIClient service skeleton
- Copy existing assets (icons, printer images)

### Phase 2: HA Integration
**Server:**
- WebSocket connection to Home Assistant
- Entity discovery service (pattern matching)
- State change event handling
- /api/discovery/scan endpoint

**iOS:**
- Onboarding flow (HA URL + token entry)
- Connection setup view
- Printer selection after discovery
- Settings storage (UserDefaults)

### Phase 3: Core Dashboard
**Server:**
- /api/printers/state endpoint
- WebSocket → state cache

**iOS:**
- Dashboard view with printer state display
- Progress ring component
- Stat cards (temps, layers, time)
- Pull-to-refresh
- Idle vs. printing states

### Phase 4: Push Notifications (requires paid account)
**Server:**
- APNs service with token-based auth
- Notification trigger logic
- /api/devices/register endpoint

**iOS:**
- APNs registration
- Push notification handling
- Notification settings view

### Phase 5: Live Activities
**Server:**
- LiveActivityService
- APNs Live Activity payloads

**iOS:**
- PrinterActivityAttributes
- Live Activity views (Lock Screen, Dynamic Island)
- Activity lifecycle management

### Phase 6: Print History
**Server:**
- Print job recording
- /api/history endpoints

**iOS:**
- History view with list
- Statistics header
- Detail view

### Phase 7: Debug & Polish
**iOS:**
- Debug menu implementation
- Mock print simulation
- Test notification buttons
- Error handling & user feedback

---

## Monorepo Structure

```
PrinterActivityMonitor/
├── ios/                          # iOS Xcode project
│   ├── PrinterMonitor/
│   ├── PrinterMonitorWidget/
│   └── PrinterMonitor.xcodeproj
├── server/                       # Node.js backend
│   ├── src/
│   ├── package.json
│   └── tsconfig.json
├── docs/                         # Documentation
│   ├── plans/
│   └── PROJECT_ANALYSIS.md
├── shared/                       # Shared schemas (future)
└── README.md
```

---

## Notes

- **APNs requires paid Apple Developer account** ($99/year)
- Development can proceed with free account; APNs features enabled after upgrade
- Placeholder design uses existing "Liquid Aurora" dark mode aesthetic
- Design refinement planned as separate future effort
