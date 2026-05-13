import SwiftUI

/// "Search" tab — unified search over **both** switch inventory and endpoint locator.
///
/// Endpoint search hits `endpointlocation.v1` (async REST call) and returns endpoints
/// connected to switch ports. Switch search filters the cached inventory client-side
/// (so typing produces instant results without per-keystroke API calls).
///
/// Two result sections so the user can disambiguate: looking for "madison" returns the
/// `madison-710p` switch under "Switches", and any endpoint named "madison-*" under
/// "Endpoints".
struct LocateView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var searchTerm: String = ""
    @State private var endpointState: EndpointState = .idle
    @State private var lldpHits: [LLDPSearchService.Hit] = []
    @State private var lldpSearching: Bool = false
    @State private var allDevices: [Device] = []
    @State private var devicesLoaded = false
    @State private var recents: [String] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var lldpTask: Task<Void, Never>?

    private let recentsStore = RecentSearchesStore()

    enum EndpointState {
        case idle
        case loading
        case success(LocateResults)
        case empty
        case failure(CVError)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if auth.isConfigured {
                    content
                } else {
                    ConfigureCTA(featureName: "Search")
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { recents = recentsStore.load() }
        .task(id: auth.tenantURL + auth.jwt) {
            guard auth.isConfigured else { return }
            await loadDevicesIfNeeded()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            stateView
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Switch hostname, MAC, IP, or endpoint", text: $searchTerm)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.search)
                .onSubmit { runEndpointSearch() }
                .onChange(of: searchTerm) { _, _ in
                    // Switches filter as you type; endpoints fire only on submit (network call).
                    // If the box clears, reset endpoint state to idle.
                    if searchTerm.isEmpty { endpointState = .idle }
                }
            if !searchTerm.isEmpty {
                Button {
                    searchTerm = ""
                    endpointState = .idle
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - State view

    @ViewBuilder
    private var stateView: some View {
        if searchTerm.trimmingCharacters(in: .whitespaces).isEmpty {
            idleView
        } else {
            resultsView
        }
    }

    @ViewBuilder
    private var idleView: some View {
        if recents.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Search",
                message: "Find a switch by hostname or an endpoint by MAC, IP, or hostname."
            )
        } else {
            List {
                Section {
                    ForEach(recents, id: \.self) { term in
                        Button {
                            searchTerm = term
                            runEndpointSearch()
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(term).font(.body.monospaced())
                                Spacer()
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear") {
                            recents = []
                            recentsStore.clear()
                        }
                        .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        let devices = matchingDevices
        let endpointMatches = endpointResults
        let hasAnyResults = !devices.isEmpty || !endpointMatches.isEmpty || !lldpHits.isEmpty
        let allTerminal = isEndpointTerminal && !lldpSearching

        if !hasAnyResults && allTerminal {
            EmptyStateView(
                systemImage: "questionmark.circle",
                title: "No matches",
                message: "Nothing matched \"\(searchTerm)\". Tap Search on the keyboard to widen the lookup to endpoint records."
            )
        } else {
            List {
                if !devices.isEmpty {
                    Section {
                        ForEach(devices) { device in
                            NavigationLink {
                                DeviceHealthView(deviceId: device.key.deviceId, prefill: device)
                            } label: {
                                SwitchResultRow(device: device)
                            }
                        }
                    } header: {
                        Text("Switches (\(devices.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Brand.graphite)
                            .textCase(nil)
                    }
                }

                Section {
                    endpointSection(matches: endpointMatches)
                } header: {
                    HStack {
                        Text(endpointHeaderText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Brand.graphite)
                            .textCase(nil)
                        if case .loading = endpointState {
                            Spacer()
                            ProgressView().controlSize(.mini)
                        }
                    }
                }

                Section {
                    lldpSection
                } header: {
                    HStack {
                        Text(lldpHeaderText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Brand.graphite)
                            .textCase(nil)
                        if lldpSearching {
                            Spacer()
                            ProgressView().controlSize(.mini)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var lldpSection: some View {
        if lldpSearching && lldpHits.isEmpty {
            HStack {
                ProgressView().controlSize(.small)
                Text("Scanning LLDP across \(allDevices.count) switches…")
                    .font(.caption)
                    .foregroundStyle(Brand.slate)
            }
        } else if lldpHits.isEmpty && isEndpointTerminal {
            Text("No LLDP-discovered hosts matched \"\(searchTerm)\".")
                .font(.caption)
                .foregroundStyle(Brand.slate)
        } else {
            ForEach(lldpHits) { hit in
                NavigationLink {
                    if let device = allDevices.first(where: { $0.key.deviceId == hit.deviceId }) {
                        DeviceHealthView(deviceId: hit.deviceId, prefill: device)
                    }
                } label: {
                    LLDPHitRow(hit: hit, hostname: hostnameForDevice(hit.deviceId))
                }
            }
        }
    }

    private var lldpHeaderText: String {
        lldpHits.isEmpty ? "Discovered (LLDP)" : "Discovered (LLDP) (\(lldpHits.count))"
    }

    private func hostnameForDevice(_ id: String) -> String {
        allDevices.first { $0.key.deviceId == id }?.displayName ?? id
    }

    @ViewBuilder
    private func endpointSection(matches: [LocateResults.DeviceRow]) -> some View {
        switch endpointState {
        case .idle:
            Button("Tap to search endpoints by this term") { runEndpointSearch() }
                .font(.caption)
                .foregroundStyle(Brand.steel)
        case .loading:
            HStack { ProgressView().controlSize(.small); Text("Searching endpoints…").font(.caption).foregroundStyle(Brand.slate) }
        case .empty:
            Text("No endpoints matched \"\(searchTerm)\".")
                .font(.caption)
                .foregroundStyle(Brand.slate)
        case .failure(let err):
            Label(err.localizedDescription, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .success:
            ForEach(matches) { record in
                LocateResultRow(device: record)
            }
        }
    }

    private var endpointHeaderText: String {
        switch endpointState {
        case .success(let results): return "Endpoints (\(results.devices.count))"
        case .empty:                return "Endpoints (0)"
        default:                    return "Endpoints"
        }
    }

    private var isEndpointTerminal: Bool {
        switch endpointState {
        case .success, .empty, .failure: return true
        default: return false
        }
    }

    // MARK: - Filtering

    private var matchingDevices: [Device] {
        let term = searchTerm.lowercased()
        guard !term.isEmpty else { return [] }
        return allDevices.filter { d in
            (d.hostname?.lowercased().contains(term) ?? false)
            || (d.fqdn?.lowercased().contains(term) ?? false)
            || (d.modelName?.lowercased().contains(term) ?? false)
            || (d.systemMacAddress?.lowercased().contains(term) ?? false)
            || d.key.deviceId.lowercased().contains(term)
        }
    }

    private var endpointResults: [LocateResults.DeviceRow] {
        if case .success(let r) = endpointState { return r.devices }
        return []
    }

    // MARK: - Loaders

    private func loadDevicesIfNeeded() async {
        if devicesLoaded { return }
        guard let url = URL(string: auth.tenantURL) else { return }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        do {
            let devs = try await InventoryService(client: client).devices()
            allDevices = devs.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            devicesLoaded = true
        } catch {
            // Non-fatal — switch search just falls back to "no results".
        }
    }

    private func runEndpointSearch() {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { endpointState = .idle; return }
        guard let url = URL(string: auth.tenantURL) else {
            endpointState = .failure(.invalidURL)
            return
        }

        // Cancel any in-flight searches.
        searchTask?.cancel()
        lldpTask?.cancel()
        endpointState = .loading
        lldpHits = []
        lldpSearching = false

        let httpClient = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        let service = EndpointLocationService(client: httpClient)

        // Exact-match endpoint search (REST).
        searchTask = Task { @MainActor in
            do {
                let resp = try await service.find(searchTerm: trimmed)
                if Task.isCancelled { return }
                let results = LocateResults(from: resp)
                endpointState = results.devices.isEmpty ? .empty : .success(results)
                addRecent(trimmed)
            } catch let err as CVError {
                if Task.isCancelled { return }
                endpointState = .failure(err)
            } catch {
                if Task.isCancelled { return }
                endpointState = .failure(.network(URLError(.unknown)))
            }
        }

        // LLDP substring search (Connector). Fires only if we have a cached device list —
        // otherwise we'd be searching nothing useful.
        guard !allDevices.isEmpty else { return }
        lldpSearching = true
        lldpTask = Task { @MainActor in
            defer { lldpSearching = false }
            do {
                let connector = try ConnectorClient(tenantURL: url, jwt: auth.jwt)
                defer { Task { await connector.shutdown() } }
                let svc = LLDPSearchService(client: connector)
                let serials = allDevices.map { $0.key.deviceId }
                let hits = await svc.search(term: trimmed, across: serials)
                if !Task.isCancelled {
                    lldpHits = hits.sorted { $0.sysName.localizedCaseInsensitiveCompare($1.sysName) == .orderedAscending }
                }
            } catch {
                // Silent — LLDP search is best-effort.
            }
        }
    }

    private func addRecent(_ term: String) {
        var updated = recents
        updated.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        updated.insert(term, at: 0)
        if updated.count > RecentSearchesStore.maxItems {
            updated = Array(updated.prefix(RecentSearchesStore.maxItems))
        }
        recents = updated
        recentsStore.save(updated)
    }
}

// MARK: - LLDP hit row

private struct LLDPHitRow: View {
    let hit: LLDPSearchService.Hit
    let hostname: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 16))
                .foregroundStyle(Brand.steel)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.sysName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.graphite)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(hostname)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                    Text("·").foregroundStyle(Brand.mist).font(.caption)
                    Text(hit.localInterface)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                }
                if let portId = hit.remotePortId, !portId.isEmpty {
                    Text("remote: \(portId)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Switch row

private struct SwitchResultRow: View {
    let device: Device

    private var isOnline: Bool { device.streamingStatus?.isActive == true }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 16))
                .foregroundStyle(Brand.graphite)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Brand.graphite)
                    .lineLimit(1)
                if let model = device.modelName, !model.isEmpty {
                    Text(model)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
