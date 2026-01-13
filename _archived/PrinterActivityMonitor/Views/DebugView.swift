import SwiftUI

/// Debug console for verifying Home Assistant connection and sensor data
struct DebugView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var activityManager: ActivityManager

    @State private var sensorResults: [SensorResult] = []
    @State private var isTestingAll = false
    @State private var isTestingAMS = false
    @State private var isDiscovering = false
    @State private var lastFetchTime: Date?
    @State private var rawJSON: String = ""
    @State private var amsDebugJSON: String = ""
    @State private var showingCopyAlert = false
    @State private var discoveredPrinters: [DiscoveredPrinter] = []
    @State private var discoveredAMS: [DiscoveredAMS] = []

    // Mock Live Activity state
    @State private var mockProgress: Double = 45
    @State private var mockStatus: PrinterState.PrintStatus = .running
    @State private var mockCurrentLayer: Int = 125
    @State private var mockTotalLayers: Int = 280
    @State private var mockRemainingMinutes: Int = 84
    @State private var mockNozzleTemp: Double = 220
    @State private var mockBedTemp: Double = 60
    @State private var isStartingMockActivity = false

    var body: some View {
        NavigationStack {
            List {
                // Connection Status Section
                Section {
                    ConnectionStatusRow(
                        isConnected: haService.isConnected,
                        isLoading: haService.isLoading,
                        lastFetch: lastFetchTime,
                        serverURL: settingsManager.settings.haServerURL
                    )

                    if let error = haService.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Connection")
                }

                // Quick Actions
                Section {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        HStack {
                            Label("Refresh Data", systemImage: "arrow.clockwise")
                            Spacer()
                            if haService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(haService.isLoading)

                    Button {
                        Task {
                            await testAllSensors()
                        }
                    } label: {
                        HStack {
                            Label("Test All Sensors", systemImage: "checkmark.circle")
                            Spacer()
                            if isTestingAll {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingAll || !settingsManager.settings.isConfigured)

                    Button {
                        Task {
                            await testAMSWithDetails()
                        }
                    } label: {
                        HStack {
                            Label("Test AMS Entities", systemImage: "tray.2.fill")
                            Spacer()
                            if isTestingAMS {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingAMS || !settingsManager.settings.isConfigured)

                    Button {
                        Task {
                            await discoverAMSEntities()
                        }
                    } label: {
                        HStack {
                            Label("Discover ALL AMS Entities", systemImage: "magnifyingglass")
                            Spacer()
                            if isTestingAMS {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingAMS || !settingsManager.settings.isConfigured)

                    Button {
                        Task {
                            await autoDiscoverDevices()
                        }
                    } label: {
                        HStack {
                            Label("Auto-Discover Devices", systemImage: "wand.and.stars")
                            Spacer()
                            if isDiscovering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .tint(.purple)
                    .disabled(isDiscovering || !settingsManager.settings.isConfigured)
                } header: {
                    Text("Actions")
                }

                // MARK: - Mock Live Activity Section
                Section {
                    // Activity Status
                    HStack {
                        Circle()
                            .fill(activityManager.isActivityActive ? (activityManager.isMockMode ? Color.orange : Color.green) : Color.gray)
                            .frame(width: 12, height: 12)
                        Text(activityManager.isActivityActive
                             ? (activityManager.isMockMode ? "Mock Activity Active" : "Live Activity Active")
                             : "No Active Live Activity")
                            .font(.subheadline)
                        Spacer()
                        if activityManager.isMockMode {
                            Text("MOCK")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    if activityManager.isActivityActive {
                        // Progress Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(mockProgress))%")
                                    .font(.caption.bold())
                            }
                            Slider(value: $mockProgress, in: 0...100, step: 1)
                                .tint(settingsManager.settings.accentColor.color)
                        }

                        // Layer Controls
                        HStack {
                            Text("Layer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Stepper("\(mockCurrentLayer)/\(mockTotalLayers)", value: $mockCurrentLayer, in: 0...mockTotalLayers)
                                .font(.caption)
                        }

                        // Time Remaining
                        HStack {
                            Text("Time Left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Stepper("\(mockRemainingMinutes) min", value: $mockRemainingMinutes, in: 0...999, step: 5)
                                .font(.caption)
                        }

                        // Temperature Controls
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Nozzle: \(Int(mockNozzleTemp))°")
                                    .font(.caption)
                                Slider(value: $mockNozzleTemp, in: 0...300, step: 5)
                                    .frame(width: 100)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Bed: \(Int(mockBedTemp))°")
                                    .font(.caption)
                                Slider(value: $mockBedTemp, in: 0...120, step: 5)
                                    .frame(width: 100)
                            }
                        }

                        // Status Picker
                        Picker("Status", selection: $mockStatus) {
                            Text("Running").tag(PrinterState.PrintStatus.running)
                            Text("Paused").tag(PrinterState.PrintStatus.paused)
                            Text("Preparing").tag(PrinterState.PrintStatus.prepare)
                            Text("Finished").tag(PrinterState.PrintStatus.finish)
                            Text("Failed").tag(PrinterState.PrintStatus.failed)
                        }
                        .pickerStyle(.menu)

                        // Update Button
                        Button {
                            Task {
                                await updateMockActivity()
                            }
                        } label: {
                            Label("Update Live Activity", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .tint(.blue)

                        // Stop Button
                        Button(role: .destructive) {
                            Task {
                                await activityManager.endAllActivities()
                            }
                        } label: {
                            Label("Stop Live Activity", systemImage: "stop.circle.fill")
                        }
                    } else {
                        // Start Mock Activity Button
                        Button {
                            Task {
                                await startMockActivity()
                            }
                        } label: {
                            HStack {
                                Label("Start Mock Print Job", systemImage: "play.circle.fill")
                                Spacer()
                                if isStartingMockActivity {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .tint(.green)
                        .disabled(isStartingMockActivity)

                        // Quick presets
                        HStack(spacing: 12) {
                            Text("Presets:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("25%") { setMockPreset(progress: 25, layer: 70, time: 180) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Button("50%") { setMockPreset(progress: 50, layer: 140, time: 90) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Button("75%") { setMockPreset(progress: 75, layer: 210, time: 45) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Button("99%") { setMockPreset(progress: 99, layer: 277, time: 5) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    if let error = activityManager.activityError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Mock Live Activity", systemImage: "rectangle.badge.play")
                } footer: {
                    Text("Test Live Activity UI without starting a real print. Changes appear on Lock Screen and Dynamic Island.")
                }

                // Auto-Discovered Devices
                if !discoveredPrinters.isEmpty || !discoveredAMS.isEmpty {
                    Section {
                        if !discoveredPrinters.isEmpty {
                            ForEach(discoveredPrinters) { printer in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "printer.fill")
                                            .foregroundStyle(.blue)
                                        Text(printer.name)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(printer.entityCount) entities")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Text("Prefix:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(printer.prefix)
                                            .font(.system(.caption, design: .monospaced))
                                        if let model = printer.model {
                                            Spacer()
                                            Text(model)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        if !discoveredAMS.isEmpty {
                            ForEach(discoveredAMS) { ams in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "tray.2.fill")
                                            .foregroundStyle(.orange)
                                        Text(ams.name)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(ams.trayCount) trays")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Text("Prefix:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(ams.prefix)
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    if !ams.trayEntities.isEmpty {
                                        Text("Trays: \(ams.trayEntities.joined(separator: ", "))")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let humidity = ams.humidityEntity {
                                        Text("Humidity: \(humidity)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Discovered Devices")
                    } footer: {
                        Text("Found \(discoveredPrinters.count) printer(s) and \(discoveredAMS.count) AMS unit(s)")
                    }
                }

                // AMS Debug Results
                if !amsDebugJSON.isEmpty {
                    Section {
                        Text(amsDebugJSON)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)

                        Button {
                            UIPasteboard.general.string = amsDebugJSON
                            showingCopyAlert = true
                        } label: {
                            Label("Copy AMS Data", systemImage: "doc.on.doc")
                        }
                    } header: {
                        Text("AMS Entity Debug")
                    } footer: {
                        Text("Full entity data including attributes")
                    }
                }

                // Current Printer State
                Section {
                    PrinterStateRow(label: "Status", value: haService.printerState.status.rawValue, icon: "printer.fill")
                    PrinterStateRow(label: "Progress", value: "\(haService.printerState.progress)%", icon: "percent")
                    PrinterStateRow(label: "File", value: haService.printerState.fileName, icon: "doc.fill")
                    PrinterStateRow(label: "Layer", value: "\(haService.printerState.currentLayer)/\(haService.printerState.totalLayers)", icon: "square.stack.3d.up.fill")
                    PrinterStateRow(label: "Time Left", value: haService.printerState.formattedTimeRemaining, icon: "clock.fill")
                    PrinterStateRow(label: "Nozzle", value: String(format: "%.1f°C", haService.printerState.nozzleTemp), icon: "flame.fill")
                    PrinterStateRow(label: "Bed", value: String(format: "%.1f°C", haService.printerState.bedTemp), icon: "rectangle.fill")
                    PrinterStateRow(label: "Speed", value: "\(haService.printerState.printSpeed)%", icon: "speedometer")
                    PrinterStateRow(label: "Filament", value: String(format: "%.1fg", haService.printerState.filamentUsed), icon: "cylinder.fill")
                } header: {
                    Text("Current State")
                } footer: {
                    Text("Data from HAAPIService.printerState")
                }

                // Individual Sensor Test Results
                if !sensorResults.isEmpty {
                    Section {
                        ForEach(sensorResults) { result in
                            SensorResultRow(result: result)
                        }
                    } header: {
                        Text("Sensor Test Results")
                    } footer: {
                        let successCount = sensorResults.filter { $0.status == .success }.count
                        Text("\(successCount)/\(sensorResults.count) sensors responding")
                    }
                }

                // Raw JSON Section
                if !rawJSON.isEmpty {
                    Section {
                        Text(rawJSON)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)

                        Button {
                            UIPasteboard.general.string = rawJSON
                            showingCopyAlert = true
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                    } header: {
                        Text("Raw Data")
                    }
                }

                // Configuration Info
                Section {
                    LabeledContent("Server URL") {
                        Text(settingsManager.settings.haServerURL.isEmpty ? "Not set" : settingsManager.settings.haServerURL)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    LabeledContent("Entity Prefix") {
                        Text(settingsManager.settings.entityPrefix)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Refresh Interval") {
                        Text("\(settingsManager.settings.refreshInterval)s")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Token Set") {
                        Image(systemName: settingsManager.settings.haAccessToken.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(settingsManager.settings.haAccessToken.isEmpty ? .red : .green)
                    }
                } header: {
                    Text("Configuration")
                }
            }
            .navigationTitle("Debug Console")
            .refreshable {
                await refreshData()
            }
            .alert("Copied!", isPresented: $showingCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Raw JSON copied to clipboard")
            }
            .onAppear {
                lastFetchTime = Date()
            }
        }
    }

    private func refreshData() async {
        lastFetchTime = Date()
        do {
            _ = try await haService.fetchPrinterState()
        } catch {
            // Error is handled by haService.lastError
        }
    }

    private func testAllSensors() async {
        isTestingAll = true
        sensorResults = []
        rawJSON = ""

        // Core print sensors
        let sensors = [
            "print_progress",
            "print_status",
            "current_layer",
            "total_layer_count",
            "remaining_time",
            "subtask_name",
            "nozzle_temperature",
            "bed_temperature",
            "speed_profile",
            "filament_used"
        ]

        // AMS sensors - try multiple naming conventions
        let amsSensors = [
            // Standard naming
            "ams_humidity",
            "ams_active_tray",
            "ams_drying",
            "ams_remaining_drying_time",
            // Tray sensors (1-4)
            "ams_tray_1",
            "ams_tray_2",
            "ams_tray_3",
            "ams_tray_4",
            // Alternative naming conventions
            "ams_1_color",
            "ams_1_type",
            "ams_1_remaining",
            "ams_slot_1",
            "ams_slot_1_color",
            // External spool
            "external_spool"
        ]

        var results: [SensorResult] = []
        var jsonDict: [String: String] = [:]

        // Test core sensors
        for sensor in sensors {
            let result = await haService.testSensor(sensor)
            results.append(result)
            jsonDict[sensor] = result.value ?? result.error ?? "unknown"
        }

        // Test AMS sensors
        for sensor in amsSensors {
            let result = await haService.testSensor(sensor)
            results.append(result)
            jsonDict["ams:\(sensor)"] = result.value ?? result.error ?? "unknown"
        }

        sensorResults = results

        // Format as JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            rawJSON = jsonString
        }

        isTestingAll = false
    }

    private func autoDiscoverDevices() async {
        isDiscovering = true
        discoveredPrinters = []
        discoveredAMS = []

        do {
            let (printers, amsUnits) = try await haService.discoverAllDevices()
            discoveredPrinters = printers
            discoveredAMS = amsUnits

            // Also output as JSON for debugging
            var resultDict: [String: Any] = [:]
            resultDict["printers"] = printers.map { [
                "prefix": $0.prefix,
                "name": $0.name,
                "model": $0.model ?? "Unknown",
                "entityCount": $0.entityCount
            ]}
            resultDict["amsUnits"] = amsUnits.map { [
                "prefix": $0.prefix,
                "name": $0.name,
                "trayCount": $0.trayCount,
                "trayEntities": $0.trayEntities,
                "humidityEntity": $0.humidityEntity ?? "none",
                "temperatureEntity": $0.temperatureEntity ?? "none"
            ]}

            let jsonData = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys]
            )
            amsDebugJSON = String(data: jsonData, encoding: .utf8) ?? "Failed to format"
        } catch {
            amsDebugJSON = "Error: \(error.localizedDescription)"
        }

        isDiscovering = false
    }

    private func discoverAMSEntities() async {
        isTestingAMS = true
        amsDebugJSON = "Discovering all AMS-related entities..."

        do {
            // Search for entities containing these keywords
            let keywords = ["ams", "tray", "filament", "spool", "active_tray"]
            let results = try await haService.discoverEntities(containing: keywords)

            // Format results as pretty JSON
            let jsonData = try JSONSerialization.data(
                withJSONObject: results,
                options: [.prettyPrinted, .sortedKeys]
            )
            amsDebugJSON = String(data: jsonData, encoding: .utf8) ?? "Failed to format JSON"
        } catch {
            amsDebugJSON = "Error discovering entities: \(error.localizedDescription)"
        }

        isTestingAMS = false
    }

    private func testAMSWithDetails() async {
        isTestingAMS = true
        amsDebugJSON = "Fetching AMS data..."

        var results: [String: Any] = [:]
        let prefix = settingsManager.settings.entityPrefix

        // Try various AMS entity naming conventions
        // The ha-bambulab integration uses different patterns:
        // - sensor.{prefix}_ams_1_tray_1 (with AMS unit number)
        // - sensor.{prefix}_ams_tray_1 (without unit number)
        // - sensor.{prefix}_{serial}_ams_1_tray_1 (with serial)
        let amsEntityPatterns = [
            // WITH AMS unit number (most common for ha-bambulab)
            "sensor.\(prefix)_ams_1_tray_1",
            "sensor.\(prefix)_ams_1_tray_2",
            "sensor.\(prefix)_ams_1_tray_3",
            "sensor.\(prefix)_ams_1_tray_4",
            // Second AMS unit
            "sensor.\(prefix)_ams_2_tray_1",
            // WITHOUT AMS unit number (older versions)
            "sensor.\(prefix)_ams_tray_1",
            "sensor.\(prefix)_ams_tray_2",
            "sensor.\(prefix)_ams_tray_3",
            "sensor.\(prefix)_ams_tray_4",
            // AMS unit sensors
            "sensor.\(prefix)_ams_1_humidity",
            "sensor.\(prefix)_ams_humidity",
            "sensor.\(prefix)_humidity_index",
            "sensor.\(prefix)_ams_1_temperature",
            "sensor.\(prefix)_ams_temperature",
            // Active tray
            "sensor.\(prefix)_active_tray",
            "sensor.\(prefix)_active_tray_index",
            "sensor.\(prefix)_ams_1_active_tray",
            // Drying
            "sensor.\(prefix)_ams_1_drying",
            "sensor.\(prefix)_ams_drying",
            "sensor.\(prefix)_ams_1_remaining_drying_time",
            "switch.\(prefix)_ams_drying",
            "binary_sensor.\(prefix)_ams_drying",
            // External spool
            "sensor.\(prefix)_external_spool",
        ]

        for entityId in amsEntityPatterns {
            do {
                let entity = try await haService.fetchEntityWithAttributes(entityId)
                // Convert attributes to string representation
                var attrsDict: [String: String] = [:]
                for (key, value) in entity.attributes {
                    attrsDict[key] = "\(value)"
                }
                results[entityId] = [
                    "state": entity.state,
                    "attributes": attrsDict
                ]
            } catch {
                results[entityId] = ["error": error.localizedDescription]
            }
        }

        // Format results as pretty JSON
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: results,
                options: [.prettyPrinted, .sortedKeys]
            )
            amsDebugJSON = String(data: jsonData, encoding: .utf8) ?? "Failed to format JSON"
        } catch {
            amsDebugJSON = "Error: \(error.localizedDescription)"
        }

        isTestingAMS = false
    }

    private func testAMSEntitiesWithAttributes() async -> [String: Any] {
        var results: [String: Any] = [:]
        let prefix = settingsManager.settings.entityPrefix

        // Try fetching AMS tray entities with full attributes
        for i in 1...4 {
            let entityId = "sensor.\(prefix)_ams_tray_\(i)"
            do {
                let entity = try await haService.fetchEntityWithAttributes(entityId)
                results["tray_\(i)"] = [
                    "state": entity.state,
                    "attributes": entity.attributes.mapValues { "\($0)" }
                ]
            } catch {
                results["tray_\(i)"] = ["error": error.localizedDescription]
            }
        }

        // Try humidity
        let humidityId = "sensor.\(prefix)_ams_humidity"
        do {
            let entity = try await haService.fetchEntityWithAttributes(humidityId)
            results["humidity"] = ["state": entity.state, "attributes": entity.attributes.mapValues { "\($0)" }]
        } catch {
            results["humidity"] = ["error": error.localizedDescription]
        }

        return results
    }

    // MARK: - Mock Live Activity Methods

    private func setMockPreset(progress: Double, layer: Int, time: Int) {
        mockProgress = progress
        mockCurrentLayer = layer
        mockRemainingMinutes = time
    }

    private func startMockActivity() async {
        isStartingMockActivity = true

        let mockState = createMockPrinterState()

        do {
            try await activityManager.startMockActivity(
                fileName: "mock_benchy_test.gcode",
                initialState: mockState,
                settings: settingsManager.settings
            )
        } catch {
            // Error is captured in activityManager.activityError
        }

        isStartingMockActivity = false
    }

    private func updateMockActivity() async {
        let mockState = createMockPrinterState()
        await activityManager.updateMockActivity(with: mockState)
    }

    private func createMockPrinterState() -> PrinterState {
        PrinterState(
            progress: Int(mockProgress),
            currentLayer: mockCurrentLayer,
            totalLayers: mockTotalLayers,
            remainingMinutes: mockRemainingMinutes,
            status: mockStatus,
            fileName: "mock_benchy_test.gcode",
            printSpeed: 100,
            filamentUsed: Double(mockCurrentLayer) * 0.15,
            nozzleTemp: mockNozzleTemp,
            nozzleTargetTemp: 220,
            bedTemp: mockBedTemp,
            bedTargetTemp: 60,
            chamberTemp: 35,
            currentStage: mockStatus == .running ? "Printing" : mockStatus.rawValue.capitalized,
            printWeight: 12.5,
            printLength: 4.2,
            bedType: "Textured PEI",
            startTime: Date().addingTimeInterval(-Double(mockRemainingMinutes) * 60 * (mockProgress / 100)),
            endTime: Date().addingTimeInterval(Double(mockRemainingMinutes) * 60),
            auxFanSpeed: 0,
            chamberFanSpeed: 50,
            coolingFanSpeed: 80,
            isOnline: true,
            wifiSignal: -45,
            hmsErrors: "",
            coverImageURL: nil,
            printerModel: .x1c
        )
    }
}

// MARK: - Supporting Views

struct ConnectionStatusRow: View {
    let isConnected: Bool
    let isLoading: Bool
    let lastFetch: Date?
    let serverURL: String

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.headline)

                if let lastFetch = lastFetch {
                    Text("Last fetch: \(lastFetch.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private var statusColor: Color {
        if isLoading { return .orange }
        return isConnected ? .green : .red
    }

    private var statusText: String {
        if isLoading { return "Fetching..." }
        return isConnected ? "Connected" : "Disconnected"
    }
}

struct PrinterStateRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct SensorResultRow: View {
    let result: SensorResult

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.sensorName)
                    .font(.system(.body, design: .monospaced))

                if let value = result.value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = result.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Text(result.responseTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusIcon: String {
        switch result.status {
        case .success: return "checkmark.circle.fill"
        case .notFound: return "questionmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .success: return .green
        case .notFound: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Data Models

struct SensorResult: Identifiable {
    let id = UUID()
    let sensorName: String
    let status: SensorStatus
    let value: String?
    let error: String?
    let responseTime: String

    enum SensorStatus {
        case success
        case notFound
        case error
    }
}

#Preview {
    DebugView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(DeviceConfigurationManager())
        .environmentObject(ActivityManager())
}
