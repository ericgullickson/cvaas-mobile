import SwiftUI

/// Devices tab. Sectioned by Online/Offline streaming status, with search and a filter sheet
/// reached from the toolbar hamburger. Replaces the prior single-section list per Direction-3
/// mockup.
struct SwitchesView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var devices: [Device] = []
    @State private var loadState: LoadState = .idle
    @State private var searchText: String = ""
    @State private var filter: DeviceFilter = .all
    @State private var showFilters = false

    enum LoadState {
        case idle, loading, loaded
        case failure(CVError)
    }

    enum DeviceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case online = "Online only"
        case offline = "Offline only"
        var id: String { rawValue }
    }

    // MARK: - Computed

    private var filtered: [Device] {
        let bySearch: [Device]
        if searchText.isEmpty {
            bySearch = devices
        } else {
            let term = searchText.lowercased()
            bySearch = devices.filter { d in
                (d.hostname?.lowercased().contains(term) ?? false)
                || (d.fqdn?.lowercased().contains(term) ?? false)
                || (d.modelName?.lowercased().contains(term) ?? false)
                || (d.systemMacAddress?.lowercased().contains(term) ?? false)
                || d.key.deviceId.lowercased().contains(term)
            }
        }
        switch filter {
        case .all:     return bySearch
        case .online:  return bySearch.filter { $0.streamingStatus?.isActive == true }
        case .offline: return bySearch.filter { $0.streamingStatus?.isActive != true }
        }
    }

    private var onlineDevices: [Device] {
        filtered.filter { $0.streamingStatus?.isActive == true }
    }

    private var offlineDevices: [Device] {
        filtered.filter { $0.streamingStatus?.isActive != true }
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isConfigured {
                    ConfigureCTA(featureName: "Devices")
                } else {
                    listContent
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Filter devices")
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(filter: $filter)
                    .presentationDetents([.fraction(0.35), .medium])
            }
        }
        .task(id: auth.tenantURL + auth.jwt) {
            guard auth.isConfigured else { return }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch loadState {
        case .failure(let err):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load devices",
                message: err.localizedDescription,
                action: .init(label: "Try again") { Task { await load() } }
            )
        case .idle, .loading:
            if devices.isEmpty {
                loadingList
            } else {
                deviceList
            }
        case .loaded:
            deviceList
        }
    }

    private var loadingList: some View {
        List {
            Section {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonRow(showLeadingEdge: false)
                }
            } header: {
                SectionLabel(text: "LOADING")
                    .padding(.bottom, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var deviceList: some View {
        List {
            if !onlineDevices.isEmpty {
                Section {
                    ForEach(onlineDevices) { device in
                        NavigationLink {
                            DeviceHealthView(deviceId: device.key.deviceId, prefill: device)
                        } label: {
                            DeviceRow(device: device)
                        }
                    }
                } header: {
                    sectionHeader(title: "Online", count: onlineDevices.count)
                }
            }
            if !offlineDevices.isEmpty {
                Section {
                    ForEach(offlineDevices) { device in
                        NavigationLink {
                            DeviceHealthView(deviceId: device.key.deviceId, prefill: device)
                        } label: {
                            DeviceRow(device: device)
                        }
                    }
                } header: {
                    sectionHeader(title: "Offline", count: offlineDevices.count)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search devices")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable { await load() }
        .overlay {
            if filtered.isEmpty && !searchText.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    message: "Nothing matched \"\(searchText)\"."
                )
            } else if devices.isEmpty {
                EmptyStateView(
                    systemImage: "network.slash",
                    title: "No devices",
                    message: "No onboarded devices in this tenant."
                )
            }
        }
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Brand.graphite)
            Text("(\(count))")
                .font(.system(size: 13))
                .foregroundStyle(Brand.slate)
            Spacer()
        }
        .textCase(nil)
        .padding(.leading, -8)
    }

    // MARK: - Load

    private func load() async {
        guard let url = URL(string: auth.tenantURL) else {
            loadState = .failure(.invalidURL)
            return
        }
        if devices.isEmpty { loadState = .loading }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        do {
            let result = try await InventoryService(client: client).devices()
            devices = result.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            loadState = .loaded
        } catch let err as CVError {
            loadState = .failure(err)
        } catch {
            loadState = .failure(.network(URLError(.unknown)))
        }
    }
}

// MARK: - Row

private struct DeviceRow: View {
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
            Spacer(minLength: 8)
            if let uptimeLabel = uptimeLabel(for: device) {
                Text(uptimeLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Brand.slate)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    /// Returns a friendly uptime label like "1m", "3h", "12d" — or `nil` if the device's
    /// reported `bootTime` looks like an epoch-zero default rather than a real value.
    private func uptimeLabel(for device: Device) -> String? {
        guard let bootDate = device.bootDate else { return nil }
        let interval = Date().timeIntervalSince(bootDate)
        // Filter "device reported no bootTime" cases (epoch 0 → ~57y in 2026).
        guard interval > 0, interval < 10 * 365 * 24 * 3600 else { return nil }
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86_400)
        if days > 0 { return "\(days)d" }
        if hours > 0 { return "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "now"
    }
}

// MARK: - Filter sheet

private struct FilterSheet: View {
    @Binding var filter: SwitchesView.DeviceFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SwitchesView.DeviceFilter.allCases) { option in
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
