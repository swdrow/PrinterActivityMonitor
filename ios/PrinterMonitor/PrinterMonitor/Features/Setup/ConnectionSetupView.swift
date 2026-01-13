import SwiftUI

struct ConnectionSetupView: View {
    @State private var haURL = ""
    @State private var haToken = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var showPrinterSelection = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Assistant URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("http://homeassistant.local:8123", text: $haURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Long-Lived Access Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Enter your token", text: $haToken)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Connection Details")
            } footer: {
                Text("You can create a long-lived access token in Home Assistant under Profile → Security → Long-Lived Access Tokens")
            }

            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: validateConnection) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isValidating ? "Validating..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(haURL.isEmpty || haToken.isEmpty || isValidating)
            }
        }
        .navigationTitle("Setup")
        .navigationDestination(isPresented: $showPrinterSelection) {
            PrinterSelectionView(haURL: haURL, haToken: haToken)
        }
    }

    private func validateConnection() {
        isValidating = true
        validationError = nil

        // TODO: Call API to validate connection
        // For now, simulate validation
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isValidating = false

                // Basic URL validation
                if !haURL.hasPrefix("http://") && !haURL.hasPrefix("https://") {
                    validationError = "URL must start with http:// or https://"
                    return
                }

                showPrinterSelection = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionSetupView()
    }
}
