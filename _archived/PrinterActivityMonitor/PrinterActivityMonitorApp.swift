import SwiftUI
import BackgroundTasks

@main
struct PrinterActivityMonitorApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var haService = HAAPIService()
    @StateObject private var activityManager = ActivityManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var historyService = PrintHistoryService()
    @StateObject private var deviceConfig = DeviceConfigurationManager()

    @State private var showDeviceSetup = false

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environmentObject(haService)
                .environmentObject(activityManager)
                .environmentObject(notificationManager)
                .environmentObject(historyService)
                .environmentObject(deviceConfig)
                .onReceive(haService.$printerState) { state in
                    // Handle notifications when printer state changes
                    notificationManager.handleStateUpdate(
                        state,
                        settings: settingsManager.settings.notificationSettings
                    )

                    // Update Live Activity when printer state changes
                    Task {
                        await activityManager.updateActivity(with: state)
                    }
                }
                .onAppear {
                    // Wire up the callback to sync entity prefix when primary printer changes
                    deviceConfig.onPrimaryPrinterChanged = { newPrefix in
                        settingsManager.settings.entityPrefix = newPrefix
                    }

                    // On first launch, sync entity prefix from discovered primary printer
                    if let primaryPrefix = deviceConfig.selectedPrinterPrefix,
                       settingsManager.settings.entityPrefix != primaryPrefix {
                        settingsManager.settings.entityPrefix = primaryPrefix
                    }

                    // Show device setup if not completed and HA is configured
                    if !deviceConfig.configuration.setupCompleted && settingsManager.settings.isConfigured {
                        showDeviceSetup = true
                    }
                }
                .sheet(isPresented: $showDeviceSetup) {
                    DeviceSetupView(showSetup: $showDeviceSetup)
                        .environmentObject(settingsManager)
                        .environmentObject(haService)
                        .environmentObject(deviceConfig)
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.samduncan.PrinterActivityMonitor.refresh",
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
        let request = BGAppRefreshTaskRequest(identifier: "com.samduncan.PrinterActivityMonitor.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
