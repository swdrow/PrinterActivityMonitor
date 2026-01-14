# Phase 5: Live Activities Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display real-time print progress on Lock Screen and Dynamic Island using ActivityKit, with server-driven APNs updates.

**Architecture:**
```
Print Status Change (Server WebSocket)
    ↓
Server sends APNs Live Activity Update
    ↓
iOS ActivityKit receives push → updates Live Activity
    ↓
Lock Screen / Dynamic Island refresh
```

**Prerequisites:**
- Phase 4 complete (APNsService, device registration working)
- Widget extension exists (`PrinterMonitorWidget/`)
- `NSSupportsLiveActivities: true` already in Info.plist

---

## Task 1: Create PrinterActivityAttributes

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitorWidget/PrinterActivityAttributes.swift`

**Step 1: Create the ActivityAttributes struct**

This defines static data (set at start) and dynamic ContentState (updated via push).

```swift
import ActivityKit
import Foundation

struct PrinterActivityAttributes: ActivityAttributes {
    // Static data - set when activity starts, never changes
    let filename: String
    let startTime: Date
    let printerName: String
    let printerModel: String
    let entityPrefix: String

    struct ContentState: Codable, Hashable {
        // Dynamic data - updated via push
        let progress: Int           // 0-100
        let currentLayer: Int
        let totalLayers: Int
        let remainingSeconds: Int
        let status: String          // running, paused, failed, complete
        let nozzleTemp: Int
        let bedTemp: Int

        // Computed helpers
        var formattedTimeRemaining: String {
            let hours = remainingSeconds / 3600
            let minutes = (remainingSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        var estimatedCompletion: Date {
            Date().addingTimeInterval(TimeInterval(remainingSeconds))
        }
    }
}
```

**Step 2: Verify build**

Run: `cd ios/PrinterMonitor && xcodegen generate && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitorWidget/PrinterActivityAttributes.swift
git commit -m "feat(ios): add PrinterActivityAttributes for Live Activities"
```

---

## Task 2: Create Live Activity Views

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitorWidget/LiveActivityView.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitorWidget/PrinterMonitorWidgetBundle.swift`

**Step 1: Create the Live Activity view**

Create Lock Screen and Dynamic Island layouts using the existing Theme and ProgressRing patterns.

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct PrinterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrinterActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact leading - progress ring
                CompactProgressRing(progress: Double(context.state.progress) / 100)
            } compactTrailing: {
                // Compact trailing - time remaining
                Text(context.state.formattedTimeRemaining)
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                // Minimal - just progress ring
                CompactProgressRing(progress: Double(context.state.progress) / 100)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(context.state.progress) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .purple, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(context.state.progress)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(width: 50, height: 50)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(context.state.formattedTimeRemaining, systemImage: "clock")
                    Label("\(context.state.currentLayer)/\(context.state.totalLayers)", systemImage: "square.stack.3d.up")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Temps
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(context.state.nozzleTemp)°")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("\(context.state.bedTemp)°")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Dynamic Island Components

struct CompactProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

struct ExpandedView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            Text(context.attributes.filename)
                .font(.headline)

            HStack {
                Text("\(context.state.progress)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Text(context.state.formattedTimeRemaining)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<PrinterActivityAttributes>

    var body: some View {
        HStack {
            Label("\(context.state.currentLayer)/\(context.state.totalLayers)", systemImage: "square.stack.3d.up")
            Spacer()
            Text("\(context.state.nozzleTemp)° / \(context.state.bedTemp)°")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
```

**Step 2: Update widget bundle**

Update `PrinterMonitorWidgetBundle.swift` to include the Live Activity:

```swift
import WidgetKit
import SwiftUI

@main
struct PrinterMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrinterLiveActivity()
    }
}
```

Remove the placeholder widget code.

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodegen generate && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitorWidget/
git commit -m "feat(ios): add Live Activity views for Lock Screen and Dynamic Island"
```

---

## Task 3: Create ActivityManager Service

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Services/ActivityManager.swift`

**Step 1: Create the ActivityManager**

Handles activity lifecycle - start, update, end.

```swift
import ActivityKit
import Foundation

@MainActor
@Observable
final class ActivityManager: Sendable {
    private(set) var currentActivity: Activity<PrinterActivityAttributes>?
    private(set) var activityToken: String?
    private(set) var lastError: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startActivity(
        filename: String,
        printerName: String,
        printerModel: String,
        entityPrefix: String,
        initialState: PrinterActivityAttributes.ContentState
    ) async {
        // End any existing activity
        await endActivity()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "Live Activities are disabled"
            return
        }

        let attributes = PrinterActivityAttributes(
            filename: filename,
            startTime: Date(),
            printerName: printerName,
            printerModel: printerModel,
            entityPrefix: entityPrefix
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(120)),
                pushType: .token
            )

            currentActivity = activity

            // Get push token for server updates
            for await token in activity.pushTokenUpdates {
                let tokenString = token.map { String(format: "%02x", $0) }.joined()
                activityToken = tokenString

                // Register token with server
                await registerActivityToken(tokenString, entityPrefix: entityPrefix)
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateActivity(state: PrinterActivityAttributes.ContentState) async {
        guard let activity = currentActivity else { return }

        await activity.update(
            ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(120)
            )
        )
    }

    func endActivity(dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }

        await activity.end(dismissalPolicy: dismissalPolicy)
        currentActivity = nil
        activityToken = nil
    }

    private func registerActivityToken(_ token: String, entityPrefix: String) async {
        guard !settings.serverURL.isEmpty else { return }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            try await apiClient.registerActivityToken(
                activityToken: token,
                printerPrefix: entityPrefix
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}
```

**Step 2: Add registerActivityToken to APIClient**

Add to `APIClient.swift`:

```swift
// MARK: - Activity Token Registration

func registerActivityToken(
    activityToken: String,
    printerPrefix: String
) async throws {
    let body = ActivityTokenRequest(
        activityToken: activityToken,
        printerPrefix: printerPrefix
    )
    _ = try await request(endpoint: "/api/devices/activity-token", method: .post, body: body)
}

// Add to Supporting Types:
struct ActivityTokenRequest: Codable {
    let activityToken: String
    let printerPrefix: String
}
```

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodegen generate && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/ActivityManager.swift
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git commit -m "feat(ios): add ActivityManager for Live Activity lifecycle"
```

---

## Task 4: Create Server LiveActivityService

**Files:**
- Create: `server/src/services/LiveActivityService.ts`
- Create: `server/src/types/live-activity.ts`
- Modify: `server/src/routes/devices.ts`

**Step 1: Create Live Activity types**

```typescript
// server/src/types/live-activity.ts
export interface LiveActivityContentState {
  progress: number;
  currentLayer: number;
  totalLayers: number;
  remainingSeconds: number;
  status: string;
  nozzleTemp: number;
  bedTemp: number;
}

export interface ActivityTokenRegistration {
  deviceId: string;
  activityToken: string;
  printerPrefix: string;
  createdAt: Date;
}
```

**Step 2: Create LiveActivityService**

```typescript
// server/src/services/LiveActivityService.ts
import { ApnsClient, Notification, Priority, PushType } from 'apns2';
import { env } from '../config/index.js';
import { readFileSync } from 'fs';
import type { LiveActivityContentState } from '../types/live-activity.js';

export class LiveActivityService {
  private client: ApnsClient | null = null;
  private isConfigured = false;

  // Map of printerPrefix -> activityToken
  private activityTokens: Map<string, string> = new Map();

  configure(): void {
    if (!env.APNS_TEAM_ID || !env.APNS_KEY_ID || !env.APNS_KEY_PATH) {
      console.log('APNs not configured - Live Activity updates disabled');
      return;
    }

    try {
      const signingKey = readFileSync(env.APNS_KEY_PATH, 'utf8');

      this.client = new ApnsClient({
        team: env.APNS_TEAM_ID,
        keyId: env.APNS_KEY_ID,
        signingKey,
        defaultTopic: `${env.APNS_BUNDLE_ID}.push-type.liveactivity`,
        host: env.APNS_PRODUCTION === 'true'
          ? 'api.push.apple.com'
          : 'api.sandbox.push.apple.com',
      });

      this.isConfigured = true;
      console.log('LiveActivityService configured');
    } catch (error) {
      console.error('Failed to configure LiveActivityService:', error);
    }
  }

  registerActivityToken(printerPrefix: string, token: string): void {
    this.activityTokens.set(printerPrefix, token);
    console.log(`Registered activity token for ${printerPrefix}`);
  }

  removeActivityToken(printerPrefix: string): void {
    this.activityTokens.delete(printerPrefix);
  }

  async sendUpdate(
    printerPrefix: string,
    state: LiveActivityContentState
  ): Promise<boolean> {
    if (!this.client || !this.isConfigured) {
      return false;
    }

    const token = this.activityTokens.get(printerPrefix);
    if (!token) {
      return false;
    }

    const notification = new Notification(token, {
      type: PushType.liveactivity,
      priority: Priority.immediate,
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: 'update',
        'content-state': state,
      },
    });

    try {
      await this.client.send(notification);
      return true;
    } catch (error) {
      console.error(`Live Activity update failed:`, error);
      this.activityTokens.delete(printerPrefix);
      return false;
    }
  }

  async endActivity(printerPrefix: string, finalState: LiveActivityContentState): Promise<boolean> {
    if (!this.client || !this.isConfigured) {
      return false;
    }

    const token = this.activityTokens.get(printerPrefix);
    if (!token) {
      return false;
    }

    const notification = new Notification(token, {
      type: PushType.liveactivity,
      priority: Priority.immediate,
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: 'end',
        'content-state': finalState,
        'dismissal-date': Math.floor(Date.now() / 1000) + 3600, // Dismiss after 1 hour
      },
    });

    try {
      await this.client.send(notification);
      this.activityTokens.delete(printerPrefix);
      return true;
    } catch (error) {
      console.error(`Live Activity end failed:`, error);
      return false;
    }
  }

  isReady(): boolean {
    return this.isConfigured;
  }
}

export const liveActivityService = new LiveActivityService();
```

**Step 3: Add activity token endpoint to devices route**

Add to `server/src/routes/devices.ts`:

```typescript
import { liveActivityService } from '../services/LiveActivityService.js';

// Register activity token
router.post('/activity-token', (req, res) => {
  const { activityToken, printerPrefix } = req.body;

  if (!activityToken || !printerPrefix) {
    return res.status(400).json({
      success: false,
      error: 'activityToken and printerPrefix required',
    });
  }

  liveActivityService.registerActivityToken(printerPrefix, activityToken);

  return res.json({
    success: true,
    message: 'Activity token registered',
  });
});
```

**Step 4: Verify build**

Run: `cd server && npm run build`

**Step 5: Commit**

```bash
git add server/src/services/LiveActivityService.ts server/src/types/live-activity.ts server/src/routes/devices.ts
git commit -m "feat(server): add LiveActivityService for APNs Live Activity updates"
```

---

## Task 5: Integrate Live Activity with PrinterMonitor

**Files:**
- Modify: `server/src/services/PrinterMonitor.ts`
- Modify: `server/src/services/NotificationTrigger.ts`

**Step 1: Update NotificationTrigger to send Live Activity updates**

Add imports and modify `NotificationTrigger.ts`:

```typescript
import { liveActivityService } from './LiveActivityService.js';
import type { LiveActivityContentState } from '../types/live-activity.js';

// Add to handleStatusChange - after sending push notification:
if (newStatus === 'running') {
  // Don't end activity on start - iOS will create it
} else if (newStatus === 'complete' || newStatus === 'failed' || newStatus === 'cancelled') {
  // End the Live Activity
  const finalState: LiveActivityContentState = {
    progress: newStatus === 'complete' ? 100 : 0,
    currentLayer: 0,
    totalLayers: 0,
    remainingSeconds: 0,
    status: newStatus,
    nozzleTemp: 0,
    bedTemp: 0,
  };
  await liveActivityService.endActivity(printerPrefix, finalState);
}

// Add new method for progress updates:
async handleStateUpdate(
  printerPrefix: string,
  state: {
    progress: number;
    currentLayer: number;
    totalLayers: number;
    remainingSeconds: number;
    status: string;
    nozzleTemp: number;
    bedTemp: number;
  }
): Promise<void> {
  // Only send updates while running
  if (state.status !== 'running' && state.status !== 'paused') {
    return;
  }

  const liveActivityState: LiveActivityContentState = {
    progress: state.progress,
    currentLayer: state.currentLayer,
    totalLayers: state.totalLayers,
    remainingSeconds: state.remainingSeconds,
    status: state.status,
    nozzleTemp: state.nozzleTemp,
    bedTemp: state.bedTemp,
  };

  await liveActivityService.sendUpdate(printerPrefix, liveActivityState);
}
```

**Step 2: Update PrinterMonitor to call state updates**

In `PrinterMonitor.ts`, after updating cache in `updateCacheFromEvent`:

```typescript
// At the end of updateCacheFromEvent, after updating cache.lastUpdated:
// Send Live Activity update (throttled to every 30 seconds)
if (this.shouldSendLiveActivityUpdate(prefix)) {
  notificationTrigger.handleStateUpdate(prefix, {
    progress: cache.progress,
    currentLayer: cache.currentLayer,
    totalLayers: cache.totalLayers,
    remainingSeconds: cache.remainingSeconds,
    status: cache.status,
    nozzleTemp: cache.nozzleTemp,
    bedTemp: cache.bedTemp,
  });
}

// Add throttling helper:
private lastLiveActivityUpdate: Map<string, number> = new Map();

private shouldSendLiveActivityUpdate(prefix: string): boolean {
  const now = Date.now();
  const lastUpdate = this.lastLiveActivityUpdate.get(prefix) ?? 0;

  // Throttle to every 30 seconds
  if (now - lastUpdate < 30000) {
    return false;
  }

  this.lastLiveActivityUpdate.set(prefix, now);
  return true;
}
```

**Step 3: Verify build**

Run: `cd server && npm run build`

**Step 4: Commit**

```bash
git add server/src/services/PrinterMonitor.ts server/src/services/NotificationTrigger.ts
git commit -m "feat(server): integrate Live Activity updates with PrinterMonitor"
```

---

## Task 6: Add Activity Controls to Dashboard

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`

**Step 1: Add ActivityManager to app**

Update `PrinterMonitorApp.swift`:

```swift
@State private var activityManager: ActivityManager?

// In .task:
let actManager = ActivityManager(apiClient: apiClient, settings: settings)
activityManager = actManager
```

**Step 2: Add Live Activity toggle to Dashboard**

Add a button to start/stop Live Activity when a print is running. Read the current DashboardView and add an appropriate button that:
- Shows "Start Live Activity" when no activity is running and print is active
- Shows "Stop Live Activity" when activity is running
- Calls activityManager.startActivity() / endActivity()

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift
git commit -m "feat(ios): add Live Activity controls to Dashboard"
```

---

## Phase 5 Complete Checkpoint

At this point you should have:

**iOS:**
- PrinterActivityAttributes defining static and dynamic data
- Live Activity views for Lock Screen and Dynamic Island
- ActivityManager handling lifecycle and token registration
- Dashboard controls for starting/stopping activities

**Server:**
- LiveActivityService for sending APNs Live Activity pushes
- Activity token registration endpoint
- Integration with PrinterMonitor for real-time updates
- Throttled updates (every 30 seconds)

**To Test:**

1. Run iOS app on physical device (simulator doesn't fully support Live Activities)
2. Start a print job on your printer
3. Tap "Start Live Activity" in Dashboard
4. Verify Lock Screen shows progress
5. Pull down Dynamic Island to see expanded view
6. Verify updates arrive every ~30 seconds
7. When print completes, verify activity dismisses

**Verification Commands:**

```bash
# Server tests
cd server && npm test -- --run

# iOS build
cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

---

## Next Steps

Phase 6 will implement:
- Print History View
- Print job recording on server
- Statistics dashboard
