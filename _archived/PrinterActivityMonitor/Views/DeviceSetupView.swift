import SwiftUI

/// Onboarding view for auto-discovering and configuring devices
struct DeviceSetupView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var deviceConfig: DeviceConfigurationManager

    @State private var currentStep: SetupStep = .welcome
    @State private var isDiscovering = false
    @State private var discoveryError: String?

    @Binding var showSetup: Bool

    enum SetupStep {
        case welcome
        case discovering
        case selectDevices
        case complete
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .discovering:
                    discoveringView
                case .selectDevices:
                    selectDevicesView
                case .complete:
                    completeView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .discovering {
                        Button("Cancel") {
                            showSetup = false
                        }
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .welcome: return "Device Setup"
        case .discovering: return "Discovering"
        case .selectDevices: return "Select Devices"
        case .complete: return "Setup Complete"
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "printer.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Auto-Discover Devices")
                .font(.title.bold())

            Text("We'll scan your Home Assistant for Bambu Lab printers and AMS units, then let you choose which ones to display.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if !settingsManager.settings.isConfigured {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("Please configure your Home Assistant connection in Settings first.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            Button {
                startDiscovery()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Start Discovery")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(settingsManager.settings.isConfigured ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!settingsManager.settings.isConfigured)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Discovering View

    private var discoveringView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2)
                .padding()

            Text("Scanning Home Assistant...")
                .font(.title2.bold())

            Text("Looking for Bambu Lab printers and AMS units")
                .font(.body)
                .foregroundStyle(.secondary)

            if let error = discoveryError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Select Devices View

    private var selectDevicesView: some View {
        List {
            // Printers Section
            Section {
                if deviceConfig.configuration.printers.isEmpty {
                    HStack {
                        Image(systemName: "printer.fill")
                            .foregroundStyle(.secondary)
                        Text("No printers found")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(deviceConfig.configuration.printers) { printer in
                        PrinterSelectionRow(printer: printer) {
                            deviceConfig.togglePrinter(printer)
                        } onSetPrimary: {
                            deviceConfig.setPrimaryPrinter(printer)
                        }
                    }
                }
            } header: {
                Label("Printers", systemImage: "printer.fill")
            } footer: {
                Text("Select which printers to monitor. The primary printer will be used for Live Activity.")
            }

            // AMS Section
            Section {
                if deviceConfig.configuration.amsUnits.isEmpty {
                    HStack {
                        Image(systemName: "tray.2.fill")
                            .foregroundStyle(.secondary)
                        Text("No AMS units found")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(deviceConfig.configuration.amsUnits) { ams in
                        AMSSelectionRow(ams: ams) {
                            deviceConfig.toggleAMS(ams)
                        }
                    }
                }
            } header: {
                Label("AMS Units", systemImage: "tray.2.fill")
            } footer: {
                Text("Select which AMS units to display. Filament information will be shown for enabled units.")
            }

            // Discovery Info
            Section {
                if let date = deviceConfig.configuration.lastDiscoveryDate {
                    LabeledContent("Last Scanned") {
                        Text(date, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    startDiscovery()
                } label: {
                    Label("Re-scan Devices", systemImage: "arrow.clockwise")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                completeSetup()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Setup Complete!")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 12) {
                if !deviceConfig.configuration.enabledPrinters.isEmpty {
                    HStack {
                        Image(systemName: "printer.fill")
                            .foregroundStyle(.blue)
                        Text("\(deviceConfig.configuration.enabledPrinters.count) printer(s) configured")
                    }
                }
                if !deviceConfig.configuration.enabledAMSUnits.isEmpty {
                    HStack {
                        Image(systemName: "tray.2.fill")
                            .foregroundStyle(.orange)
                        Text("\(deviceConfig.configuration.enabledAMSUnits.count) AMS unit(s) configured")
                    }
                }
            }
            .font(.body)
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("You can change these settings anytime from the Settings tab.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                showSetup = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Actions

    private func startDiscovery() {
        currentStep = .discovering
        discoveryError = nil

        Task {
            await deviceConfig.runDiscovery(using: haService)

            if let error = deviceConfig.discoveryError {
                discoveryError = error
            } else {
                currentStep = .selectDevices
            }
        }
    }

    private func completeSetup() {
        deviceConfig.completeSetup()
        currentStep = .complete
    }
}

// MARK: - Selection Rows

struct PrinterSelectionRow: View {
    let printer: PrinterConfiguration
    let onToggle: () -> Void
    let onSetPrimary: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(printer.name)
                        .font(.headline)
                    if printer.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    Text("Prefix: \(printer.prefix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let model = printer.model {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if printer.isEnabled && !printer.isPrimary {
                Button {
                    onSetPrimary()
                } label: {
                    Text("Set Primary")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Toggle("", isOn: Binding(
                get: { printer.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
    }
}

struct AMSSelectionRow: View {
    let ams: AMSConfiguration
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ams.name)
                    .font(.headline)

                HStack {
                    Text("Prefix: \(ams.prefix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(ams.trayCount) trays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { ams.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
    }
}

#Preview {
    DeviceSetupView(showSetup: .constant(true))
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(DeviceConfigurationManager())
}
