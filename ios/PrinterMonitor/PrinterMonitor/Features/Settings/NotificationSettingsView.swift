import SwiftUI

struct NotificationSettingsView: View {
    @State private var onStart = true
    @State private var onComplete = true
    @State private var onFailed = true
    @State private var onPaused = true
    @State private var onMilestone = true

    var body: some View {
        List {
            Section {
                Toggle("Print Started", isOn: $onStart)
                Toggle("Print Complete", isOn: $onComplete)
                Toggle("Print Failed", isOn: $onFailed)
                Toggle("Print Paused", isOn: $onPaused)
            } header: {
                Text("Status Notifications")
            } footer: {
                Text("Get notified when your print status changes")
            }

            Section {
                Toggle("Progress Milestones", isOn: $onMilestone)
            } header: {
                Text("Progress Notifications")
            } footer: {
                Text("Get notified at 25%, 50%, and 75% completion")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
