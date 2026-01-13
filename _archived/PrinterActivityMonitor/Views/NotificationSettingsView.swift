import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showingPermissionAlert = false

    var body: some View {
        List {
            // Authorization Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.headline)

                        Text(authorizationStatusText)
                            .font(.caption)
                            .foregroundStyle(authorizationStatusColor)
                    }

                    Spacer()

                    if notificationManager.authorizationStatus == .notDetermined {
                        Button("Enable") {
                            Task {
                                _ = await notificationManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if notificationManager.authorizationStatus == .denied {
                        Button("Open Settings") {
                            openAppSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } footer: {
                if notificationManager.authorizationStatus == .denied {
                    Text("Notifications are disabled. Enable them in Settings to receive print updates.")
                }
            }

            // Master Toggle
            if notificationManager.isAuthorized {
                Section {
                    Toggle("Enable Notifications", isOn: $settingsManager.settings.notificationSettings.enabled)
                } footer: {
                    Text("When enabled, you'll receive notifications about your print status.")
                }

                // Notification Types
                if settingsManager.settings.notificationSettings.enabled {
                    Section("Print Events") {
                        Toggle(isOn: $settingsManager.settings.notificationSettings.notifyOnPrintStart) {
                            Label("Print Started", systemImage: "play.circle.fill")
                        }

                        Toggle(isOn: $settingsManager.settings.notificationSettings.notifyOnPrintComplete) {
                            Label("Print Complete", systemImage: "checkmark.circle.fill")
                        }

                        Toggle(isOn: $settingsManager.settings.notificationSettings.notifyOnPrintFailed) {
                            Label("Print Failed", systemImage: "xmark.circle.fill")
                        }

                        Toggle(isOn: $settingsManager.settings.notificationSettings.notifyOnPrintPaused) {
                            Label("Print Paused", systemImage: "pause.circle.fill")
                        }
                    }

                    Section("Progress Updates") {
                        Toggle(isOn: $settingsManager.settings.notificationSettings.notifyOnLayerMilestones) {
                            Label("Layer Milestones", systemImage: "chart.bar.fill")
                        }

                        if settingsManager.settings.notificationSettings.notifyOnLayerMilestones {
                            Picker("Notify Every", selection: $settingsManager.settings.notificationSettings.layerMilestoneInterval) {
                                Text("10%").tag(10)
                                Text("25%").tag(25)
                                Text("50%").tag(50)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Section {
                        Toggle(isOn: $settingsManager.settings.notificationSettings.criticalAlertsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Critical Alerts", systemImage: "exclamationmark.triangle.fill")
                                Text("Bypass Do Not Disturb for failures")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("Critical alerts require special permission from Apple and may not be available on all devices.")
                    }
                }

                // Debug section for testing
                NotificationDebugSection()
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await notificationManager.checkAuthorizationStatus()
            }
        }
    }

    private var authorizationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled in Settings"
        case .notDetermined:
            return "Not configured"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    private var authorizationStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Debug Section View
struct NotificationDebugSection: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var lastSentType: NotificationManager.TestNotificationType?

    var body: some View {
        Section {
            ForEach(NotificationManager.TestNotificationType.allCases, id: \.self) { type in
                Button {
                    notificationManager.sendTestNotification(type: type)
                    lastSentType = type
                } label: {
                    HStack {
                        Label(type.displayName, systemImage: type.icon)
                        Spacer()
                        if lastSentType == type {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Test Notifications")
        } footer: {
            Text("Tap to send a test notification. Lock your phone first to see it on the Lock Screen.")
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(SettingsManager())
            .environmentObject(NotificationManager())
    }
}
