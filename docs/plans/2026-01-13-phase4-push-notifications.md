# Phase 4: Push Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable real-time push notifications from server to iOS app when printer state changes (print started, completed, failed, paused, progress milestones).

**Architecture:** Server detects state changes via WebSocket → triggers APNs push → iOS receives and displays notification.

**Tech Stack:**
- Server: `apns2` npm package for APNs token-based auth
- iOS: UNUserNotificationCenter, remote notification registration

**Prerequisites:**
- Phase 3 complete (PrinterMonitor service working)
- **Paid Apple Developer account** for APNs certificates ($99/year)
- APNs Auth Key (.p8 file) from Apple Developer Portal

**Note:** Code can be written without paid account; APNs calls will fail until credentials are configured.

---

## Task 1: Create APNs Service on Server

**Files:**
- Create: `server/src/services/APNsService.ts`
- Create: `server/src/types/apns.ts`

**Step 1: Install apns2 package**

Run: `cd server && npm install apns2`

**Step 2: Create APNs types**

Create file `server/src/types/apns.ts`:

```typescript
export interface APNsConfig {
  teamId: string;
  keyId: string;
  keyPath: string;  // Path to .p8 file
  bundleId: string;
  production: boolean;
}

export interface PrinterNotificationPayload {
  type: 'print_started' | 'print_complete' | 'print_failed' | 'print_paused' | 'progress_milestone';
  printerPrefix: string;
  printerName: string;
  filename?: string;
  progress?: number;
  status?: string;
}

export interface NotificationResult {
  success: boolean;
  deviceToken: string;
  error?: string;
}
```

**Step 3: Create APNsService**

Create file `server/src/services/APNsService.ts`:

```typescript
import { ApnsClient, Notification, Priority, PushType } from 'apns2';
import type { APNsConfig, PrinterNotificationPayload, NotificationResult } from '../types/apns.js';
import { readFileSync } from 'fs';

export class APNsService {
  private client: ApnsClient | null = null;
  private config: APNsConfig | null = null;
  private isConfigured = false;

  configure(config: APNsConfig): void {
    try {
      const signingKey = readFileSync(config.keyPath, 'utf8');

      this.client = new ApnsClient({
        team: config.teamId,
        keyId: config.keyId,
        signingKey,
        defaultTopic: config.bundleId,
        host: config.production
          ? 'api.push.apple.com'
          : 'api.sandbox.push.apple.com',
      });

      this.config = config;
      this.isConfigured = true;
      console.log('APNs service configured successfully');
    } catch (error) {
      console.error('Failed to configure APNs:', error);
      this.isConfigured = false;
    }
  }

  async sendNotification(
    deviceToken: string,
    payload: PrinterNotificationPayload
  ): Promise<NotificationResult> {
    if (!this.client || !this.isConfigured) {
      return {
        success: false,
        deviceToken,
        error: 'APNs not configured',
      };
    }

    const { title, body } = this.formatNotification(payload);

    const notification = new Notification(deviceToken, {
      aps: {
        alert: { title, body },
        sound: 'default',
        'thread-id': payload.printerPrefix,
      },
      printerState: {
        type: payload.type,
        prefix: payload.printerPrefix,
        progress: payload.progress,
        status: payload.status,
        filename: payload.filename,
      },
    });

    notification.pushType = PushType.alert;
    notification.priority = Priority.immediate;

    try {
      await this.client.send(notification);
      return { success: true, deviceToken };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`APNs send failed for ${deviceToken}:`, message);
      return { success: false, deviceToken, error: message };
    }
  }

  async sendToMultiple(
    deviceTokens: string[],
    payload: PrinterNotificationPayload
  ): Promise<NotificationResult[]> {
    const results = await Promise.all(
      deviceTokens.map(token => this.sendNotification(token, payload))
    );
    return results;
  }

  private formatNotification(payload: PrinterNotificationPayload): { title: string; body: string } {
    const printer = payload.printerName || payload.printerPrefix;

    switch (payload.type) {
      case 'print_started':
        return {
          title: 'Print Started',
          body: `${payload.filename || 'Print'} started on ${printer}`,
        };
      case 'print_complete':
        return {
          title: 'Print Complete! 🎉',
          body: `${payload.filename || 'Print'} finished on ${printer}`,
        };
      case 'print_failed':
        return {
          title: 'Print Failed ⚠️',
          body: `${payload.filename || 'Print'} failed on ${printer}`,
        };
      case 'print_paused':
        return {
          title: 'Print Paused',
          body: `${payload.filename || 'Print'} paused on ${printer}`,
        };
      case 'progress_milestone':
        return {
          title: `${payload.progress}% Complete`,
          body: `${payload.filename || 'Print'} on ${printer}`,
        };
      default:
        return {
          title: 'Printer Update',
          body: `Update from ${printer}`,
        };
    }
  }

  isReady(): boolean {
    return this.isConfigured;
  }
}

// Singleton instance
export const apnsService = new APNsService();
```

**Step 4: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds (may have unused variable warnings)

**Step 5: Commit**

```bash
git add server/src/services/APNsService.ts server/src/types/apns.ts server/package.json server/package-lock.json
git commit -m "feat(server): add APNsService for push notifications"
```

---

## Task 2: Create Device Registration Endpoint

**Files:**
- Create: `server/src/routes/devices.ts`
- Modify: `server/src/index.ts`
- Modify: `server/src/config/database.ts` (add devices table)

**Step 1: Add devices table to database**

Update `server/src/config/database.ts` to add devices table in initDatabase:

```typescript
// Add to CREATE TABLE statements
db.exec(`
  CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    apns_token TEXT NOT NULL UNIQUE,
    ha_url TEXT NOT NULL,
    printer_prefix TEXT,
    printer_name TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    notifications_enabled INTEGER DEFAULT 1,
    on_start INTEGER DEFAULT 1,
    on_complete INTEGER DEFAULT 1,
    on_failed INTEGER DEFAULT 1,
    on_paused INTEGER DEFAULT 1,
    on_milestone INTEGER DEFAULT 1
  )
`);
```

**Step 2: Create devices route**

Create file `server/src/routes/devices.ts`:

```typescript
import { Router } from 'express';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { getDatabase } from '../config/database.js';

const router = Router();

const registerSchema = z.object({
  apnsToken: z.string().min(1),
  haUrl: z.string().url(),
  printerPrefix: z.string().optional(),
  printerName: z.string().optional(),
});

const updateSettingsSchema = z.object({
  notificationsEnabled: z.boolean().optional(),
  onStart: z.boolean().optional(),
  onComplete: z.boolean().optional(),
  onFailed: z.boolean().optional(),
  onPaused: z.boolean().optional(),
  onMilestone: z.boolean().optional(),
});

// Register or update device
router.post('/register', (req, res) => {
  const parsed = registerSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { apnsToken, haUrl, printerPrefix, printerName } = parsed.data;
  const db = getDatabase();

  // Check if device exists
  const existing = db.prepare(
    'SELECT id FROM devices WHERE apns_token = ?'
  ).get(apnsToken) as { id: string } | undefined;

  if (existing) {
    // Update existing device
    db.prepare(`
      UPDATE devices SET
        ha_url = ?,
        printer_prefix = ?,
        printer_name = ?,
        last_seen = CURRENT_TIMESTAMP
      WHERE apns_token = ?
    `).run(haUrl, printerPrefix ?? null, printerName ?? null, apnsToken);

    return res.json({
      success: true,
      deviceId: existing.id,
      message: 'Device updated',
    });
  }

  // Create new device
  const deviceId = uuidv4();
  db.prepare(`
    INSERT INTO devices (id, apns_token, ha_url, printer_prefix, printer_name)
    VALUES (?, ?, ?, ?, ?)
  `).run(deviceId, apnsToken, haUrl, printerPrefix ?? null, printerName ?? null);

  return res.json({
    success: true,
    deviceId,
    message: 'Device registered',
  });
});

// Update notification settings
router.patch('/:deviceId/settings', (req, res) => {
  const { deviceId } = req.params;
  const parsed = updateSettingsSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
    });
  }

  const db = getDatabase();
  const device = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);

  if (!device) {
    return res.status(404).json({
      success: false,
      error: 'Device not found',
    });
  }

  const updates: string[] = [];
  const values: (number | string)[] = [];

  const settings = parsed.data;
  if (settings.notificationsEnabled !== undefined) {
    updates.push('notifications_enabled = ?');
    values.push(settings.notificationsEnabled ? 1 : 0);
  }
  if (settings.onStart !== undefined) {
    updates.push('on_start = ?');
    values.push(settings.onStart ? 1 : 0);
  }
  if (settings.onComplete !== undefined) {
    updates.push('on_complete = ?');
    values.push(settings.onComplete ? 1 : 0);
  }
  if (settings.onFailed !== undefined) {
    updates.push('on_failed = ?');
    values.push(settings.onFailed ? 1 : 0);
  }
  if (settings.onPaused !== undefined) {
    updates.push('on_paused = ?');
    values.push(settings.onPaused ? 1 : 0);
  }
  if (settings.onMilestone !== undefined) {
    updates.push('on_milestone = ?');
    values.push(settings.onMilestone ? 1 : 0);
  }

  if (updates.length > 0) {
    values.push(deviceId);
    db.prepare(`UPDATE devices SET ${updates.join(', ')} WHERE id = ?`).run(...values);
  }

  return res.json({
    success: true,
    message: 'Settings updated',
  });
});

// Get devices for a printer prefix (used by notification service)
router.get('/by-printer/:prefix', (req, res) => {
  const { prefix } = req.params;
  const db = getDatabase();

  const devices = db.prepare(`
    SELECT id, apns_token, printer_name,
           notifications_enabled, on_start, on_complete, on_failed, on_paused, on_milestone
    FROM devices
    WHERE printer_prefix = ? AND notifications_enabled = 1
  `).all(prefix);

  return res.json({
    success: true,
    devices,
  });
});

// Unregister device
router.delete('/:deviceId', (req, res) => {
  const { deviceId } = req.params;
  const db = getDatabase();

  db.prepare('DELETE FROM devices WHERE id = ?').run(deviceId);

  return res.json({
    success: true,
    message: 'Device unregistered',
  });
});

export default router;
```

**Step 3: Install uuid package**

Run: `cd server && npm install uuid && npm install -D @types/uuid`

**Step 4: Wire into main app**

Update `server/src/index.ts`:

```typescript
// Add import
import devicesRoutes from './routes/devices.js';

// Add route
app.use('/api/devices', devicesRoutes);
```

**Step 5: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds

**Step 6: Commit**

```bash
git add server/src/routes/devices.ts server/src/config/database.ts server/src/index.ts server/package.json server/package-lock.json
git commit -m "feat(server): add device registration endpoint with notification settings"
```

---

## Task 3: Integrate Notifications with PrinterMonitor

**Files:**
- Modify: `server/src/services/PrinterMonitor.ts`
- Create: `server/src/services/NotificationTrigger.ts`

**Step 1: Create NotificationTrigger service**

This service decides when to send notifications based on state changes.

Create file `server/src/services/NotificationTrigger.ts`:

```typescript
import { getDatabase } from '../config/database.js';
import { apnsService } from './APNsService.js';
import type { PrinterNotificationPayload } from '../types/apns.js';

interface DeviceRow {
  id: string;
  apns_token: string;
  printer_name: string | null;
  on_start: number;
  on_complete: number;
  on_failed: number;
  on_paused: number;
  on_milestone: number;
}

export class NotificationTrigger {
  private lastProgress: Map<string, number> = new Map();
  private milestones = [25, 50, 75];

  async handleStatusChange(
    printerPrefix: string,
    oldStatus: string,
    newStatus: string,
    filename?: string
  ): Promise<void> {
    const devices = this.getDevicesForPrinter(printerPrefix);
    if (devices.length === 0) return;

    let notificationType: PrinterNotificationPayload['type'] | null = null;
    let filterField: keyof DeviceRow | null = null;

    // Determine notification type based on status transition
    if (oldStatus !== 'running' && newStatus === 'running') {
      notificationType = 'print_started';
      filterField = 'on_start';
    } else if (oldStatus === 'running' && newStatus === 'complete') {
      notificationType = 'print_complete';
      filterField = 'on_complete';
    } else if (oldStatus === 'running' && newStatus === 'failed') {
      notificationType = 'print_failed';
      filterField = 'on_failed';
    } else if (oldStatus === 'running' && newStatus === 'paused') {
      notificationType = 'print_paused';
      filterField = 'on_paused';
    }

    if (!notificationType || !filterField) return;

    // Filter devices by notification preference
    const eligibleDevices = devices.filter(d => d[filterField as keyof DeviceRow] === 1);
    if (eligibleDevices.length === 0) return;

    const payload: PrinterNotificationPayload = {
      type: notificationType,
      printerPrefix,
      printerName: eligibleDevices[0].printer_name || printerPrefix,
      filename,
    };

    const tokens = eligibleDevices.map(d => d.apns_token);
    await apnsService.sendToMultiple(tokens, payload);

    console.log(`Sent ${notificationType} notification to ${tokens.length} devices`);
  }

  async handleProgressChange(
    printerPrefix: string,
    progress: number,
    filename?: string
  ): Promise<void> {
    const lastProg = this.lastProgress.get(printerPrefix) ?? 0;
    this.lastProgress.set(printerPrefix, progress);

    // Check if we crossed a milestone
    const crossedMilestone = this.milestones.find(
      m => lastProg < m && progress >= m
    );

    if (!crossedMilestone) return;

    const devices = this.getDevicesForPrinter(printerPrefix);
    const eligibleDevices = devices.filter(d => d.on_milestone === 1);
    if (eligibleDevices.length === 0) return;

    const payload: PrinterNotificationPayload = {
      type: 'progress_milestone',
      printerPrefix,
      printerName: eligibleDevices[0].printer_name || printerPrefix,
      filename,
      progress: crossedMilestone,
    };

    const tokens = eligibleDevices.map(d => d.apns_token);
    await apnsService.sendToMultiple(tokens, payload);

    console.log(`Sent ${crossedMilestone}% milestone notification to ${tokens.length} devices`);
  }

  resetProgress(printerPrefix: string): void {
    this.lastProgress.delete(printerPrefix);
  }

  private getDevicesForPrinter(printerPrefix: string): DeviceRow[] {
    const db = getDatabase();
    return db.prepare(`
      SELECT id, apns_token, printer_name,
             on_start, on_complete, on_failed, on_paused, on_milestone
      FROM devices
      WHERE printer_prefix = ? AND notifications_enabled = 1
    `).all(printerPrefix) as DeviceRow[];
  }
}

export const notificationTrigger = new NotificationTrigger();
```

**Step 2: Integrate with PrinterMonitor**

Update `server/src/services/PrinterMonitor.ts` to emit events that trigger notifications:

Add at the top:
```typescript
import { notificationTrigger } from './NotificationTrigger.js';
```

In the `handleStateChange` method, after updating cache for `_print_status`:
```typescript
case '_print_status':
  const oldStatus = cache.status;
  cache.status = value;
  if (oldStatus !== value) {
    this.emit('status_changed', { prefix, oldStatus, newStatus: value });
    // Trigger notification
    notificationTrigger.handleStatusChange(
      prefix,
      oldStatus,
      value,
      cache.subtaskName ?? undefined
    );
  }
  break;
```

After updating progress in `_print_progress`:
```typescript
case '_print_progress':
  const oldProgress = cache.progress;
  cache.progress = this.parseNumber(value, cache.progress);
  // Check for milestone notification
  if (cache.progress > oldProgress) {
    notificationTrigger.handleProgressChange(
      prefix,
      cache.progress,
      cache.subtaskName ?? undefined
    );
  }
  break;
```

**Step 3: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds

**Step 4: Commit**

```bash
git add server/src/services/NotificationTrigger.ts server/src/services/PrinterMonitor.ts
git commit -m "feat(server): integrate push notifications with printer state changes"
```

---

## Task 4: Add APNs Configuration Endpoint

**Files:**
- Create: `server/src/routes/config.ts`
- Modify: `server/src/index.ts`
- Update: `server/.env.example`

**Step 1: Update .env.example**

Add to `server/.env.example`:

```
# APNs Configuration (requires paid Apple Developer account)
APNS_TEAM_ID=
APNS_KEY_ID=
APNS_KEY_PATH=./certs/AuthKey.p8
APNS_BUNDLE_ID=com.samduncan.PrinterMonitor
APNS_PRODUCTION=false
```

**Step 2: Update config/index.ts**

Add APNs config to environment schema:

```typescript
// Add to envSchema
apnsTeamId: z.string().optional(),
apnsKeyId: z.string().optional(),
apnsKeyPath: z.string().optional(),
apnsBundleId: z.string().default('com.samduncan.PrinterMonitor'),
apnsProduction: z.string().default('false'),
```

**Step 3: Create config route**

Create file `server/src/routes/config.ts`:

```typescript
import { Router } from 'express';
import { apnsService } from '../services/APNsService.js';
import { env } from '../config/index.js';

const router = Router();

// Initialize APNs on server startup
router.post('/apns/init', (req, res) => {
  if (!env.apnsTeamId || !env.apnsKeyId || !env.apnsKeyPath) {
    return res.status(400).json({
      success: false,
      error: 'APNs not configured. Set APNS_TEAM_ID, APNS_KEY_ID, APNS_KEY_PATH in .env',
    });
  }

  try {
    apnsService.configure({
      teamId: env.apnsTeamId,
      keyId: env.apnsKeyId,
      keyPath: env.apnsKeyPath,
      bundleId: env.apnsBundleId,
      production: env.apnsProduction === 'true',
    });

    return res.json({
      success: true,
      message: 'APNs configured',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to configure APNs',
    });
  }
});

// Check APNs status
router.get('/apns/status', (req, res) => {
  return res.json({
    configured: apnsService.isReady(),
    bundleId: env.apnsBundleId,
    production: env.apnsProduction === 'true',
  });
});

export default router;
```

**Step 4: Wire into main app**

Update `server/src/index.ts`:

```typescript
// Add import
import configRoutes from './routes/config.js';

// Add route
app.use('/api/config', configRoutes);
```

**Step 5: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds

**Step 6: Commit**

```bash
git add server/src/routes/config.ts server/src/config/index.ts server/src/index.ts server/.env.example
git commit -m "feat(server): add APNs configuration endpoint"
```

---

## Task 5: Create iOS Push Notification Handler

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Services/NotificationManager.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift`

**Step 1: Create NotificationManager**

Create file `ios/PrinterMonitor/PrinterMonitor/Core/Services/NotificationManager.swift`:

```swift
import Foundation
import UserNotifications
import UIKit

@MainActor
@Observable
final class NotificationManager: NSObject, Sendable {
    private(set) var isAuthorized = false
    private(set) var deviceToken: String?
    private(set) var lastError: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
        super.init()
    }

    func requestAuthorization() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isAuthorized = granted

            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token

        Task {
            await registerWithServer(token: token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        lastError = error.localizedDescription
    }

    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Parse printer state from notification payload
        guard let printerState = userInfo["printerState"] as? [String: Any] else { return }

        // Post notification for views to update
        NotificationCenter.default.post(
            name: .printerStateUpdated,
            object: nil,
            userInfo: printerState
        )
    }

    private func registerWithServer(token: String) async {
        guard !settings.serverURL.isEmpty,
              let prefix = settings.selectedPrinterPrefix else {
            return
        }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            _ = try await apiClient.registerDevice(
                apnsToken: token,
                haUrl: settings.haURL,
                printerPrefix: prefix,
                printerName: settings.selectedPrinterName
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let printerStateUpdated = Notification.Name("printerStateUpdated")
}
```

**Step 2: Add registerDevice to APIClient**

Update `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`:

```swift
// MARK: - Device Registration

func registerDevice(
    apnsToken: String,
    haUrl: String,
    printerPrefix: String?,
    printerName: String?
) async throws -> DeviceRegistrationResponse {
    let body = DeviceRegistrationRequest(
        apnsToken: apnsToken,
        haUrl: haUrl,
        printerPrefix: printerPrefix,
        printerName: printerName
    )
    let data = try await request(endpoint: "/api/devices/register", method: .post, body: body)
    return try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data)
}

// Add to Supporting Types extension:

struct DeviceRegistrationRequest: Codable {
    let apnsToken: String
    let haUrl: String
    let printerPrefix: String?
    let printerName: String?
}

struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let deviceId: String
    let message: String
}
```

**Step 3: Update PrinterMonitorApp for notifications**

Update `ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift`:

```swift
import SwiftUI

@main
struct PrinterMonitorApp: App {
    @State private var apiClient = APIClient()
    @State private var settings = SettingsStorage()
    @State private var notificationManager: NotificationManager?

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, settings: settings)
                .preferredColorScheme(.dark)
                .task {
                    let manager = NotificationManager(apiClient: apiClient, settings: settings)
                    notificationManager = manager
                    appDelegate.notificationManager = manager
                    await manager.requestAuthorization()
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var notificationManager: NotificationManager?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            notificationManager?.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            notificationManager?.handleRegistrationError(error)
        }
    }
}
```

**Step 4: Regenerate Xcode project**

Run: `cd ios/PrinterMonitor && xcodegen generate`

**Step 5: Build to verify**

Run: `xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/NotificationManager.swift
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git add ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift
git add ios/PrinterMonitor/PrinterMonitor.xcodeproj/
git commit -m "feat(ios): add push notification registration and handling"
```

---

## Task 6: Create Notification Settings View

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/Settings/NotificationSettingsView.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift`

**Step 1: Create NotificationSettingsView**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Settings/NotificationSettingsView.swift`:

```swift
import SwiftUI

struct NotificationSettingsView: View {
    @State private var onStart = true
    @State private var onComplete = true
    @State private var onFailed = true
    @State private var onPaused = true
    @State private var onMilestone = true

    var body: some View {
        List {
            Section {
                Toggle("Print Started", isOn: $onStart)
                Toggle("Print Complete", isOn: $onComplete)
                Toggle("Print Failed", isOn: $onFailed)
                Toggle("Print Paused", isOn: $onPaused)
            } header: {
                Text("Status Notifications")
            } footer: {
                Text("Get notified when your print status changes")
            }

            Section {
                Toggle("Progress Milestones", isOn: $onMilestone)
            } header: {
                Text("Progress Notifications")
            } footer: {
                Text("Get notified at 25%, 50%, and 75% completion")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
```

**Step 2: Update SettingsView to link to notification settings**

Read and update `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift` to add a NavigationLink to NotificationSettingsView in the appropriate section.

**Step 3: Regenerate Xcode project**

Run: `cd ios/PrinterMonitor && xcodegen generate`

**Step 4: Build to verify**

Run: `xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Settings/NotificationSettingsView.swift
git add ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift
git add ios/PrinterMonitor/PrinterMonitor.xcodeproj/
git commit -m "feat(ios): add notification settings view"
```

---

## Phase 4 Complete Checkpoint

At this point you should have:

**Server:**
- APNsService for sending push notifications
- Device registration endpoint (`/api/devices/register`)
- NotificationTrigger that sends notifications on state changes
- APNs configuration endpoint

**iOS:**
- NotificationManager for handling push registration
- Device token registration with server
- Notification settings view

**To Test (requires APNs credentials):**

1. Add APNs credentials to server `.env`:
```
APNS_TEAM_ID=YOUR_TEAM_ID
APNS_KEY_ID=YOUR_KEY_ID
APNS_KEY_PATH=./certs/AuthKey.p8
```

2. Start server and initialize APNs:
```bash
curl -X POST http://localhost:3000/api/config/apns/init
```

3. Run iOS app on physical device (simulator doesn't support push)

4. Start a print on your printer and verify notifications arrive

**Without APNs credentials:** Code will build and run, but push notifications won't be delivered. Device registration will succeed but APNs sends will fail gracefully.

---

## Next Steps

Phase 5 will implement:
- Live Activities (Lock Screen and Dynamic Island)
- APNs Live Activity update payloads
- Activity lifecycle management
