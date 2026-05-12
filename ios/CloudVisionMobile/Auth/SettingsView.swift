import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var tenantURLDraft: String = ""
    @State private var jwtDraft: String = ""
    @State private var saveError: String?
    @State private var savedJustNow: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tenant") {
                    TextField(
                        "https://www.cv-prod-us-4.arista.io",
                        text: $tenantURLDraft
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    if !tenantURLDraft.isEmpty && !looksLikeAristaURL(tenantURLDraft) {
                        Text("URL must use https and end in .arista.io")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Service Account JWT") {
                    SecureField(
                        "Paste from CVaaS Settings → Service Accounts",
                        text: $jwtDraft
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Text("Create a service account in CVaaS, generate a token, and paste it here. Stored only in iOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Save") { save() }
                        .disabled(tenantURLDraft.isEmpty || jwtDraft.isEmpty)

                    if savedJustNow {
                        Text("Saved.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if auth.isConfigured {
                    Section("Debug") {
                        NavigationLink("Connector test (D.4)") {
                            ConnectorTestView()
                        }
                    }

                    Section {
                        Button("Sign out", role: .destructive) {
                            try? auth.signOut()
                            tenantURLDraft = ""
                            jwtDraft = ""
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                tenantURLDraft = auth.tenantURL
                jwtDraft = auth.jwt
            }
        }
    }

    private func save() {
        auth.tenantURL = tenantURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        auth.jwt = jwtDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try auth.save()
            saveError = nil
            savedJustNow = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                savedJustNow = false
            }
        } catch {
            saveError = "Could not save: \(error.localizedDescription)"
        }
    }

    private func looksLikeAristaURL(_ s: String) -> Bool {
        guard let url = URL(string: s),
              url.scheme == "https",
              let host = url.host else { return false }
        return host.hasSuffix(".arista.io")
    }
}
