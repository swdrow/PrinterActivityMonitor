import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var historyService: PrintHistoryService
    @State private var selectedTab = 0

    init() {
        // Configure native dark mode tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(DS.Colors.backgroundPrimary)

        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(DS.Colors.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(DS.Colors.textTertiary)
        ]

        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(DS.Colors.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(DS.Colors.accent)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PrinterDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "printer.fill")
                }
                .tag(0)

            PrintControlView()
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
                .tag(1)

            AMSView()
                .tabItem {
                    Label("AMS", systemImage: "tray.2.fill")
                }
                .tag(2)

            PrintHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)

#if DEBUG
            DebugView()
                .tabItem {
                    Label("Debug", systemImage: "ant.fill")
                }
                .tag(5)
#endif
        }
        .preferredColorScheme(.dark)
        .tint(settingsManager.settings.accentColor.color)
        .onAppear {
            // Configure HAAPIService when view appears
            haService.configure(with: settingsManager.settings)
        }
        .onChange(of: settingsManager.settings) { _, newSettings in
            // Reconfigure when settings change
            haService.configure(with: newSettings)
        }
    }
}

#Preview("App") {
    ContentView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
        .environmentObject(PrintHistoryService())
        .environmentObject(DeviceConfigurationManager())
}

#Preview("App - Dark") {
    ContentView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
        .environmentObject(PrintHistoryService())
        .environmentObject(DeviceConfigurationManager())
        .preferredColorScheme(.dark)
}
