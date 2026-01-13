import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("No print history yet")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
