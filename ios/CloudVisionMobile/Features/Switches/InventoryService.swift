import Foundation

/// Wraps the CVaaS inventory.v1 REST endpoints.
struct InventoryService {
    let client: CVHTTPClient

    /// GET /api/resources/inventory/v1/Device/all  → array of Device (NDJSON stream).
    func devices() async throws -> [Device] {
        try await client.getAll(path: "/api/resources/inventory/v1/Device/all")
    }

    /// GET /api/resources/inventory/v1/Device?key.deviceId=<id>  → single Device.
    func device(id: String) async throws -> Device {
        let result: SingleResult<Device> = try await client.get(
            path: "/api/resources/inventory/v1/Device",
            query: ["key.deviceId": id]
        )
        return result.value
    }
}
