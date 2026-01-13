import SwiftUI

@main
struct PrinterMonitorApp: App {
    @State private var apiClient = APIClient()
    @State private var settings = SettingsStorage()

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, settings: settings)
                .preferredColorScheme(.dark)
        }
    }
}
