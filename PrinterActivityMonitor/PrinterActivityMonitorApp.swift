import SwiftUI
import BackgroundTasks

@main
struct PrinterActivityMonitorApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var haService = HAAPIService()
    @StateObject private var activityManager = ActivityManager()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environmentObject(haService)
                .environmentObject(activityManager)
                .onAppear {
                    haService.configure(with: settingsManager.settings)
                }
                .onChange(of: settingsManager.settings) { _, newSettings in
                    haService.configure(with: newSettings)
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yourname.PrinterActivityMonitor.refresh",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let fetchTask = Task {
            do {
                let state = try await haService.fetchPrinterState()
                await activityManager.updateActivity(with: state)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            fetchTask.cancel()
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourname.PrinterActivityMonitor.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
