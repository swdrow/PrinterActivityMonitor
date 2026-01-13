import Foundation
import UserNotifications
import UIKit

/// Manages push notification registration and handling
@MainActor
@Observable
final class NotificationManager: NSObject, Sendable {
    private(set) var isAuthorized = false
    private(set) var deviceToken: String?
    private(set) var lastError: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
        super.init()
    }

    func requestAuthorization() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isAuthorized = granted

            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token

        Task {
            await registerWithServer(token: token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        lastError = error.localizedDescription
    }

    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Parse printer state from notification payload
        guard let printerState = userInfo["printerState"] as? [String: Any] else { return }

        // Post notification for views to update
        NotificationCenter.default.post(
            name: .printerStateUpdated,
            object: nil,
            userInfo: printerState
        )
    }

    private func registerWithServer(token: String) async {
        guard !settings.serverURL.isEmpty,
              let prefix = settings.selectedPrinterPrefix else {
            return
        }

        do {
            try apiClient.configure(serverURL: settings.serverURL)
            _ = try await apiClient.registerDevice(
                apnsToken: token,
                haUrl: settings.haURL,
                printerPrefix: prefix,
                printerName: settings.selectedPrinterName
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let printerStateUpdated = Notification.Name("printerStateUpdated")
}
