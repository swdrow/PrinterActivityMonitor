import SwiftUI

struct PrinterDashboardView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var activityManager: ActivityManager
    @EnvironmentObject var deviceConfig: DeviceConfigurationManager
    @State private var showingActivityError: Bool = false
    @State private var isInitialLoad: Bool = true
    @State private var showingPrintDetails: Bool = false

    private var accentColor: Color {
        settingsManager.settings.accentColor.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if !settingsManager.settings.isConfigured {
                        NotConfiguredCard()
                    } else if isInitialLoad && haService.isLoading {
                        LoadingSkeletonView(accentColor: settingsManager.settings.accentColor)
                    } else if !haService.isConnected && haService.lastError != nil {
                        ConnectionErrorCard(
                            error: haService.lastError ?? "Connection failed",
                            onRetry: retryConnection
                        )
                    } else {
                        // Connection Status
                        ConnectionStatusView(
                            isConnected: haService.isConnected,
                            isLoading: haService.isLoading
                        )

                        // Printer Info Card
                        if let primaryPrinter = deviceConfig.configuration.primaryPrinter {
                            PrinterInfoCard(
                                printer: primaryPrinter,
                                printerState: haService.printerState,
                                accentColor: settingsManager.settings.accentColor
                            )
                        }

                        // Main Status Card
                        Button {
                            showingPrintDetails = true
                        } label: {
                            PrinterStatusCard(state: haService.printerState, settings: settingsManager.settings)
                        }
                        .buttonStyle(CardButtonStyle())

                        // Live Activity Control
                        LiveActivityControlCard(
                            isActive: activityManager.isActivityActive,
                            printerState: haService.printerState,
                            accentColor: settingsManager.settings.accentColor,
                            onStart: startActivity,
                            onStop: stopActivity
                        )

                        // Stats Grid (when printing)
                        if haService.printerState.status == .running || haService.printerState.status == .paused {
                            StatsGridView(state: haService.printerState, settings: settingsManager.settings)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background {
                DarkModeBackground(accentColor: accentColor, style: .aurora)
            }
            .navigationTitle("Printer Monitor")
            .refreshable {
                await refreshData()
            }
            .onChange(of: haService.isConnected) { _, connected in
                if connected { isInitialLoad = false }
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
        Task { await activityManager.endActivity() }
    }

    private func refreshData() async {
        do {
            let state = try await haService.fetchPrinterState()
            await activityManager.updateActivity(with: state)
        } catch { }
    }

    private func retryConnection() {
        Task {
            do { _ = try await haService.fetchPrinterState() } catch { }
        }
    }
}

// MARK: - Not Configured Card

struct NotConfiguredCard: View {
    var body: some View {
        GlassCard {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "gear.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.textTertiary)

                Text("Not Configured")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Go to Settings to connect to your Home Assistant instance")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DS.Spacing.lg)
        }
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    let isConnected: Bool
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(isConnected ? DS.Colors.success : DS.Colors.error)
                    .frame(width: 8, height: 8)
            }

            Text(isLoading ? "Updating..." : (isConnected ? "Connected" : "Disconnected"))
                .font(DS.Typography.labelSmall)
                .foregroundStyle(DS.Colors.textTertiary)

            Spacer()
        }
    }
}

// MARK: - Printer Info Card

struct PrinterInfoCard: View {
    let printer: PrinterConfiguration
    let printerState: PrinterState
    let accentColor: AccentColorOption

    var body: some View {
        GlassCardCompact(accentColor: accentColor.color) {
            HStack(spacing: DS.Spacing.sm) {
                PrinterIcon(model: printer.model, size: .medium)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(printer.name)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        if let model = printer.model {
                            Text(model)
                                .font(DS.Typography.labelMicro)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(PrinterModelType.detect(from: model).accentColor.opacity(0.8))
                                }
                        }

                        Text(printer.prefix)
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xxs) {
                        Circle()
                            .fill(printerState.isOnline ? DS.Colors.success : DS.Colors.textTertiary)
                            .frame(width: 6, height: 6)
                        Text(printerState.isOnline ? "Online" : "Offline")
                            .font(DS.Typography.labelMicro)
                            .foregroundStyle(printerState.isOnline ? DS.Colors.success : DS.Colors.textTertiary)
                    }

                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: printerState.status.icon)
                            .font(.system(size: 10))
                        Text(printerState.status.displayName)
                            .font(DS.Typography.labelMicro)
                    }
                    .foregroundStyle(printerState.status.color)
                }
            }
            .padding(DS.Spacing.sm)
        }
    }
}

// MARK: - Loading Skeleton View

struct LoadingSkeletonView: View {
    let accentColor: AccentColorOption
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Connection status skeleton
            HStack {
                Circle()
                    .fill(DS.Colors.surfaceGlassHighlight)
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(DS.Colors.surfaceGlassHighlight)
                    .frame(width: 80, height: 12)
                Spacer()
            }
            .shimmer(isAnimating: isAnimating)

            // Main card skeleton
            GlassCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(DS.Colors.surfaceGlassHighlight)
                                .frame(width: 150, height: 16)
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(DS.Colors.surfaceGlass)
                                .frame(width: 80, height: 12)
                        }
                        Spacer()
                        Circle()
                            .fill(DS.Colors.surfaceGlassHighlight)
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack {
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(accentColor.color.opacity(0.3))
                                .frame(width: 60, height: 24)
                            Spacer()
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(DS.Colors.surfaceGlass)
                                .frame(width: 80, height: 16)
                        }

                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.surfaceGlass)
                            .frame(height: 8)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .shimmer(isAnimating: isAnimating)

            // Live activity card skeleton
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.surfaceGlassHighlight)
                            .frame(width: 100, height: 16)
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.surfaceGlass)
                            .frame(width: 120, height: 12)
                    }
                    Spacer()
                    Capsule()
                        .fill(DS.Colors.surfaceGlassHighlight)
                        .frame(width: 70, height: 36)
                }
                .padding(DS.Spacing.md)
            }
            .shimmer(isAnimating: isAnimating)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

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
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.error)

                Text("Connection Failed")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(error)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    isRetrying = true
                    onRetry()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRetrying ? "Retrying..." : "Retry")
                    }
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background {
                        Capsule()
                            .fill(DS.Colors.accent)
                    }
                }
                .disabled(isRetrying)
            }
            .padding(DS.Spacing.lg)
        }
    }
}

// MARK: - Printer Status Card

struct PrinterStatusCard: View {
    let state: PrinterState
    let settings: AppSettings

    private var accentColor: Color {
        settings.accentColor.color
    }

    var body: some View {
        ZStack {
            if settings.accentColor == .rainbow && state.status == .running {
                GlassCard { Color.clear.padding() }
                    .rainbowBorder(lineWidth: 2, cornerRadius: DS.Radius.large)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Header
                    HStack(spacing: DS.Spacing.sm) {
                        // Printer icon
                        ZStack {
                            Circle()
                                .fill(state.printerModel.color.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: state.printerModel.icon)
                                .font(.title2)
                                .foregroundStyle(state.printerModel.color)
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(state.fileName)
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            HStack(spacing: DS.Spacing.xs) {
                                // Status badge
                                HStack(spacing: DS.Spacing.xxs) {
                                    Image(systemName: state.status.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(state.status.displayName)
                                        .font(DS.Typography.labelSmall)
                                }
                                .foregroundStyle(state.status.color)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background {
                                    Capsule()
                                        .fill(state.status.color.opacity(0.15))
                                }

                                if state.isOnline {
                                    HStack(spacing: DS.Spacing.xxs) {
                                        Circle()
                                            .fill(DS.Colors.success)
                                            .frame(width: 5, height: 5)
                                        Text("Online")
                                            .font(DS.Typography.labelMicro)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Cover image
                        if let coverURL = state.coverImageURL, !coverURL.isEmpty {
                            AsyncImage(url: URL(string: coverURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: DS.Radius.small)
                                    .fill(DS.Colors.surfaceGlass)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                            }
                        }
                    }

                    // Progress section (only when printing)
                    if state.status == .running || state.status == .paused {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                if settings.accentColor == .rainbow {
                                    ShimmeringText(text: "\(state.progress)%", font: .system(size: 24, weight: .bold, design: .rounded))
                                } else {
                                    Text("\(state.progress)%")
                                        .font(DS.Typography.numeric)
                                        .foregroundStyle(accentColor)
                                }

                                Spacer()

                                if settings.showTimeRemaining {
                                    HStack(spacing: DS.Spacing.xxs) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 12))
                                        Text(state.formattedTimeRemaining)
                                            .font(DS.Typography.label)
                                    }
                                    .foregroundStyle(DS.Colors.textSecondary)
                                }
                            }

                            ProgressBar(
                                progress: Double(state.progress) / 100.0,
                                accentColor: accentColor,
                                isRainbow: settings.accentColor == .rainbow
                            )

                            if !state.currentStage.isEmpty {
                                Text(state.currentStage)
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }
                    }

                    // Temperature quick view
                    if state.status == .running || state.status == .paused || state.nozzleTemp > 50 {
                        TemperatureQuickView(state: state, settings: settings)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
    }
}

// MARK: - Temperature Quick View

struct TemperatureQuickView: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            TemperatureIndicator(
                icon: "flame.fill",
                label: "Nozzle",
                current: state.nozzleTemp,
                target: state.nozzleTargetTemp,
                color: nozzleColor
            )

            Divider()
                .frame(height: 28)
                .background(DS.Colors.borderSubtle)

            TemperatureIndicator(
                icon: "square.grid.3x3.topleft.filled",
                label: "Bed",
                current: state.bedTemp,
                target: state.bedTargetTemp,
                color: bedColor
            )

            if state.chamberTemp > 0 {
                Divider()
                    .frame(height: 28)
                    .background(DS.Colors.borderSubtle)

                TemperatureIndicator(
                    icon: "cube.transparent",
                    label: "Chamber",
                    current: state.chamberTemp,
                    target: 0,
                    color: DS.Colors.warning
                )
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .fill(DS.Colors.surfaceGlass)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .stroke(DS.Colors.borderSubtle, lineWidth: DS.Stroke.hairline)
                }
        }
    }

    private var nozzleColor: Color {
        if state.nozzleTemp >= 200 { return DS.Colors.error }
        if state.nozzleTemp >= 100 { return DS.Colors.warning }
        return DS.Colors.accent
    }

    private var bedColor: Color {
        if state.bedTemp >= 80 { return DS.Colors.error }
        if state.bedTemp >= 50 { return DS.Colors.warning }
        return DS.Colors.accent
    }
}

struct TemperatureIndicator: View {
    let icon: String
    let label: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                if target > 0 {
                    Text("\(Int(current))°/\(Int(target))°")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Colors.textPrimary)
                } else {
                    Text("\(Int(current))°C")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Text(label)
                    .font(DS.Typography.labelMicro)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Live Activity Control Card

struct LiveActivityControlCard: View {
    let isActive: Bool
    let printerState: PrinterState
    let accentColor: AccentColorOption
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Live Activity")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(isActive ? "Active on Lock Screen" : "Not running")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                Button {
                    if isActive { onStop() } else { onStart() }
                } label: {
                    Text(isActive ? "Stop" : "Start")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            Capsule()
                                .fill(isActive ? DS.Colors.error : accentColor.color)
                        }
                }
                .disabled(!printerState.status.isActive && !isActive)
            }
            .padding(DS.Spacing.md)
        }
    }
}

private extension PrinterState.PrintStatus {
    var isActive: Bool {
        self == .running || self == .paused || self == .prepare
    }
}

// MARK: - Stats Grid View

struct StatsGridView: View {
    let state: PrinterState
    let settings: AppSettings

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                if settings.showLayers {
                    StatCard(title: "Layers", value: state.layerProgress, icon: "square.stack.3d.up", accentColor: settings.accentColor)
                }
                if settings.showNozzleTemp {
                    StatCard(title: "Nozzle", value: state.formattedNozzleTemp, icon: "flame.fill", accentColor: settings.accentColor, tempColor: nozzleColor)
                }
                if settings.showBedTemp {
                    StatCard(title: "Bed", value: state.formattedBedTemp, icon: "square.grid.3x3.topleft.filled", accentColor: settings.accentColor, tempColor: bedColor)
                }
                if settings.showPrintSpeed {
                    StatCard(title: "Speed", value: "\(state.printSpeed)%", icon: "gauge.with.needle.fill", accentColor: settings.accentColor)
                }
                if settings.showFilamentUsed {
                    StatCard(title: "Filament", value: String(format: "%.1fg", state.filamentUsed), icon: "circle.hexagongrid.fill", accentColor: settings.accentColor)
                }
                if state.chamberTemp > 0 {
                    StatCard(title: "Chamber", value: state.formattedChamberTemp, icon: "cube.transparent.fill", accentColor: settings.accentColor, tempColor: DS.Colors.warning)
                }
            }

            if state.status == .running {
                FanStatusRow(state: state, accentColor: settings.accentColor)
            }
        }
    }

    private var nozzleColor: Color {
        if state.nozzleTemp >= 200 { return DS.Colors.error }
        if state.nozzleTemp >= 100 { return DS.Colors.warning }
        return DS.Colors.accent
    }

    private var bedColor: Color {
        if state.bedTemp >= 80 { return DS.Colors.error }
        if state.bedTemp >= 50 { return DS.Colors.warning }
        return DS.Colors.accent
    }
}

// MARK: - Fan Status Row

struct FanStatusRow: View {
    let state: PrinterState
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            HStack(spacing: DS.Spacing.lg) {
                FanIndicator(name: "Cooling", speed: state.coolingFanSpeed, icon: "fan.fill")
                FanIndicator(name: "Aux", speed: state.auxFanSpeed, icon: "wind")
                if state.chamberFanSpeed > 0 {
                    FanIndicator(name: "Chamber", speed: state.chamberFanSpeed, icon: "wind.circle.fill")
                }
            }
            .padding(DS.Spacing.md)
        }
    }
}

struct FanIndicator: View {
    let name: String
    let speed: Int
    let icon: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(speed > 0 ? DS.Colors.accent : DS.Colors.textTertiary)
                .rotationEffect(.degrees(isAnimating && speed > 0 ? 360 : 0))
                .animation(
                    speed > 0 ?
                        .linear(duration: Double(100 - min(speed, 99)) / 50.0).repeatForever(autoreverses: false) :
                        .default,
                    value: isAnimating
                )
                .onAppear { isAnimating = true }

            Text("\(speed)%")
                .font(DS.Typography.label)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(name)
                .font(DS.Typography.labelMicro)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: AccentColorOption
    var tempColor: Color? = nil

    var body: some View {
        ZStack {
            if accentColor == .rainbow {
                GlassCard { Color.clear.padding() }
                    .rainbowBorder(lineWidth: 1.5, cornerRadius: DS.Radius.large)
            }

            GlassCard {
                VStack(spacing: DS.Spacing.xs) {
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
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(tempColor ?? accentColor.color)
                    }

                    if accentColor == .rainbow {
                        ShimmeringText(text: value, font: DS.Typography.numericSmall)
                    } else {
                        Text(value)
                            .font(DS.Typography.numericSmall)
                            .foregroundStyle(DS.Colors.textPrimary)
                    }

                    Text(title)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.sm)
            }
        }
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(DS.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Print Details Sheet

struct PrintDetailsSheet: View {
    let state: PrinterState
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // Large progress ring
                    if state.status == .running || state.status == .paused {
                        CircularProgressView(
                            progress: Double(state.progress) / 100.0,
                            accentColor: settings.accentColor,
                            size: 140
                        )
                        .padding(.top, DS.Spacing.lg)
                    }

                    // File info
                    GlassCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(DS.Colors.textTertiary)
                                Text("Print File")
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            Text(state.fileName)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(2)
                        }
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Status and model
                    GlassCard {
                        HStack(spacing: DS.Spacing.md) {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(DS.Colors.textTertiary)
                                    Text("Status")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: state.status.icon)
                                    Text(state.status.displayName)
                                        .font(DS.Typography.numericSmall)
                                }
                                .foregroundStyle(state.status.color)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "printer")
                                        .foregroundStyle(DS.Colors.textTertiary)
                                    Text("Printer")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: state.printerModel.icon)
                                    Text(state.printerModel.rawValue)
                                        .font(DS.Typography.numericSmall)
                                }
                                .foregroundStyle(state.printerModel.color)
                            }
                        }
                        .padding(DS.Spacing.md)
                    }

                    // Progress details
                    if state.status == .running || state.status == .paused {
                        GlassCard {
                            VStack(spacing: DS.Spacing.md) {
                                HStack {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(DS.Colors.textTertiary)
                                        Text("Time Remaining")
                                            .font(DS.Typography.labelSmall)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                    Spacer()
                                    Text(state.formattedTimeRemaining)
                                        .font(DS.Typography.numericMedium)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                }

                                Divider().background(DS.Colors.borderSubtle)

                                HStack {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Image(systemName: "square.stack.3d.up")
                                            .foregroundStyle(DS.Colors.textTertiary)
                                        Text("Layer Progress")
                                            .font(DS.Typography.labelSmall)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                    Spacer()
                                    Text("\(state.currentLayer) / \(state.totalLayers)")
                                        .font(DS.Typography.numericMedium)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                }

                                if !state.currentStage.isEmpty {
                                    Divider().background(DS.Colors.borderSubtle)
                                    HStack {
                                        HStack(spacing: DS.Spacing.xs) {
                                            Image(systemName: "gearshape.fill")
                                                .foregroundStyle(DS.Colors.textTertiary)
                                            Text("Stage")
                                                .font(DS.Typography.labelSmall)
                                                .foregroundStyle(DS.Colors.textTertiary)
                                        }
                                        Spacer()
                                        Text(state.currentStage)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(DS.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                        }
                    }

                    // Temperature details
                    GlassCard {
                        VStack(spacing: DS.Spacing.md) {
                            Text("Temperatures")
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: DS.Spacing.lg) {
                                TemperatureDetail(icon: "flame.fill", label: "Nozzle", current: state.nozzleTemp, target: state.nozzleTargetTemp, color: DS.Colors.warning)

                                Divider().frame(height: 60).background(DS.Colors.borderSubtle)

                                TemperatureDetail(icon: "square.grid.3x3.topleft.filled", label: "Bed", current: state.bedTemp, target: state.bedTargetTemp, color: DS.Colors.accent)

                                if state.chamberTemp > 0 {
                                    Divider().frame(height: 60).background(DS.Colors.borderSubtle)
                                    TemperatureDetail(icon: "cube.transparent", label: "Chamber", current: state.chamberTemp, target: 0, color: .purple)
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                    }

                    // Speed and filament
                    if state.status == .running || state.status == .paused {
                        GlassCard {
                            HStack(spacing: DS.Spacing.lg) {
                                VStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "gauge.with.needle.fill")
                                        .font(.title2)
                                        .foregroundStyle(settings.accentColor.color)
                                    Text("\(state.printSpeed)%")
                                        .font(DS.Typography.numericMedium)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                    Text("Speed")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)

                                Divider().frame(height: 60).background(DS.Colors.borderSubtle)

                                VStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "circle.hexagongrid.fill")
                                        .font(.title2)
                                        .foregroundStyle(settings.accentColor.color)
                                    Text(String(format: "%.1fg", state.filamentUsed))
                                        .font(DS.Typography.numericMedium)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                    Text("Filament")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(DS.Spacing.md)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.lg)
            }
            .background {
                DarkModeBackground(accentColor: settings.accentColor.color, style: .aurora)
            }
            .navigationTitle("Print Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Colors.accent)
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
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            if target > 0 {
                Text("\(Int(current))°")
                    .font(DS.Typography.numeric)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("→ \(Int(target))°")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                Text("\(Int(current))°C")
                    .font(DS.Typography.numeric)
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            Text(label)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(DS.Colors.textTertiary)
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
            Circle()
                .stroke(DS.Colors.surfaceGlass, lineWidth: 12)

            if accentColor == .rainbow {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
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

            VStack(spacing: DS.Spacing.xxs) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size / 3, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Complete")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    PrinterDashboardView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
        .environmentObject(DeviceConfigurationManager())
}
