import SwiftUI

/// "Port Snapshot" — F2 port table redesigned per Direction-3 mockup.
///
/// Rows now have a full-height leading color strip (link/PoE state at a glance from arm's
/// length in a dim closet) and a status pill on the trailing edge (PoE watts / Link Down /
/// Not PoE). Error counters remain PRD-DROPPED (Sprint 2 §1.5 F.1.d) — the detail screen,
/// not this list, explains the gap.
struct PortInspectorView: View {
    let deviceId: String

    @EnvironmentObject private var auth: AuthStore
    @State private var state: LoadState = .idle
    @State private var snapshot: PortStateService.Snapshot?
    @State private var searchText: String = ""
    @State private var linkFilter: LinkFilter = .all
    @State private var showFilters = false

    enum LoadState { case idle, loading, loaded; case failure(String) }

    enum LinkFilter: String, CaseIterable, Identifiable {
        case all = "All ports"
        case up = "Link up only"
        case down = "Link down only"
        case poe = "PoE powered only"
        var id: String { rawValue }
    }

    private var filteredPorts: [PortState] {
        let ports = snapshot?.ports ?? []
        let bySearch: [PortState]
        if searchText.isEmpty {
            bySearch = ports
        } else {
            let term = searchText.lowercased()
            bySearch = ports.filter { port in
                port.interfaceName.lowercased().contains(term)
                || (port.lldp?.sysName?.lowercased().contains(term) ?? false)
            }
        }
        switch linkFilter {
        case .all:  return bySearch
        case .up:   return bySearch.filter { $0.link?.linkStatus == "linkUp" }
        case .down: return bySearch.filter { $0.link?.linkStatus == "linkDown" }
        case .poe:  return bySearch.filter { ($0.poe?.outputPowerWatts ?? 0) > 0 }
        }
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                if snapshot == nil { skeletonList } else { portsList }
            case .loaded:
                portsList
            case .failure(let msg):
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load ports",
                    message: msg,
                    action: .init(label: "Try again") { Task { await load(force: true) } }
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Port Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Filter ports")
            }
        }
        .searchable(text: $searchText, prompt: "Search ports")
        .sheet(isPresented: $showFilters) {
            FilterSheet(filter: $linkFilter)
                .presentationDetents([.fraction(0.4), .medium])
        }
        .task(id: deviceId) { await load() }
        .refreshable { await load(force: true) }
    }

    // MARK: - Lists

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonRow()
                        .padding(.horizontal, 16)
                    Divider().padding(.leading, 32)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private var portsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                metadataBar
                portsCard
                Color.clear.frame(height: 100)
            }
        }
        .overlay {
            if filteredPorts.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No ports match your filters.",
                    message: "Try adjusting your search."
                )
            }
        }
    }

    @ViewBuilder
    private var metadataBar: some View {
        if let snap = snapshot {
            HStack {
                Text("Updated \(snap.asOf.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.slate)
                Spacer()
                Text("\(snap.ports.count) ports")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.slate)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)
            if !snap.partialErrors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Some columns failed: \(snap.partialErrors.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(Brand.slate)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private var portsCard: some View {
        if !filteredPorts.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(filteredPorts.enumerated()), id: \.element.id) { index, port in
                    NavigationLink {
                        PortDetailView(deviceId: deviceId, port: port)
                    } label: {
                        PortRow(port: port)
                    }
                    .buttonStyle(.plain)
                    if index < filteredPorts.count - 1 {
                        Divider().padding(.leading, 28)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Load

    private func load(force: Bool = false) async {
        if !force, snapshot != nil { return }
        guard let url = URL(string: auth.tenantURL) else {
            state = .failure("Invalid tenant URL")
            return
        }
        state = .loading
        do {
            let client = try ConnectorClient(tenantURL: url, jwt: auth.jwt)
            let snap = try await PortStateService(client: client).fetchAllColumns(deviceSerial: deviceId)
            await client.shutdown()
            snapshot = snap
            state = .loaded
        } catch {
            state = .failure("\(type(of: error)): \(error.localizedDescription)")
        }
    }
}

// MARK: - Port row

private struct PortRow: View {
    let port: PortState

    var body: some View {
        HStack(spacing: 0) {
            // Leading edge state strip — full row height, 4pt wide.
            Rectangle()
                .fill(edgeColor)
                .frame(width: 4)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(port.interfaceName)
                        .font(TypeScale.identifierLarge)
                        .foregroundStyle(Brand.graphite)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                statusPill
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }

    private var edgeColor: Color {
        switch port.link?.linkStatus {
        case "linkDown":   return .red
        case "notPresent": return Brand.mist
        case "linkUp":
            if let watts = port.poe?.outputPowerWatts, watts > 0 {
                return .green
            }
            if isPoEPort {
                return Brand.slate
            }
            return Brand.navy
        default: return Brand.mist
        }
    }

    private var isPoEPort: Bool {
        // Heuristic: if any PoE field is reported, the port is PoE-capable.
        port.poe?.portClass != nil || port.poe?.capacityWatts != nil
    }

    private var subtitle: String {
        if let sys = port.lldp?.sysName, !sys.isEmpty { return sys }
        return "N/A"
    }

    @ViewBuilder
    private var statusPill: some View {
        if port.link?.linkStatus == "linkDown" {
            StatusPill(label: "Link Down", intent: .danger)
        } else if port.link?.linkStatus == "notPresent" {
            StatusPill(label: "Not Present", intent: .neutral)
        } else if let watts = port.poe?.outputPowerWatts, watts > 0 {
            let pillIntent: StatusPill.Intent = watts < 10 ? .warning : .success
            StatusPill(label: "PoE \(formatWatts(watts))", intent: pillIntent, style: .outlined)
        } else if isPoEPort {
            StatusPill(label: "PoE Off", intent: .neutral)
        } else {
            StatusPill(label: "Not PoE", intent: .info)
        }
    }

    private func formatWatts(_ watts: Double) -> String {
        if watts.truncatingRemainder(dividingBy: 1) < 0.05 {
            return "\(Int(watts))W"
        }
        return String(format: "%.1fW", watts)
    }
}

// MARK: - Filter sheet

private struct FilterSheet: View {
    @Binding var filter: PortInspectorView.LinkFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PortInspectorView.LinkFilter.allCases) { option in
                        Button {
                            filter = option
                            dismiss()
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundStyle(Brand.graphite)
                                Spacer()
                                if filter == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Brand.steel)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Show")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.graphite)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
