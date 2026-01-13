import SwiftUI

struct PrinterDashboardView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var activityManager: ActivityManager
    @State private var showingActivityError: Bool = false
    @State private var isInitialLoad: Bool = true
    @State private var showingPrintDetails: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    if !settingsManager.settings.isConfigured {
                        NotConfiguredCard()
                    } else if isInitialLoad && haService.isLoading {
                        // Initial loading state - show skeletons
                        LoadingSkeletonView(accentColor: settingsManager.settings.accentColor)
                    } else if !haService.isConnected && haService.lastError != nil {
                        // Error state with retry
                        ConnectionErrorCard(
                            error: haService.lastError ?? "Connection failed",
                            onRetry: retryConnection
                        )
                    } else {
                        // Normal content
                        ConnectionStatusView(
                            isConnected: haService.isConnected,
                            isLoading: haService.isLoading
                        )

                        // Main Printer Card
                        Button {
                            showingPrintDetails = true
                        } label: {
                            PrinterStatusCard(state: haService.printerState, settings: settingsManager.settings)
                        }
                        .buttonStyle(CardButtonStyle())
                        .accessibilityLabel(printerStatusAccessibilityLabel)
                        .accessibilityHint("Double tap to view detailed printer information")

                        // Live Activity Control
                        LiveActivityControlCard(
                            isActive: activityManager.isActivityActive,
                            printerState: haService.printerState,
                            accentColor: settingsManager.settings.accentColor,
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
            .background {
                DarkModeBackground(
                    accentColor: settingsManager.settings.accentColor.color,
                    style: .radialGlow
                )
            }
            .navigationTitle("Printer Monitor")
            .refreshable {
                await refreshData()
            }
            .onChange(of: haService.isConnected) { _, connected in
                if connected {
                    isInitialLoad = false
                }
            }
            .alert("Live Activity Error", isPresented: $showingActivityError) {
                Button("OK") { }
            } message: {
                Text(activityManager.activityError ?? "Unknown error")
            }
            .sheet(isPresented: $showingPrintDetails) {
                PrintDetailsSheet(state: haService.printerState, settings: settingsManager.settings)
            }
        }
    }

    private func startActivity() {
        Task {
            do {
                try await activityManager.startActivity(
                    fileName: haService.printerState.fileName,
                    initialState: haService.printerState,
                    settings: settingsManager.settings
                )
            } catch {
                showingActivityError = true
            }
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

    private func retryConnection() {
        Task {
            do {
                _ = try await haService.fetchPrinterState()
            } catch {
                // Error handled by HAAPIService
            }
        }
    }

    private var printerStatusAccessibilityLabel: String {
        let state = haService.printerState
        var label = "Printer status: \(state.status.displayName). "

        if state.status == .running || state.status == .paused {
            label += "Print progress: \(state.progress) percent. "
            if settingsManager.settings.showTimeRemaining {
                label += "Time remaining: \(state.formattedTimeRemaining). "
            }
        }

        label += "File: \(state.fileName). "
        label += "Model: \(state.printerModel.rawValue). "

        if state.isOnline {
            label += "Printer is online."
        }

        return label
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
                    .accessibilityHidden(true)

                Text("Not Configured")
                    .font(.headline)

                Text("Go to Settings to connect to your Home Assistant instance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Printer not configured")
        .accessibilityHint("Navigate to Settings to connect to your Home Assistant instance")
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool
    var isLoading: Bool = false

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            Text(isLoading ? "Updating..." : (isConnected ? "Connected" : "Disconnected"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLoading ? "Updating printer status" : (isConnected ? "Connected to Home Assistant" : "Disconnected from Home Assistant"))
    }
}

// MARK: - Loading Skeleton View

struct LoadingSkeletonView: View {
    let accentColor: AccentColorOption
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Connection status skeleton
            HStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 80, height: 12)
                Spacer()
            }
            .shimmer(isAnimating: isAnimating)

            // Main card skeleton
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4))
                                .frame(width: 150, height: 16)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 12)
                        }
                        Spacer()
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentColor.color.opacity(0.3))
                                .frame(width: 60, height: 24)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 16)
                        }

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                    }
                }
                .padding()
            }
            .shimmer(isAnimating: isAnimating)

            // Live activity card skeleton
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(width: 100, height: 16)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 12)
                    }
                    Spacer()
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 70, height: 36)
                }
                .padding()
            }
            .shimmer(isAnimating: isAnimating)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading printer status")
    }
}

// Shimmer effect modifier
extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.opacity(isAnimating ? 0.6 : 1.0)
    }
}

// MARK: - Connection Error Card

struct ConnectionErrorCard: View {
    let error: String
    let onRetry: () -> Void
    @State private var isRetrying = false

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("Connection Failed")
                    .font(.headline)

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    isRetrying = true
                    onRetry()
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRetrying = false
                    }
                } label: {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRetrying ? "Retrying..." : "Retry")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .disabled(isRetrying)
                .accessibilityLabel(isRetrying ? "Retrying connection" : "Retry connection")
                .accessibilityHint("Attempts to reconnect to Home Assistant")
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Connection failed")
        .accessibilityValue(error)
    }
}

struct PrinterStatusCard: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        ZStack {
            // Rainbow border for active prints
            if settings.accentColor == .rainbow && state.status == .running {
                GlassCard {
                    Color.clear
                        .padding()
                }
                .rainbowBorder(lineWidth: 2, cornerRadius: 16)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with printer model
                    HStack(spacing: 12) {
                        // Printer model icon
                        ZStack {
                            Circle()
                                .fill(state.printerModel.color.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: state.printerModel.icon)
                                .font(.title2)
                                .foregroundStyle(state.printerModel.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.fileName)
                                .font(.headline)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                // Status badge with icon
                                HStack(spacing: 4) {
                                    Image(systemName: state.status.icon)
                                        .font(.caption)
                                    Text(state.status.displayName)
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(state.status.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(state.status.color.opacity(0.15))
                                .clipShape(Capsule())

                                // Online indicator
                                if state.isOnline {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 6, height: 6)
                                        Text("Online")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Cover image preview (if available)
                        if let coverURL = state.coverImageURL, !coverURL.isEmpty {
                            AsyncImage(url: URL(string: coverURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 50, height: 50)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                    }

                    // Progress Bar
                    if state.status == .running || state.status == .paused {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Progress with shimmer for rainbow
                                if settings.accentColor == .rainbow {
                                    ShimmeringText(
                                        text: "\(state.progress)%",
                                        font: .title2.bold()
                                    )
                                } else {
                                    Text("\(state.progress)%")
                                        .font(.title2.bold())
                                        .foregroundStyle(settings.accentColor.color)
                                }

                                Spacer()

                                if settings.showTimeRemaining {
                                    Label(state.formattedTimeRemaining, systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ProgressBar(
                                progress: Double(state.progress) / 100.0,
                                accentColor: settings.accentColor.color,
                                isRainbow: settings.accentColor == .rainbow
                            )
                            .accessibilityLabel("Print progress bar")
                            .accessibilityValue("\(state.progress) percent complete")

                            // Current stage
                            if !state.currentStage.isEmpty {
                                Text(state.currentStage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Temperature quick view
                    if state.status == .running || state.status == .paused || state.nozzleTemp > 50 {
                        TemperatureQuickView(state: state, settings: settings)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Temperature Quick View

struct TemperatureQuickView: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 16) {
            // Nozzle temp with icon
            TemperatureIndicator(
                icon: "flame.fill",
                label: "Nozzle",
                current: state.nozzleTemp,
                target: state.nozzleTargetTemp,
                color: nozzleColor
            )

            Divider()
                .frame(height: 30)
                .accessibilityHidden(true)

            // Bed temp with icon
            TemperatureIndicator(
                icon: "square.grid.3x3.topleft.filled",
                label: "Bed",
                current: state.bedTemp,
                target: state.bedTargetTemp,
                color: bedColor
            )

            if state.chamberTemp > 0 {
                Divider()
                    .frame(height: 30)
                    .accessibilityHidden(true)

                // Chamber temp
                TemperatureIndicator(
                    icon: "cube.transparent",
                    label: "Chamber",
                    current: state.chamberTemp,
                    target: 0,
                    color: .orange
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(temperatureAccessibilityLabel)
    }

    private var nozzleColor: Color {
        if state.nozzleTemp >= 200 { return .red }
        if state.nozzleTemp >= 100 { return .orange }
        return .blue
    }

    private var bedColor: Color {
        if state.bedTemp >= 80 { return .red }
        if state.bedTemp >= 50 { return .orange }
        return .blue
    }

    private var temperatureAccessibilityLabel: String {
        var label = "Temperatures. "
        if state.nozzleTargetTemp > 0 {
            label += "Nozzle: \(Int(state.nozzleTemp)) degrees, target \(Int(state.nozzleTargetTemp)) degrees. "
        } else {
            label += "Nozzle: \(Int(state.nozzleTemp)) degrees. "
        }

        if state.bedTargetTemp > 0 {
            label += "Bed: \(Int(state.bedTemp)) degrees, target \(Int(state.bedTargetTemp)) degrees. "
        } else {
            label += "Bed: \(Int(state.bedTemp)) degrees. "
        }

        if state.chamberTemp > 0 {
            label += "Chamber: \(Int(state.chamberTemp)) degrees. "
        }

        return label
    }
}

struct TemperatureIndicator: View {
    let icon: String
    let label: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                if target > 0 {
                    Text("\(Int(current))°/\(Int(target))°")
                        .font(.caption.bold())
                } else {
                    Text("\(Int(current))°C")
                        .font(.caption.bold())
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LiveActivityControlCard: View {
    let isActive: Bool
    let printerState: PrinterState
    let accentColor: AccentColorOption
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
                        .background(isActive ? Color.red : accentColor.color)
                        .clipShape(Capsule())
                }
                .disabled(!printerState.status.isActive && !isActive)
                .accessibilityLabel(isActive ? "Stop live activity" : "Start live activity")
                .accessibilityHint(isActive ? "Removes printer status from lock screen and dynamic island" : "Shows printer status on lock screen and dynamic island")
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
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
        VStack(spacing: 12) {
            // Primary stats row
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if settings.showLayers {
                    StatCard(
                        title: "Layers",
                        value: state.layerProgress,
                        icon: "square.stack.3d.up",
                        accentColor: settings.accentColor
                    )
                }

                if settings.showNozzleTemp {
                    StatCard(
                        title: "Nozzle",
                        value: state.formattedNozzleTemp,
                        icon: "flame.fill",
                        accentColor: settings.accentColor,
                        tempColor: nozzleColor
                    )
                }

                if settings.showBedTemp {
                    StatCard(
                        title: "Bed",
                        value: state.formattedBedTemp,
                        icon: "square.grid.3x3.topleft.filled",
                        accentColor: settings.accentColor,
                        tempColor: bedColor
                    )
                }

                if settings.showPrintSpeed {
                    StatCard(
                        title: "Speed",
                        value: "\(state.printSpeed)%",
                        icon: "gauge.with.needle.fill",
                        accentColor: settings.accentColor
                    )
                }

                if settings.showFilamentUsed {
                    StatCard(
                        title: "Filament",
                        value: String(format: "%.1fg", state.filamentUsed),
                        icon: "circle.hexagongrid.fill",
                        accentColor: settings.accentColor
                    )
                }

                // Chamber temp (always show if available)
                if state.chamberTemp > 0 {
                    StatCard(
                        title: "Chamber",
                        value: state.formattedChamberTemp,
                        icon: "cube.transparent.fill",
                        accentColor: settings.accentColor,
                        tempColor: .orange
                    )
                }
            }

            // Fan status row (when printing)
            if state.status == .running {
                FanStatusRow(state: state, accentColor: settings.accentColor)
            }
        }
    }

    private var nozzleColor: Color {
        if state.nozzleTemp >= 200 { return .red }
        if state.nozzleTemp >= 100 { return .orange }
        return .blue
    }

    private var bedColor: Color {
        if state.bedTemp >= 80 { return .red }
        if state.bedTemp >= 50 { return .orange }
        return .blue
    }
}

// MARK: - Fan Status Row

struct FanStatusRow: View {
    let state: PrinterState
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            HStack(spacing: 20) {
                FanIndicator(name: "Cooling", speed: state.coolingFanSpeed, icon: "fan.fill")
                FanIndicator(name: "Aux", speed: state.auxFanSpeed, icon: "wind")
                if state.chamberFanSpeed > 0 {
                    FanIndicator(name: "Chamber", speed: state.chamberFanSpeed, icon: "wind.circle.fill")
                }
            }
            .padding()
        }
    }
}

struct FanIndicator: View {
    let name: String
    let speed: Int
    let icon: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(speed > 0 ? .cyan : .secondary)
                .rotationEffect(.degrees(isAnimating && speed > 0 ? 360 : 0))
                .animation(
                    speed > 0 ?
                        .linear(duration: Double(100 - min(speed, 99)) / 50.0).repeatForever(autoreverses: false) :
                        .default,
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
                .accessibilityHidden(true)

            Text("\(speed)%")
                .font(.caption.bold())

            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) fan: \(speed) percent")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: AccentColorOption
    var tempColor: Color? = nil

    var body: some View {
        ZStack {
            // Rainbow border for rainbow accent
            if accentColor == .rainbow {
                GlassCard {
                    Color.clear
                        .padding()
                }
                .rainbowBorder(lineWidth: 1.5, cornerRadius: 16)
            }

            GlassCard {
                VStack(spacing: 8) {
                    // Icon with color based on type
                    if accentColor == .rainbow {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(tempColor ?? accentColor.color)
                            .accessibilityHidden(true)
                    }

                    // Value with shimmer for rainbow
                    if accentColor == .rainbow {
                        ShimmeringText(text: value, font: .title3.bold())
                    } else {
                        Text(value)
                            .font(.title3.bold())
                    }

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Print Details Sheet

struct PrintDetailsSheet: View {
    let state: PrinterState
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching dashboard
                DarkModeBackground(
                    accentColor: settings.accentColor.color,
                    style: .radialGlow
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large circular progress display
                        if state.status == .running || state.status == .paused {
                            CircularProgressView(
                                progress: Double(state.progress) / 100.0,
                                accentColor: settings.accentColor,
                                size: 140
                            )
                            .padding(.top, 20)
                        }

                        // File info card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Print File", systemImage: "doc.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(state.fileName)
                                    .font(.headline)
                                    .lineLimit(2)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Status and model info
                        GlassCard {
                            HStack(spacing: 16) {
                                // Status badge
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Status", systemImage: "info.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        Image(systemName: state.status.icon)
                                            .font(.body)
                                        Text(state.status.displayName)
                                            .font(.title3.bold())
                                    }
                                    .foregroundStyle(state.status.color)
                                }

                                Spacer()

                                // Printer model
                                VStack(alignment: .trailing, spacing: 8) {
                                    Label("Printer", systemImage: "printer")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        Image(systemName: state.printerModel.icon)
                                        Text(state.printerModel.rawValue)
                                            .font(.title3.bold())
                                    }
                                    .foregroundStyle(state.printerModel.color)
                                }
                            }
                            .padding()
                        }

                        // Progress details (only for active prints)
                        if state.status == .running || state.status == .paused {
                            GlassCard {
                                VStack(spacing: 16) {
                                    // Time remaining
                                    HStack {
                                        Label("Time Remaining", systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(state.formattedTimeRemaining)
                                            .font(.title2.bold())
                                    }

                                    Divider()

                                    // Layers
                                    HStack {
                                        Label("Layer Progress", systemImage: "square.stack.3d.up")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(state.currentLayer) / \(state.totalLayers)")
                                            .font(.title2.bold())
                                    }

                                    // Current stage
                                    if !state.currentStage.isEmpty {
                                        Divider()
                                        HStack {
                                            Label("Current Stage", systemImage: "gearshape.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(state.currentStage)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }

                        // Temperature card
                        GlassCard {
                            VStack(spacing: 16) {
                                Text("Temperatures")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 30) {
                                    TemperatureDetail(
                                        icon: "flame.fill",
                                        label: "Nozzle",
                                        current: state.nozzleTemp,
                                        target: state.nozzleTargetTemp,
                                        color: .orange
                                    )

                                    Divider()
                                        .frame(height: 60)

                                    TemperatureDetail(
                                        icon: "square.grid.3x3.topleft.filled",
                                        label: "Bed",
                                        current: state.bedTemp,
                                        target: state.bedTargetTemp,
                                        color: .blue
                                    )

                                    if state.chamberTemp > 0 {
                                        Divider()
                                            .frame(height: 60)

                                        TemperatureDetail(
                                            icon: "cube.transparent",
                                            label: "Chamber",
                                            current: state.chamberTemp,
                                            target: 0,
                                            color: .purple
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                        }

                        // Speed and filament (only for active prints)
                        if state.status == .running || state.status == .paused {
                            GlassCard {
                                HStack(spacing: 30) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "gauge.with.needle.fill")
                                            .font(.title2)
                                            .foregroundStyle(settings.accentColor.color)
                                        Text("\(state.printSpeed)%")
                                            .font(.title2.bold())
                                        Text("Print Speed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)

                                    Divider()
                                        .frame(height: 60)

                                    VStack(spacing: 8) {
                                        Image(systemName: "circle.hexagongrid.fill")
                                            .font(.title2)
                                            .foregroundStyle(settings.accentColor.color)
                                        Text(String(format: "%.1fg", state.filamentUsed))
                                            .font(.title2.bold())
                                        Text("Filament Used")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Print Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Temperature Detail View

struct TemperatureDetail: View {
    let icon: String
    let label: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            if target > 0 {
                Text("\(Int(current))°")
                    .font(.title.bold())
                Text("→ \(Int(target))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(Int(current))°C")
                    .font(.title.bold())
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let accentColor: AccentColorOption
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)

            // Progress circle
            if accentColor == .rainbow {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Progress percentage in center
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size / 3, weight: .bold))
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Print progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

#Preview {
    PrinterDashboardView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
}
