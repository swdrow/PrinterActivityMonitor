# Phase 3: Core Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a live dashboard displaying real-time printer state, with server-side state caching and polling-based updates.

**Architecture:** Server maintains WebSocket connection to HA, caches printer state, exposes REST endpoint. iOS polls this endpoint and displays the data.

**Tech Stack:**
- Server: Express routes, in-memory state cache, WebSocket subscriptions
- iOS: SwiftUI views, `@Observable` view model, async/await polling

**Prerequisites:**
- Phase 2 complete (discovery working, HA WebSocket verified)
- User has HA URL + token configured
- At least one printer discovered

---

## Task 1: Fix AMS Association Logic

**Problem:** Discovery returned `"associatedPrinter": "pro"` for `ams_2_pro` instead of `"h2s"`.

**Files:**
- Modify: `server/src/services/EntityDiscovery.ts`

**Step 1: Update findAssociatedPrinter method**

The current logic strips "ams" and numbers, but needs to also check against known printer prefixes. Update the method:

```typescript
/**
 * Try to find associated printer for an AMS unit
 * Now accepts discovered printer prefixes for smarter matching
 */
static findAssociatedPrinter(
  amsPrefix: string,
  knownPrinterPrefixes: string[] = []
): string | null {
  // First try: check if any known printer prefix is contained in the AMS prefix
  for (const printerPrefix of knownPrinterPrefixes) {
    if (amsPrefix.toLowerCase().includes(printerPrefix.toLowerCase())) {
      return printerPrefix;
    }
  }

  // Fallback: original logic - remove 'ams' and numbers
  const parts = amsPrefix.split('_');
  const filtered = parts.filter(p =>
    p.toLowerCase() !== 'ams' && !/^\d+$/.test(p) && p.toLowerCase() !== 'pro'
  );

  return filtered.length > 0 ? filtered.join('_') : null;
}
```

**Step 2: Update discoverAMS to pass printer prefixes**

Modify the discoverAMS method signature and call:

```typescript
static discoverAMS(
  entities: HAEntityState[],
  knownPrinterPrefixes: string[] = []
): DiscoveredAMS[] {
  // ... existing tray discovery logic ...

  // Update the loop to use new method
  for (const [prefix, trays] of amsMap) {
    amsUnits.push({
      entityPrefix: prefix,
      displayName: this.formatAMSName(prefix),
      trayCount: trays.size,
      associatedPrinter: this.findAssociatedPrinter(prefix, knownPrinterPrefixes),
    });
  }

  return amsUnits;
}
```

**Step 3: Update discovery route to pass printer prefixes**

Update `server/src/routes/discovery.ts`:

```typescript
// After discovering printers, pass their prefixes to AMS discovery
const printers = EntityDiscoveryService.discoverPrinters(entities);
const printerPrefixes = printers.map(p => p.entityPrefix);
const amsUnits = EntityDiscoveryService.discoverAMS(entities, printerPrefixes);
```

**Step 4: Update test for new signature**

Update `server/tests/discovery.test.ts` to pass known prefixes:

```typescript
it('discovers AMS units from tray entities', () => {
  const amsUnits = EntityDiscoveryService.discoverAMS(mockEntities, ['h2s']);

  expect(amsUnits).toHaveLength(1);
  expect(amsUnits[0].entityPrefix).toBe('h2s_ams');
  expect(amsUnits[0].trayCount).toBe(4);
  expect(amsUnits[0].associatedPrinter).toBe('h2s');
});
```

**Step 5: Run tests**

Run: `cd server && npm run test:run`

Expected: All tests pass

**Step 6: Commit**

```bash
git add server/src/services/EntityDiscovery.ts server/src/routes/discovery.ts server/tests/discovery.test.ts
git commit -m "fix(server): improve AMS-to-printer association with prefix matching"
```

---

## Task 2: Create PrinterMonitor Service

**Files:**
- Create: `server/src/services/PrinterMonitor.ts`

**Step 1: Create PrinterMonitor service**

This service maintains a persistent connection to HA and caches printer state.

Create file `server/src/services/PrinterMonitor.ts`:

```typescript
import { EventEmitter } from 'events';
import { HomeAssistantService, StateChangeEvent } from './HomeAssistant.js';
import type { HAEntityState } from '../types/homeassistant.js';

export interface PrinterStateCache {
  entityPrefix: string;
  progress: number;
  currentLayer: number;
  totalLayers: number;
  remainingSeconds: number;
  status: string;
  nozzleTemp: number;
  bedTemp: number;
  subtaskName: string | null;
  speedProfile: string | null;
  lastUpdated: Date;
  isOnline: boolean;
}

export interface PrinterMonitorConfig {
  haUrl: string;
  haToken: string;
  printerPrefixes: string[];
}

export class PrinterMonitor extends EventEmitter {
  private ha: HomeAssistantService;
  private config: PrinterMonitorConfig | null = null;
  private stateCache: Map<string, PrinterStateCache> = new Map();
  private isRunning = false;

  constructor() {
    super();
    this.ha = new HomeAssistantService();
  }

  async start(config: PrinterMonitorConfig): Promise<void> {
    this.config = config;

    try {
      // Connect to Home Assistant
      await this.ha.connect({ url: config.haUrl, token: config.haToken });

      // Get initial state
      const states = await this.ha.getStates();
      this.initializeCache(states, config.printerPrefixes);

      // Subscribe to state changes
      await this.ha.subscribeToStateChanges();

      // Handle state change events
      this.ha.on('state_changed', (event: StateChangeEvent) => {
        this.handleStateChange(event);
      });

      this.ha.on('disconnected', () => {
        this.emit('disconnected');
      });

      this.isRunning = true;
      this.emit('started');

      console.log(`PrinterMonitor started for prefixes: ${config.printerPrefixes.join(', ')}`);
    } catch (error) {
      console.error('Failed to start PrinterMonitor:', error);
      throw error;
    }
  }

  stop(): void {
    this.ha.disconnect();
    this.stateCache.clear();
    this.isRunning = false;
    this.emit('stopped');
  }

  getState(entityPrefix: string): PrinterStateCache | null {
    return this.stateCache.get(entityPrefix) ?? null;
  }

  getAllStates(): PrinterStateCache[] {
    return Array.from(this.stateCache.values());
  }

  isConnected(): boolean {
    return this.isRunning && this.ha.isConnected();
  }

  private initializeCache(states: HAEntityState[], prefixes: string[]): void {
    for (const prefix of prefixes) {
      const cache = this.buildCacheFromStates(prefix, states);
      if (cache) {
        this.stateCache.set(prefix, cache);
      }
    }
  }

  private buildCacheFromStates(prefix: string, states: HAEntityState[]): PrinterStateCache | null {
    const find = (suffix: string): HAEntityState | undefined =>
      states.find(s => s.entity_id === `sensor.${prefix}${suffix}`);

    const progressEntity = find('_print_progress');
    if (!progressEntity) {
      return null; // Not a valid printer prefix
    }

    return {
      entityPrefix: prefix,
      progress: this.parseNumber(find('_print_progress')?.state, 0),
      currentLayer: this.parseNumber(find('_current_layer')?.state, 0),
      totalLayers: this.parseNumber(find('_total_layer_count')?.state, 0),
      remainingSeconds: this.parseNumber(find('_remaining_time')?.state, 0),
      status: find('_print_status')?.state ?? 'unknown',
      nozzleTemp: this.parseNumber(find('_nozzle_temperature')?.state, 0),
      bedTemp: this.parseNumber(find('_bed_temperature')?.state, 0),
      subtaskName: find('_subtask_name')?.state ?? null,
      speedProfile: find('_speed_profile')?.state ?? null,
      lastUpdated: new Date(),
      isOnline: true,
    };
  }

  private handleStateChange(event: StateChangeEvent): void {
    const { entityId, newState, attributes } = event;

    // Check if this entity belongs to a monitored printer
    for (const prefix of this.config?.printerPrefixes ?? []) {
      if (entityId.startsWith(`sensor.${prefix}_`)) {
        this.updateCacheFromEvent(prefix, entityId, newState, attributes);
        break;
      }
    }
  }

  private updateCacheFromEvent(
    prefix: string,
    entityId: string,
    newState: string | null,
    attributes: Record<string, unknown>
  ): void {
    let cache = this.stateCache.get(prefix);
    if (!cache) {
      cache = this.createEmptyCache(prefix);
      this.stateCache.set(prefix, cache);
    }

    const suffix = entityId.replace(`sensor.${prefix}`, '');
    const value = newState ?? '';

    switch (suffix) {
      case '_print_progress':
        cache.progress = this.parseNumber(value, cache.progress);
        break;
      case '_current_layer':
        cache.currentLayer = this.parseNumber(value, cache.currentLayer);
        break;
      case '_total_layer_count':
        cache.totalLayers = this.parseNumber(value, cache.totalLayers);
        break;
      case '_remaining_time':
        cache.remainingSeconds = this.parseNumber(value, cache.remainingSeconds);
        break;
      case '_print_status':
        const oldStatus = cache.status;
        cache.status = value;
        if (oldStatus !== value) {
          this.emit('status_changed', { prefix, oldStatus, newStatus: value });
        }
        break;
      case '_nozzle_temperature':
        cache.nozzleTemp = this.parseNumber(value, cache.nozzleTemp);
        break;
      case '_bed_temperature':
        cache.bedTemp = this.parseNumber(value, cache.bedTemp);
        break;
      case '_subtask_name':
        cache.subtaskName = value || null;
        break;
      case '_speed_profile':
        cache.speedProfile = value || null;
        break;
    }

    cache.lastUpdated = new Date();
    this.emit('state_updated', { prefix, state: cache });
  }

  private createEmptyCache(prefix: string): PrinterStateCache {
    return {
      entityPrefix: prefix,
      progress: 0,
      currentLayer: 0,
      totalLayers: 0,
      remainingSeconds: 0,
      status: 'unknown',
      nozzleTemp: 0,
      bedTemp: 0,
      subtaskName: null,
      speedProfile: null,
      lastUpdated: new Date(),
      isOnline: true,
    };
  }

  private parseNumber(value: string | undefined | null, fallback: number): number {
    if (!value || value === 'unknown' || value === 'unavailable') {
      return fallback;
    }
    const num = parseFloat(value);
    return isNaN(num) ? fallback : Math.round(num);
  }
}
```

**Step 2: Verify file exists**

Run: `ls -la server/src/services/PrinterMonitor.ts`

Expected: File exists

**Step 3: Commit**

```bash
git add server/src/services/PrinterMonitor.ts
git commit -m "feat(server): add PrinterMonitor service with state caching"
```

---

## Task 3: Add Printer State API Endpoint

**Files:**
- Create: `server/src/routes/printers.ts`
- Modify: `server/src/index.ts`

**Step 1: Create printers route**

Create file `server/src/routes/printers.ts`:

```typescript
import { Router } from 'express';
import { PrinterMonitor } from '../services/PrinterMonitor.js';

const router = Router();

// Global printer monitor instance (will be set by app startup)
let printerMonitor: PrinterMonitor | null = null;

export function setPrinterMonitor(monitor: PrinterMonitor): void {
  printerMonitor = monitor;
}

router.get('/state', (req, res) => {
  if (!printerMonitor || !printerMonitor.isConnected()) {
    return res.status(503).json({
      success: false,
      error: 'Printer monitor not connected',
    });
  }

  const states = printerMonitor.getAllStates();

  return res.json({
    success: true,
    connected: true,
    printers: states,
    timestamp: new Date().toISOString(),
  });
});

router.get('/state/:prefix', (req, res) => {
  if (!printerMonitor || !printerMonitor.isConnected()) {
    return res.status(503).json({
      success: false,
      error: 'Printer monitor not connected',
    });
  }

  const { prefix } = req.params;
  const state = printerMonitor.getState(prefix);

  if (!state) {
    return res.status(404).json({
      success: false,
      error: `Printer with prefix '${prefix}' not found`,
    });
  }

  return res.json({
    success: true,
    printer: state,
    timestamp: new Date().toISOString(),
  });
});

export default router;
```

**Step 2: Wire route into main app**

Update `server/src/index.ts` to add the route:

```typescript
// Add import at top
import printerRoutes from './routes/printers.js';

// Add route after discovery routes
app.use('/api/printers', printerRoutes);
```

**Step 3: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds

**Step 4: Commit**

```bash
git add server/src/routes/printers.ts server/src/index.ts
git commit -m "feat(server): add /api/printers/state endpoint"
```

---

## Task 4: Create Start Monitor Endpoint

**Files:**
- Create: `server/src/routes/monitor.ts`
- Modify: `server/src/index.ts`

**Step 1: Create monitor control route**

This allows the iOS app to start/stop the monitor with HA credentials.

Create file `server/src/routes/monitor.ts`:

```typescript
import { Router } from 'express';
import { z } from 'zod';
import { PrinterMonitor } from '../services/PrinterMonitor.js';
import { setPrinterMonitor } from './printers.js';

const router = Router();

let currentMonitor: PrinterMonitor | null = null;

const startSchema = z.object({
  haUrl: z.string().url(),
  haToken: z.string().min(1),
  printerPrefixes: z.array(z.string()).min(1),
});

router.post('/start', async (req, res) => {
  const parsed = startSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { haUrl, haToken, printerPrefixes } = parsed.data;

  // Stop existing monitor if running
  if (currentMonitor) {
    currentMonitor.stop();
  }

  try {
    currentMonitor = new PrinterMonitor();
    await currentMonitor.start({ haUrl, haToken, printerPrefixes });

    // Share with printers route
    setPrinterMonitor(currentMonitor);

    return res.json({
      success: true,
      message: 'Monitor started',
      monitoringPrefixes: printerPrefixes,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Failed to start monitor',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

router.post('/stop', (req, res) => {
  if (currentMonitor) {
    currentMonitor.stop();
    currentMonitor = null;
  }

  return res.json({
    success: true,
    message: 'Monitor stopped',
  });
});

router.get('/status', (req, res) => {
  return res.json({
    running: currentMonitor?.isConnected() ?? false,
    states: currentMonitor?.getAllStates() ?? [],
  });
});

export default router;
```

**Step 2: Wire into main app**

Update `server/src/index.ts`:

```typescript
// Add import
import monitorRoutes from './routes/monitor.js';

// Add route
app.use('/api/monitor', monitorRoutes);
```

**Step 3: Verify build**

Run: `cd server && npm run build`

Expected: Build succeeds

**Step 4: Commit**

```bash
git add server/src/routes/monitor.ts server/src/index.ts
git commit -m "feat(server): add monitor control endpoints (start/stop/status)"
```

---

## Task 5: Create iOS PrinterViewModel

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/PrinterViewModel.swift`

**Step 1: Create view model**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/PrinterViewModel.swift`:

```swift
import Foundation

/// View model for printer state and polling
@Observable
final class PrinterViewModel {
    // MARK: - Published State

    private(set) var printerState: PrinterState?
    private(set) var isLoading = false
    private(set) var isConnected = false
    private(set) var error: String?

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let settings: SettingsStorage
    private var pollingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    // MARK: - Public Methods

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchState()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second interval
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        await fetchState()
    }

    // MARK: - Private Methods

    private func fetchState() async {
        guard let printerPrefix = settings.selectedPrinterPrefix else {
            error = "No printer selected"
            return
        }

        do {
            isLoading = printerState == nil // Only show loading on first fetch
            let response = try await apiClient.getPrinterState(prefix: printerPrefix)

            await MainActor.run {
                self.printerState = PrinterState(
                    progress: response.progress,
                    currentLayer: response.currentLayer,
                    totalLayers: response.totalLayers,
                    remainingSeconds: response.remainingSeconds,
                    filename: response.subtaskName,
                    status: PrintStatus(rawValue: response.status) ?? .unknown,
                    nozzleTemp: response.nozzleTemp,
                    bedTemp: response.bedTemp,
                    chamberTemp: nil,
                    printerName: settings.selectedPrinterName ?? printerPrefix,
                    printerModel: .h2s, // TODO: Store model in settings
                    isOnline: response.isOnline
                )
                self.isConnected = true
                self.error = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isConnected = false
                self.isLoading = false
            }
        }
    }
}
```

**Step 2: Add API method to APIClient**

Update `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift` - add this method and response type:

```swift
// MARK: - Printer State

func getPrinterState(prefix: String) async throws -> PrinterStateResponse {
    let data = try await request(endpoint: "/api/printers/state/\(prefix)", method: .get)
    let wrapper = try JSONDecoder().decode(PrinterStateWrapper.self, from: data)
    return wrapper.printer
}

// Add to Supporting Types extension:

struct PrinterStateWrapper: Codable {
    let success: Bool
    let printer: PrinterStateResponse
}

struct PrinterStateResponse: Codable {
    let entityPrefix: String
    let progress: Int
    let currentLayer: Int
    let totalLayers: Int
    let remainingSeconds: Int
    let status: String
    let nozzleTemp: Int
    let bedTemp: Int
    let subtaskName: String?
    let speedProfile: String?
    let isOnline: Bool
}
```

**Step 3: Verify files exist**

Run: `ls ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/`

Expected: PrinterViewModel.swift present

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/PrinterViewModel.swift
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git commit -m "feat(ios): add PrinterViewModel with polling and APIClient state method"
```

---

## Task 6: Create Progress Ring Component

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Components/ProgressRing.swift`

**Step 1: Create ProgressRing**

Create file `ios/PrinterMonitor/PrinterMonitor/Components/ProgressRing.swift`:

```swift
import SwiftUI

/// Circular progress indicator with aurora gradient
struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, lineWidth: CGFloat = 12, size: CGFloat = 120) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Theme.Colors.backgroundCard,
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.auroraStart,
                            Theme.Colors.auroraMid,
                            Theme.Colors.auroraEnd,
                            Theme.Colors.auroraStart
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center content
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(Theme.Typography.numericLarge)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("%")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Theme.Colors.backgroundPrimary
            .ignoresSafeArea()

        VStack(spacing: 24) {
            ProgressRing(progress: 0.45)
            ProgressRing(progress: 0.75, lineWidth: 8, size: 80)
            ProgressRing(progress: 1.0, lineWidth: 16, size: 160)
        }
    }
}
```

**Step 2: Verify file exists**

Run: `ls ios/PrinterMonitor/PrinterMonitor/Components/ProgressRing.swift`

Expected: File exists

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Components/ProgressRing.swift
git commit -m "feat(ios): add ProgressRing component with aurora gradient"
```

---

## Task 7: Create StatCard Component

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Components/StatCard.swift`

**Step 1: Create StatCard**

Create file `ios/PrinterMonitor/PrinterMonitor/Components/StatCard.swift`:

```swift
import SwiftUI

/// Card displaying a single statistic with icon
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let secondaryValue: String?

    init(icon: String, label: String, value: String, secondaryValue: String? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)

                Text(label)
                    .font(Theme.Typography.labelSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let secondary = secondaryValue {
                    Text(secondary)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .cardBackground()
    }
}

/// Grid of stat cards
struct StatGrid: View {
    let stats: [StatItem]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(stats) { stat in
                StatCard(
                    icon: stat.icon,
                    label: stat.label,
                    value: stat.value,
                    secondaryValue: stat.secondaryValue
                )
            }
        }
    }
}

struct StatItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let secondaryValue: String?

    init(icon: String, label: String, value: String, secondaryValue: String? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
    }
}

#Preview {
    ZStack {
        Theme.Colors.backgroundPrimary
            .ignoresSafeArea()

        VStack(spacing: Theme.Spacing.md) {
            StatCard(icon: "timer", label: "Time Left", value: "1h 23m", secondaryValue: "~3:45 PM")
            StatCard(icon: "square.stack.3d.up", label: "Layer", value: "142", secondaryValue: "of 300")

            StatGrid(stats: [
                StatItem(icon: "thermometer.high", label: "Nozzle", value: "220°C"),
                StatItem(icon: "thermometer.low", label: "Bed", value: "60°C"),
                StatItem(icon: "gauge.with.dots.needle.bottom.50percent", label: "Speed", value: "Standard"),
                StatItem(icon: "square.stack.3d.up", label: "Layer", value: "142/300")
            ])
        }
        .padding()
    }
}
```

**Step 2: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Components/StatCard.swift
git commit -m "feat(ios): add StatCard and StatGrid components"
```

---

## Task 8: Update Dashboard View

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`

**Step 1: Update DashboardView with real data**

Replace the contents of `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @State private var viewModel: PrinterViewModel

    init(apiClient: APIClient, settings: SettingsStorage) {
        _viewModel = State(initialValue: PrinterViewModel(apiClient: apiClient, settings: settings))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                } else if let state = viewModel.printerState {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            // Status header
                            statusHeader(state: state)

                            // Progress ring (only when printing)
                            if state.status.isActive {
                                progressSection(state: state)
                            }

                            // Stats grid
                            statsSection(state: state)
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                } else {
                    ContentUnavailableView(
                        "No Printer Connected",
                        systemImage: "printer.fill",
                        description: Text("Configure your printer in Settings")
                    )
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionIndicator
                }
            }
        }
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func statusHeader(state: PrinterState) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: state.status.systemImage)
                    .foregroundStyle(statusColor(for: state.status))
                Text(state.status.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if let filename = state.filename {
                Text(filename)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Text(state.printerName)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassBackground()
    }

    @ViewBuilder
    private func progressSection(state: PrinterState) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressRing(
                progress: Double(state.progress) / 100.0,
                lineWidth: 14,
                size: 140
            )

            // Time info row
            HStack(spacing: Theme.Spacing.xl) {
                VStack {
                    Text(state.formattedTimeRemaining)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("remaining")
                        .font(Theme.Typography.labelSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                VStack {
                    Text(state.formattedETA)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("completion")
                        .font(Theme.Typography.labelSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassBackground()
    }

    @ViewBuilder
    private func statsSection(state: PrinterState) -> some View {
        StatGrid(stats: [
            StatItem(
                icon: "square.stack.3d.up",
                label: "Layer",
                value: "\(state.currentLayer)",
                secondaryValue: "of \(state.totalLayers)"
            ),
            StatItem(
                icon: "thermometer.high",
                label: "Nozzle",
                value: "\(state.nozzleTemp)°C"
            ),
            StatItem(
                icon: "thermometer.low",
                label: "Bed",
                value: "\(state.bedTemp)°C"
            ),
            StatItem(
                icon: "bolt.fill",
                label: "Status",
                value: state.isOnline ? "Online" : "Offline"
            )
        ])
    }

    @ViewBuilder
    private var connectionIndicator: some View {
        Circle()
            .fill(viewModel.isConnected ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }

    // MARK: - Helpers

    private func statusColor(for status: PrintStatus) -> Color {
        switch status {
        case .running: return Theme.Colors.success
        case .paused: return Theme.Colors.warning
        case .failed, .cancelled: return Theme.Colors.error
        case .completed: return Theme.Colors.accent
        default: return Theme.Colors.textSecondary
        }
    }
}

#Preview {
    DashboardView(apiClient: APIClient(), settings: SettingsStorage())
}
```

**Step 2: Update ContentView to inject dependencies**

Update `ios/PrinterMonitor/PrinterMonitor/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    let apiClient: APIClient
    let settings: SettingsStorage

    var body: some View {
        TabView {
            DashboardView(apiClient: apiClient, settings: settings)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    ContentView(apiClient: APIClient(), settings: SettingsStorage())
}
```

**Step 3: Update PrinterMonitorApp to create dependencies**

Update `ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift`:

```swift
import SwiftUI

@main
struct PrinterMonitorApp: App {
    @State private var apiClient = APIClient()
    @State private var settings = SettingsStorage()

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, settings: settings)
                .preferredColorScheme(.dark)
        }
    }
}
```

**Step 4: Regenerate Xcode project**

Run: `cd ios/PrinterMonitor && xcodegen generate`

Expected: Project regenerated successfully

**Step 5: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift
git add ios/PrinterMonitor/PrinterMonitor/App/ContentView.swift
git add ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift
git add ios/PrinterMonitor/PrinterMonitor.xcodeproj/
git commit -m "feat(ios): update Dashboard with live data, progress ring, and stat cards"
```

---

## Phase 3 Complete Checkpoint

At this point you should have:

**Server:**
- Fixed AMS association with better prefix matching
- PrinterMonitor service with real-time state caching
- `/api/printers/state` endpoint
- `/api/monitor/start|stop|status` endpoints

**iOS:**
- PrinterViewModel with polling
- ProgressRing component with aurora gradient
- StatCard and StatGrid components
- Dashboard with live printer data

**To Test:**

1. Start server and monitor:
```bash
cd server && npm run dev
```

2. Start the monitor (in another terminal):
```bash
curl -X POST http://localhost:3000/api/monitor/start \
  -H "Content-Type: application/json" \
  -d '{"haUrl": "http://YOUR_HA_IP:8123", "haToken": "YOUR_TOKEN", "printerPrefixes": ["h2s"]}'
```

3. Check state:
```bash
curl http://localhost:3000/api/printers/state
```

4. Open iOS app in simulator to see Dashboard

---

## Next Steps

Phase 4 will implement:
- Push notifications (requires paid Apple Developer account)
- APNs service on server
- Device registration
- Notification settings
