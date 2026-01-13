import ActivityKit
import Foundation

/// Manages Live Activity lifecycle
@MainActor
class ActivityManager: ObservableObject {
    @Published var isActivityActive: Bool = false
    @Published var activityError: String?
    @Published var isMockMode: Bool = false

    private var currentActivity: Activity<PrinterActivityAttributes>?

    init() {
        // Check if there's an existing activity
        checkExistingActivities()
    }

    private func checkExistingActivities() {
        for activity in Activity<PrinterActivityAttributes>.activities {
            currentActivity = activity
            isActivityActive = true
            break
        }
    }

    /// Start a new Live Activity for a print job
    func startActivity(
        fileName: String,
        initialState: PrinterState,
        settings: AppSettings
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw ActivityError.notAuthorized
        }

        // End any existing activity first (await to avoid race condition)
        await endAllActivities()

        let attributes = PrinterActivityAttributes(
            fileName: fileName,
            startTime: Date(),
            printerModel: initialState.printerModel.rawValue,
            showLayers: settings.showLayers,
            showNozzleTemp: settings.showNozzleTemp,
            showBedTemp: settings.showBedTemp,
            accentColorName: settings.accentColor.rawValue,
            compactMode: settings.compactMode
        )

        let contentState = PrinterActivityAttributes.ContentState(
            progress: initialState.progress,
            currentLayer: initialState.currentLayer,
            totalLayers: initialState.totalLayers,
            remainingMinutes: initialState.remainingMinutes,
            status: initialState.status.rawValue,
            nozzleTemp: initialState.nozzleTemp,
            bedTemp: initialState.bedTemp,
            chamberTemp: initialState.chamberTemp,
            nozzleTargetTemp: initialState.nozzleTargetTemp,
            bedTargetTemp: initialState.bedTargetTemp,
            currentStage: initialState.currentStage,
            coverImageURL: initialState.coverImageURL
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil // Local updates only (no APNs needed for $0 option)
            )
            currentActivity = activity
            isActivityActive = true
            activityError = nil
        } catch {
            activityError = error.localizedDescription
            throw error
        }
    }

    /// Update the Live Activity with new printer state
    func updateActivity(with state: PrinterState) async {
        // Skip real updates when in mock mode
        guard !isMockMode else { return }
        guard let activity = currentActivity else { return }

        let contentState = PrinterActivityAttributes.ContentState(
            progress: state.progress,
            currentLayer: state.currentLayer,
            totalLayers: state.totalLayers,
            remainingMinutes: state.remainingMinutes,
            status: state.status.rawValue,
            nozzleTemp: state.nozzleTemp,
            bedTemp: state.bedTemp,
            chamberTemp: state.chamberTemp,
            nozzleTargetTemp: state.nozzleTargetTemp,
            bedTargetTemp: state.bedTargetTemp,
            currentStage: state.currentStage,
            coverImageURL: state.coverImageURL
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes
        )

        await activity.update(activityContent)

        // Auto-end if print finished or failed
        if state.status == .finish || state.status == .failed || state.status == .idle {
            await endActivity(dismissalPolicy: .default)
        }
    }

    /// Update the Live Activity with mock state (no auto-end logic)
    func updateMockActivity(with state: PrinterState) async {
        guard let activity = currentActivity else { return }

        let contentState = PrinterActivityAttributes.ContentState(
            progress: state.progress,
            currentLayer: state.currentLayer,
            totalLayers: state.totalLayers,
            remainingMinutes: state.remainingMinutes,
            status: state.status.rawValue,
            nozzleTemp: state.nozzleTemp,
            bedTemp: state.bedTemp,
            chamberTemp: state.chamberTemp,
            nozzleTargetTemp: state.nozzleTargetTemp,
            bedTargetTemp: state.bedTargetTemp,
            currentStage: state.currentStage,
            coverImageURL: state.coverImageURL
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes
        )

        await activity.update(activityContent)
        // Note: No auto-end logic for mock mode - user controls when to stop
    }

    /// End the current Live Activity
    func endActivity(dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }

        let finalState = PrinterActivityAttributes.ContentState(
            progress: 100,
            currentLayer: 0,
            totalLayers: 0,
            remainingMinutes: 0,
            status: "finish",
            nozzleTemp: 0,
            bedTemp: 0,
            chamberTemp: 0,
            nozzleTargetTemp: 0,
            bedTargetTemp: 0,
            currentStage: "",
            coverImageURL: nil
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        currentActivity = nil
        isActivityActive = false
    }

    /// End all active Live Activities
    func endAllActivities() async {
        for activity in Activity<PrinterActivityAttributes>.activities {
            let finalContent = ActivityContent(
                state: PrinterActivityAttributes.ContentState(
                    progress: 0,
                    currentLayer: 0,
                    totalLayers: 0,
                    remainingMinutes: 0,
                    status: "idle",
                    nozzleTemp: 0,
                    bedTemp: 0,
                    chamberTemp: 0,
                    nozzleTargetTemp: 0,
                    bedTargetTemp: 0,
                    currentStage: "",
                    coverImageURL: nil
                ),
                staleDate: nil
            )
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        isActivityActive = false
        isMockMode = false
    }

    /// Start a mock Live Activity for testing
    func startMockActivity(
        fileName: String,
        initialState: PrinterState,
        settings: AppSettings
    ) async throws {
        isMockMode = true
        try await startActivity(fileName: fileName, initialState: initialState, settings: settings)
    }
}

enum ActivityError: LocalizedError {
    case notAuthorized
    case alreadyActive

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Live Activities are not enabled. Enable them in Settings > Printer Monitor > Live Activities"
        case .alreadyActive:
            return "A Live Activity is already running"
        }
    }
}
