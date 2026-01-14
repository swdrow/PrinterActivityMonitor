# Phase 7: Debug & Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add developer debugging tools, test notification infrastructure, improve error handling, and polish the user experience.

**Scope:**
- Debug menu with mock print simulation
- Test notification buttons
- Server health monitoring endpoint
- Error handling improvements
- UI polish and edge case fixes

---

## Task 1: Create Debug Settings Section

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift`
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/Debug/DebugView.swift`

**Step 1: Create DebugView**

Create a debug menu with useful developer tools:

```swift
// ios/PrinterMonitor/PrinterMonitor/Features/Debug/DebugView.swift
import SwiftUI

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss

    let apiClient: APIClient
    let settings: SettingsStorage

    @State private var serverStatus: String = "Unknown"
    @State private var isLoading = false
    @State private var showClearConfirm = false

    var body: some View {
        List {
            Section("Server") {
                HStack {
                    Text("Server URL")
                    Spacer()
                    Text(settings.serverURL.isEmpty ? "Not configured" : settings.serverURL)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(serverStatus)
                        .foregroundStyle(serverStatus == "Connected" ? .green : .secondary)
                }

                Button("Check Connection") {
                    Task { await checkServerHealth() }
                }
                .disabled(isLoading)
            }

            Section("Device Info") {
                LabeledContent("Device ID", value: settings.deviceId.isEmpty ? "Not registered" : String(settings.deviceId.prefix(8)) + "...")
                LabeledContent("Printer Prefix", value: settings.selectedPrinterPrefix ?? "None")
            }

            Section("Actions") {
                Button("Clear All Settings", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear All Settings?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) {
                settings.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all app settings and require reconfiguration.")
        }
        .task {
            await checkServerHealth()
        }
    }

    private func checkServerHealth() async {
        guard !settings.serverURL.isEmpty else {
            serverStatus = "Not configured"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            let health = try await apiClient.checkHealth()
            serverStatus = health.status == "ok" ? "Connected" : "Error: \(health.status)"
        } catch {
            serverStatus = "Error: \(error.localizedDescription)"
        }
    }
}
```

**Step 2: Add Debug section to SettingsView**

Update SettingsView to include Debug menu (only in DEBUG builds):

```swift
#if DEBUG
Section("Developer") {
    NavigationLink("Debug Menu") {
        DebugView(apiClient: apiClient, settings: settings)
    }
}
#endif
```

**Step 3: Update SettingsView to accept dependencies**

```swift
struct SettingsView: View {
    let apiClient: APIClient
    let settings: SettingsStorage
    // ...
}
```

**Step 4: Update ContentView to pass dependencies**

Update the SettingsView instantiation in ContentView.

**Step 5: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 6: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Debug/
git add ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift
git add ios/PrinterMonitor/PrinterMonitor/App/ContentView.swift
git commit -m "feat(ios): add debug menu with server health check"
```

---

## Task 2: Add Test Notification Triggers to Server

**Files:**
- Create: `server/src/routes/debug.ts`
- Modify: `server/src/index.ts`

**Step 1: Create debug routes**

```typescript
// server/src/routes/debug.ts
import { Router } from 'express';
import { notificationTrigger } from '../services/NotificationTrigger.js';
import { printHistoryService } from '../services/PrintHistoryService.js';
import { getDatabase } from '../config/database.js';

const router = Router();

// Simulate print start
router.post('/simulate/start', async (req, res) => {
  const { printerPrefix, filename } = req.body;

  if (!printerPrefix) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix required',
    });
  }

  try {
    await notificationTrigger.handleStatusChange(
      printerPrefix,
      'idle',
      'running',
      filename ?? 'Test Print.gcode'
    );

    return res.json({
      success: true,
      message: `Simulated print start for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate start failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate print start',
    });
  }
});

// Simulate print complete
router.post('/simulate/complete', async (req, res) => {
  const { printerPrefix, status } = req.body;

  if (!printerPrefix) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix required',
    });
  }

  const finalStatus = status ?? 'complete';

  try {
    await notificationTrigger.handleStatusChange(
      printerPrefix,
      'running',
      finalStatus
    );

    return res.json({
      success: true,
      message: `Simulated print ${finalStatus} for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate complete failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate print complete',
    });
  }
});

// Simulate progress milestone
router.post('/simulate/progress', async (req, res) => {
  const { printerPrefix, progress, filename } = req.body;

  if (!printerPrefix || progress === undefined) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix and progress required',
    });
  }

  try {
    await notificationTrigger.handleProgressChange(
      printerPrefix,
      progress,
      filename ?? 'Test Print.gcode'
    );

    return res.json({
      success: true,
      message: `Simulated ${progress}% progress for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate progress failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate progress',
    });
  }
});

// Get database stats
router.get('/stats', (req, res) => {
  const db = getDatabase();

  return res.json({
    success: true,
    data: {
      devices: db.devices.length,
      printers: db.printers.length,
      printJobs: db.printJobs.length,
      notificationSettings: db.notificationSettings.length,
    },
  });
});

// Clear print history (for testing)
router.delete('/history', (req, res) => {
  const db = getDatabase();
  const count = db.printJobs.length;
  db.printJobs = [];

  return res.json({
    success: true,
    message: `Cleared ${count} print jobs`,
  });
});

export default router;
```

**Step 2: Register route in index.ts**

Add import and use:

```typescript
import debugRoutes from './routes/debug.js';

// With other routes (only in development)
if (isDev) {
  app.use('/api/debug', debugRoutes);
}
```

**Step 3: Verify build**

Run: `cd server && npm run build`

**Step 4: Commit**

```bash
git add server/src/routes/debug.ts server/src/index.ts
git commit -m "feat(server): add debug routes for notification testing"
```

---

## Task 3: Add Test Notification UI to iOS

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Debug/DebugView.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`

**Step 1: Add debug API methods to APIClient**

```swift
// MARK: - Debug

func simulatePrintStart(printerPrefix: String, filename: String = "Test Print.gcode") async throws {
    struct Request: Codable {
        let printerPrefix: String
        let filename: String
    }
    _ = try await request(
        endpoint: "/api/debug/simulate/start",
        method: .post,
        body: Request(printerPrefix: printerPrefix, filename: filename)
    )
}

func simulatePrintComplete(printerPrefix: String, status: String = "complete") async throws {
    struct Request: Codable {
        let printerPrefix: String
        let status: String
    }
    _ = try await request(
        endpoint: "/api/debug/simulate/complete",
        method: .post,
        body: Request(printerPrefix: printerPrefix, status: status)
    )
}

func simulateProgress(printerPrefix: String, progress: Int) async throws {
    struct Request: Codable {
        let printerPrefix: String
        let progress: Int
    }
    _ = try await request(
        endpoint: "/api/debug/simulate/progress",
        method: .post,
        body: Request(printerPrefix: printerPrefix, progress: progress)
    )
}
```

**Step 2: Add notification test section to DebugView**

Add a new section to DebugView:

```swift
Section("Test Notifications") {
    Button("Simulate Print Start") {
        Task { await simulateStart() }
    }
    .disabled(settings.selectedPrinterPrefix == nil)

    Button("Simulate 50% Progress") {
        Task { await simulateProgress(50) }
    }
    .disabled(settings.selectedPrinterPrefix == nil)

    Button("Simulate Print Complete") {
        Task { await simulateComplete("complete") }
    }
    .disabled(settings.selectedPrinterPrefix == nil)

    Button("Simulate Print Failed") {
        Task { await simulateComplete("failed") }
    }
    .disabled(settings.selectedPrinterPrefix == nil)
}
```

Add the helper methods:

```swift
private func simulateStart() async {
    guard let prefix = settings.selectedPrinterPrefix else { return }
    do {
        try apiClient.configure(serverURL: settings.serverURL)
        try await apiClient.simulatePrintStart(printerPrefix: prefix)
    } catch {
        print("Simulate start failed: \(error)")
    }
}

private func simulateProgress(_ progress: Int) async {
    guard let prefix = settings.selectedPrinterPrefix else { return }
    do {
        try apiClient.configure(serverURL: settings.serverURL)
        try await apiClient.simulateProgress(printerPrefix: prefix, progress: progress)
    } catch {
        print("Simulate progress failed: \(error)")
    }
}

private func simulateComplete(_ status: String) async {
    guard let prefix = settings.selectedPrinterPrefix else { return }
    do {
        try apiClient.configure(serverURL: settings.serverURL)
        try await apiClient.simulatePrintComplete(printerPrefix: prefix, status: status)
    } catch {
        print("Simulate complete failed: \(error)")
    }
}
```

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Debug/DebugView.swift
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git commit -m "feat(ios): add notification test buttons to debug menu"
```

---

## Task 4: Improve Error Handling in Dashboard

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/PrinterViewModel.swift`

**Step 1: Review and update PrinterViewModel error handling**

Ensure errors are properly captured and displayed:
- Network errors show retry option
- Configuration errors link to settings
- Add error categorization

**Step 2: Update DashboardView error states**

- Add ContentUnavailableView for error states
- Add retry button
- Add link to settings when not configured

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/
git commit -m "feat(ios): improve dashboard error handling and retry UX"
```

---

## Task 5: Add Pull-to-Refresh to Dashboard

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`

**Step 1: Add refreshable modifier**

Add `.refreshable` to the main content view in DashboardView that calls the ViewModel's refresh method.

**Step 2: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift
git commit -m "feat(ios): add pull-to-refresh to dashboard"
```

---

## Task 6: Add App Version and Build Info

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift`

**Step 1: Update About section**

Add dynamic version and build number from Bundle:

```swift
Section("About") {
    LabeledContent("Version", value: Bundle.main.appVersion)
    LabeledContent("Build", value: Bundle.main.buildNumber)
}

// Add extension:
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

**Step 2: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift
git commit -m "feat(ios): add dynamic version and build info to settings"
```

---

## Phase 7 Complete Checkpoint

At this point you should have:

**iOS:**
- Debug menu with server health check
- Test notification buttons (start, progress, complete, failed)
- Clear settings functionality
- Improved dashboard error handling
- Pull-to-refresh on dashboard
- Dynamic version/build info

**Server:**
- Debug routes for notification simulation
- Database stats endpoint
- History clear endpoint

**Verification Commands:**

```bash
# Server tests
cd server && npm test -- --run

# iOS build
cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

---

## Project Complete!

After Phase 7, the Printer Activity Monitor app includes:

1. **Foundation** - Express server + iOS app structure
2. **HA Integration** - WebSocket connection, entity discovery
3. **Core Dashboard** - Real-time printer status display
4. **Push Notifications** - APNs integration, status alerts
5. **Live Activities** - Lock Screen and Dynamic Island
6. **Print History** - Job tracking with statistics
7. **Debug & Polish** - Developer tools, error handling, UX improvements

**Next Steps (Future Phases):**
- Multi-printer dashboard
- AMS filament tracking
- Camera thumbnail integration
- Apple Watch companion app
