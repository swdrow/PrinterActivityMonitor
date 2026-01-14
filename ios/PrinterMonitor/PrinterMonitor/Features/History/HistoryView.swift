import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    init(apiClient: APIClient, settings: SettingsStorage) {
        _viewModel = State(initialValue: HistoryViewModel(
            apiClient: apiClient,
            settings: settings
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView("Loading history...")
                } else if let error = viewModel.error, viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "Error Loading History",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No Print History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed prints will appear here")
                    )
                } else {
                    jobsList
                }
            }
            .navigationTitle("History")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadHistory()
            }
        }
    }

    private var jobsList: some View {
        List {
            // Stats header
            if let stats = viewModel.stats {
                StatsHeaderView(stats: stats)
            }

            // Job list
            Section("Recent Prints") {
                ForEach(viewModel.jobs) { job in
                    NavigationLink(value: job) {
                        PrintJobRow(job: job)
                    }
                }
            }
        }
        .navigationDestination(for: PrintJob.self) { job in
            PrintJobDetailView(job: job)
        }
    }
}

struct StatsHeaderView: View {
    let stats: PrintStats

    var body: some View {
        Section {
            HStack(spacing: 20) {
                HistoryStatItem(
                    title: "Total",
                    value: "\(stats.totalJobs)",
                    icon: "printer.fill"
                )

                HistoryStatItem(
                    title: "Success",
                    value: stats.formattedSuccessRate,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                HistoryStatItem(
                    title: "Print Time",
                    value: stats.formattedTotalTime,
                    icon: "clock.fill"
                )
            }
            .padding(.vertical, 8)
        }
    }
}

struct HistoryStatItem: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HistoryView(
        apiClient: APIClient(),
        settings: SettingsStorage()
    )
}
