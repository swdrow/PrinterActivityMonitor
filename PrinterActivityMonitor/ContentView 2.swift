import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Emergency fallback - if nothing else shows, this will
            Color.blue
                .ignoresSafeArea()
                .opacity(0.1)
            
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
        .onAppear {
            print("✅ ContentView appeared")
            print("📱 Settings configured: \(settingsManager.settings.isConfigured)")
            print("🔌 Server: \(settingsManager.settings.haServerURL)")
            
            // Configure HAAPIService when view appears
            haService.configure(with: settingsManager.settings)
        }
        .onChange(of: settingsManager.settings) { _, newSettings in
            print("⚙️ Settings changed, reconfiguring...")
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
}

#Preview("App - Dark") {
    ContentView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(ActivityManager())
        .preferredColorScheme(.dark)
}

#Preview("Simple Test") {
    ZStack {
        Color.green.ignoresSafeArea()
        VStack {
            Text("TEST VIEW")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text("If you see this, SwiftUI is working")
                .foregroundColor(.white)
        }
    }
}
