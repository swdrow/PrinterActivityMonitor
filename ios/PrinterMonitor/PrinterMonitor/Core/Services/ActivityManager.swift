import ActivityKit
import Foundation

/// Manages Live Activity lifecycle for printer monitoring
@MainActor
@Observable
final class ActivityManager {
    private(set) var currentActivityId: String?
    private(set) var activityToken: String?
    private(set) var lastError: String?

    private let apiClient: APIClient
    private let settings: SettingsStorage

    init(apiClient: APIClient, settings: SettingsStorage) {
        self.apiClient = apiClient
        self.settings = settings
    }

    var isActivityActive: Bool {
        currentActivityId != nil
    }

    func startActivity(
        filename: String,
        printerName: String,
        printerModel: String,
        entityPrefix: String,
        initialState: PrinterActivityAttributes.ContentState
    ) {
        // End any existing activities first
        endAllActivities()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "Live Activities are disabled"
            return
        }

        let attributes = PrinterActivityAttributes(
            filename: filename,
            startTime: Date(),
            printerName: printerName,
            printerModel: printerModel,
            entityPrefix: entityPrefix
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(120)),
                pushType: .token
            )

            currentActivityId = activity.id

            // Handle push token updates
            observePushToken(for: activity, entityPrefix: entityPrefix)

        } catch {
            lastError = error.localizedDescription
        }
    }

    func endActivity() {
        guard let activityId = currentActivityId else { return }

        Task {
            await Self.endActivityById(activityId)
        }

        currentActivityId = nil
        activityToken = nil
    }

    private func endAllActivities() {
        Task {
            await Self.endAllPrinterActivities()
        }
        currentActivityId = nil
        activityToken = nil
    }

    private func observePushToken(for activity: Activity<PrinterActivityAttributes>, entityPrefix: String) {
        let activityId = activity.id

        Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()

                await MainActor.run {
                    // Only update if this is still our current activity
                    if self?.currentActivityId == activityId {
                        self?.activityToken = tokenString
                    }
                }

                // Register with server
                await self?.registerActivityToken(tokenString, entityPrefix: entityPrefix)
                break
            }
        }
    }

    private func registerActivityToken(_ token: String, entityPrefix: String) async {
        let serverURL = settings.serverURL
        guard !serverURL.isEmpty else { return }

        do {
            try apiClient.configure(serverURL: serverURL)
            try await apiClient.registerActivityToken(
                activityToken: token,
                printerPrefix: entityPrefix
            )
        } catch {
            await MainActor.run { [weak self] in
                self?.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Static helpers (nonisolated)

    nonisolated private static func endActivityById(_ activityId: String) async {
        let activities = Activity<PrinterActivityAttributes>.activities
        if let activity = activities.first(where: { $0.id == activityId }) {
            await activity.end(dismissalPolicy: .default)
        }
    }

    nonisolated private static func endAllPrinterActivities() async {
        let activities = Activity<PrinterActivityAttributes>.activities
        for activity in activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
