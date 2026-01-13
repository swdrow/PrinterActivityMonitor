import SwiftUI

// Preview helper to ensure previews work in Xcode
struct PreviewContainer: View {
    var body: some View {
        ContentView()
            .environmentObject(SettingsManager())
            .environmentObject(HAAPIService())
            .environmentObject(ActivityManager())
    }
}

#Preview("Dashboard") {
    PreviewContainer()
}

#Preview("Dashboard - Dark") {
    PreviewContainer()
        .preferredColorScheme(.dark)
}
