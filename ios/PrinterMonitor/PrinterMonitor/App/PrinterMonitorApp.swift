import SwiftUI

@main
struct PrinterMonitorApp: App {
    @State private var apiClient = APIClient()
    @State private var settings = SettingsStorage()
    @State private var notificationManager: NotificationManager?
    @State private var activityManager: ActivityManager?

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(
                apiClient: apiClient,
                settings: settings,
                activityManager: activityManager
            )
            .preferredColorScheme(.dark)
            .task {
                // Initialize notification manager
                let notifManager = NotificationManager(apiClient: apiClient, settings: settings)
                notificationManager = notifManager
                appDelegate.notificationManager = notifManager
                await notifManager.requestAuthorization()

                // Initialize activity manager
                let actManager = ActivityManager(apiClient: apiClient, settings: settings)
                activityManager = actManager
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
