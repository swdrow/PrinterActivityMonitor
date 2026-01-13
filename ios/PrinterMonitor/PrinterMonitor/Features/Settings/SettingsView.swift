import SwiftUI

struct SettingsView: View {
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
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
