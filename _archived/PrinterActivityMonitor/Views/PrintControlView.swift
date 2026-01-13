import SwiftUI

struct PrintControlView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @State private var isPerformingAction: Bool = false
    @State private var actionError: String?
    @State private var showingStopConfirmation: Bool = false
    @State private var showingError: Bool = false

    // Temperature controls
    @State private var targetNozzleTemp: Double = 0
    @State private var targetBedTemp: Double = 0
    @State private var isLightOn: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Print Status Header
                    PrintStatusHeader(state: haService.printerState, accentColor: settingsManager.settings.accentColor)

                    // Print Controls
                    PrintControlsSection(
                        state: haService.printerState,
                        accentColor: settingsManager.settings.accentColor,
                        isPerformingAction: isPerformingAction,
                        onPause: pausePrint,
                        onResume: resumePrint,
                        onStop: { showingStopConfirmation = true }
                    )

                    // Temperature Controls
                    TemperatureControlSection(
                        currentNozzleTemp: haService.printerState.nozzleTemp,
                        currentBedTemp: haService.printerState.bedTemp,
                        targetNozzleTemp: $targetNozzleTemp,
                        targetBedTemp: $targetBedTemp,
                        accentColor: settingsManager.settings.accentColor,
                        onSetNozzle: setNozzleTemp,
                        onSetBed: setBedTemp
                    )

                    // Light Control
                    LightControlSection(
                        isOn: $isLightOn,
                        accentColor: settingsManager.settings.accentColor,
                        onToggle: toggleLight
                    )

                    // Temperature Presets
                    TemperaturePresetsSection(
                        accentColor: settingsManager.settings.accentColor,
                        onApplyPreset: applyTempPreset
                    )
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Controls")
            .alert("Stop Print?", isPresented: $showingStopConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Stop Print", role: .destructive) {
                    stopPrint()
                }
            } message: {
                Text("This will cancel the current print. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "An unknown error occurred")
            }
            .onAppear {
                // Initialize targets to current values
                targetNozzleTemp = haService.printerState.nozzleTemp
                targetBedTemp = haService.printerState.bedTemp
            }
        }
    }

    // MARK: - Actions

    private func pausePrint() {
        performAction {
            try await haService.pausePrint()
            hapticFeedback(.success)
        }
    }

    private func resumePrint() {
        performAction {
            try await haService.resumePrint()
            hapticFeedback(.success)
        }
    }

    private func stopPrint() {
        performAction {
            try await haService.stopPrint()
            hapticFeedback(.warning)
        }
    }

    private func setNozzleTemp() {
        performAction {
            try await haService.setNozzleTemp(targetNozzleTemp)
            hapticFeedback(.success)
        }
    }

    private func setBedTemp() {
        performAction {
            try await haService.setBedTemp(targetBedTemp)
            hapticFeedback(.success)
        }
    }

    private func toggleLight() {
        performAction {
            try await haService.toggleLight(isLightOn)
            hapticFeedback(.light)
        }
    }

    private func applyTempPreset(nozzle: Double, bed: Double) {
        targetNozzleTemp = nozzle
        targetBedTemp = bed
        hapticFeedback(.light)
    }

    private func performAction(_ action: @escaping () async throws -> Void) {
        isPerformingAction = true

        Task {
            do {
                try await action()
            } catch {
                actionError = error.localizedDescription
                showingError = true
                hapticFeedback(.error)
            }
            isPerformingAction = false
        }
    }

    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Print Status Header

struct PrintStatusHeader: View {
    let state: PrinterState
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.fileName == "No print" && state.status == .running ? "Print in progress..." : state.fileName)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(state.status.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(state.progress)%")
                        .font(.title2.bold())
                        .foregroundStyle(accentColor.color)

                    Text(state.formattedTimeRemaining)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
}

// MARK: - Print Controls Section

struct PrintControlsSection: View {
    let state: PrinterState
    let accentColor: AccentColorOption
    let isPerformingAction: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Print Controls")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    // Pause/Resume button
                    if state.status == .running {
                        ControlButton(
                            icon: "pause.fill",
                            label: "Pause",
                            color: .orange,
                            isLoading: isPerformingAction,
                            action: onPause
                        )
                    } else if state.status == .paused {
                        ControlButton(
                            icon: "play.fill",
                            label: "Resume",
                            color: .green,
                            isLoading: isPerformingAction,
                            action: onResume
                        )
                    } else {
                        ControlButton(
                            icon: "pause.fill",
                            label: "Pause",
                            color: .gray,
                            isLoading: false,
                            action: { }
                        )
                        .disabled(true)
                    }

                    // Stop button
                    ControlButton(
                        icon: "stop.fill",
                        label: "Stop",
                        color: .red,
                        isLoading: isPerformingAction,
                        action: onStop
                    )
                    .disabled(state.status != .running && state.status != .paused)
                }
            }
            .padding()
        }
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                }

                Text(label)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }
}

// MARK: - Temperature Control Section

struct TemperatureControlSection: View {
    let currentNozzleTemp: Double
    let currentBedTemp: Double
    @Binding var targetNozzleTemp: Double
    @Binding var targetBedTemp: Double
    let accentColor: AccentColorOption
    let onSetNozzle: () -> Void
    let onSetBed: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                Text("Temperature")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Nozzle Temperature
                VStack(spacing: 8) {
                    HStack {
                        Label("Nozzle", systemImage: "flame")
                            .font(.subheadline)

                        Spacer()

                        Text("Current: \(Int(currentNozzleTemp))°C")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Slider(value: $targetNozzleTemp, in: 0...300, step: 5)
                            .tint(accentColor.color)

                        Text("\(Int(targetNozzleTemp))°C")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 50)

                        Button("Set") {
                            onSetNozzle()
                        }
                        .buttonStyle(.bordered)
                        .tint(accentColor.color)
                    }
                }

                Divider()

                // Bed Temperature
                VStack(spacing: 8) {
                    HStack {
                        Label("Bed", systemImage: "bed.double")
                            .font(.subheadline)

                        Spacer()

                        Text("Current: \(Int(currentBedTemp))°C")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Slider(value: $targetBedTemp, in: 0...120, step: 5)
                            .tint(accentColor.color)

                        Text("\(Int(targetBedTemp))°C")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 50)

                        Button("Set") {
                            onSetBed()
                        }
                        .buttonStyle(.bordered)
                        .tint(accentColor.color)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Light Control Section

struct LightControlSection: View {
    @Binding var isOn: Bool
    let accentColor: AccentColorOption
    let onToggle: () -> Void

    var body: some View {
        GlassCard {
            HStack {
                Label("Chamber Light", systemImage: isOn ? "lightbulb.fill" : "lightbulb")
                    .font(.headline)
                    .foregroundStyle(isOn ? accentColor.color : .primary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .tint(accentColor.color)
                    .onChange(of: isOn) { _, _ in
                        onToggle()
                    }
            }
            .padding()
        }
    }
}

// MARK: - Temperature Presets Section

struct TemperaturePresetsSection: View {
    let accentColor: AccentColorOption
    let onApplyPreset: (Double, Double) -> Void

    private let presets: [(name: String, nozzle: Double, bed: Double)] = [
        ("PLA", 210, 60),
        ("PETG", 240, 80),
        ("ABS", 250, 100),
        ("TPU", 230, 50),
        ("Cool Down", 0, 0)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Presets")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            onApplyPreset(preset.nozzle, preset.bed)
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.name)
                                    .font(.caption.bold())

                                if preset.nozzle > 0 {
                                    Text("\(Int(preset.nozzle))/\(Int(preset.bed))°C")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Off")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    PrintControlView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
}
