import SwiftUI

@main
struct PrinterMonitorApp: App {
    @State private var apiClient = APIClient()
    @State private var settings = SettingsStorage()
    @State private var notificationManager: NotificationManager?

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, settings: settings)
                .preferredColorScheme(.dark)
                .task {
                    let manager = NotificationManager(apiClient: apiClient, settings: settings)
                    notificationManager = manager
                    appDelegate.notificationManager = manager
                    await manager.requestAuthorization()
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var notificationManager: NotificationManager?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            notificationManager?.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            notificationManager?.handleRegistrationError(error)
        }
    }
}
