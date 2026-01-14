# Phase 6: Print History Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Track and display print job history with start/completion recording, server persistence, and iOS list/detail views.

**Architecture:**
```
Print Status Change (WebSocket)
    ↓
PrinterMonitor detects start/complete/fail
    ↓
PrintHistoryService records job to database
    ↓
iOS fetches history via /api/history
    ↓
HistoryView displays list with stats
```

**Prerequisites:**
- Phase 5 complete (Live Activities working)
- PrinterMonitor already detects status changes
- Database schema has print_jobs table (needs population)

---

## Task 1: Create PrintHistoryService on Server

**Files:**
- Create: `server/src/services/PrintHistoryService.ts`
- Modify: `server/src/types/index.ts`

**Step 1: Add PrintJob types**

Add to `server/src/types/index.ts`:

```typescript
export interface PrintJob {
  id: string;
  deviceId: string;
  printerPrefix: string;
  filename: string;
  startedAt: Date;
  completedAt?: Date;
  durationSeconds?: number;
  status: 'running' | 'completed' | 'failed' | 'cancelled';
  finalLayer?: number;
  totalLayers?: number;
  filamentUsedMm?: number;
}

export interface PrintJobCreate {
  deviceId: string;
  printerPrefix: string;
  filename: string;
  totalLayers?: number;
}

export interface PrintJobComplete {
  status: 'completed' | 'failed' | 'cancelled';
  finalLayer?: number;
  filamentUsedMm?: number;
}
```

**Step 2: Create PrintHistoryService**

```typescript
// server/src/services/PrintHistoryService.ts
import { v4 as uuidv4 } from 'uuid';
import { db } from '../config/database.js';
import type { PrintJob, PrintJobCreate, PrintJobComplete } from '../types/index.js';

class PrintHistoryService {
  // Track active print jobs by printer prefix
  private activeJobs: Map<string, string> = new Map(); // prefix -> jobId

  async startJob(data: PrintJobCreate): Promise<PrintJob> {
    const job: PrintJob = {
      id: uuidv4(),
      deviceId: data.deviceId,
      printerPrefix: data.printerPrefix,
      filename: data.filename,
      startedAt: new Date(),
      status: 'running',
      totalLayers: data.totalLayers,
    };

    // End any existing job for this printer
    const existingJobId = this.activeJobs.get(data.printerPrefix);
    if (existingJobId) {
      await this.completeJob(data.printerPrefix, { status: 'cancelled' });
    }

    await db.createPrintJob(job);
    this.activeJobs.set(data.printerPrefix, job.id);

    console.log(`[PrintHistory] Started job ${job.id}: ${job.filename}`);
    return job;
  }

  async completeJob(printerPrefix: string, data: PrintJobComplete): Promise<PrintJob | null> {
    const jobId = this.activeJobs.get(printerPrefix);
    if (!jobId) {
      console.log(`[PrintHistory] No active job for ${printerPrefix}`);
      return null;
    }

    const job = await db.getPrintJob(jobId);
    if (!job) {
      this.activeJobs.delete(printerPrefix);
      return null;
    }

    const completedAt = new Date();
    const durationSeconds = Math.floor(
      (completedAt.getTime() - new Date(job.startedAt).getTime()) / 1000
    );

    const updatedJob: PrintJob = {
      ...job,
      completedAt,
      durationSeconds,
      status: data.status,
      finalLayer: data.finalLayer ?? job.totalLayers,
      filamentUsedMm: data.filamentUsedMm,
    };

    await db.updatePrintJob(updatedJob);
    this.activeJobs.delete(printerPrefix);

    console.log(`[PrintHistory] Completed job ${job.id}: ${data.status}`);
    return updatedJob;
  }

  async getActiveJob(printerPrefix: string): Promise<PrintJob | null> {
    const jobId = this.activeJobs.get(printerPrefix);
    if (!jobId) return null;
    return db.getPrintJob(jobId);
  }

  async getHistory(deviceId: string, limit = 50): Promise<PrintJob[]> {
    return db.getPrintJobs(deviceId, limit);
  }

  async getStats(deviceId: string): Promise<{
    totalJobs: number;
    completedJobs: number;
    failedJobs: number;
    totalPrintTimeSeconds: number;
    successRate: number;
  }> {
    const jobs = await db.getPrintJobs(deviceId, 1000);

    const completedJobs = jobs.filter(j => j.status === 'completed').length;
    const failedJobs = jobs.filter(j => j.status === 'failed').length;
    const totalPrintTimeSeconds = jobs
      .filter(j => j.durationSeconds)
      .reduce((sum, j) => sum + (j.durationSeconds ?? 0), 0);

    return {
      totalJobs: jobs.length,
      completedJobs,
      failedJobs,
      totalPrintTimeSeconds,
      successRate: jobs.length > 0 ? completedJobs / jobs.length : 0,
    };
  }
}

export const printHistoryService = new PrintHistoryService();
```

**Step 3: Add database methods**

Add to `server/src/config/database.ts`:

```typescript
async createPrintJob(job: PrintJob): Promise<void> {
  const data = await this.load();
  data.printJobs.push(job);
  await this.save(data);
}

async getPrintJob(id: string): Promise<PrintJob | null> {
  const data = await this.load();
  return data.printJobs.find(j => j.id === id) ?? null;
}

async updatePrintJob(job: PrintJob): Promise<void> {
  const data = await this.load();
  const index = data.printJobs.findIndex(j => j.id === job.id);
  if (index >= 0) {
    data.printJobs[index] = job;
    await this.save(data);
  }
}

async getPrintJobs(deviceId: string, limit: number): Promise<PrintJob[]> {
  const data = await this.load();
  return data.printJobs
    .filter(j => j.deviceId === deviceId)
    .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime())
    .slice(0, limit);
}
```

**Step 4: Verify build**

Run: `cd server && npm run build`

**Step 5: Commit**

```bash
git add server/src/services/PrintHistoryService.ts server/src/types/index.ts server/src/config/database.ts
git commit -m "feat(server): add PrintHistoryService for tracking print jobs"
```

---

## Task 2: Integrate PrintHistory with PrinterMonitor

**Files:**
- Modify: `server/src/services/PrinterMonitor.ts`
- Modify: `server/src/services/NotificationTrigger.ts`

**Step 1: Import PrintHistoryService in NotificationTrigger**

Add to `NotificationTrigger.ts`:

```typescript
import { printHistoryService } from './PrintHistoryService.js';
```

**Step 2: Record job start in handleStatusChange**

In the `handleStatusChange` method, when status changes to `running`:

```typescript
// After sending start notification, record the job
if (newStatus === 'running') {
  const state = printerMonitor.getCachedState(printerPrefix);
  await printHistoryService.startJob({
    deviceId: device.id,
    printerPrefix,
    filename: state?.subtaskName ?? 'Unknown',
    totalLayers: state?.totalLayers,
  });
}
```

**Step 3: Record job completion**

When status changes to `completed`, `failed`, or `cancelled`:

```typescript
if (newStatus === 'complete' || newStatus === 'failed' || newStatus === 'cancelled') {
  const state = printerMonitor.getCachedState(printerPrefix);
  await printHistoryService.completeJob(printerPrefix, {
    status: newStatus === 'complete' ? 'completed' : newStatus as 'failed' | 'cancelled',
    finalLayer: state?.currentLayer,
    filamentUsedMm: state?.filamentUsed,
  });
}
```

**Step 4: Verify build**

Run: `cd server && npm run build`

**Step 5: Commit**

```bash
git add server/src/services/NotificationTrigger.ts
git commit -m "feat(server): integrate print history recording with status changes"
```

---

## Task 3: Create History API Routes

**Files:**
- Create: `server/src/routes/history.ts`
- Modify: `server/src/index.ts`

**Step 1: Create history routes**

```typescript
// server/src/routes/history.ts
import { Router } from 'express';
import { printHistoryService } from '../services/PrintHistoryService.js';

const router = Router();

// Get print history for a device
router.get('/', async (req, res) => {
  const deviceId = req.query.deviceId as string;
  const limit = parseInt(req.query.limit as string) || 50;

  if (!deviceId) {
    return res.status(400).json({
      success: false,
      error: 'deviceId query parameter required',
    });
  }

  try {
    const history = await printHistoryService.getHistory(deviceId, limit);
    return res.json({
      success: true,
      data: history,
    });
  } catch (error) {
    console.error('Error fetching history:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch history',
    });
  }
});

// Get print statistics for a device
router.get('/stats', async (req, res) => {
  const deviceId = req.query.deviceId as string;

  if (!deviceId) {
    return res.status(400).json({
      success: false,
      error: 'deviceId query parameter required',
    });
  }

  try {
    const stats = await printHistoryService.getStats(deviceId);
    return res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch stats',
    });
  }
});

// Get single print job details
router.get('/:jobId', async (req, res) => {
  const { jobId } = req.params;

  try {
    const jobs = await printHistoryService.getHistory('', 1000);
    const job = jobs.find(j => j.id === jobId);

    if (!job) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    return res.json({
      success: true,
      data: job,
    });
  } catch (error) {
    console.error('Error fetching job:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch job',
    });
  }
});

export default router;
```

**Step 2: Register route in index.ts**

Add import and use:

```typescript
import historyRoutes from './routes/history.js';

// With other routes
app.use('/api/history', historyRoutes);
```

**Step 3: Verify build**

Run: `cd server && npm run build`

**Step 4: Commit**

```bash
git add server/src/routes/history.ts server/src/index.ts
git commit -m "feat(server): add print history API routes"
```

---

## Task 4: Add PrintJob Model to iOS

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Models/PrintJob.swift`
- Modify: `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`

**Step 1: Create PrintJob model**

```swift
// ios/PrinterMonitor/PrinterMonitor/Core/Models/PrintJob.swift
import Foundation

struct PrintJob: Codable, Identifiable, Hashable {
    let id: String
    let deviceId: String
    let printerPrefix: String
    let filename: String
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int?
    let status: PrintJobStatus
    let finalLayer: Int?
    let totalLayers: Int?
    let filamentUsedMm: Double?

    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "--" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }
}

enum PrintJobStatus: String, Codable {
    case running
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .running: return "printer.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "orange"
        }
    }
}

struct PrintStats: Codable {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let totalPrintTimeSeconds: Int
    let successRate: Double

    var formattedTotalTime: String {
        let hours = totalPrintTimeSeconds / 3600
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        let minutes = (totalPrintTimeSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var formattedSuccessRate: String {
        return String(format: "%.0f%%", successRate * 100)
    }
}
```

**Step 2: Add API methods to APIClient**

Add to `APIClient.swift`:

```swift
// MARK: - Print History

struct HistoryResponse: Codable {
    let success: Bool
    let data: [PrintJob]?
    let error: String?
}

struct StatsResponse: Codable {
    let success: Bool
    let data: PrintStats?
    let error: String?
}

func fetchHistory(deviceId: String, limit: Int = 50) async throws -> [PrintJob] {
    let response: HistoryResponse = try await request(
        endpoint: "/api/history?deviceId=\(deviceId)&limit=\(limit)",
        method: .get
    )
    guard let data = response.data else {
        throw APIError.serverError(response.error ?? "Unknown error")
    }
    return data
}

func fetchStats(deviceId: String) async throws -> PrintStats {
    let response: StatsResponse = try await request(
        endpoint: "/api/history/stats?deviceId=\(deviceId)",
        method: .get
    )
    guard let data = response.data else {
        throw APIError.serverError(response.error ?? "Unknown error")
    }
    return data
}
```

**Step 3: Verify build**

Run: `cd ios/PrinterMonitor && xcodegen generate && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 4: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Models/PrintJob.swift
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift
git commit -m "feat(ios): add PrintJob model and history API methods"
```

---

## Task 5: Create HistoryViewModel

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryViewModel.swift`

**Step 1: Create the ViewModel**

```swift
// ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryViewModel.swift
import Foundation

@MainActor
@Observable
final class HistoryViewModel {
    var jobs: [PrintJob] = []
    var stats: PrintStats?
    var isLoading = false
    var error: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    func loadHistory() async {
        guard !settings.serverURL.isEmpty else {
            error = "Server not configured"
            return
        }

        isLoading = true
        error = nil

        do {
            try apiClient.configure(serverURL: settings.serverURL)

            // Load history and stats in parallel
            async let historyTask = apiClient.fetchHistory(
                deviceId: settings.deviceId,
                limit: 100
            )
            async let statsTask = apiClient.fetchStats(deviceId: settings.deviceId)

            let (history, fetchedStats) = try await (historyTask, statsTask)

            jobs = history
            stats = fetchedStats
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadHistory()
    }
}
```

**Step 2: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryViewModel.swift
git commit -m "feat(ios): add HistoryViewModel for print history"
```

---

## Task 6: Create HistoryView UI

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryView.swift`
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/History/PrintJobRow.swift`
- Create: `ios/PrinterMonitor/PrinterMonitor/Features/History/PrintJobDetailView.swift`

**Step 1: Create PrintJobRow component**

```swift
// ios/PrinterMonitor/PrinterMonitor/Features/History/PrintJobRow.swift
import SwiftUI

struct PrintJobRow: View {
    let job: PrintJob

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: job.status.iconName)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(job.formattedDate)
                    if let layers = job.totalLayers {
                        Text("•")
                        Text("\(layers) layers")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(job.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(job.status.displayName)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .running: return .blue
        }
    }
}
```

**Step 2: Create PrintJobDetailView**

```swift
// ios/PrinterMonitor/PrinterMonitor/Features/History/PrintJobDetailView.swift
import SwiftUI

struct PrintJobDetailView: View {
    let job: PrintJob

    var body: some View {
        List {
            Section("Print Info") {
                LabeledContent("Filename", value: job.filename)
                LabeledContent("Status", value: job.status.displayName)
                LabeledContent("Started", value: job.formattedDate)
                if let completedAt = job.completedAt {
                    LabeledContent("Completed") {
                        Text(completedAt, style: .date)
                        Text(" ")
                        Text(completedAt, style: .time)
                    }
                }
            }

            Section("Statistics") {
                LabeledContent("Duration", value: job.formattedDuration)
                if let layers = job.totalLayers {
                    LabeledContent("Total Layers", value: "\(layers)")
                }
                if let finalLayer = job.finalLayer, let total = job.totalLayers {
                    LabeledContent("Final Layer", value: "\(finalLayer)/\(total)")
                }
                if let filament = job.filamentUsedMm {
                    LabeledContent("Filament Used", value: String(format: "%.1f mm", filament))
                }
            }

            Section("Printer") {
                LabeledContent("Prefix", value: job.printerPrefix)
            }
        }
        .navigationTitle("Print Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Step 3: Update HistoryView**

Replace the placeholder `HistoryView.swift`:

```swift
// ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    init(apiClient: APIClient, settings: SettingsStorage) {
        _viewModel = State(initialValue: HistoryViewModel(
            apiClient: apiClient,
            settings: settings
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView("Loading history...")
                } else if let error = viewModel.error, viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "Error Loading History",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No Print History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed prints will appear here")
                    )
                } else {
                    List {
                        // Stats header
                        if let stats = viewModel.stats {
                            StatsHeaderView(stats: stats)
                        }

                        // Job list
                        Section("Recent Prints") {
                            ForEach(viewModel.jobs) { job in
                                NavigationLink(value: job) {
                                    PrintJobRow(job: job)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: PrintJob.self) { job in
                        PrintJobDetailView(job: job)
                    }
                }
            }
            .navigationTitle("History")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadHistory()
            }
        }
    }
}

struct StatsHeaderView: View {
    let stats: PrintStats

    var body: some View {
        Section {
            HStack(spacing: 20) {
                StatItem(
                    title: "Total",
                    value: "\(stats.totalJobs)",
                    icon: "printer.fill"
                )

                StatItem(
                    title: "Success",
                    value: stats.formattedSuccessRate,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatItem(
                    title: "Print Time",
                    value: stats.formattedTotalTime,
                    icon: "clock.fill"
                )
            }
            .padding(.vertical, 8)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

**Step 4: Verify build**

Run: `cd ios/PrinterMonitor && xcodegen generate && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 5: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/History/
git commit -m "feat(ios): implement HistoryView with job list and statistics"
```

---

## Task 7: Wire HistoryView into ContentView

**Files:**
- Modify: `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/ContentView.swift`

**Step 1: Update ContentView**

Find the History tab and update it to pass the required dependencies:

```swift
// In the TabView, update the History tab:
HistoryView(apiClient: apiClient, settings: settings)
    .tabItem {
        Label("History", systemImage: "clock.arrow.circlepath")
    }
```

Ensure `apiClient` and `settings` are available in ContentView's scope (they should be passed from PrinterMonitorApp).

**Step 2: Verify build**

Run: `cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "(BUILD|error:)"`

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/ContentView.swift
git commit -m "feat(ios): wire HistoryView into main navigation"
```

---

## Phase 6 Complete Checkpoint

At this point you should have:

**Server:**
- PrintHistoryService tracking active jobs and recording completions
- History API routes (/api/history, /api/history/stats)
- Integration with NotificationTrigger to record job start/complete

**iOS:**
- PrintJob model with status, duration, formatting
- PrintStats model for aggregate statistics
- HistoryViewModel for data loading
- HistoryView with stats header and job list
- PrintJobRow for list items
- PrintJobDetailView for job details
- Navigation wiring in ContentView

**Verification Commands:**

```bash
# Server tests
cd server && npm test -- --run

# iOS build
cd ios/PrinterMonitor && xcodebuild -project PrinterMonitor.xcodeproj -scheme PrinterMonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

---

## Next Steps

Phase 7 will implement:
- Debug Menu with mock print simulation
- Test notification buttons
- Error handling improvements
- Polish and UI refinements
