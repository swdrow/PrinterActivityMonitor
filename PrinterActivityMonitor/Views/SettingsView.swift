import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @State private var testResult: String?
    @State private var isTesting: Bool = false
    @State private var showingTokenInfo: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // Connection Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://your-ha-instance.local:8123", text: $settingsManager.settings.haServerURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Access Token")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showingTokenInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        SecureField("Long-lived access token", text: $settingsManager.settings.haAccessToken)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entity Prefix")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("h2s", text: $settingsManager.settings.entityPrefix)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Text("Prefix for sensor entities (e.g., sensor.h2s_print_progress)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        HStack {
                            Image(systemName: result.contains("success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.contains("success") ? .green : .red)
                            Text(result)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Home Assistant Connection")
                }

                // Display Fields Section
                Section {
                    Toggle("Progress", isOn: $settingsManager.settings.showProgress)
                    Toggle("Layers", isOn: $settingsManager.settings.showLayers)
                    Toggle("Time Remaining", isOn: $settingsManager.settings.showTimeRemaining)
                    Toggle("Nozzle Temperature", isOn: $settingsManager.settings.showNozzleTemp)
                    Toggle("Bed Temperature", isOn: $settingsManager.settings.showBedTemp)
                    Toggle("Print Speed", isOn: $settingsManager.settings.showPrintSpeed)
                    Toggle("Filament Used", isOn: $settingsManager.settings.showFilamentUsed)
                } header: {
                    Text("Display Fields")
                } footer: {
                    Text("Choose which fields to show in the dashboard and Live Activity")
                }

                // Appearance Section
                Section {
                    Picker("Accent Color", selection: $settingsManager.settings.accentColor) {
                        ForEach(AccentColorOption.allCases, id: \.self) { option in
                            HStack {
                                if option == .rainbow {
                                    RainbowCircle()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 20, height: 20)
                                }
                                Text(option.displayName)
                            }
                            .tag(option)
                        }
                    }

                    Toggle("Compact Mode", isOn: $settingsManager.settings.compactMode)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Compact mode shows less information in the Live Activity")
                }

                // Refresh Section
                Section {
                    Picker("Refresh Interval", selection: $settingsManager.settings.refreshInterval) {
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                    }
                } header: {
                    Text("Updates")
                } footer: {
                    Text("How often to fetch printer status from Home Assistant")
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        settingsManager.reset()
                        testResult = nil
                    } label: {
                        Text("Reset All Settings")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingTokenInfo) {
                TokenInfoSheet()
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await haService.testConnection()
            isTesting = false
            testResult = result.message
        }
    }
}

struct TokenInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Create a Long-Lived Access Token")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        StepView(number: 1, text: "Open your Home Assistant web interface")
                        StepView(number: 2, text: "Click your profile icon in the bottom left")
                        StepView(number: 3, text: "Scroll down to \"Long-Lived Access Tokens\"")
                        StepView(number: 4, text: "Click \"Create Token\"")
                        StepView(number: 5, text: "Give it a name like \"Printer Monitor\"")
                        StepView(number: 6, text: "Copy the token and paste it here")
                    }

                    Text("Important")
                        .font(.headline)
                        .padding(.top)

                    Text("The token is only shown once when created. If you lose it, you'll need to create a new one.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Access Token Help")
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

struct StepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.cyan)
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}

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
}
