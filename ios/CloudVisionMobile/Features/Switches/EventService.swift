import Foundation

/// Wraps the CVaaS event.v1 REST endpoint.
struct EventService {
    let client: CVHTTPClient

    /// GET /api/resources/event/v1/Event/all?time.start=<-N h>&time.end=<now>
    ///
    /// Returns every event in the time window for the entire tenant. Callers are expected to
    /// filter to a specific device using `Event.mentionsDevice(id:)`. Server-side device filtering
    /// via nested partialEqFilter is awkward against the REST gateway and is punted until volumes
    /// demand it.
    func recentEvents(hours: Int = 24) async throws -> [Event] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -hours, to: now) ?? now
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return try await client.getAll(
            path: "/api/resources/event/v1/Event/all",
            query: [
                "time.start": f.string(from: start),
                "time.end": f.string(from: now)
            ]
        )
    }

    /// Port-scoped subset of `recentEvents` for F2 port-detail (PRD CAP-2.4). Sprint 2 §F.5.b cap:
    /// 50 raw events per device → 20 events per port after filter. The raw-event ceiling protects
    /// the UI from runaway responses on busy switches.
    func eventsForPort(deviceId: String, interfaceName: String,
                       sinceHours: Int = 24,
                       rawCapPerDevice: Int = 50,
                       portCap: Int = 20) async throws -> [Event] {
        let all = try await recentEvents(hours: sinceHours)
        let deviceEvents = all
            .filter { $0.mentionsDevice(id: deviceId) }
            .prefix(rawCapPerDevice)
        return deviceEvents
            .filter { $0.mentionsInterface(deviceId: deviceId, interfaceName: interfaceName) }
            .prefix(portCap)
            .map { $0 }
    }
}
