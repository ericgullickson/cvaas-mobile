import SwiftUI

/// Detail screen for one device. Navy hero band + sectioned overview, quick-actions grid, and
/// recent-activity list. Replaces the prior insetGrouped-list layout.
///
/// **Scope decisions** (PRD §6 / Sprint-2 plan):
/// - Quick Actions are read-only navigation shortcuts — `Ports`, `Alerts`, `Events`, `Open in
///   CVaaS web`. No write/probe ops (no Ping, no Reboot, no port LED) in MVP.
/// - Star/favorite is local-only (`FavoritesStore` → UserDefaults).
struct DeviceHealthView: View {
    let deviceId: String
    let prefill: Device?

    @EnvironmentObject private var auth: AuthStore

    @State private var device: Device?
    @State private var deviceLoadState: LoadState = .idle
    @State private var events: [Event] = []
    @State private var eventsLoadState: LoadState = .idle
    @State private var isFavorite: Bool
    /// Last-reload time fetched via Connector (`Sysdb/cell/1/sys/reload/cause.timestamp`).
    /// Authoritative source for uptime — `inventory.v1.Device.boot_time` is always epoch 0.
    @State private var bootDateFromNetDB: Date?

    init(deviceId: String, prefill: Device?) {
        self.deviceId = deviceId
        self.prefill = prefill
        _isFavorite = State(initialValue: FavoritesStore.shared.contains(deviceId))
    }

    enum LoadState {
        case idle, loading, loaded
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

    private var isHealthy: Bool { activeAlerts.isEmpty }

    // MARK: - View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                overviewSection
                quickActionsSection
                recentActivitySection
                Color.clear.frame(height: 100) // tab bar clearance
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentDevice?.displayName ?? deviceId)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFavorite.toggle()
                    FavoritesStore.shared.toggle(deviceId)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .white)
                }
                .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")
            }
        }
        .task(id: deviceId) {
            while !Task.isCancelled {
                await loadAll()
                try? await Task.sleep(for: .seconds(10))
            }
        }
        .refreshable { await loadAll() }
    }

    // MARK: - Hero

    private var hero: some View {
        DeviceHeroBand(
            hostname: currentDevice?.displayName ?? deviceId,
            model: currentDevice?.modelName,
            address: shortDeviceIdentifier,
            isHealthy: isHealthy,
            isFavorite: $isFavorite
        )
    }

    private var shortDeviceIdentifier: String? {
        // Prefer system MAC (short, unique-ish) over the full serial-ID — looks cleaner in
        // the hero subtitle and matches the mockup's "192.168.1.101"-style metadata line.
        currentDevice?.systemMacAddress ?? deviceId
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "OVERVIEW")
                .padding(.horizontal, 18)
                .padding(.top, 18)
            VStack(spacing: 0) {
                KVRow(label: "Model", value: currentDevice?.modelName ?? "—")
                Divider().padding(.leading, 16)
                KVRow(label: "Serial Number", value: deviceId, monospaced: true)
                Divider().padding(.leading, 16)
                KVRow(label: "Uptime", value: uptimeText)
                Divider().padding(.leading, 16)
                KVRow(label: "Software", value: currentDevice?.softwareVersion ?? "—", monospaced: true)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private var uptimeText: String {
        // Prefer the Connector-sourced boot date (real uptime). Fall back to inventory.v1's
        // boot_time only if the Connector hasn't responded yet — and even then we filter
        // epoch-zero defaults.
        guard let bootDate = bootDateFromNetDB ?? validInventoryBootDate else { return "—" }
        let interval = Date().timeIntervalSince(bootDate)
        guard interval > 0 else { return "—" }
        let days = Int(interval / 86_400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86_400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var validInventoryBootDate: Date? {
        guard let bootDate = currentDevice?.bootDate else { return nil }
        let interval = Date().timeIntervalSince(bootDate)
        guard interval > 0, interval < 10 * 365 * 24 * 3600 else { return nil }
        return bootDate
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "QUICK ACTIONS")
                .padding(.horizontal, 18)
                .padding(.top, 18)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                NavigationLink {
                    PortInspectorView(deviceId: deviceId)
                } label: {
                    QuickActionTile(icon: "cable.connector", label: "Ports")
                }
                NavigationLink {
                    AlertsListView(alerts: activeAlerts, hostname: currentDevice?.displayName)
                } label: {
                    QuickActionTile(
                        icon: "exclamationmark.triangle.fill",
                        label: "Alerts",
                        badge: activeAlerts.isEmpty ? nil : "\(activeAlerts.count)"
                    )
                }
                NavigationLink {
                    DeviceEventsView(deviceId: deviceId, hostname: currentDevice?.displayName, events: deviceEvents)
                } label: {
                    QuickActionTile(icon: "list.bullet.rectangle", label: "Events")
                }
                Button {
                    openInWeb()
                } label: {
                    QuickActionTile(icon: "safari", label: "Open in CVaaS")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "RECENT ACTIVITY")
                .padding(.horizontal, 18)
                .padding(.top, 18)
            VStack(spacing: 0) {
                if case .loading = eventsLoadState, deviceEvents.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 24)
                } else if case .failure(let err) = eventsLoadState {
                    Text(err.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(16)
                } else if deviceEvents.isEmpty {
                    Text("No events in the last 24 hours")
                        .font(.system(size: 14))
                        .foregroundStyle(Brand.slate)
                        .padding(16)
                } else {
                    let visible = Array(deviceEvents.prefix(3))
                    ForEach(Array(visible.enumerated()), id: \.element.stableId) { index, event in
                        ActivityRow(event: event)
                        if index < visible.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Actions

    private func openInWeb() {
        guard var components = URLComponents(string: auth.tenantURL) else { return }
        components.path = "/cv/devices/\(deviceId)"
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Loading

    private func loadAll() async {
        guard let url = URL(string: auth.tenantURL) else {
            deviceLoadState = .failure(.invalidURL)
            eventsLoadState = .failure(.invalidURL)
            return
        }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        async let dev: () = loadDevice(client: client)
        async let evs: () = loadEvents(client: client)
        async let uptime: () = loadUptime(tenantURL: url)
        _ = await (dev, evs, uptime)
    }

    /// One-shot Connector query for the real boot time. Fires alongside the REST loads and
    /// updates `bootDateFromNetDB` once received. Failures are silent — the Uptime row falls
    /// back to `inventory.v1.boot_time` (which is typically epoch 0, so renders "—").
    private func loadUptime(tenantURL: URL) async {
        do {
            let client = try ConnectorClient(tenantURL: tenantURL, jwt: auth.jwt)
            defer { Task { await client.shutdown() } }
            let svc = SystemUptimeService(client: client)
            if let date = try await svc.bootDate(deviceSerial: deviceId) {
                bootDateFromNetDB = date
            }
        } catch {
            // Silent — uptime is non-critical; Connector failures shouldn't block the page.
        }
    }

    private func loadDevice(client: CVHTTPClient) async {
        deviceLoadState = .loading
        do {
            device = try await InventoryService(client: client).device(id: deviceId)
            deviceLoadState = .loaded
        } catch let err as CVError {
            deviceLoadState = .failure(err)
        } catch {
            deviceLoadState = .failure(.network(URLError(.unknown)))
        }
    }

    private func loadEvents(client: CVHTTPClient) async {
        eventsLoadState = .loading
        do {
            events = try await EventService(client: client).recentEvents(hours: 24)
            eventsLoadState = .loaded
        } catch let err as CVError {
            eventsLoadState = .failure(err)
        } catch {
            eventsLoadState = .failure(.network(URLError(.unknown)))
        }
    }
}

// MARK: - Key/value row

private struct KVRow: View {
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
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Quick action tile

private struct QuickActionTile: View {
    let icon: String
    let label: String
    var badge: String?

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Brand.steel)
                    .frame(width: 28, height: 28)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                        .offset(x: 12, y: -6)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Brand.graphite)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Activity row

private struct ActivityRow: View {
    let event: Event

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Event")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Brand.graphite)
                    .lineLimit(2)
                if let date = event.startDate {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.slate)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var iconName: String {
        switch event.severity ?? .unspecified {
        case .critical: return "exclamationmark.octagon.fill"
        case .error:    return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        case .info, .debug, .unspecified: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.severity ?? .unspecified {
        case .critical, .error: return .red
        case .warning: return .orange
        case .info: return Brand.steel
        case .debug, .unspecified: return Brand.slate
        }
    }
}
