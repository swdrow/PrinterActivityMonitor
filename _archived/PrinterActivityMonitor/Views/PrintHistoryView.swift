import SwiftUI

struct PrintHistoryView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var historyService: PrintHistoryService
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingClearConfirmation: Bool = false
    @State private var selectedEntry: PrintHistoryEntry?

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case success = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }

    var filteredHistory: [PrintHistoryEntry] {
        switch selectedFilter {
        case .all:
            return historyService.history
        case .success:
            return historyService.prints(withStatus: .success)
        case .failed:
            return historyService.prints(withStatus: .failed)
        case .cancelled:
            return historyService.prints(withStatus: .cancelled)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Statistics Card
                    StatisticsCard(
                        statistics: historyService.statistics,
                        accentColor: settingsManager.settings.accentColor
                    )

                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    // History List
                    if filteredHistory.isEmpty {
                        EmptyHistoryCard(filter: selectedFilter)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHistory) { entry in
                                HistoryEntryCard(
                                    entry: entry,
                                    accentColor: settingsManager.settings.accentColor
                                )
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        historyService.deletePrint(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background {
                DarkModeBackground(
                    accentColor: settingsManager.settings.accentColor.color,
                    style: .topGlow
                )
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }

                        #if DEBUG
                        Button {
                            historyService.addMockData()
                        } label: {
                            Label("Add Mock Data", systemImage: "plus.square.dashed")
                        }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear History?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    historyService.clearHistory()
                }
            } message: {
                Text("This will delete all print history. This action cannot be undone.")
            }
            .sheet(item: $selectedEntry) { entry in
                PrintDetailSheet(
                    entry: entry,
                    accentColor: settingsManager.settings.accentColor,
                    onDelete: {
                        historyService.deletePrint(entry)
                        selectedEntry = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Statistics Card

struct StatisticsCard: View {
    let statistics: PrintStatistics
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Statistics")
                        .font(.headline)
                    Spacer()
                }

                // Main Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatBox(
                        title: "Total",
                        value: "\(statistics.totalPrints)",
                        icon: "printer.fill",
                        color: accentColor.color
                    )

                    StatBox(
                        title: "Success",
                        value: "\(statistics.successfulPrints)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    StatBox(
                        title: "Failed",
                        value: "\(statistics.failedPrints)",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                }

                Divider()

                // Secondary Stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Print Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statistics.formattedTotalTime)
                            .font(.subheadline.bold())
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 4) {
                        Text("Filament")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statistics.formattedFilament)
                            .font(.subheadline.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Success Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(statistics.successRate * 100))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(successRateColor)
                    }
                }
            }
            .padding()
        }
    }

    private var successRateColor: Color {
        if statistics.successRate >= 0.9 {
            return .green
        } else if statistics.successRate >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCardCompact(accentColor: color) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title2.bold())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Empty History Card

struct EmptyHistoryCard: View {
    let filter: PrintHistoryView.HistoryFilter

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Prints Found")
                    .font(.headline)

                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            return "Your print history will appear here once you complete prints."
        case .success:
            return "No completed prints yet."
        case .failed:
            return "No failed prints. Great job!"
        case .cancelled:
            return "No cancelled prints."
        }
    }
}

// MARK: - History Entry Card

struct HistoryEntryCard: View {
    let entry: PrintHistoryEntry
    let accentColor: AccentColorOption

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: entry.status.icon)
                    .font(.title2)
                    .foregroundStyle(entry.status.color)
                    .frame(width: 40)

                // Print Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.fileName)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(entry.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(entry.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Progress/Result
                VStack(alignment: .trailing, spacing: 4) {
                    if entry.status == .success {
                        Text("100%")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(entry.progress)%")
                            .font(.subheadline.bold())
                            .foregroundStyle(entry.status.color)
                    }

                    Text("\(Int(entry.filamentUsed))g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}

// MARK: - Print Detail Sheet

struct PrintDetailSheet: View {
    let entry: PrintHistoryEntry
    let accentColor: AccentColorOption
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Header
                    VStack(spacing: 12) {
                        Image(systemName: entry.status.icon)
                            .font(.system(size: 56))
                            .foregroundStyle(entry.status.color)

                        Text(entry.status.displayName)
                            .font(.title2.bold())
                            .foregroundStyle(entry.status.color)
                    }
                    .padding(.top)

                    // File Name
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(entry.fileName)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }

                    // Time Info
                    GlassCard {
                        VStack(spacing: 12) {
                            DetailRow(label: "Started", value: entry.formattedStartDate)
                            Divider()
                            DetailRow(label: "Duration", value: entry.formattedDuration)
                            Divider()
                            DetailRow(label: "Progress", value: "\(entry.progress)%")
                        }
                        .padding()
                    }

                    // Print Stats
                    GlassCard {
                        VStack(spacing: 12) {
                            DetailRow(label: "Total Layers", value: "\(entry.totalLayers)")
                            Divider()
                            DetailRow(label: "Filament Used", value: String(format: "%.1fg", entry.filamentUsed))
                            Divider()
                            DetailRow(label: "Accuracy", value: "\(Int(entry.accuracy * 100))%")
                        }
                        .padding()
                    }

                    // Delete Button
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Print", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
            }
            .background {
                DarkModeBackground(
                    accentColor: accentColor.color,
                    style: .radialGlow
                )
            }
            .navigationTitle("Print Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

// MARK: - Preview

#Preview("History View") {
    PrintHistoryView()
        .environmentObject(SettingsManager())
        .environmentObject({
            let service = PrintHistoryService()
            service.addMockData()
            return service
        }())
}

#Preview("Statistics Card") {
    StatisticsCard(
        statistics: PrintStatistics(
            totalPrints: 42,
            successfulPrints: 38,
            failedPrints: 3,
            cancelledPrints: 1,
            totalPrintTime: 360000,
            totalFilamentUsed: 1250,
            averagePrintTime: 8571,
            successRate: 0.905
        ),
        accentColor: .cyan
    )
    .padding()
}

#Preview("Empty History") {
    EmptyHistoryCard(filter: .all)
        .padding()
}
