import SwiftUI

/// F2 port table — one card per interface with link state, PoE, LLDP neighbor, and learned-MAC
/// count. Error counters are PRD-DROPPED (Sprint 2 §1.5 F.1.d); the port-detail screen explains
/// the gap rather than rendering zeros.
struct PortInspectorView: View {
    let deviceId: String

    @EnvironmentObject private var auth: AuthStore
    @State private var state: LoadState = .idle
    @State private var snapshot: PortStateService.Snapshot?

    enum LoadState {
        case idle
        case loading
        case loaded
        case failure(String)
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                listContent
            case .failure(let msg):
                ContentUnavailableView {
                    Label("Couldn't load ports", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Try again") { Task { await load() } }
                }
            }
        }
        .navigationTitle("Ports")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: deviceId) { await load() }
        .refreshable { await load(force: true) }
    }

    @ViewBuilder
    private var listContent: some View {
        if let snap = snapshot {
            List {
                Section {
                    HStack {
                        Text("Updated \(snap.asOf.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(snap.ports.count) ports")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !snap.partialErrors.isEmpty {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Some columns failed to load")
                                    .font(.caption.bold())
                                ForEach(snap.partialErrors, id: \.self) { err in
                                    Text(err).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section {
                    ForEach(snap.ports) { port in
                        NavigationLink {
                            PortDetailView(deviceId: deviceId, port: port)
                        } label: {
                            PortRow(port: port)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func load(force: Bool = false) async {
        // task(id:) can re-fire when SwiftUI loses our structural identity (e.g. parent body
        // invalidations during navigation). If we already have data, skip the fresh load —
        // mutating @State mid-push can cause SwiftUI to tear down the pushed PortDetailView.
        if !force, snapshot != nil { return }
        guard let url = URL(string: auth.tenantURL) else {
            state = .failure("Invalid tenant URL")
            return
        }
        state = .loading
        do {
            let client = try ConnectorClient(tenantURL: url, jwt: auth.jwt)
            let snap = try await PortStateService(client: client)
                .fetchAllColumns(deviceSerial: deviceId)
            await client.shutdown()
            snapshot = snap
            state = .loaded
        } catch {
            state = .failure("\(type(of: error)): \(error.localizedDescription)")
        }
    }
}

// MARK: - Row

private struct PortRow: View {
    let port: PortState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Link state dot
            Circle()
                .fill(linkColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(port.interfaceName)
                        .font(.body.monospaced())
                    Spacer()
                    if port.learnedMACCount > 0 {
                        Text("\(port.learnedMACCount) MAC")
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if let poe = port.poe, let summary = poeSummary(poe) {
                    Text(summary)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let lldp = port.lldp, let sys = lldp.sysName {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(sys)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let rp = lldp.remotePortId ?? lldp.remotePortDesc {
                            Text("· \(rp)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var linkColor: Color {
        switch port.link?.linkStatus {
        case "linkUp": return .green
        case "linkDown": return .orange
        case "notPresent": return .gray
        case .some: return .blue
        case .none: return .gray
        }
    }

    /// "Powered · 9.3 W" / "Searching · 0 W" / nil if no PoE data.
    private func poeSummary(_ poe: PortPoEState) -> String? {
        guard let state = poe.portState else { return nil }
        let watts = poe.outputPowerWatts.map { String(format: "%.1f W", $0) } ?? "—"
        return "PoE \(state) · \(watts)"
    }
}
