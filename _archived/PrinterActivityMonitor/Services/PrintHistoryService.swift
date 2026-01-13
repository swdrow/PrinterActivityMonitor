import Foundation
import SwiftUI

/// Service for managing print history persistence and statistics
@MainActor
class PrintHistoryService: ObservableObject {
    @Published var history: [PrintHistoryEntry] = []
    @Published var statistics: PrintStatistics = .empty
    @Published var isLoading: Bool = false

    private let fileManager = FileManager.default
    private let historyFileName = "print_history.json"

    private var historyFileURL: URL? {
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent(historyFileName)
    }

    init() {
        loadHistory()
    }

    // MARK: - Persistence

    /// Load history from disk
    func loadHistory() {
        guard let url = historyFileURL else { return }

        do {
            if fileManager.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                history = try JSONDecoder().decode([PrintHistoryEntry].self, from: data)
                statistics = PrintStatistics.calculate(from: history)
            }
        } catch {
            // If we can't load, start fresh
            history = []
            statistics = .empty
        }
    }

    /// Save history to disk
    private func saveHistory() {
        guard let url = historyFileURL else { return }

        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: url)
        } catch {
            // Silent fail - we'll try again next time
        }
    }

    // MARK: - History Management

    /// Add a new print to history
    func addPrint(_ entry: PrintHistoryEntry) {
        history.insert(entry, at: 0) // Newest first
        statistics = PrintStatistics.calculate(from: history)
        saveHistory()
    }

    /// Record a completed print from current printer state
    func recordCompletedPrint(
        fileName: String,
        startDate: Date,
        status: PrintHistoryEntry.PrintResult,
        progress: Int,
        totalLayers: Int,
        estimatedDuration: TimeInterval,
        filamentUsed: Double
    ) {
        let entry = PrintHistoryEntry(
            id: UUID(),
            fileName: fileName,
            startDate: startDate,
            endDate: Date(),
            status: status,
            progress: progress,
            totalLayers: totalLayers,
            printDuration: Date().timeIntervalSince(startDate),
            estimatedDuration: estimatedDuration,
            filamentUsed: filamentUsed,
            thumbnailData: nil
        )
        addPrint(entry)
    }

    /// Delete a print from history
    func deletePrint(at indexSet: IndexSet) {
        history.remove(atOffsets: indexSet)
        statistics = PrintStatistics.calculate(from: history)
        saveHistory()
    }

    /// Delete a specific print entry
    func deletePrint(_ entry: PrintHistoryEntry) {
        history.removeAll { $0.id == entry.id }
        statistics = PrintStatistics.calculate(from: history)
        saveHistory()
    }

    /// Clear all history
    func clearHistory() {
        history = []
        statistics = .empty
        saveHistory()
    }

    // MARK: - Filtering

    /// Get prints filtered by status
    func prints(withStatus status: PrintHistoryEntry.PrintResult) -> [PrintHistoryEntry] {
        history.filter { $0.status == status }
    }

    /// Get prints from a specific date range
    func prints(from startDate: Date, to endDate: Date) -> [PrintHistoryEntry] {
        history.filter { $0.endDate >= startDate && $0.endDate <= endDate }
    }

    /// Get prints from the last N days
    func prints(lastDays days: Int) -> [PrintHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return history.filter { $0.endDate >= cutoff }
    }

    // MARK: - Statistics

    /// Recalculate statistics
    func recalculateStatistics() {
        statistics = PrintStatistics.calculate(from: history)
    }

    /// Get statistics for a specific time period
    func statistics(lastDays days: Int) -> PrintStatistics {
        let filtered = prints(lastDays: days)
        return PrintStatistics.calculate(from: filtered)
    }

    // MARK: - Mock Data for Testing

    /// Add mock history entries for testing
    func addMockData() {
        let mockEntries: [PrintHistoryEntry] = [
            PrintHistoryEntry(
                id: UUID(),
                fileName: "benchy.3mf",
                startDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                endDate: Date().addingTimeInterval(-86400 * 2 + 3600), // 1 hour print
                status: .success,
                progress: 100,
                totalLayers: 150,
                printDuration: 3600,
                estimatedDuration: 3500,
                filamentUsed: 15.2,
                thumbnailData: nil
            ),
            PrintHistoryEntry(
                id: UUID(),
                fileName: "phone_stand_v2.3mf",
                startDate: Date().addingTimeInterval(-86400), // Yesterday
                endDate: Date().addingTimeInterval(-86400 + 7200), // 2 hour print
                status: .success,
                progress: 100,
                totalLayers: 280,
                printDuration: 7200,
                estimatedDuration: 7000,
                filamentUsed: 32.5,
                thumbnailData: nil
            ),
            PrintHistoryEntry(
                id: UUID(),
                fileName: "failed_print.3mf",
                startDate: Date().addingTimeInterval(-43200), // 12 hours ago
                endDate: Date().addingTimeInterval(-43200 + 1800), // Failed after 30 min
                status: .failed,
                progress: 15,
                totalLayers: 300,
                printDuration: 1800,
                estimatedDuration: 10800,
                filamentUsed: 5.0,
                thumbnailData: nil
            ),
            PrintHistoryEntry(
                id: UUID(),
                fileName: "headphone_hook.3mf",
                startDate: Date().addingTimeInterval(-3600 * 5), // 5 hours ago
                endDate: Date().addingTimeInterval(-3600 * 3), // Finished 3 hours ago
                status: .success,
                progress: 100,
                totalLayers: 200,
                printDuration: 7200,
                estimatedDuration: 7500,
                filamentUsed: 25.0,
                thumbnailData: nil
            ),
            PrintHistoryEntry(
                id: UUID(),
                fileName: "cancelled_print.3mf",
                startDate: Date().addingTimeInterval(-3600 * 8),
                endDate: Date().addingTimeInterval(-3600 * 7),
                status: .cancelled,
                progress: 45,
                totalLayers: 400,
                printDuration: 3600,
                estimatedDuration: 14400,
                filamentUsed: 18.0,
                thumbnailData: nil
            )
        ]

        for entry in mockEntries {
            addPrint(entry)
        }
    }
}
