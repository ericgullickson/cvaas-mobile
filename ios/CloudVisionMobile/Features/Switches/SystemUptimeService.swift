import Foundation

/// Reads the device's true boot time from `Sysdb/cell/1/sys/reload/cause.timestamp`
/// via `cloudvision.Connector`. Used to populate the Uptime row on Device Detail.
///
/// **Why not `inventory.v1.Device.boot_time`?** That field is documented but universally
/// returns epoch 0 (1970-01-01) on every CVaaS tenant we've tested. The actual telemetry
/// stream that backs the CVaaS web UI's uptime display is the per-device Sysdb path used
/// here. Verified live 2026-05-13 against `WTW25120383`.
struct SystemUptimeService {
    let client: ConnectorClient

    /// Returns the device's most recent reload time (= system boot), or nil if the path
    /// reports no data on this device.
    func bootDate(deviceSerial: String) async throws -> Date? {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.systemReloadCause
        )
        for notif in notifications {
            for update in notif.updates {
                guard let keyV = try? NEATCodec.decode(update.key),
                      case .string("timestamp") = keyV,
                      let valueV = try? NEATCodec.decode(update.value) else { continue }
                if let seconds = Self.epochSeconds(valueV) {
                    return Date(timeIntervalSince1970: seconds)
                }
            }
        }
        return nil
    }

    /// NEAT may encode the epoch-seconds timestamp as float, double, or int depending on
    /// the value. Accept all numeric forms.
    private static func epochSeconds(_ v: NEATValue) -> TimeInterval? {
        switch v {
        case .double(let d): return d
        case .float(let f): return Double(f)
        case .int(let i): return Double(i)
        case .uint(let u): return Double(u)
        default: return nil
        }
    }
}
