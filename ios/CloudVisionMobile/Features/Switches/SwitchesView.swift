import SwiftUI

struct SwitchesView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var devices: [Device] = []
    @State private var loadState: LoadState = .idle
    @State private var searchText: String = ""

    enum LoadState {
        case idle
        case loading
        case loaded
        case failure(CVError)
    }

    private var filteredDevices: [Device] {
        guard !searchText.isEmpty else { return devices }
        let term = searchText.lowercased()
        return devices.filter { d in
            (d.hostname?.lowercased().contains(term) ?? false)
            || (d.fqdn?.lowercased().contains(term) ?? false)
            || (d.modelName?.lowercased().contains(term) ?? false)
            || (d.systemMacAddress?.lowercased().contains(term) ?? false)
            || d.key.deviceId.lowercased().contains(term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isConfigured {
                    ConfigureCTA(featureName: "Switches")
                } else {
                    deviceList
                }
            }
            .navigationTitle("Switches")
        }
        .task(id: auth.tenantURL + auth.jwt) {
            // Poll while the view is alive. Task is auto-cancelled on view teardown and
            // re-started when auth (tenantURL or JWT) changes. 10 s cadence trades cellular
            // data for freshness — feels live without hammering the API.
            guard auth.isConfigured else { return }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        switch loadState {
        case .idle, .loading:
            if devices.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        case .loaded:
            listContent
        case .failure(let err):
            ContentUnavailableView {
                Label("Couldn't load devices", systemImage: "exclamationmark.triangle")
            } description: {
                Text(err.localizedDescription)
            } actions: {
                Button("Try again") { Task { await load() } }
            }
        }
    }

    private var listContent: some View {
        List(filteredDevices) { device in
            NavigationLink {
                DeviceHealthView(deviceId: device.key.deviceId, prefill: device)
            } label: {
                DeviceListRow(device: device)
            }
        }
        .searchable(text: $searchText, prompt: "Hostname, model, MAC")
        .listStyle(.insetGrouped)
        .refreshable { await load() }
        .overlay {
            if filteredDevices.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if devices.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No devices",
                    systemImage: "network.slash",
                    description: Text("No onboarded devices in this tenant.")
                )
            }
        }
    }

    private func load() async {
        guard let url = URL(string: auth.tenantURL) else {
            loadState = .failure(.invalidURL)
            return
        }
        loadState = .loading
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        let service = InventoryService(client: client)
        do {
            let result = try await service.devices()
            devices = result.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            loadState = .loaded
        } catch let err as CVError {
            loadState = .failure(err)
        } catch {
            loadState = .failure(.network(URLError(.unknown)))
        }
    }
}

// MARK: - Row

private struct DeviceListRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(device.streamingStatus?.isActive == true ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let model = device.modelName, !model.isEmpty {
                        Text(model).font(.caption).foregroundStyle(.secondary)
                    }
                    if let sw = device.softwareVersion, !sw.isEmpty {
                        Text("·").foregroundStyle(.tertiary).font(.caption)
                        Text(sw).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
