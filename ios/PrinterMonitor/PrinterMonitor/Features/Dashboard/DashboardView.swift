import SwiftUI

struct DashboardView: View {
    @State private var viewModel: PrinterViewModel
    var activityManager: ActivityManager?

    init(apiClient: APIClient, settings: SettingsStorage, activityManager: ActivityManager? = nil) {
        _viewModel = State(initialValue: PrinterViewModel(apiClient: apiClient, settings: settings))
        self.activityManager = activityManager
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

                                // Live Activity button
                                if let activityManager {
                                    liveActivityButton(state: state, manager: activityManager)
                                }
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
    private func liveActivityButton(state: PrinterState, manager: ActivityManager) -> some View {
        Button {
            if manager.isActivityActive {
                manager.endActivity()
            } else {
                startLiveActivity(state: state, manager: manager)
            }
        } label: {
            HStack {
                Image(systemName: manager.isActivityActive ? "stop.circle.fill" : "play.circle.fill")
                Text(manager.isActivityActive ? "Stop Live Activity" : "Start Live Activity")
            }
            .font(Theme.Typography.headlineSmall)
            .foregroundStyle(manager.isActivityActive ? Theme.Colors.error : Theme.Colors.accent)
            .padding()
            .frame(maxWidth: .infinity)
            .glassBackground()
        }
    }

    private func startLiveActivity(state: PrinterState, manager: ActivityManager) {
        let contentState = PrinterActivityAttributes.ContentState(
            progress: state.progress,
            currentLayer: state.currentLayer,
            totalLayers: state.totalLayers,
            remainingSeconds: state.remainingSeconds,
            status: state.status.rawValue,
            nozzleTemp: state.nozzleTemp,
            bedTemp: state.bedTemp
        )

        manager.startActivity(
            filename: state.filename ?? "Print",
            printerName: state.printerName,
            printerModel: state.printerModel.rawValue,
            entityPrefix: viewModel.entityPrefix ?? "",
            initialState: contentState
        )
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
