import SwiftUI

/// "More" tab — account info, preferences, support, sign-out. Replaces the legacy Settings tab
/// with a sectioned card layout. The JWT is masked by default with a Reveal toggle (deskside
/// discretion — a customer glancing at the tech's screen should not see the raw token).
struct MoreView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var revealJWT = false
    @State private var sendDiagnosticsAck = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if auth.isConfigured {
                        accountSection
                        preferencesSection
                        supportSection
                        #if DEBUG
                        debugSection
                        #endif
                        signOutSection
                    } else {
                        notConfiguredSection
                    }
                    Color.clear.frame(height: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Diagnostics would be sent in production", isPresented: $sendDiagnosticsAck) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("In MVP, this is a placeholder action. A production build would attach app logs and recent network traces.")
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        section(title: "ACCOUNT") {
            NavigationLink {
                TenantSettingsView()
            } label: {
                MoreRow(label: "Tenant", value: shortTenant, chevron: true)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 16)
            jwtRow
            Divider().padding(.leading, 16)
            MoreRow(label: "Server", value: shortServerURL, chevron: true)
        }
    }

    private var preferencesSection: some View {
        section(title: "PREFERENCES") {
            MoreRow(label: "Default Refresh", value: "10 seconds", chevron: true)
            Divider().padding(.leading, 16)
            MoreRow(label: "Appearance", value: "System", chevron: true)
        }
    }

    private var supportSection: some View {
        section(title: "SUPPORT") {
            Button {
                sendDiagnosticsAck = true
            } label: {
                MoreRow(label: "Send Diagnostics", value: nil, chevron: true)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 16)
            MoreRow(label: "About", value: aboutVersion, chevron: true)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        section(title: "DEBUG") {
            NavigationLink {
                ConnectorTestView()
            } label: {
                MoreRow(label: "Connector test (D.4)", value: nil, chevron: true)
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var signOutSection: some View {
        VStack(spacing: 0) {
            Button {
                try? auth.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
    }

    private var notConfiguredSection: some View {
        // For first-launch / signed-out state: show the tenant/JWT input directly.
        VStack(alignment: .leading, spacing: 0) {
            section(title: "ACCOUNT") {
                NavigationLink {
                    TenantSettingsView()
                } label: {
                    MoreRow(label: "Configure tenant & JWT", value: nil, chevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var jwtRow: some View {
        HStack {
            Text("JWT Token")
                .font(.system(size: 14))
                .foregroundStyle(Brand.slate)
            Spacer()
            Text(revealJWT ? truncatedJWT : "••••••••••••••")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Brand.graphite)
                .textSelection(.enabled)
                .lineLimit(1)
            Button(revealJWT ? "Hide" : "Reveal") {
                revealJWT.toggle()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Brand.steel)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Section builder

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Computed

    private var shortTenant: String {
        guard let host = URL(string: auth.tenantURL)?.host else { return "—" }
        return host
    }

    private var shortServerURL: String {
        if auth.tenantURL.count > 28 {
            return String(auth.tenantURL.prefix(28)) + "…"
        }
        return auth.tenantURL
    }

    private var truncatedJWT: String {
        // Mid-truncate so prefix and suffix are visible — useful for "is this the right token?"
        // verification without revealing the cryptographic middle.
        let jwt = auth.jwt
        guard jwt.count > 20 else { return jwt }
        let prefix = jwt.prefix(8)
        let suffix = jwt.suffix(8)
        return "\(prefix)…\(suffix)"
    }

    private var aboutVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

// MARK: - Row

private struct MoreRow: View {
    let label: String
    let value: String?
    var chevron: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Brand.slate)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Brand.graphite)
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Brand.slate)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Tenant settings (drill-down)

private struct TenantSettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var tenantURLDraft = ""
    @State private var jwtDraft = ""
    @State private var saveError: String?
    @State private var savedJustNow = false

    var body: some View {
        Form {
            Section {
                TextField("https://www.cv-prod-us-4.arista.io", text: $tenantURLDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                if !tenantURLDraft.isEmpty && !looksLikeAristaURL(tenantURLDraft) {
                    Text("URL must use https and end in .arista.io")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Tenant URL")
            } footer: {
                Text("The CVaaS web URL — e.g. https://www.cv-prod-us-4.arista.io")
            }

            Section {
                SecureField("Paste service-account JWT", text: $jwtDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Service Account JWT")
            } footer: {
                Text("Create a service account in CVaaS, generate a token, and paste it here. Stored in iOS Keychain.")
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
        }
        .navigationTitle("Tenant & Auth")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tenantURLDraft = auth.tenantURL
            jwtDraft = auth.jwt
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
        guard let url = URL(string: s), url.scheme == "https", let host = url.host else { return false }
        return host.hasSuffix(".arista.io")
    }
}
