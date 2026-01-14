import SwiftUI

struct ContentView: View {
    let apiClient: APIClient
    let settings: SettingsStorage
    var activityManager: ActivityManager?

    var body: some View {
        TabView {
            DashboardView(
                apiClient: apiClient,
                settings: settings,
                activityManager: activityManager
            )
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    ContentView(apiClient: APIClient(), settings: SettingsStorage())
}
