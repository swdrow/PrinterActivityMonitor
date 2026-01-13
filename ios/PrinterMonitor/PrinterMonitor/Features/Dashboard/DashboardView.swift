import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("No Printer Connected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Configure your Home Assistant connection in Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
