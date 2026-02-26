import AppStoreConnect
import SwiftUI

struct ContentView: View {
    @AppStorage("keyId") private var keyId = ""
    @AppStorage("issuerId") private var issuerId = ""
    @AppStorage("privateKey") private var privateKey = ""
    @AppStorage("appId") private var appId = ""
    @AppStorage("version") private var version = "1.0"
    @AppStorage("buildNumber") private var buildNumber = ""

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
                TextField("Version", text: $version)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                TextField("Build Number", text: $buildNumber)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
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

                Button(action: { Task { await fetchVersionStatus() } }) {
                    Text("Fetch Version Status")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || credentialsMissing || version.isEmpty)

                Button(action: { Task { await fetchBetaStatus() } }) {
                    Text("Fetch Beta Status")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || credentialsMissing || buildNumber.isEmpty)
                .padding(.bottom)
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

    private var credentialsMissing: Bool {
        keyId.isEmpty || issuerId.isEmpty || privateKey.isEmpty || appId.isEmpty
    }

    private func makeAPI() throws -> API {
        let jwt = try makeJWT(keyId: keyId, issuerId: issuerId, key: privateKey)
        return API(jwt: jwt, appId: appId)
    }

    func fetchVersionStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let api = try makeAPI()
            let status = try await api.getAppVersionStatus(version: version)
            var text = "State: \(status.state)\nBuild: \(status.buildNumber ?? "N/A")"
            if let phased = status.phasedRelease {
                text += "\n\nPhased Release: \(phased.state)"
                text += "\nRollout: \(phased.rolloutPercentage)%"
                if let day = phased.currentDayNumber {
                    text += " (Day \(day)/7)"
                }
            }
            statusText = text
        } catch {
            statusText = "Error: \(error)"
        }
    }

    func fetchBetaStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let api = try makeAPI()
            let status = try await api.getBuildBetaStatus(buildNumber: buildNumber)
            statusText = "Internal: \(status.internalState.map(String.init(describing:)) ?? "N/A")\nExternal: \(status.externalState.map(String.init(describing:)) ?? "N/A")"
        } catch {
            statusText = "Error: \(error)"
        }
    }
}
