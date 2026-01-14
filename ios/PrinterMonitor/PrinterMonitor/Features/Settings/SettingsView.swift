import SwiftUI

struct SettingsView: View {
    let apiClient: APIClient
    let settings: SettingsStorage

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    NavigationLink("Home Assistant") {
                        ConnectionSetupView()
                    }
                }

                Section("Notifications") {
                    NavigationLink("Notification Settings") {
                        NotificationSettingsView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                    LabeledContent("Build", value: Bundle.main.buildNumber)
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink("Debug Menu") {
                        DebugView(apiClient: apiClient, settings: settings)
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
        }
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView(apiClient: APIClient(), settings: SettingsStorage())
}
