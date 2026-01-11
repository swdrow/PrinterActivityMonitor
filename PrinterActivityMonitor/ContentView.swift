import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PrinterDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "printer.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .tint(.cyan)
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
}
