# Phase 2: Home Assistant Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Establish WebSocket connection to Home Assistant, implement entity discovery, and create iOS onboarding flow for printer setup.

**Architecture:** Server maintains persistent WebSocket connection to HA, subscribes to state_changed events, filters for printer entities. iOS app provides onboarding flow for users to enter HA credentials and select discovered printers.

**Tech Stack:**
- Server: `ws` library for WebSocket, Home Assistant WebSocket API
- iOS: SwiftUI forms, @Observable state management

**Prerequisites:**
- Phase 1 complete (server running, iOS app building)
- Home Assistant instance accessible (URL + long-lived access token)
- ha_bambulab integration installed in Home Assistant

---

## Task 1: Create Home Assistant WebSocket Service

**Files:**
- Create: `server/src/services/HomeAssistant.ts`
- Create: `server/src/types/homeassistant.ts`

**Step 1: Create HA type definitions**

Create file `server/src/types/homeassistant.ts`:

```typescript
// Home Assistant WebSocket API types

export interface HAAuthMessage {
  type: 'auth';
  access_token: string;
}

export interface HAAuthOkMessage {
  type: 'auth_ok';
  ha_version: string;
}

export interface HAAuthInvalidMessage {
  type: 'auth_invalid';
  message: string;
}

export interface HASubscribeEventsMessage {
  id: number;
  type: 'subscribe_events';
  event_type: string;
}

export interface HAStateChangedEvent {
  id: number;
  type: 'event';
  event: {
    event_type: 'state_changed';
    data: {
      entity_id: string;
      old_state: HAEntityState | null;
      new_state: HAEntityState | null;
    };
    origin: string;
    time_fired: string;
  };
}

export interface HAEntityState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed: string;
  last_updated: string;
}

export interface HAGetStatesMessage {
  id: number;
  type: 'get_states';
}

export interface HAResultMessage {
  id: number;
  type: 'result';
  success: boolean;
  result: HAEntityState[] | null;
  error?: {
    code: string;
    message: string;
  };
}

export type HAMessage =
  | HAAuthOkMessage
  | HAAuthInvalidMessage
  | HAStateChangedEvent
  | HAResultMessage
  | { type: string; [key: string]: unknown };
```

**Step 2: Create HomeAssistant service**

Create file `server/src/services/HomeAssistant.ts`:

```typescript
import WebSocket from 'ws';
import { EventEmitter } from 'events';
import type {
  HAAuthMessage,
  HAMessage,
  HAEntityState,
  HAStateChangedEvent,
} from '../types/homeassistant.js';

export interface HomeAssistantConfig {
  url: string;
  token: string;
}

export interface StateChangeEvent {
  entityId: string;
  oldState: string | null;
  newState: string | null;
  attributes: Record<string, unknown>;
}

export class HomeAssistantService extends EventEmitter {
  private ws: WebSocket | null = null;
  private config: HomeAssistantConfig | null = null;
  private messageId = 1;
  private connected = false;
  private authenticated = false;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000;
  private pendingRequests: Map<number, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
  }> = new Map();

  constructor() {
    super();
  }

  async connect(config: HomeAssistantConfig): Promise<void> {
    this.config = config;
    return this.establishConnection();
  }

  private async establishConnection(): Promise<void> {
    if (!this.config) {
      throw new Error('HomeAssistant not configured');
    }

    return new Promise((resolve, reject) => {
      const wsUrl = this.config!.url.replace(/^http/, 'ws') + '/api/websocket';

      console.log(`Connecting to Home Assistant at ${wsUrl}`);

      this.ws = new WebSocket(wsUrl);

      this.ws.on('open', () => {
        console.log('WebSocket connection opened');
        this.connected = true;
        this.reconnectAttempts = 0;
      });

      this.ws.on('message', (data) => {
        try {
          const message: HAMessage = JSON.parse(data.toString());
          this.handleMessage(message, resolve, reject);
        } catch (error) {
          console.error('Failed to parse message:', error);
        }
      });

      this.ws.on('close', () => {
        console.log('WebSocket connection closed');
        this.connected = false;
        this.authenticated = false;
        this.emit('disconnected');
        this.scheduleReconnect();
      });

      this.ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      });
    });
  }

  private handleMessage(
    message: HAMessage,
    connectResolve?: (value: void) => void,
    connectReject?: (error: Error) => void
  ): void {
    switch (message.type) {
      case 'auth_required':
        this.sendAuth();
        break;

      case 'auth_ok':
        console.log('Authenticated with Home Assistant');
        this.authenticated = true;
        this.emit('connected');
        connectResolve?.();
        break;

      case 'auth_invalid':
        console.error('Authentication failed:', (message as { message: string }).message);
        this.emit('auth_failed', (message as { message: string }).message);
        connectReject?.(new Error('Authentication failed'));
        break;

      case 'event':
        this.handleEvent(message as HAStateChangedEvent);
        break;

      case 'result':
        this.handleResult(message as { id: number; success: boolean; result: unknown; error?: { message: string } });
        break;
    }
  }

  private sendAuth(): void {
    if (!this.config || !this.ws) return;

    const authMessage: HAAuthMessage = {
      type: 'auth',
      access_token: this.config.token,
    };

    this.ws.send(JSON.stringify(authMessage));
  }

  private handleEvent(message: HAStateChangedEvent): void {
    const { entity_id, old_state, new_state } = message.event.data;

    const event: StateChangeEvent = {
      entityId: entity_id,
      oldState: old_state?.state ?? null,
      newState: new_state?.state ?? null,
      attributes: new_state?.attributes ?? {},
    };

    this.emit('state_changed', event);
  }

  private handleResult(message: { id: number; success: boolean; result: unknown; error?: { message: string } }): void {
    const pending = this.pendingRequests.get(message.id);
    if (pending) {
      this.pendingRequests.delete(message.id);
      if (message.success) {
        pending.resolve(message.result);
      } else {
        pending.reject(new Error(message.error?.message ?? 'Request failed'));
      }
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnect attempts reached');
      this.emit('max_reconnects');
      return;
    }

    const delay = Math.min(
      this.reconnectDelay * Math.pow(2, this.reconnectAttempts),
      60000
    );

    console.log(`Scheduling reconnect in ${delay}ms (attempt ${this.reconnectAttempts + 1})`);

    setTimeout(() => {
      this.reconnectAttempts++;
      this.establishConnection().catch((error) => {
        console.error('Reconnect failed:', error);
      });
    }, delay);
  }

  async subscribeToStateChanges(): Promise<void> {
    const id = this.messageId++;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, {
        resolve: () => resolve(),
        reject,
      });

      this.ws?.send(JSON.stringify({
        id,
        type: 'subscribe_events',
        event_type: 'state_changed',
      }));
    });
  }

  async getStates(): Promise<HAEntityState[]> {
    const id = this.messageId++;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, {
        resolve: (result) => resolve(result as HAEntityState[]),
        reject,
      });

      this.ws?.send(JSON.stringify({
        id,
        type: 'get_states',
      }));
    });
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.connected = false;
    this.authenticated = false;
  }

  isConnected(): boolean {
    return this.connected && this.authenticated;
  }
}
```

**Step 3: Verify files exist**

Run: `ls server/src/services/ && ls server/src/types/`

Expected: HomeAssistant.ts in services/, homeassistant.ts in types/

**Step 4: Commit**

```bash
git add server/src/services/HomeAssistant.ts server/src/types/homeassistant.ts
git commit -m "feat(server): add Home Assistant WebSocket service"
```

---

## Task 2: Create Entity Discovery Service

**Files:**
- Create: `server/src/services/EntityDiscovery.ts`

**Step 1: Create EntityDiscovery service**

Create file `server/src/services/EntityDiscovery.ts`:

```typescript
import type { HAEntityState } from '../types/homeassistant.js';

export interface DiscoveredPrinter {
  entityPrefix: string;
  displayName: string;
  model: string;
  entityCount: number;
  entities: string[];
}

export interface DiscoveredAMS {
  entityPrefix: string;
  displayName: string;
  trayCount: number;
  associatedPrinter: string | null;
}

// Known printer sensor suffixes from ha_bambulab integration
const PRINTER_SUFFIXES = [
  '_print_progress',
  '_print_status',
  '_current_layer',
  '_total_layer_count',
  '_nozzle_temperature',
  '_bed_temperature',
  '_remaining_time',
  '_subtask_name',
  '_speed_profile',
  '_stage',
];

// Model detection patterns
const MODEL_PATTERNS: Record<string, string> = {
  x1c: 'X1 Carbon',
  x1: 'X1',
  p1s: 'P1S',
  p1p: 'P1P',
  a1: 'A1',
  a1m: 'A1 Mini',
  h2s: 'H2S',
  h2d: 'H2D',
};

export class EntityDiscoveryService {
  /**
   * Discover printers from Home Assistant entities
   */
  static discoverPrinters(entities: HAEntityState[]): DiscoveredPrinter[] {
    const prefixMap = new Map<string, Set<string>>();

    // Find all sensor entities matching printer suffixes
    for (const entity of entities) {
      if (!entity.entity_id.startsWith('sensor.')) continue;

      for (const suffix of PRINTER_SUFFIXES) {
        if (entity.entity_id.endsWith(suffix)) {
          const prefix = entity.entity_id
            .replace('sensor.', '')
            .replace(suffix, '');

          if (!prefixMap.has(prefix)) {
            prefixMap.set(prefix, new Set());
          }
          prefixMap.get(prefix)!.add(entity.entity_id);
          break;
        }
      }
    }

    // Convert to DiscoveredPrinter array
    const printers: DiscoveredPrinter[] = [];

    for (const [prefix, entitySet] of prefixMap) {
      // Only consider prefixes with at least 3 matching entities
      if (entitySet.size < 3) continue;

      const model = this.detectModel(prefix);

      printers.push({
        entityPrefix: prefix,
        displayName: this.formatDisplayName(prefix, model),
        model,
        entityCount: entitySet.size,
        entities: Array.from(entitySet),
      });
    }

    // Sort by entity count (most complete first)
    return printers.sort((a, b) => b.entityCount - a.entityCount);
  }

  /**
   * Discover AMS units from Home Assistant entities
   */
  static discoverAMS(entities: HAEntityState[]): DiscoveredAMS[] {
    const amsMap = new Map<string, Set<number>>();

    // Find AMS tray entities (pattern: sensor.{prefix}_tray_{1-4})
    const trayPattern = /^sensor\.(.+)_tray_(\d+)$/;

    for (const entity of entities) {
      const match = entity.entity_id.match(trayPattern);
      if (match) {
        const prefix = match[1];
        const trayNum = parseInt(match[2], 10);

        if (!amsMap.has(prefix)) {
          amsMap.set(prefix, new Set());
        }
        amsMap.get(prefix)!.add(trayNum);
      }
    }

    // Convert to DiscoveredAMS array
    const amsUnits: DiscoveredAMS[] = [];

    for (const [prefix, trays] of amsMap) {
      amsUnits.push({
        entityPrefix: prefix,
        displayName: this.formatAMSName(prefix),
        trayCount: trays.size,
        associatedPrinter: this.findAssociatedPrinter(prefix),
      });
    }

    return amsUnits;
  }

  /**
   * Detect printer model from prefix
   */
  private static detectModel(prefix: string): string {
    const lowerPrefix = prefix.toLowerCase();

    for (const [pattern, model] of Object.entries(MODEL_PATTERNS)) {
      if (lowerPrefix.includes(pattern)) {
        return model;
      }
    }

    return 'Unknown';
  }

  /**
   * Format a human-readable display name
   */
  private static formatDisplayName(prefix: string, model: string): string {
    if (model !== 'Unknown') {
      return `Bambu Lab ${model}`;
    }
    // Capitalize and replace underscores with spaces
    return prefix
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  /**
   * Format AMS display name
   */
  private static formatAMSName(prefix: string): string {
    // Check if prefix contains ams identifier
    if (prefix.toLowerCase().includes('ams')) {
      return prefix
        .split('_')
        .map(word => word.toUpperCase() === 'AMS' ? 'AMS' : word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
    }
    return `AMS (${prefix})`;
  }

  /**
   * Try to find associated printer for an AMS unit
   */
  private static findAssociatedPrinter(amsPrefix: string): string | null {
    // AMS prefixes often share a base with the printer
    // e.g., printer: h2s, ams: h2s_ams or h2s_ams_2
    const parts = amsPrefix.split('_');

    // Remove 'ams' and any numbers to get potential printer prefix
    const filtered = parts.filter(p =>
      p.toLowerCase() !== 'ams' && !/^\d+$/.test(p)
    );

    return filtered.length > 0 ? filtered.join('_') : null;
  }
}
```

**Step 2: Verify file exists**

Run: `cat server/src/services/EntityDiscovery.ts | head -30`

Expected: EntityDiscoveryService class definition visible

**Step 3: Commit**

```bash
git add server/src/services/EntityDiscovery.ts
git commit -m "feat(server): add entity discovery service for printers and AMS"
```

---

## Task 3: Add Discovery API Endpoint

**Files:**
- Create: `server/src/routes/discovery.ts`
- Modify: `server/src/index.ts`

**Step 1: Create discovery route**

Create file `server/src/routes/discovery.ts`:

```typescript
import { Router } from 'express';
import { z } from 'zod';
import { HomeAssistantService } from '../services/HomeAssistant.js';
import { EntityDiscoveryService } from '../services/EntityDiscovery.js';

const router = Router();

const scanSchema = z.object({
  haUrl: z.string().url(),
  haToken: z.string().min(1),
});

router.post('/scan', async (req, res) => {
  const parsed = scanSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { haUrl, haToken } = parsed.data;

  const ha = new HomeAssistantService();

  try {
    // Connect to Home Assistant
    await ha.connect({ url: haUrl, token: haToken });

    // Fetch all entities
    const entities = await ha.getStates();

    // Discover printers and AMS units
    const printers = EntityDiscoveryService.discoverPrinters(entities);
    const amsUnits = EntityDiscoveryService.discoverAMS(entities);

    // Disconnect after discovery
    ha.disconnect();

    return res.json({
      success: true,
      printers,
      amsUnits,
      totalEntities: entities.length,
    });
  } catch (error) {
    ha.disconnect();

    return res.status(500).json({
      success: false,
      error: 'Discovery failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

export default router;
```

**Step 2: Wire discovery route into main app**

Update `server/src/index.ts` - add import and route:

```typescript
// Add this import at the top (after authRoutes)
import discoveryRoutes from './routes/discovery.js';

// Add this after app.use('/api/auth', authRoutes)
app.use('/api/discovery', discoveryRoutes);
```

**Step 3: Verify server compiles**

Run: `cd server && npm run build`

Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add server/src/routes/discovery.ts server/src/index.ts
git commit -m "feat(server): add discovery API endpoint for finding printers"
```

---

## Task 4: Create Discovery Service Tests

**Files:**
- Create: `server/tests/discovery.test.ts`

**Step 1: Create test file**

Create file `server/tests/discovery.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import { EntityDiscoveryService } from '../src/services/EntityDiscovery.js';
import type { HAEntityState } from '../src/types/homeassistant.js';

// Mock entity data simulating ha_bambulab integration
const mockEntities: HAEntityState[] = [
  // H2S printer entities
  { entity_id: 'sensor.h2s_print_progress', state: '45', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_print_status', state: 'running', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_current_layer', state: '67', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_total_layer_count', state: '150', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_nozzle_temperature', state: '220', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_bed_temperature', state: '60', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_remaining_time', state: '3600', attributes: {}, last_changed: '', last_updated: '' },

  // AMS entities
  { entity_id: 'sensor.h2s_ams_tray_1', state: 'PLA', attributes: { color: '#FF0000' }, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_2', state: 'PETG', attributes: { color: '#00FF00' }, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_3', state: 'empty', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_4', state: 'ABS', attributes: { color: '#0000FF' }, last_changed: '', last_updated: '' },

  // Non-printer entities (should be ignored)
  { entity_id: 'sensor.living_room_temperature', state: '22', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'light.bedroom', state: 'on', attributes: {}, last_changed: '', last_updated: '' },
];

describe('EntityDiscoveryService', () => {
  describe('discoverPrinters', () => {
    it('discovers printers from entities', () => {
      const printers = EntityDiscoveryService.discoverPrinters(mockEntities);

      expect(printers).toHaveLength(1);
      expect(printers[0].entityPrefix).toBe('h2s');
      expect(printers[0].model).toBe('H2S');
      expect(printers[0].entityCount).toBeGreaterThanOrEqual(5);
    });

    it('returns empty array for no matching entities', () => {
      const nonPrinterEntities: HAEntityState[] = [
        { entity_id: 'sensor.temperature', state: '22', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'light.bedroom', state: 'on', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const printers = EntityDiscoveryService.discoverPrinters(nonPrinterEntities);
      expect(printers).toHaveLength(0);
    });

    it('detects correct model from prefix', () => {
      const x1cEntities: HAEntityState[] = [
        { entity_id: 'sensor.bambu_x1c_print_progress', state: '0', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_print_status', state: 'idle', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_current_layer', state: '0', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_nozzle_temperature', state: '25', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const printers = EntityDiscoveryService.discoverPrinters(x1cEntities);
      expect(printers).toHaveLength(1);
      expect(printers[0].model).toBe('X1 Carbon');
    });
  });

  describe('discoverAMS', () => {
    it('discovers AMS units from tray entities', () => {
      const amsUnits = EntityDiscoveryService.discoverAMS(mockEntities);

      expect(amsUnits).toHaveLength(1);
      expect(amsUnits[0].entityPrefix).toBe('h2s_ams');
      expect(amsUnits[0].trayCount).toBe(4);
    });

    it('returns empty array for no AMS entities', () => {
      const noAmsEntities: HAEntityState[] = [
        { entity_id: 'sensor.h2s_print_progress', state: '45', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const amsUnits = EntityDiscoveryService.discoverAMS(noAmsEntities);
      expect(amsUnits).toHaveLength(0);
    });
  });
});
```

**Step 2: Run tests**

Run: `cd server && npm run test:run`

Expected: All tests pass

**Step 3: Commit**

```bash
git add server/tests/discovery.test.ts
git commit -m "test(server): add entity discovery service tests"
```

---

## Task 5: Create iOS PrinterState Model

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Models/PrinterState.swift`

**Step 1: Create PrinterState.swift**

Create file `ios/PrinterMonitor/PrinterMonitor/Core/Models/PrinterState.swift`:

```swift
import Foundation

/// Represents the current state of a 3D printer
struct PrinterState: Codable, Equatable {
    // MARK: - Print Job Info

    let progress: Int              // 0-100
    let currentLayer: Int
    let totalLayers: Int
    let remainingSeconds: Int
    let filename: String?
    let status: PrintStatus

    // MARK: - Temperatures

    let nozzleTemp: Int
    let bedTemp: Int
    let chamberTemp: Int?

    // MARK: - Printer Info

    let printerName: String
    let printerModel: PrinterModel
    let isOnline: Bool

    // MARK: - Computed Properties

    var formattedTimeRemaining: String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var estimatedCompletion: Date {
        Date().addingTimeInterval(TimeInterval(remainingSeconds))
    }

    var formattedETA: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: estimatedCompletion)
    }

    var layerProgress: String {
        "\(currentLayer)/\(totalLayers)"
    }

    // MARK: - Static

    static let placeholder = PrinterState(
        progress: 0,
        currentLayer: 0,
        totalLayers: 0,
        remainingSeconds: 0,
        filename: nil,
        status: .idle,
        nozzleTemp: 0,
        bedTemp: 0,
        chamberTemp: nil,
        printerName: "Printer",
        printerModel: .unknown,
        isOnline: false
    )
}

// MARK: - Print Status

enum PrintStatus: String, Codable, CaseIterable {
    case idle
    case running
    case paused
    case completed = "complete"
    case failed
    case cancelled
    case preparing
    case unknown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Printing"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .preparing: return "Preparing"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "moon.zzz"
        case .running: return "printer.fill"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        case .preparing: return "gear"
        case .unknown: return "questionmark.circle"
        }
    }

    var isActive: Bool {
        self == .running || self == .paused || self == .preparing
    }
}

// MARK: - Printer Model

enum PrinterModel: String, Codable, CaseIterable {
    case x1Carbon = "X1 Carbon"
    case x1 = "X1"
    case p1s = "P1S"
    case p1p = "P1P"
    case a1 = "A1"
    case a1Mini = "A1 Mini"
    case h2s = "H2S"
    case h2d = "H2D"
    case unknown = "Unknown"

    var displayName: String { rawValue }
}
```

**Step 2: Verify file exists**

Run: `cat ios/PrinterMonitor/PrinterMonitor/Core/Models/PrinterState.swift | head -30`

Expected: PrinterState struct definition visible

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Models/
git commit -m "feat(ios): add PrinterState model with status and model enums"
```

---

## Task 6: Create iOS Onboarding View

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/Setup/ConnectionSetupView.swift`
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/Setup/PrinterSelectionView.swift`

**Step 1: Create ConnectionSetupView**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Setup/ConnectionSetupView.swift`:

```swift
import SwiftUI

struct ConnectionSetupView: View {
    @State private var haURL = ""
    @State private var haToken = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var showPrinterSelection = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Assistant URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("http://homeassistant.local:8123", text: $haURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Long-Lived Access Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Enter your token", text: $haToken)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Connection Details")
            } footer: {
                Text("You can create a long-lived access token in Home Assistant under Profile → Security → Long-Lived Access Tokens")
            }

            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: validateConnection) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isValidating ? "Validating..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(haURL.isEmpty || haToken.isEmpty || isValidating)
            }
        }
        .navigationTitle("Setup")
        .navigationDestination(isPresented: $showPrinterSelection) {
            PrinterSelectionView(haURL: haURL, haToken: haToken)
        }
    }

    private func validateConnection() {
        isValidating = true
        validationError = nil

        // TODO: Call API to validate connection
        // For now, simulate validation
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isValidating = false

                // Basic URL validation
                if !haURL.hasPrefix("http://") && !haURL.hasPrefix("https://") {
                    validationError = "URL must start with http:// or https://"
                    return
                }

                showPrinterSelection = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionSetupView()
    }
}
```

**Step 2: Create PrinterSelectionView**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Setup/PrinterSelectionView.swift`:

```swift
import SwiftUI

struct DiscoveredPrinter: Identifiable, Codable {
    let id = UUID()
    let entityPrefix: String
    let displayName: String
    let model: String
    let entityCount: Int

    enum CodingKeys: String, CodingKey {
        case entityPrefix, displayName, model, entityCount
    }
}

struct PrinterSelectionView: View {
    let haURL: String
    let haToken: String

    @State private var isScanning = true
    @State private var printers: [DiscoveredPrinter] = []
    @State private var selectedPrinter: DiscoveredPrinter?
    @State private var scanError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning for printers...")
                            .padding(.leading, 8)
                    }
                }
            } else if let error = scanError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)

                    Button("Retry") {
                        scanForPrinters()
                    }
                }
            } else if printers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "printer.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No printers found")
                            .font(.headline)
                        Text("Make sure ha_bambulab is installed and configured in Home Assistant")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            } else {
                Section("Select Your Printer") {
                    ForEach(printers) { printer in
                        Button(action: { selectPrinter(printer) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(printer.displayName)
                                        .font(.headline)
                                    Text(printer.entityPrefix)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedPrinter?.entityPrefix == printer.entityPrefix {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Printer")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    // TODO: Save selection and dismiss
                    dismiss()
                }
                .disabled(selectedPrinter == nil)
            }
        }
        .onAppear {
            scanForPrinters()
        }
    }

    private func scanForPrinters() {
        isScanning = true
        scanError = nil

        // TODO: Call API to discover printers
        // For now, simulate with mock data
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                isScanning = false

                // Mock data for development
                printers = [
                    DiscoveredPrinter(
                        entityPrefix: "h2s",
                        displayName: "Bambu Lab H2S",
                        model: "H2S",
                        entityCount: 15
                    )
                ]
            }
        }
    }

    private func selectPrinter(_ printer: DiscoveredPrinter) {
        selectedPrinter = printer
    }
}

#Preview {
    NavigationStack {
        PrinterSelectionView(haURL: "http://localhost:8123", haToken: "test")
    }
}
```

**Step 3: Update SettingsView to link to setup**

Update `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    NavigationLink("Home Assistant") {
                        ConnectionSetupView()
                    }
                }

                Section("Notifications") {
                    NavigationLink("Notification Settings") {
                        Text("Notification Settings")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
```

**Step 4: Verify files exist**

Run: `ls ios/PrinterMonitor/PrinterMonitor/Features/Setup/`

Expected: ConnectionSetupView.swift, PrinterSelectionView.swift

**Step 5: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Setup/
git add ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift
git commit -m "feat(ios): add onboarding flow with HA connection and printer selection"
```

---

## Task 7: Wire iOS APIClient to Discovery Endpoint

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`

**Step 1: Add discovery method to APIClient**

Update `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift` - add these types and methods:

```swift
// Add to APIClient class

// MARK: - Discovery

func discoverPrinters(haURL: String, haToken: String) async throws -> DiscoveryResponse {
    let body = DiscoveryRequest(haUrl: haURL, haToken: haToken)
    let data = try await request(endpoint: "/api/discovery/scan", method: .post, body: body)
    return try JSONDecoder().decode(DiscoveryResponse.self, from: data)
}

// Add to Supporting Types extension

struct DiscoveryRequest: Codable {
    let haUrl: String
    let haToken: String
}

struct DiscoveryResponse: Codable {
    let success: Bool
    let printers: [DiscoveredPrinterDTO]
    let amsUnits: [DiscoveredAMSDTO]
    let totalEntities: Int
}

struct DiscoveredPrinterDTO: Codable, Identifiable {
    var id: String { entityPrefix }
    let entityPrefix: String
    let displayName: String
    let model: String
    let entityCount: Int
}

struct DiscoveredAMSDTO: Codable, Identifiable {
    var id: String { entityPrefix }
    let entityPrefix: String
    let displayName: String
    let trayCount: Int
    let associatedPrinter: String?
}
```

**Step 2: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git commit -m "feat(ios): add discovery endpoint to APIClient"
```

---

## Task 8: Create Settings Storage

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Storage/SettingsStorage.swift`

**Step 1: Create SettingsStorage**

Create file `ios/PrinterMonitor/PrinterMonitor/Core/Storage/SettingsStorage.swift`:

```swift
import Foundation

/// Manages persistent storage of app settings
@Observable
final class SettingsStorage {
    // MARK: - Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let haURL = "haURL"
        static let haToken = "haToken"
        static let selectedPrinterPrefix = "selectedPrinterPrefix"
        static let selectedPrinterName = "selectedPrinterName"
        static let isOnboardingComplete = "isOnboardingComplete"
        static let temperatureUnit = "temperatureUnit"
        static let use24HourTime = "use24HourTime"
    }

    // MARK: - Properties

    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Keys.serverURL) }
    }

    var haURL: String {
        didSet { defaults.set(haURL, forKey: Keys.haURL) }
    }

    var haToken: String {
        didSet {
            // Store token in Keychain in production
            // For now, use UserDefaults (not secure, but fine for dev)
            defaults.set(haToken, forKey: Keys.haToken)
        }
    }

    var selectedPrinterPrefix: String? {
        didSet { defaults.set(selectedPrinterPrefix, forKey: Keys.selectedPrinterPrefix) }
    }

    var selectedPrinterName: String? {
        didSet { defaults.set(selectedPrinterName, forKey: Keys.selectedPrinterName) }
    }

    var isOnboardingComplete: Bool {
        didSet { defaults.set(isOnboardingComplete, forKey: Keys.isOnboardingComplete) }
    }

    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    var use24HourTime: Bool {
        didSet { defaults.set(use24HourTime, forKey: Keys.use24HourTime) }
    }

    // MARK: - Private

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted values
        self.serverURL = defaults.string(forKey: Keys.serverURL) ?? ""
        self.haURL = defaults.string(forKey: Keys.haURL) ?? ""
        self.haToken = defaults.string(forKey: Keys.haToken) ?? ""
        self.selectedPrinterPrefix = defaults.string(forKey: Keys.selectedPrinterPrefix)
        self.selectedPrinterName = defaults.string(forKey: Keys.selectedPrinterName)
        self.isOnboardingComplete = defaults.bool(forKey: Keys.isOnboardingComplete)
        self.temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Keys.temperatureUnit) ?? "") ?? .celsius
        self.use24HourTime = defaults.bool(forKey: Keys.use24HourTime)
    }

    // MARK: - Methods

    func reset() {
        serverURL = ""
        haURL = ""
        haToken = ""
        selectedPrinterPrefix = nil
        selectedPrinterName = nil
        isOnboardingComplete = false
        temperatureUnit = .celsius
        use24HourTime = false
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !haURL.isEmpty && !haToken.isEmpty && selectedPrinterPrefix != nil
    }
}

// MARK: - Temperature Unit

enum TemperatureUnit: String, CaseIterable {
    case celsius = "C"
    case fahrenheit = "F"

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    func convert(_ celsius: Int) -> Int {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return Int(Double(celsius) * 9/5 + 32)
        }
    }
}
```

**Step 2: Verify file exists**

Run: `cat ios/PrinterMonitor/PrinterMonitor/Core/Storage/SettingsStorage.swift | head -30`

Expected: SettingsStorage class definition visible

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Storage/
git commit -m "feat(ios): add SettingsStorage for persisting app configuration"
```

---

## Phase 2 Complete Checkpoint

At this point you should have:

**Server:**
- HomeAssistant WebSocket service
- Entity discovery service with pattern matching
- `/api/discovery/scan` endpoint
- Tests for discovery service

**iOS:**
- PrinterState model
- Connection setup view (HA URL + token entry)
- Printer selection view (shows discovered printers)
- APIClient with discovery method
- SettingsStorage for persistence

**To Test:**

1. Start server: `cd server && npm run dev`
2. Test discovery endpoint (requires real HA):
```bash
curl -X POST http://localhost:3000/api/discovery/scan \
  -H "Content-Type: application/json" \
  -d '{"haUrl": "http://YOUR_HA_IP:8123", "haToken": "YOUR_TOKEN"}'
```

3. Open iOS app in simulator, navigate to Settings → Home Assistant

---

## Next Steps

Phase 3 will implement:
- Real-time WebSocket subscription on server
- PrintMonitor service for state change detection
- Dashboard view with live printer data
- Pull-to-refresh functionality
