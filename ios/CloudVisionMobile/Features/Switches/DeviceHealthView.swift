import SwiftUI

struct DeviceHealthView: View {
    let deviceId: String
    /// Device snapshot from the list view, used to show metadata immediately while the per-device
    /// fetch runs in the background.
    let prefill: Device?

    @EnvironmentObject private var auth: AuthStore

    @State private var device: Device?
    @State private var deviceLoad: LoadState = .idle
    @State private var events: [Event] = []
    @State private var eventsLoad: LoadState = .idle

    enum LoadState {
        case idle
        case loading
        case loaded
        case failure(CVError)
    }

    private var currentDevice: Device? { device ?? prefill }

    private var deviceEvents: [Event] {
        events
            .filter { $0.mentionsDevice(id: deviceId) }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    private var activeAlerts: [Event] {
        deviceEvents.filter { $0.isActive && ($0.severity ?? .unspecified) >= .warning }
    }

    var body: some View {
        List {
            Section { headerContent }

            Section("Health") { healthRows }

            Section("Ports") {
                NavigationLink {
                    PortInspectorView(deviceId: deviceId)
                } label: {
                    HStack {
                        Image(systemName: "cable.connector")
                            .foregroundStyle(.blue)
                        Text("View ports")
                    }
                }
            }

            Section("Alerts") {
                NavigationLink {
                    AlertsListView(alerts: activeAlerts, hostname: currentDevice?.displayName)
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(activeAlerts.isEmpty ? .green : .orange)
                        Text("Active alerts")
                        Spacer()
                        Text("\(activeAlerts.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .disabled(activeAlerts.isEmpty)
            }

            Section("Recent events (last 24 h)") { eventsRows }
        }
        .navigationTitle(currentDevice?.displayName ?? deviceId)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: deviceId) {
            // Poll device + events while view is alive. 10 s feels live; scroll position is
            // preserved by SwiftUI's List diffing on Identifiable items as long as deviceId
            // stays stable.
            while !Task.isCancelled {
                await loadAll()
                try? await Task.sleep(for: .seconds(10))
            }
        }
        .refreshable { await loadAll() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerContent: some View {
        let d = currentDevice
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(d?.displayName ?? deviceId)
                    .font(.title3.weight(.semibold))
                Spacer()
                StreamingPill(status: d?.streamingStatus)
            }
            if let fqdn = d?.fqdn, !fqdn.isEmpty, fqdn != d?.hostname {
                Text(fqdn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var healthRows: some View {
        let d = currentDevice
        LabeledRow(label: "Serial", value: deviceId, monospaced: true)
        if let model = d?.modelName, !model.isEmpty {
            LabeledRow(label: "Model", value: model)
        }
        if let sw = d?.softwareVersion, !sw.isEmpty {
            LabeledRow(label: "EOS", value: sw, monospaced: true)
        }
        if let mac = d?.systemMacAddress, !mac.isEmpty {
            LabeledRow(label: "System MAC", value: mac, monospaced: true)
        }
        if let bootDate = d?.bootDate {
            LabeledRow(
                label: "Up since",
                value: bootDate.formatted(.relative(presentation: .named))
            )
        }
        if let hwRev = d?.hardwareRevision, !hwRev.isEmpty {
            LabeledRow(label: "Hardware rev", value: hwRev)
        }
        if case .failure(let err) = deviceLoad {
            Text(err.localizedDescription)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var eventsRows: some View {
        if case .loading = eventsLoad, events.isEmpty {
            HStack { Spacer(); ProgressView(); Spacer() }
        } else if case .failure(let err) = eventsLoad {
            Text(err.localizedDescription)
                .font(.caption)
                .foregroundStyle(.red)
        } else if deviceEvents.isEmpty {
            Text("No events in the last 24 hours.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(deviceEvents.prefix(20)), id: \.stableId) { event in
                EventRowView(event: event)
            }
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        guard let url = URL(string: auth.tenantURL) else {
            deviceLoad = .failure(.invalidURL)
            eventsLoad = .failure(.invalidURL)
            return
        }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        async let dev: () = loadDevice(client: client)
        async let evs: () = loadEvents(client: client)
        _ = await (dev, evs)
    }

    private func loadDevice(client: CVHTTPClient) async {
        deviceLoad = .loading
        do {
            device = try await InventoryService(client: client).device(id: deviceId)
            deviceLoad = .loaded
        } catch let err as CVError {
            deviceLoad = .failure(err)
        } catch {
            deviceLoad = .failure(.network(URLError(.unknown)))
        }
    }

    private func loadEvents(client: CVHTTPClient) async {
        eventsLoad = .loading
        do {
            events = try await EventService(client: client).recentEvents(hours: 24)
            eventsLoad = .loaded
        } catch let err as CVError {
            eventsLoad = .failure(err)
        } catch {
            eventsLoad = .failure(.network(URLError(.unknown)))
        }
    }
}

// MARK: - Pieces

private struct StreamingPill: View {
    let status: StreamingStatus?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status?.isActive == true ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(status?.label ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .body.monospaced() : .body)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }
}
