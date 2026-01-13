import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var deviceConfig: DeviceConfigurationManager
    @State private var testResult: String?
    @State private var isTesting: Bool = false
    @State private var showingTokenInfo: Bool = false
    @State private var showingDeviceSetup: Bool = false
    @State private var isDiscovering: Bool = false

    private var accentColor: Color {
        settingsManager.settings.accentColor.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // Device Selection Section
                    if !deviceConfig.configuration.printers.isEmpty {
                        deviceSection
                    }

                    // Connection Section
                    connectionSection

                    // Display Options Section
                    displaySection

                    // Appearance Section
                    appearanceSection

                    // Updates Section
                    updatesSection

                    // Notifications Section
                    notificationsSection

                    // Reset Section
                    resetSection
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background {
                DarkModeBackground(accentColor: accentColor, style: .ambient)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingTokenInfo) {
                TokenInfoSheet()
            }
        }
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        SettingsSection(title: "Devices", icon: "printer.fill") {
            VStack(spacing: DS.Spacing.sm) {
                // Printers
                ForEach(deviceConfig.configuration.printers) { printer in
                    DeviceRow(
                        printer: printer,
                        isSelected: printer.isPrimary,
                        accentColor: accentColor
                    ) {
                        deviceConfig.setPrimaryPrinter(printer)
                    }
                }

                // AMS Units
                if !deviceConfig.configuration.amsUnits.isEmpty {
                    Divider()
                        .background(DS.Colors.borderSubtle)
                        .padding(.vertical, DS.Spacing.xs)

                    ForEach(deviceConfig.configuration.amsUnits) { ams in
                        AMSRow(
                            ams: ams,
                            accentColor: accentColor
                        ) {
                            deviceConfig.toggleAMS(ams)
                        }
                    }
                }

                // Re-discover button
                Button {
                    runDiscovery()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isDiscovering {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(DS.Colors.textSecondary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text(isDiscovering ? "Discovering..." : "Re-discover Devices")
                            .font(DS.Typography.body)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .disabled(isDiscovering)

                // Last discovery info
                if let date = deviceConfig.configuration.lastDiscoveryDate {
                    Text("Last discovered: \(date, style: .relative) ago")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        SettingsSection(title: "Home Assistant", icon: "network") {
            VStack(spacing: DS.Spacing.md) {
                // Server URL
                SettingsTextField(
                    title: "Server URL",
                    placeholder: "https://your-ha-instance.local:8123",
                    text: $settingsManager.settings.haServerURL,
                    keyboardType: .URL
                )

                // Access Token
                HStack {
                    SettingsSecureField(
                        title: "Access Token",
                        placeholder: "Long-lived access token",
                        text: $settingsManager.settings.haAccessToken
                    )

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.top, 20)
                }

                // Entity Prefix
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    SettingsTextField(
                        title: "Entity Prefix",
                        placeholder: "h2s",
                        text: $settingsManager.settings.entityPrefix
                    )
                    Text("Prefix for sensor entities (e.g., sensor.h2s_print_progress)")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                // Test Connection Button
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                            .font(DS.Typography.bodySemibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: DS.Radius.medium)
                            .fill(accentColor)
                    }
                }
                .disabled(isTesting)

                // Test Result
                if let result = testResult {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: result.contains("success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.contains("success") ? DS.Colors.success : DS.Colors.error)
                        Text(result)
                            .font(DS.Typography.label)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        SettingsSection(title: "Display Fields", icon: "square.grid.2x2") {
            VStack(spacing: 0) {
                SettingsToggleRow(title: "Progress", isOn: $settingsManager.settings.showProgress)
                SettingsToggleRow(title: "Layers", isOn: $settingsManager.settings.showLayers)
                SettingsToggleRow(title: "Time Remaining", isOn: $settingsManager.settings.showTimeRemaining)
                SettingsToggleRow(title: "Nozzle Temperature", isOn: $settingsManager.settings.showNozzleTemp)
                SettingsToggleRow(title: "Bed Temperature", isOn: $settingsManager.settings.showBedTemp)
                SettingsToggleRow(title: "Print Speed", isOn: $settingsManager.settings.showPrintSpeed)
                SettingsToggleRow(title: "Filament Used", isOn: $settingsManager.settings.showFilamentUsed, showDivider: false)
            }

            Text("Choose which fields to show in the dashboard and Live Activity")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance", icon: "paintbrush") {
            VStack(spacing: DS.Spacing.md) {
                // Accent Color Picker
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Accent Color")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Colors.textSecondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DS.Spacing.sm) {
                        ForEach(AccentColorOption.allCases, id: \.self) { option in
                            ColorButton(
                                option: option,
                                isSelected: settingsManager.settings.accentColor == option
                            ) {
                                settingsManager.settings.accentColor = option
                            }
                        }
                    }
                }

                Divider()
                    .background(DS.Colors.borderSubtle)

                // Compact Mode Toggle
                SettingsToggleRow(title: "Compact Mode", isOn: $settingsManager.settings.compactMode, showDivider: false)

                Text("Compact mode shows less information in the Live Activity")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Updates Section

    private var updatesSection: some View {
        SettingsSection(title: "Updates", icon: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Refresh Interval")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Colors.textSecondary)

                HStack(spacing: DS.Spacing.xs) {
                    ForEach([15, 30, 60, 120], id: \.self) { interval in
                        IntervalButton(
                            interval: interval,
                            isSelected: settingsManager.settings.refreshInterval == interval,
                            accentColor: accentColor
                        ) {
                            settingsManager.settings.refreshInterval = interval
                        }
                    }
                }

                Text("How often to fetch printer status from Home Assistant")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications", icon: "bell.badge") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Push Notifications")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Get notified when prints start, finish, or fail")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    Spacer()

                    HStack(spacing: DS.Spacing.xs) {
                        if notificationManager.isAuthorized {
                            if settingsManager.settings.notificationSettings.enabled {
                                Text("On")
                                    .font(DS.Typography.label)
                                    .foregroundStyle(DS.Colors.success)
                            } else {
                                Text("Off")
                                    .font(DS.Typography.label)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        } else {
                            Text("Not Configured")
                                .font(DS.Typography.label)
                                .foregroundStyle(DS.Colors.warning)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Button {
            settingsManager.reset()
            testResult = nil
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .medium))
                Text("Reset All Settings")
                    .font(DS.Typography.body)
            }
            .foregroundStyle(DS.Colors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .fill(DS.Colors.error.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.large)
                            .stroke(DS.Colors.error.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await haService.testConnection()
            isTesting = false
            testResult = result.message
        }
    }

    private func runDiscovery() {
        isDiscovering = true

        Task {
            await deviceConfig.runDiscovery(using: haService)
            isDiscovering = false

            if let primary = deviceConfig.configuration.primaryPrinter {
                settingsManager.settings.entityPrefix = primary.prefix
            }
        }
    }
}

// MARK: - Settings Section Container

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text(title)
                    .font(DS.Typography.headlineSmall)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(.leading, DS.Spacing.xxs)

            // Content Card
            GlassCard(cornerRadius: DS.Radius.large) {
                VStack(spacing: DS.Spacing.sm) {
                    content
                }
                .padding(DS.Spacing.md)
            }
        }
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let printer: PrinterConfiguration
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                PrinterIcon(model: printer.model)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.name)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(printer.prefix)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                if let model = printer.model {
                    Text(model)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background {
                            Capsule()
                                .fill(DS.Colors.surfaceGlass)
                        }
                }

                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : DS.Colors.borderLight, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AMS Row

private struct AMSRow: View {
    let ams: AMSConfiguration
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            AMSIcon()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(ams.name)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("\(ams.trayCount) trays • \(ams.prefix)")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { ams.isEnabled },
                set: { _ in action() }
            ))
            .labelsHidden()
            .tint(accentColor)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Settings Toggle Row

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(DS.Colors.accent)
            }
            .padding(.vertical, DS.Spacing.sm)

            if showDivider {
                Divider()
                    .background(DS.Colors.borderSubtle)
            }
        }
    }
}

// MARK: - Settings Text Field

private struct SettingsTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Colors.textSecondary)

            TextField(placeholder, text: $text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(DS.Colors.backgroundTertiary)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        }
                }
        }
    }
}

// MARK: - Settings Secure Field

private struct SettingsSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Colors.textSecondary)

            SecureField(placeholder, text: $text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(DS.Colors.backgroundTertiary)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        }
                }
        }
    }
}

// MARK: - Color Button

private struct ColorButton: View {
    let option: AccentColorOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if option == .rainbow {
                    RainbowCircle()
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(option.color)
                        .frame(width: 36, height: 36)
                }

                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .shadow(color: isSelected ? option.color.opacity(0.4) : .clear, radius: 8)
    }
}

// MARK: - Interval Button

private struct IntervalButton: View {
    let interval: Int
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    private var label: String {
        switch interval {
        case 15: return "15s"
        case 30: return "30s"
        case 60: return "1m"
        case 120: return "2m"
        default: return "\(interval)s"
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(isSelected ? accentColor : DS.Colors.surfaceGlass)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Token Info Sheet

struct TokenInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("How to Create a Long-Lived Access Token")
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.textPrimary)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            StepView(number: 1, text: "Open your Home Assistant web interface")
                            StepView(number: 2, text: "Click your profile icon in the bottom left")
                            StepView(number: 3, text: "Scroll down to \"Long-Lived Access Tokens\"")
                            StepView(number: 4, text: "Click \"Create Token\"")
                            StepView(number: 5, text: "Give it a name like \"Printer Monitor\"")
                            StepView(number: 6, text: "Copy the token and paste it here")
                        }
                    }

                    GlassCard(accentColor: DS.Colors.warning, cornerRadius: DS.Radius.medium) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DS.Colors.warning)

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text("Important")
                                    .font(DS.Typography.bodySemibold)
                                    .foregroundStyle(DS.Colors.textPrimary)

                                Text("The token is only shown once when created. If you lose it, you'll need to create a new one.")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background {
                DarkModeBackground(style: .standard)
            }
            .navigationTitle("Access Token Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DS.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Step View

struct StepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("\(number)")
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(DS.Colors.accent)
                }

            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
        }
    }
}

// MARK: - Rainbow Circle

struct RainbowCircle: View {
    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                    center: .center
                )
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(NotificationManager())
        .environmentObject(DeviceConfigurationManager())
}
