import SwiftUI

struct PrinterDashboardView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var activityManager: ActivityManager
    @State private var showingActivityError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    if !settingsManager.settings.isConfigured {
                        NotConfiguredCard()
                    } else {
                        // Status Header
                        ConnectionStatusView(isConnected: haService.isConnected)

                        // Main Printer Card
                        PrinterStatusCard(state: haService.printerState, settings: settingsManager.settings)

                        // Live Activity Control
                        LiveActivityControlCard(
                            isActive: activityManager.isActivityActive,
                            printerState: haService.printerState,
                            onStart: startActivity,
                            onStop: stopActivity
                        )

                        // Stats Grid
                        if haService.printerState.status == .running || haService.printerState.status == .paused {
                            StatsGridView(state: haService.printerState, settings: settingsManager.settings)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Printer Monitor")
            .refreshable {
                await refreshData()
            }
            .alert("Live Activity Error", isPresented: $showingActivityError) {
                Button("OK") { }
            } message: {
                Text(activityManager.activityError ?? "Unknown error")
            }
        }
    }

    private func startActivity() {
        do {
            try activityManager.startActivity(
                fileName: haService.printerState.fileName,
                initialState: haService.printerState,
                settings: settingsManager.settings
            )
        } catch {
            showingActivityError = true
        }
    }

    private func stopActivity() {
        Task {
            await activityManager.endActivity()
        }
    }

    private func refreshData() async {
        do {
            let state = try await haService.fetchPrinterState()
            await activityManager.updateActivity(with: state)
        } catch {
            // Error handled by HAAPIService
        }
    }
}

// MARK: - Sub Views

struct NotConfiguredCard: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "gear.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Not Configured")
                    .font(.headline)

                Text("Go to Settings to connect to your Home Assistant instance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

struct PrinterStatusCard: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.fileName)
                            .font(.headline)
                            .lineLimit(1)

                        Text(state.status.displayName)
                            .font(.subheadline)
                            .foregroundStyle(statusColor)
                    }

                    Spacer()

                    Image(systemName: statusIcon)
                        .font(.title)
                        .foregroundStyle(statusColor)
                }

                // Progress Bar
                if state.status == .running || state.status == .paused {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(state.progress)%")
                                .font(.title2.bold())
                                .foregroundStyle(settings.accentColor.color)

                            Spacer()

                            if settings.showTimeRemaining {
                                Label(state.formattedTimeRemaining, systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ProgressBar(
                            progress: Double(state.progress) / 100.0,
                            accentColor: settings.accentColor
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .running: return .green
        case .paused: return .orange
        case .finish: return .blue
        case .failed: return .red
        case .prepare: return .yellow
        default: return .secondary
        }
    }

    private var statusIcon: String {
        switch state.status {
        case .running: return "printer.fill"
        case .paused: return "pause.circle.fill"
        case .finish: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .prepare: return "hourglass"
        default: return "printer"
        }
    }
}

struct LiveActivityControlCard: View {
    let isActive: Bool
    let printerState: PrinterState
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Activity")
                        .font(.headline)

                    Text(isActive ? "Active on Lock Screen" : "Not running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if isActive {
                        onStop()
                    } else {
                        onStart()
                    }
                } label: {
                    Text(isActive ? "Stop" : "Start")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(isActive ? Color.red : Color.cyan)
                        .clipShape(Capsule())
                }
                .disabled(!printerState.status.isActive && !isActive)
            }
            .padding()
        }
    }
}

private extension PrinterState.PrintStatus {
    var isActive: Bool {
        self == .running || self == .paused || self == .prepare
    }
}

struct StatsGridView: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if settings.showLayers {
                StatCard(
                    title: "Layers",
                    value: state.layerProgress,
                    icon: "square.stack.3d.up"
                )
            }

            if settings.showNozzleTemp {
                StatCard(
                    title: "Nozzle",
                    value: "\(Int(state.nozzleTemp))°C",
                    icon: "flame"
                )
            }

            if settings.showBedTemp {
                StatCard(
                    title: "Bed",
                    value: "\(Int(state.bedTemp))°C",
                    icon: "bed.double"
                )
            }

            if settings.showPrintSpeed {
                StatCard(
                    title: "Speed",
                    value: "\(state.printSpeed)%",
                    icon: "speedometer"
                )
            }

            if settings.showFilamentUsed {
                StatCard(
                    title: "Filament",
                    value: String(format: "%.1fg", state.filamentUsed),
                    icon: "cylinder"
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.cyan)

                Text(value)
                    .font(.title3.bold())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    PrinterDashboardView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
}
