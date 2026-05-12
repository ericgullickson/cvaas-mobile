import SwiftUI

/// Port-detail screen for F2 (PRD CAP-2.2 tap-through + CAP-2.4 24h event feed).
///
/// Receives a `PortState` (so PoE/LLDP/MAC data is already loaded from the parent list) and
/// independently loads the port-scoped 24h event feed via `EventService.eventsForPort`.
struct PortDetailView: View {
    let deviceId: String
    let port: PortState

    @EnvironmentObject private var auth: AuthStore
    @State private var events: [Event] = []
    @State private var eventLoadState: EventLoadState = .idle

    enum EventLoadState {
        case idle
        case loading
        case loaded
        case failure(String)
    }

    var body: some View {
        List {
            linkSection
            poeSection
            lldpSection
            macsSection
            errorsSection
            eventsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(port.interfaceName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: port.interfaceName) { await loadEvents() }
        .refreshable { await loadEvents() }
    }

    // MARK: - Sections

    private var linkSection: some View {
        Section("Link") {
            KV(label: "Status",   value: port.link?.linkStatus ?? "—")
            KV(label: "Active",   value: port.link?.active.map { $0 ? "Yes" : "No" } ?? "—")
            KV(label: "MTU",      value: port.link?.mtu.map(String.init) ?? "—")
        }
    }

    @ViewBuilder
    private var poeSection: some View {
        Section("PoE") {
            if let poe = port.poe {
                KV(label: "Port class",        value: poe.portClass ?? "—")
                KV(label: "Port state",        value: poe.portState ?? "—")
                KV(label: "Priority",          value: poe.priority ?? "—")
                KV(label: "Capacity",          value: poe.capacityWatts.map { String(format: "%.1f W", $0) } ?? "—")
                KV(label: "Granted power",     value: poe.grantedPowerWatts.map { String(format: "%.1f W", $0) } ?? "—")
                KV(label: "Output power",      value: poe.outputPowerWatts.map { String(format: "%.2f W", $0) } ?? "—")
                KV(label: "Output current",    value: poe.outputCurrentMA.map { String(format: "%.0f mA", $0) } ?? "—")
                KV(label: "Output voltage",    value: poe.outputVoltageV.map { String(format: "%.2f V", $0) } ?? "—")
                KV(label: "Chip temperature",  value: poe.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—")
                KV(label: "LLDP enabled",      value: poe.lldpEnabled.map { $0 ? "Yes" : "No" } ?? "—")
            } else {
                Text("No PoE data for this port")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var lldpSection: some View {
        Section("LLDP neighbor") {
            if let lldp = port.lldp {
                KV(label: "System name", value: lldp.sysName ?? "—")
                if let desc = lldp.sysDesc, !desc.isEmpty {
                    KV(label: "System desc", value: desc)
                }
                KV(label: "Remote port",
                   value: lldp.remotePortId ?? lldp.remotePortDesc ?? "—")
                if let portDesc = lldp.remotePortDesc,
                   portDesc != lldp.remotePortId, !portDesc.isEmpty {
                    KV(label: "Remote port desc", value: portDesc)
                }
                KV(label: "TTL", value: lldp.ttl.map { "\($0)s" } ?? "—")
            } else {
                Text("No LLDP neighbor on this port")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var macsSection: some View {
        Section {
            if port.learnedMACs.isEmpty {
                Text("No MACs learned on this port")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(port.learnedMACs.sorted(), id: \.self) { mac in
                    Text(mac).font(.body.monospaced())
                }
            }
        } header: {
            Text("Learned MACs (\(port.learnedMACs.count))")
        }
    }

    private var errorsSection: some View {
        Section("Errors") {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error counters unavailable from CVaaS API.")
                        .font(.callout)
                    Text("On the switch CLI: `show interface counters errors`")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        Section("Recent events (24h)") {
            switch eventLoadState {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading events…").foregroundStyle(.secondary) }
            case .loaded:
                if events.isEmpty {
                    Text("No port-scoped events in the last 24 hours")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events, id: \.stableId) { ev in
                        EventRowView(event: ev)
                    }
                }
            case .failure(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Load events

    private func loadEvents() async {
        guard let url = URL(string: auth.tenantURL) else {
            eventLoadState = .failure("Invalid tenant URL")
            return
        }
        eventLoadState = .loading
        do {
            let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
            let svc = EventService(client: client)
            let scoped = try await svc.eventsForPort(deviceId: deviceId,
                                                     interfaceName: port.interfaceName)
            events = scoped
            eventLoadState = .loaded
        } catch {
            eventLoadState = .failure("Couldn't load events: \(error.localizedDescription)")
        }
    }
}

// MARK: - Key/value row

private struct KV: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
                .multilineTextAlignment(.trailing)
        }
    }
}
