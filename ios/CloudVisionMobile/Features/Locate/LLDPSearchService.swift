import Foundation

/// LLDP-based endpoint search via `cloudvision.Connector`.
///
/// **Why this exists**: `endpointlocation.v1` indexes endpoints only by MAC and IP — the
/// AP's LLDP-advertised `sysName` ("Arista AP/Sensor C-230") never appears in its endpoint
/// record. The CVaaS web UI's endpoint-overview page joins LLDP data with the FDB MAC
/// index via an internal API that isn't exposed in the public proto repo. To recover
/// substring hostname search from mobile, we walk LLDP tables on each known switch and
/// match the search term against `sysName` and `sysDesc`.
///
/// Cost: one Connector Get per device. ~100-500ms each. For pilot-scale tenants (<20
/// devices) this is fine. For larger tenants the search would need debouncing or a
/// per-device cache.
struct LLDPSearchService {
    let client: ConnectorClient

    struct Hit: Identifiable, Hashable {
        let id: String           // synthetic — `<deviceId>|<localInterface>|<remoteIndex>`
        let deviceId: String
        let localInterface: String
        let sysName: String
        let sysDesc: String?
        let remotePortId: String?
    }

    /// Search LLDP neighbors across `devices` for `term`. Case-insensitive substring match
    /// against `sysName` and `sysDesc`. Returns up to `limit` hits, deduplicated by id.
    func search(
        term: String,
        across devices: [String],
        limit: Int = 50
    ) async -> [Hit] {
        let needle = term.lowercased()
        guard !needle.isEmpty else { return [] }

        // Fan out — one Connector Get per device, in parallel.
        return await withTaskGroup(of: [Hit].self) { group in
            for deviceSerial in devices {
                group.addTask {
                    do { return try await fetchHits(deviceSerial: deviceSerial, needle: needle) }
                    catch { return [] }   // per-device failures are silent; partial > nothing
                }
            }
            var combined: [Hit] = []
            for await hits in group {
                combined.append(contentsOf: hits)
                if combined.count >= limit { break }
            }
            return Array(combined.prefix(limit))
        }
    }

    // MARK: - Per-device fetch

    private func fetchHits(deviceSerial: String, needle: String) async throws -> [Hit] {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.lldpRemoteNeighbors
        )

        // Path tail: [..., "portStatus", "<localInterface>", "remoteSystem", <remoteIndex>]
        // Multiple notifications can carry disjoint fields for the same (port, index) — merge
        // by tail key.
        var acc: [String: (localIntf: String, remoteIndex: String, sysName: String?, sysDesc: String?, remotePortId: String?)] = [:]
        for notif in notifications {
            let pe = notif.pathElements
            guard pe.count >= 4,
                  let localIntf = decodeString(pe[pe.count - 3]),
                  let remoteIndex = decodeString(pe[pe.count - 1]) ?? decodeIntString(pe[pe.count - 1]) else { continue }
            let key = "\(deviceSerial)|\(localIntf)|\(remoteIndex)"
            var entry = acc[key, default: (localIntf, remoteIndex, nil, nil, nil)]
            for update in notif.updates {
                guard let keyV = try? NEATCodec.decode(update.key),
                      case .string(let k) = keyV,
                      let valueV = try? NEATCodec.decode(update.value) else { continue }
                switch k {
                case "sysName":
                    entry.sysName = valueV.asDict?["value"]?.asDict?["value"]?.stringValue ?? entry.sysName
                case "sysDesc":
                    entry.sysDesc = valueV.asDict?["value"]?.asDict?["value"]?.stringValue ?? entry.sysDesc
                case "msap":
                    entry.remotePortId = valueV.asDict?["portIdentifier"]?.asDict?["portId"]?.stringValue ?? entry.remotePortId
                default: break
                }
            }
            acc[key] = entry
        }

        var hits: [Hit] = []
        for (key, entry) in acc {
            // Match against sysName + sysDesc, case-insensitive.
            let hay = "\(entry.sysName ?? "") \(entry.sysDesc ?? "")".lowercased()
            guard hay.contains(needle), let name = entry.sysName, !name.isEmpty else { continue }
            hits.append(Hit(
                id: key,
                deviceId: deviceSerial,
                localInterface: entry.localIntf,
                sysName: name,
                sysDesc: entry.sysDesc,
                remotePortId: entry.remotePortId
            ))
        }
        return hits
    }

    // MARK: - NEAT decode helpers (mirror PortStateService patterns)

    private func decodeString(_ data: Data) -> String? {
        guard let v = try? NEATCodec.decode(data), case .string(let s) = v else { return nil }
        return s
    }

    private func decodeIntString(_ data: Data) -> String? {
        guard let v = try? NEATCodec.decode(data) else { return nil }
        switch v {
        case .int(let i):  return String(i)
        case .uint(let u): return String(u)
        default: return nil
        }
    }
}
