import SwiftUI

struct AMSView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var haService: HAAPIService
    @EnvironmentObject var deviceConfig: DeviceConfigurationManager
    @State private var amsState: AMSState = .placeholder
    @State private var isLoading: Bool = false
    @State private var selectedSlot: AMSSlot?
    @State private var actionError: String?
    @State private var showingError: Bool = false
    @State private var isPerformingAction: Bool = false

    private var accentColor: Color {
        settingsManager.settings.accentColor.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if !amsState.isConnected {
                        AMSDisconnectedCard(accentColor: settingsManager.settings.accentColor)
                    } else {
                        // Humidity & Environment Card
                        HumidityCard(
                            amsState: amsState,
                            accentColor: settingsManager.settings.accentColor,
                            onStartDrying: startDrying,
                            onStopDrying: stopDrying,
                            isPerformingAction: isPerformingAction
                        )

                        // Filament Slots Grid
                        FilamentSlotsGrid(
                            slots: amsState.slots,
                            accentColor: settingsManager.settings.accentColor,
                            onSlotTap: { slot in selectedSlot = slot }
                        )

                        // Low Filament Warnings
                        if !amsState.lowFilamentSlots.isEmpty {
                            LowFilamentWarningCard(
                                slots: amsState.lowFilamentSlots,
                                accentColor: settingsManager.settings.accentColor
                            )
                        }

                        // Quick Actions
                        AMSQuickActionsCard(
                            accentColor: settingsManager.settings.accentColor,
                            isPerformingAction: isPerformingAction,
                            onRefreshRFID: refreshAllRFID,
                            onRetract: retractFilament
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background {
                DarkModeBackground(accentColor: accentColor, style: .ambient)
            }
            .navigationTitle("AMS")
            .refreshable {
                await fetchAMSState()
            }
            .onAppear {
                Task { await fetchAMSState() }
            }
            .sheet(item: $selectedSlot) { slot in
                FilamentActionSheet(
                    slot: slot,
                    accentColor: settingsManager.settings.accentColor,
                    isPerformingAction: isPerformingAction,
                    onLoad: { loadFilament(slot: slot) },
                    onUnload: { unloadFilament(slot: slot) },
                    onReadRFID: { readRFID(slot: slot) }
                )
                .presentationDetents([.medium])
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Data Fetching

    private func fetchAMSState() async {
        isLoading = true
        defer { isLoading = false }

        guard let amsConfig = deviceConfig.configuration.enabledAMSUnits.first else {
            await fetchAMSStateFallback()
            return
        }

        do {
            var slots: [AMSSlot] = []
            for entityId in amsConfig.trayEntities {
                do {
                    let trayData = try await haService.fetchAMSTrayByEntityId(entityId)
                    slots.append(trayData.toAMSSlot())
                } catch {
                    let trayNum = extractTrayNumber(from: entityId)
                    slots.append(AMSSlot.empty(index: trayNum - 1))
                }
            }

            var humidity = 0
            if let humidityEntityId = amsConfig.humidityEntity {
                if let entity = try? await haService.fetchEntityWithAttributes(humidityEntityId) {
                    humidity = Int(entity.state) ?? 0
                }
            }

            var temperature = 0
            if let temperatureEntityId = amsConfig.temperatureEntity {
                if let entity = try? await haService.fetchEntityWithAttributes(temperatureEntityId) {
                    temperature = Int(Double(entity.state) ?? 0)
                }
            }

            let prefix = settingsManager.settings.entityPrefix
            var isDrying = false
            var dryingRemaining = 0
            var dryingTargetTemp = 0

            let dryingPatterns = ["switch.\(prefix)_ams_drying", "sensor.\(prefix)_ams_drying"]
            for entityId in dryingPatterns {
                if let entity = try? await haService.fetchEntityWithAttributes(entityId) {
                    isDrying = entity.state.lowercased() == "on" || entity.state == "true"
                    break
                }
            }

            if let entity = try? await haService.fetchEntityWithAttributes("sensor.\(prefix)_ams_remaining_drying_time") {
                dryingRemaining = Int(entity.state) ?? 0
            }
            if let entity = try? await haService.fetchEntityWithAttributes("number.\(prefix)_drying_temperature") {
                dryingTargetTemp = Int(Double(entity.state) ?? 0)
            }

            var activeTrayIndex = 0
            if let activeTrayEntity = try? await haService.fetchEntityWithAttributes("sensor.\(prefix)_active_tray") {
                if let trayIndex = activeTrayEntity.intAttribute("tray_index") {
                    activeTrayIndex = trayIndex
                }
            }

            for i in slots.indices {
                slots[i].isActive = (slots[i].id + 1 == activeTrayIndex)
            }

            amsState = AMSState(
                slots: slots,
                humidity: humidity,
                temperature: temperature,
                isDrying: isDrying,
                dryingRemainingTime: dryingRemaining,
                dryingTargetTemp: dryingTargetTemp,
                isConnected: true
            )
        } catch {
            amsState = .placeholder
        }
    }

    private func fetchAMSStateFallback() async {
        if !deviceConfig.configuration.amsUnits.isEmpty && deviceConfig.configuration.enabledAMSUnits.isEmpty {
            if let firstAMS = deviceConfig.configuration.amsUnits.first {
                deviceConfig.toggleAMS(firstAMS)
                await fetchAMSState()
                return
            }
        }

        do {
            let amsStatus = try await haService.fetchAMSStatus()
            guard amsStatus.isConnected else {
                amsState = .placeholder
                return
            }

            var slots: [AMSSlot] = []
            for trayNum in 1...4 {
                do {
                    let trayData = try await haService.fetchAMSTray(trayNum)
                    var slot = trayData.toAMSSlot()
                    slot.isActive = (trayNum == amsStatus.activeTrayIndex)
                    slots.append(slot)
                } catch {
                    slots.append(AMSSlot.empty(index: trayNum - 1))
                }
            }

            let prefix = settingsManager.settings.entityPrefix
            var temperature = 0
            var dryingTargetTemp = 0

            if let entity = try? await haService.fetchEntityWithAttributes("sensor.\(prefix)_ams_temperature") {
                temperature = Int(Double(entity.state) ?? 0)
            }
            if let entity = try? await haService.fetchEntityWithAttributes("number.\(prefix)_drying_temperature") {
                dryingTargetTemp = Int(Double(entity.state) ?? 0)
            }

            amsState = AMSState(
                slots: slots,
                humidity: amsStatus.humidity,
                temperature: temperature,
                isDrying: amsStatus.isDrying,
                dryingRemainingTime: amsStatus.dryingRemainingMinutes,
                dryingTargetTemp: dryingTargetTemp,
                isConnected: true
            )
        } catch {
            amsState = .placeholder
        }
    }

    private func extractTrayNumber(from entityId: String) -> Int {
        if let range = entityId.range(of: "_tray_(\\d+)$", options: .regularExpression) {
            let numberPart = entityId[range].dropFirst(6)
            return Int(numberPart) ?? 1
        }
        return 1
    }

    // MARK: - Actions

    private func loadFilament(slot: AMSSlot) {
        performAction {
            try await haService.loadFilament(slot: slot.id)
            hapticFeedback(.success)
            selectedSlot = nil
        }
    }

    private func unloadFilament(slot: AMSSlot) {
        performAction {
            try await haService.unloadFilament(slot: slot.id)
            hapticFeedback(.success)
            selectedSlot = nil
        }
    }

    private func readRFID(slot: AMSSlot) {
        performAction {
            try await haService.readAMSRFID(slot: slot.id)
            hapticFeedback(.light)
            await fetchAMSState()
        }
    }

    private func refreshAllRFID() {
        performAction {
            for i in 0..<4 {
                try await haService.readAMSRFID(slot: i)
            }
            hapticFeedback(.success)
            await fetchAMSState()
        }
    }

    private func retractFilament() {
        performAction {
            try await haService.retractFilament()
            hapticFeedback(.success)
        }
    }

    private func startDrying(temperature: Int, duration: Int) {
        performAction {
            try? await haService.setDryingTemperature(temperature)
            try? await haService.setDryingDuration(duration)
            try await haService.startFilamentDrying()
            hapticFeedback(.success)
            await fetchAMSState()
        }
    }

    private func stopDrying() {
        performAction {
            try await haService.stopFilamentDrying()
            hapticFeedback(.warning)
            await fetchAMSState()
        }
    }

    private func performAction(_ action: @escaping () async throws -> Void) {
        isPerformingAction = true
        Task {
            do {
                try await action()
            } catch {
                actionError = error.localizedDescription
                showingError = true
                hapticFeedback(.error)
            }
            isPerformingAction = false
        }
    }

    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - AMS Disconnected Card

struct AMSDisconnectedCard: View {
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.warning)

                Text("AMS Not Detected")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("The Automatic Material System is not connected or not responding. Check your printer connection.")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DS.Spacing.lg)
        }
    }
}

// MARK: - Humidity Card

struct HumidityCard: View {
    let amsState: AMSState
    let accentColor: AccentColorOption
    let onStartDrying: (Int, Int) -> Void
    let onStopDrying: () -> Void
    let isPerformingAction: Bool
    @State private var showingDryingConfig = false

    var body: some View {
        GlassCard {
            VStack(spacing: DS.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "cloud.fill")
                            .foregroundStyle(DS.Colors.accent)
                        Text("Environment")
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                    }

                    Spacer()

                    // Temperature
                    if amsState.temperature > 0 {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "thermometer.medium")
                                .foregroundStyle(DS.Colors.warning)
                            Text("\(amsState.temperature)°C")
                                .font(DS.Typography.label)
                                .foregroundStyle(DS.Colors.warning)
                        }
                    }

                    // Humidity
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: amsState.humidityLevel.icon)
                            .foregroundStyle(amsState.humidityLevel.color)
                        Text("\(amsState.humidity)%")
                            .font(DS.Typography.label)
                            .foregroundStyle(amsState.humidityLevel.color)
                    }
                }

                // Humidity Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.surfaceGlass)

                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(humidityGradient)
                            .frame(width: max(0, geometry.size.width * CGFloat(amsState.humidity) / 100))
                            .blur(radius: 4)
                            .opacity(0.5)

                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(humidityGradient)
                            .frame(width: max(0, geometry.size.width * CGFloat(amsState.humidity) / 100))
                    }
                }
                .frame(height: 8)

                // Status
                HStack {
                    Text(amsState.humidityLevel.displayName)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)

                    Spacer()

                    if amsState.isDrying {
                        HStack(spacing: DS.Spacing.xxs) {
                            ProgressView()
                                .scaleEffect(0.6)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Drying: \(amsState.dryingRemainingTime)m left")
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(accentColor.color)
                                if amsState.dryingTargetTemp > 0 {
                                    Text("Target: \(amsState.dryingTargetTemp)°C")
                                        .font(DS.Typography.labelMicro)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                            }
                        }
                    }
                }

                // Drying Controls
                HStack(spacing: DS.Spacing.sm) {
                    if amsState.isDrying {
                        Button {
                            onStopDrying()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "stop.fill")
                                Text("Stop Drying")
                            }
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: DS.Radius.medium)
                                    .fill(DS.Colors.error)
                            }
                        }
                        .disabled(isPerformingAction)
                    } else {
                        Button {
                            showingDryingConfig = true
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "fan.fill")
                                Text("Start Drying")
                            }
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: DS.Radius.medium)
                                    .fill(accentColor.color)
                            }
                        }
                        .disabled(isPerformingAction)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .sheet(isPresented: $showingDryingConfig) {
            DryingConfigSheet(
                accentColor: accentColor,
                onStart: { temp, duration in
                    showingDryingConfig = false
                    onStartDrying(temp, duration)
                }
            )
            .presentationDetents([.medium])
        }
    }

    private var humidityGradient: LinearGradient {
        LinearGradient(
            colors: [DS.Colors.success, .yellow, DS.Colors.warning, DS.Colors.error],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Drying Configuration Sheet

struct DryingConfigSheet: View {
    let accentColor: AccentColorOption
    let onStart: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemp: Int = 50
    @State private var selectedDuration: Int = 4

    private let tempPresets = [40, 45, 50, 55, 60, 65, 70]
    private let durationPresets = [1, 2, 4, 6, 8, 12]

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                // Temperature
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "thermometer.medium")
                            .foregroundStyle(DS.Colors.accent)
                        Text("Temperature")
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
                        ForEach(tempPresets, id: \.self) { temp in
                            Button {
                                selectedTemp = temp
                            } label: {
                                Text("\(temp)°C")
                                    .font(DS.Typography.bodySemibold)
                                    .foregroundStyle(selectedTemp == temp ? .white : DS.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .background {
                                        RoundedRectangle(cornerRadius: DS.Radius.medium)
                                            .fill(selectedTemp == temp ? accentColor.color : DS.Colors.surfaceGlass)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(temperatureRecommendation)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Divider().background(DS.Colors.borderSubtle)

                // Duration
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "clock")
                            .foregroundStyle(DS.Colors.accent)
                        Text("Duration")
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
                        ForEach(durationPresets, id: \.self) { hours in
                            Button {
                                selectedDuration = hours
                            } label: {
                                Text("\(hours)h")
                                    .font(DS.Typography.bodySemibold)
                                    .foregroundStyle(selectedDuration == hours ? .white : DS.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .background {
                                        RoundedRectangle(cornerRadius: DS.Radius.medium)
                                            .fill(selectedDuration == hours ? accentColor.color : DS.Colors.surfaceGlass)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Start Button
                Button {
                    onStart(selectedTemp, selectedDuration * 60)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "fan.fill")
                        Text("Start Drying")
                    }
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DS.Radius.large)
                            .fill(accentColor.color)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background {
                DarkModeBackground(accentColor: accentColor.color, style: .aurora)
            }
            .navigationTitle("Drying Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.accent)
                }
            }
        }
    }

    private var temperatureRecommendation: String {
        switch selectedTemp {
        case 40...45: return "Recommended for PLA and TPU"
        case 46...55: return "Recommended for PETG and ABS"
        case 56...65: return "Recommended for Nylon and PC"
        default: return "High temperature - use with caution"
        }
    }
}

// MARK: - Filament Slots Grid

struct FilamentSlotsGrid: View {
    let slots: [AMSSlot]
    let accentColor: AccentColorOption
    let onSlotTap: (AMSSlot) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Filament Slots")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(DS.Colors.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                    ForEach(slots) { slot in
                        FilamentSlotCard(slot: slot, accentColor: accentColor, onTap: { onSlotTap(slot) })
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }
}

// MARK: - Filament Slot Card

struct FilamentSlotCard: View {
    let slot: AMSSlot
    let accentColor: AccentColorOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCardCompact(accentColor: slot.isEmpty ? nil : slot.color) {
                VStack(spacing: DS.Spacing.xs) {
                    // Header
                    HStack {
                        ZStack {
                            if !slot.isEmpty {
                                Circle()
                                    .fill(slot.color.opacity(0.4))
                                    .blur(radius: 6)
                                    .frame(width: 28, height: 28)
                            }
                            Circle()
                                .fill(slot.isEmpty ? DS.Colors.surfaceGlassHighlight : slot.color)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .stroke(slot.isActive ? accentColor.color : Color.clear, lineWidth: 2)
                                }
                        }

                        Text(slot.displayName)
                            .font(DS.Typography.label)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Spacer()

                        if slot.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accentColor.color)
                                .font(.system(size: 14))
                        }
                    }

                    // Material Info
                    if slot.isEmpty {
                        Text("Empty")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(slot.materialType)
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(DS.Colors.textPrimary)

                            if slot.hasValidRFIDData {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(DS.Colors.surfaceGlass)

                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(remainingColor)
                                            .frame(width: geometry.size.width * slot.remaining)
                                            .blur(radius: 3)
                                            .opacity(0.5)

                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(remainingColor)
                                            .frame(width: geometry.size.width * slot.remaining)
                                    }
                                }
                                .frame(height: 4)

                                HStack {
                                    Text(slot.remainingPercent)
                                        .font(DS.Typography.labelMicro)
                                        .foregroundStyle(remainingColor)

                                    Spacer()

                                    Text(slot.tempRange)
                                        .font(DS.Typography.labelMicro)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                            } else {
                                HStack {
                                    Text("No RFID")
                                        .font(DS.Typography.labelMicro)
                                        .foregroundStyle(DS.Colors.textTertiary)

                                    Spacer()

                                    Text(slot.tempRange)
                                        .font(DS.Typography.labelMicro)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                            }
                        }
                    }
                }
                .padding(DS.Spacing.sm)
            }
        }
        .buttonStyle(.plain)
    }

    private var remainingColor: Color {
        if slot.remaining < 0.2 { return DS.Colors.error }
        else if slot.remaining < 0.5 { return DS.Colors.warning }
        return DS.Colors.success
    }
}

// MARK: - Low Filament Warning Card

struct LowFilamentWarningCard: View {
    let slots: [AMSSlot]
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard(accentColor: DS.Colors.warning) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Colors.warning)
                    .font(.title2)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Low Filament")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(slots.map { "\($0.displayName) (\($0.remainingPercent))" }.joined(separator: ", "))
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
        }
    }
}

// MARK: - AMS Quick Actions Card

struct AMSQuickActionsCard: View {
    let accentColor: AccentColorOption
    let isPerformingAction: Bool
    let onRefreshRFID: () -> Void
    let onRetract: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Quick Actions")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(DS.Colors.textPrimary)

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        onRefreshRFID()
                    } label: {
                        VStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                            Text("Refresh RFID")
                                .font(DS.Typography.labelSmall)
                        }
                        .foregroundStyle(accentColor.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(accentColor.color.opacity(0.15))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                                        .stroke(accentColor.color.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .disabled(isPerformingAction)

                    Button {
                        onRetract()
                    } label: {
                        VStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.title2)
                            Text("Retract")
                                .font(DS.Typography.labelSmall)
                        }
                        .foregroundStyle(DS.Colors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(DS.Colors.warning.opacity(0.15))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                                        .stroke(DS.Colors.warning.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .disabled(isPerformingAction)
                }
            }
            .padding(DS.Spacing.md)
        }
    }
}

// MARK: - Filament Action Sheet

struct FilamentActionSheet: View {
    let slot: AMSSlot
    let accentColor: AccentColorOption
    let isPerformingAction: Bool
    let onLoad: () -> Void
    let onUnload: () -> Void
    let onReadRFID: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                // Slot Info
                VStack(spacing: DS.Spacing.sm) {
                    ZStack {
                        if !slot.isEmpty {
                            Circle()
                                .fill(slot.color.opacity(0.3))
                                .blur(radius: 12)
                                .frame(width: 80, height: 80)
                        }
                        Circle()
                            .fill(slot.isEmpty ? DS.Colors.surfaceGlassHighlight : slot.color)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Circle()
                                    .stroke(DS.Colors.borderLight, lineWidth: 2)
                            }
                    }

                    Text(slot.displayName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)

                    if !slot.isEmpty {
                        VStack(spacing: DS.Spacing.xxs) {
                            Text(slot.materialType)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.textSecondary)

                            if slot.hasValidRFIDData {
                                Text("\(slot.remainingPercent) remaining")
                                    .font(DS.Typography.label)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            } else {
                                Text("Third-party filament")
                                    .font(DS.Typography.label)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }

                            Text(slot.tempRange)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    } else {
                        Text("No filament loaded")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Divider().background(DS.Colors.borderSubtle)

                // Actions
                VStack(spacing: DS.Spacing.sm) {
                    Button {
                        onLoad()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.down.to.line")
                            Text("Load Filament")
                        }
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(accentColor.color)
                        }
                    }
                    .disabled(isPerformingAction)

                    Button {
                        onUnload()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.up.to.line")
                            Text("Unload Filament")
                        }
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(DS.Colors.warning.opacity(0.15))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                                        .stroke(DS.Colors.warning.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .disabled(isPerformingAction || slot.isEmpty)

                    Button {
                        onReadRFID()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "wave.3.right")
                            Text("Read RFID Tag")
                        }
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                .fill(DS.Colors.surfaceGlass)
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                }
                        }
                    }
                    .disabled(isPerformingAction)
                }

                Spacer()
            }
            .padding(DS.Spacing.lg)
            .background {
                DarkModeBackground(accentColor: accentColor.color, style: .radialGlow)
            }
            .navigationTitle("Filament Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("AMS View") {
    AMSView()
        .environmentObject(SettingsManager())
        .environmentObject(HAAPIService())
        .environmentObject(DeviceConfigurationManager())
}
