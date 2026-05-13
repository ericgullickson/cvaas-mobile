import SwiftUI

/// Port-detail screen (CAP-2.2 tap-through + CAP-2.4 24h event feed). Rewritten to match the
/// Direction-3 visual language: section labels in small caps, card-style KV groups, status
/// pill at the top, monospace identifiers, custom activity rows.
struct PortDetailView: View {
    let deviceId: String
    let port: PortState

    @EnvironmentObject private var auth: AuthStore
    @State private var events: [Event] = []
    @State private var eventLoadState: EventLoadState = .idle
    @State private var diagnosticsPresented = false

    enum EventLoadState { case idle, loading, loaded; case failure(String) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerCard
                diagnosticsEntry
                linkSection
                poeSection
                lldpSection
                macsSection
                errorsNote
                eventsSection
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(port.interfaceName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: port.interfaceName) { await loadEvents() }
        .refreshable { await loadEvents() }
        // Full-screen, not .sheet — iOS 26's card-style sheet exposes the underlying chrome
        // above the rounded top, which created a visible navy "shelf" between the status bar
        // and the diagnostic nav bar. Full-screen also forecloses accidental swipe-to-dismiss
        // mid-write-op (which would orphan an in-flight ChangeControl).
        .fullScreenCover(isPresented: $diagnosticsPresented) {
            DiagnosticsLauncherView(deviceId: deviceId, interfaceName: port.interfaceName)
                .environmentObject(auth)
        }
    }

    // MARK: - F4 entry

    private var diagnosticsEntry: some View {
        Button {
            diagnosticsPresented = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wrench.adjustable")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Brand.navy, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interface Diagnostics")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Brand.graphite)
                    Text("Cable Test or Interface Cycle — disruptive")
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.slate)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.slate)
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(edgeColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text(port.interfaceName)
                    .font(TypeScale.identifierLarge)
                    .foregroundStyle(Brand.graphite)
                Text(subtitle)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Brand.slate)
            }
            Spacer()
            statusPill
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var subtitle: String {
        if let sys = port.lldp?.sysName, !sys.isEmpty {
            return sys
        }
        return "No LLDP neighbor"
    }

    private var edgeColor: Color {
        switch port.link?.linkStatus {
        case "linkDown":   return .red
        case "notPresent": return Brand.mist
        case "linkUp":
            if let watts = port.poe?.outputPowerWatts, watts > 0 { return .green }
            return Brand.navy
        default: return Brand.mist
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if port.link?.linkStatus == "linkDown" {
            StatusPill(label: "Link Down", intent: .danger)
        } else if port.link?.linkStatus == "notPresent" {
            StatusPill(label: "Not Present", intent: .neutral)
        } else if let watts = port.poe?.outputPowerWatts, watts > 0 {
            let intent: StatusPill.Intent = watts < 10 ? .warning : .success
            StatusPill(label: "PoE \(formatWatts(watts))", intent: intent, style: .outlined)
        } else if port.poe?.capacityWatts != nil {
            StatusPill(label: "PoE Off", intent: .neutral)
        } else {
            StatusPill(label: "Link Up", intent: .info)
        }
    }

    private func formatWatts(_ watts: Double) -> String {
        if watts.truncatingRemainder(dividingBy: 1) < 0.05 { return "\(Int(watts))W" }
        return String(format: "%.1fW", watts)
    }

    // MARK: - Sections

    private var linkSection: some View {
        section(title: "LINK") {
            DetailRow(label: "Status",  value: port.link?.linkStatus ?? "—")
            DetailRow(label: "Active",  value: port.link?.active.map { $0 ? "Yes" : "No" } ?? "—")
            DetailRow(label: "MTU",     value: port.link?.mtu.map { "\($0)" } ?? "—", monospaced: true)
        }
    }

    @ViewBuilder
    private var poeSection: some View {
        section(title: "POE") {
            if let poe = port.poe {
                DetailRow(label: "Port class",       value: poe.portClass ?? "—")
                DetailRow(label: "Port state",       value: poe.portState ?? "—")
                DetailRow(label: "Priority",         value: poe.priority ?? "—")
                DetailRow(label: "Capacity",         value: poe.capacityWatts.map { String(format: "%.1f W", $0) } ?? "—", monospaced: true)
                DetailRow(label: "Granted power",    value: poe.grantedPowerWatts.map { String(format: "%.1f W", $0) } ?? "—", monospaced: true)
                DetailRow(label: "Output power",     value: poe.outputPowerWatts.map { String(format: "%.2f W", $0) } ?? "—", monospaced: true)
                DetailRow(label: "Output current",   value: poe.outputCurrentMA.map { String(format: "%.0f mA", $0) } ?? "—", monospaced: true)
                DetailRow(label: "Output voltage",   value: poe.outputVoltageV.map { String(format: "%.2f V", $0) } ?? "—", monospaced: true)
                DetailRow(label: "Chip temperature", value: poe.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—", monospaced: true)
                DetailRow(label: "LLDP enabled",     value: poe.lldpEnabled.map { $0 ? "Yes" : "No" } ?? "—")
            } else {
                Text("No PoE data for this port")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.slate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
    }

    @ViewBuilder
    private var lldpSection: some View {
        section(title: "LLDP NEIGHBOR") {
            if let lldp = port.lldp {
                DetailRow(label: "System name", value: lldp.sysName ?? "—")
                if let desc = lldp.sysDesc, !desc.isEmpty {
                    DetailRow(label: "System desc", value: desc)
                }
                DetailRow(label: "Remote port",
                          value: lldp.remotePortId ?? lldp.remotePortDesc ?? "—",
                          monospaced: true)
                if let portDesc = lldp.remotePortDesc, portDesc != lldp.remotePortId, !portDesc.isEmpty {
                    DetailRow(label: "Remote port desc", value: portDesc)
                }
                DetailRow(label: "TTL", value: lldp.ttl.map { "\($0)s" } ?? "—", monospaced: true)
            } else {
                Text("No LLDP neighbor on this port")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.slate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
    }

    @ViewBuilder
    private var macsSection: some View {
        section(title: "LEARNED MACS (\(port.learnedMACs.count))") {
            if port.learnedMACs.isEmpty {
                Text("No MACs learned on this port")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.slate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(port.learnedMACs.sorted(), id: \.self) { mac in
                    HStack {
                        Text(mac)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Brand.graphite)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if mac != port.learnedMACs.sorted().last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var errorsNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "ERRORS")
                .padding(.horizontal, 18)
                .padding(.top, 18)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Brand.slate)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error counters unavailable from CVaaS API.")
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.graphite)
                    Text("On the switch CLI: `show interface counters errors`")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        section(title: "RECENT EVENTS (24h)") {
            switch eventLoadState {
            case .idle, .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Loading events…").foregroundStyle(Brand.slate)
                    Spacer()
                }
                .padding(.vertical, 18)
            case .loaded:
                if events.isEmpty {
                    Text("No port-scoped events in the last 24 hours")
                        .font(.system(size: 14))
                        .foregroundStyle(Brand.slate)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.stableId) { index, ev in
                        EventRowView(event: ev)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        if index < events.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            case .failure(let msg):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Brand.graphite)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
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

    // MARK: - Loading

    private func loadEvents() async {
        guard let url = URL(string: auth.tenantURL) else {
            eventLoadState = .failure("Invalid tenant URL")
            return
        }
        eventLoadState = .loading
        do {
            let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
            let svc = EventService(client: client)
            events = try await svc.eventsForPort(deviceId: deviceId, interfaceName: port.interfaceName)
            eventLoadState = .loaded
        } catch {
            eventLoadState = .failure("Couldn't load events: \(error.localizedDescription)")
        }
    }
}

// MARK: - Detail row

private struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Brand.slate)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
                .foregroundStyle(Brand.graphite)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            VStack(spacing: 0) {
                Spacer()
                Divider().padding(.leading, 0)
            }
            .opacity(0.5)
        )
    }
}
