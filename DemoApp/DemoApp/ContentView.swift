import AppStoreConnect
import SwiftUI

struct ContentView: View {
    @AppStorage("keyId") private var keyId = ""
    @AppStorage("issuerId") private var issuerId = ""
    @AppStorage("privateKey") private var privateKey = ""
    @AppStorage("appId") private var appId = ""
    @AppStorage("version") private var version = "1.0"

    @State private var statusText = ""
    @State private var isLoading = false

    var body: some View {
        TabView {
            statusTab
                .tabItem {
                    Label("Status", systemImage: "info.circle")
                }

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

    private var statusTab: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                if isLoading {
                    ProgressView("Fetching…")
                } else if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()

                Button(action: { Task { await fetchStatus() } }) {
                    Text("Fetch Version Status")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || keyId.isEmpty || issuerId.isEmpty || privateKey.isEmpty || appId.isEmpty)
                .padding()
            }
            .navigationTitle("ASC Demo")
        }
    }

    private var settingsTab: some View {
        NavigationView {
            Form {
                Section("API Credentials") {
                    TextField("Key ID", text: $keyId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Issuer ID", text: $issuerId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("App") {
                    TextField("App ID", text: $appId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Version", text: $version)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Private Key (PEM)") {
                    TextEditor(text: $privateKey)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Settings")
        }
    }

    func fetchStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let jwt = try makeJWT(keyId: keyId, issuerId: issuerId, key: privateKey)
            let api = API(jwt: jwt, appId: appId)
            let status = try await api.getAppVersionStatus(version: version)
            statusText = "State: \(status.state)\nBuild: \(status.buildNumber ?? "N/A")"
        } catch {
            statusText = "Error: \(error)"
        }
    }
}
