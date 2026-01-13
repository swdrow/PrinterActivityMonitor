import Foundation
import UserNotifications

/// Manages local notifications for printer status updates
@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // Track previous state to detect changes
    private var previousStatus: PrinterState.PrintStatus?
    private var previousProgress: Int = 0
    private var lastMilestoneNotified: Int = 0

    // Notification category identifiers
    static let printStatusCategory = "PRINT_STATUS"
    static let printCompleteCategory = "PRINT_COMPLETE"
    static let printFailedCategory = "PRINT_FAILED"

    override init() {
        super.init()
        // Set self as delegate to show notifications while app is in foreground
        UNUserNotificationCenter.current().delegate = self
        Task {
            await checkAuthorizationStatus()
            await registerNotificationCategories()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle the notification tap if needed
        completionHandler()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            await checkAuthorizationStatus()
            return granted
        } catch {
            // Authorization error occurred
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() async {
        let center = UNUserNotificationCenter.current()

        // Print status category (basic status updates)
        let statusCategory = UNNotificationCategory(
            identifier: Self.printStatusCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Print complete category
        let completeCategory = UNNotificationCategory(
            identifier: Self.printCompleteCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Print failed category (with potential for critical alerts)
        let failedCategory = UNNotificationCategory(
            identifier: Self.printFailedCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([statusCategory, completeCategory, failedCategory])
    }

    // MARK: - State Change Detection

    /// Call this when printer state updates to check if notifications should be sent
    func handleStateUpdate(_ state: PrinterState, settings: NotificationSettings) {
        guard settings.enabled && isAuthorized else { return }

        let currentStatus = state.status
        let currentProgress = state.progress

        // Check for status changes
        if let previous = previousStatus, previous != currentStatus {
            handleStatusChange(from: previous, to: currentStatus, state: state, settings: settings)
        }

        // Check for layer milestones
        if settings.notifyOnLayerMilestones && currentStatus == .running {
            checkLayerMilestone(progress: currentProgress, settings: settings, state: state)
        }

        // Update previous state
        previousStatus = currentStatus
        previousProgress = currentProgress
    }

    private func handleStatusChange(
        from previous: PrinterState.PrintStatus,
        to current: PrinterState.PrintStatus,
        state: PrinterState,
        settings: NotificationSettings
    ) {
        switch current {
        case .running:
            // Print started (from idle/prepare) or resumed (from paused)
            if previous == .idle || previous == .prepare || previous == .unknown {
                if settings.notifyOnPrintStart {
                    sendPrintStartedNotification(state: state)
                }
                // Reset milestone tracking for new print
                lastMilestoneNotified = 0
            }

        case .paused:
            if settings.notifyOnPrintPaused && previous == .running {
                sendPrintPausedNotification(state: state)
            }

        case .finish:
            if settings.notifyOnPrintComplete {
                sendPrintCompleteNotification(state: state)
            }

        case .failed:
            if settings.notifyOnPrintFailed {
                sendPrintFailedNotification(state: state, isCritical: settings.criticalAlertsEnabled)
            }

        default:
            break
        }
    }

    private func checkLayerMilestone(progress: Int, settings: NotificationSettings, state: PrinterState) {
        let interval = settings.layerMilestoneInterval
        guard interval > 0 else { return }

        // Calculate which milestone we're at
        let currentMilestone = (progress / interval) * interval

        // Only notify if we've reached a new milestone
        if currentMilestone > lastMilestoneNotified && currentMilestone > 0 && currentMilestone < 100 {
            lastMilestoneNotified = currentMilestone
            sendMilestoneNotification(progress: currentMilestone, state: state)
        }
    }

    // MARK: - Send Notifications

    private func sendPrintStartedNotification(state: PrinterState) {
        let content = UNMutableNotificationContent()
        content.title = "Print Started"
        content.body = "\(state.fileName) has started printing. Estimated time: \(state.formattedTimeRemaining)"
        content.sound = .default
        content.categoryIdentifier = Self.printStatusCategory

        scheduleNotification(content: content, identifier: "print-started-\(Date().timeIntervalSince1970)")
    }

    private func sendPrintCompleteNotification(state: PrinterState) {
        let content = UNMutableNotificationContent()
        content.title = "Print Complete!"
        content.body = "\(state.fileName) has finished printing successfully."
        content.sound = .default
        content.categoryIdentifier = Self.printCompleteCategory

        scheduleNotification(content: content, identifier: "print-complete-\(Date().timeIntervalSince1970)")
    }

    private func sendPrintFailedNotification(state: PrinterState, isCritical: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Print Failed"
        content.body = "\(state.fileName) has failed. Check your printer."
        content.categoryIdentifier = Self.printFailedCategory

        if isCritical {
            // Critical alerts require special entitlement from Apple
            // For now, use prominent sound
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            content.sound = .default
        }

        scheduleNotification(content: content, identifier: "print-failed-\(Date().timeIntervalSince1970)")
    }

    private func sendPrintPausedNotification(state: PrinterState) {
        let content = UNMutableNotificationContent()
        content.title = "Print Paused"
        content.body = "\(state.fileName) is paused at \(state.progress)%"
        content.sound = .default
        content.categoryIdentifier = Self.printStatusCategory

        scheduleNotification(content: content, identifier: "print-paused-\(Date().timeIntervalSince1970)")
    }

    private func sendMilestoneNotification(progress: Int, state: PrinterState) {
        let content = UNMutableNotificationContent()
        content.title = "\(progress)% Complete"
        content.body = "\(state.fileName) - \(state.formattedTimeRemaining) remaining"
        content.sound = .default
        content.categoryIdentifier = Self.printStatusCategory

        scheduleNotification(content: content, identifier: "milestone-\(progress)-\(Date().timeIntervalSince1970)")
    }

    // MARK: - Helpers

    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // Notification scheduling failed
            }
        }
    }

    /// Clear all pending notifications
    func clearPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Reset state tracking (e.g., when app becomes active)
    func resetStateTracking() {
        previousStatus = nil
        previousProgress = 0
        lastMilestoneNotified = 0
    }

    // MARK: - Debug/Testing

    /// Send a test notification to verify notifications are working
    func sendTestNotification(type: TestNotificationType) {
        let content = UNMutableNotificationContent()

        switch type {
        case .printStarted:
            content.title = "Print Started"
            content.body = "test_print.3mf has started printing. Estimated time: 2h 30m"
            content.categoryIdentifier = Self.printStatusCategory
        case .printComplete:
            content.title = "Print Complete!"
            content.body = "test_print.3mf has finished printing successfully."
            content.categoryIdentifier = Self.printCompleteCategory
        case .printFailed:
            content.title = "Print Failed"
            content.body = "test_print.3mf has failed. Check your printer."
            content.categoryIdentifier = Self.printFailedCategory
        case .printPaused:
            content.title = "Print Paused"
            content.body = "test_print.3mf is paused at 45%"
            content.categoryIdentifier = Self.printStatusCategory
        case .milestone:
            content.title = "50% Complete"
            content.body = "test_print.3mf - 1h 15m remaining"
            content.categoryIdentifier = Self.printStatusCategory
        }

        content.sound = .default
        scheduleNotification(content: content, identifier: "test-\(type.rawValue)-\(Date().timeIntervalSince1970)")
    }

    enum TestNotificationType: String, CaseIterable {
        case printStarted = "started"
        case printComplete = "complete"
        case printFailed = "failed"
        case printPaused = "paused"
        case milestone = "milestone"

        var displayName: String {
            switch self {
            case .printStarted: return "Print Started"
            case .printComplete: return "Print Complete"
            case .printFailed: return "Print Failed"
            case .printPaused: return "Print Paused"
            case .milestone: return "50% Milestone"
            }
        }

        var icon: String {
            switch self {
            case .printStarted: return "play.circle.fill"
            case .printComplete: return "checkmark.circle.fill"
            case .printFailed: return "xmark.circle.fill"
            case .printPaused: return "pause.circle.fill"
            case .milestone: return "chart.bar.fill"
            }
        }
    }
}
