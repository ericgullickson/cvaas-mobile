import Foundation

/// Wraps the CVaaS endpointlocation.v1 REST endpoint:
/// `GET /api/resources/endpointlocation/v1/EndpointLocation?key.searchTerm=<value>`
struct EndpointLocationService {
    let client: CVHTTPClient

    func find(searchTerm: String) async throws -> EndpointLocationResponse {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CVError.notFound }
        return try await client.get(
            path: "/api/resources/endpointlocation/v1/EndpointLocation",
            query: ["key.searchTerm": trimmed]
        )
    }
}

/// View-friendly flattening of `EndpointLocationResponse`. The proto layout is deeply
/// nested wrappers; the row UI wants a simple `[DeviceRow]` to enumerate over.
struct LocateResults {
    struct DeviceRow: Identifiable {
        let id: String                       // map key from DeviceMap.values (serial or MAC)
        let primaryIdentifier: Identifier?
        let deviceType: DeviceType?
        let deviceStatus: DeviceStatus?
        let locations: [Location]
        let deviceName: String?              // from DeviceInfo (often nil)
    }

    let searchTerm: String
    let devices: [DeviceRow]

    init(from response: EndpointLocationResponse) {
        self.searchTerm = response.value.key.searchTerm
        let entries = response.value.deviceMap?.values ?? [:]
        self.devices = entries
            .sorted { $0.key < $1.key }
            .map { key, dev in
                DeviceRow(
                    id: key,
                    primaryIdentifier: dev.identifierList?.values?.first,
                    deviceType: dev.deviceType,
                    deviceStatus: dev.deviceStatus,
                    locations: dev.locationList?.values ?? [],
                    deviceName: dev.deviceInfo?.deviceName
                )
            }
    }
}
