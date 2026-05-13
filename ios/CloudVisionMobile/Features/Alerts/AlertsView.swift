import SwiftUI

/// Org-wide active alerts (CVaaS-speak for "events with severity ≥ WARNING and `delete_time`
/// unset", per EventModels.swift header note). Uses the existing `EventService.recentEvents`
/// — no new API surface.
///
/// Tapping an alert pushes a detail view that surfaces the underlying event with a button to
/// jump to the source device's health screen.
struct AlertsView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var alerts: [Event] = []
    @State private var devicesById: [String: Device] = [:]
    @State private var loadState: LoadState = .idle

    enum LoadState { case idle, loading, loaded; case failure(CVError) }

    private var critical: [Event] { alerts.filter { ($0.severity ?? .unspecified) == .critical } }
    private var errors: [Event]   { alerts.filter { ($0.severity ?? .unspecified) == .error } }
    private var warnings: [Event] { alerts.filter { ($0.severity ?? .unspecified) == .warning } }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isConfigured {
                    ConfigureCTA(featureName: "Alerts")
                } else {
                    content
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: auth.tenantURL + auth.jwt) {
            guard auth.isConfigured else { return }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .failure(let err):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load alerts",
                message: err.localizedDescription,
                action: .init(label: "Try again") { Task { await load() } }
            )
        case .idle, .loading:
            if alerts.isEmpty { loadingList } else { alertsList }
        case .loaded:
            alertsList
        }
    }

    private var loadingList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRow(showLeadingEdge: false)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var alertsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if alerts.isEmpty {
                    EmptyStateView(
                        systemImage: "checkmark.shield",
                        title: "All clear",
                        message: "No active alerts in the last 24 hours."
                    )
                    .padding(.top, 80)
                } else {
                    if !critical.isEmpty { sectionCard(title: "CRITICAL (\(critical.count))", events: critical) }
                    if !errors.isEmpty   { sectionCard(title: "ERROR (\(errors.count))",     events: errors) }
                    if !warnings.isEmpty { sectionCard(title: "WARNING (\(warnings.count))", events: warnings) }
                }
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await load() }
    }

    @ViewBuilder
    private func sectionCard(title: String, events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.stableId) { index, event in
                    NavigationLink {
                        destinationForAlert(event)
                    } label: {
                        AlertRow(event: event, hostname: hostnameForEvent(event))
                    }
                    .buttonStyle(.plain)
                    if index < events.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func destinationForAlert(_ event: Event) -> some View {
        if let deviceId = sourceDeviceId(for: event), let device = devicesById[deviceId] {
            DeviceHealthView(deviceId: deviceId, prefill: device)
        } else if let deviceId = sourceDeviceId(for: event) {
            DeviceHealthView(deviceId: deviceId, prefill: nil)
        } else {
            // No device source — show a stub. Real fallback would be an event-detail view; for
            // MVP we keep navigation predictable rather than ship a half-built screen.
            EmptyStateView(
                systemImage: "info.circle",
                title: event.title ?? "Alert",
                message: event.description
            )
        }
    }

    private func sourceDeviceId(for event: Event) -> String? {
        if let id = event.data?.data?["deviceId"] { return id }
        for comp in event.components?.components ?? [] {
            if let id = comp.components?["deviceId"] { return id }
        }
        return nil
    }

    private func hostnameForEvent(_ event: Event) -> String? {
        guard let id = sourceDeviceId(for: event) else { return nil }
        return devicesById[id]?.displayName
    }

    // MARK: - Load

    private func load() async {
        guard let url = URL(string: auth.tenantURL) else {
            loadState = .failure(.invalidURL)
            return
        }
        if alerts.isEmpty { loadState = .loading }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        async let eventsTask = EventService(client: client).recentEvents(hours: 24)
        async let devicesTask = InventoryService(client: client).devices()
        do {
            let (rawEvents, devices) = try await (eventsTask, devicesTask)
            self.devicesById = Dictionary(uniqueKeysWithValues: devices.map { ($0.key.deviceId, $0) })
            self.alerts = rawEvents
                .filter { $0.isActive }
                .filter { ($0.severity ?? .unspecified) >= .warning }
                .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
            loadState = .loaded
        } catch let err as CVError {
            loadState = .failure(err)
        } catch {
            loadState = .failure(.network(URLError(.unknown)))
        }
    }
}

// MARK: - Alert row

private struct AlertRow: View {
    let event: Event
    let hostname: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Alert")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
                    .lineLimit(2)
                if let hostname {
                    Text(hostname)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Brand.slate)
                }
                if let date = event.startDate {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.slate)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.slate)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var severity: EventSeverity { event.severity ?? .unspecified }

    private var iconName: String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .error:    return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        default:        return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch severity {
        case .critical, .error: return .red
        case .warning:          return .orange
        default:                return Brand.steel
        }
    }
}
