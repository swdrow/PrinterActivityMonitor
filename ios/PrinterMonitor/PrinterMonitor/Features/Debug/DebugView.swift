import SwiftUI

struct DebugView: View {
    @State private var mockProgress: Double = 45
    @State private var mockStatus: String = "running"

    var body: some View {
        NavigationStack {
            List {
                Section("Mock Print Simulation") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress: \(Int(mockProgress))%")
                        Slider(value: $mockProgress, in: 0...100, step: 1)
                    }

                    Picker("Status", selection: $mockStatus) {
                        Text("Idle").tag("idle")
                        Text("Running").tag("running")
                        Text("Paused").tag("paused")
                        Text("Completed").tag("complete")
                        Text("Failed").tag("failed")
                    }

                    Button("Start Mock Print") {
                        // TODO: Start mock print simulation
                    }

                    Button("Stop Mock Print") {
                        // TODO: Stop mock print
                    }
                }

                Section("Test Notifications") {
                    Button("Send 'Print Started'") {
                        // TODO: Send test notification
                    }

                    Button("Send 'Print Complete'") {
                        // TODO: Send test notification
                    }

                    Button("Send 'Print Failed'") {
                        // TODO: Send test notification
                    }

                    Button("Send 'Progress Milestone'") {
                        // TODO: Send test notification
                    }
                }

                Section("Live Activity Testing") {
                    Button("Start Test Activity") {
                        // TODO: Start test Live Activity
                    }

                    Button("Update with Mock Data") {
                        // TODO: Update Live Activity
                    }

                    Button("End Activity") {
                        // TODO: End Live Activity
                    }
                }

                Section("Connection Testing") {
                    Button("Test Server Connection") {
                        // TODO: Test server connection
                    }

                    Button("Test HA Connection") {
                        // TODO: Test HA connection
                    }
                }

                Section("Data Management") {
                    Button("Clear Local Cache", role: .destructive) {
                        // TODO: Clear cache
                    }

                    Button("Reset Onboarding", role: .destructive) {
                        // TODO: Reset onboarding
                    }
                }
            }
            .navigationTitle("Debug")
        }
    }
}

#Preview {
    DebugView()
}
