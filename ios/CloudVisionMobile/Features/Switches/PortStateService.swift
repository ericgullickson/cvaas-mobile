import Foundation

// MARK: - Per-column value types

/// Link state per port, extracted from `NetDBPaths.interfaceStatus()`.
struct PortLinkInfo: Hashable {
    let linkStatus: String?      // "linkUp", "linkDown", "notPresent"
    let active: Bool?
    let mtu: Int?
}

/// PoE state per port, extracted from `NetDBPaths.poePort`. Values verified Sprint 2 §1.5
/// against a 710P. All fields are optional because non-PoE ports return zeros or absent keys.
struct PortPoEState: Hashable {
    let portClass: String?          // portStatus.pdClass.Name        e.g. "class4", "classUnknown"
    let portState: String?          // portStatus.poePortState.Name   e.g. "powered"
    let priority: String?           // portPriority.Name              e.g. "low"
    let capacityWatts: Double?      // capacity.value                 (W)
    let grantedPowerWatts: Double?  // portStatus.grantedPower.value  (W)
    let outputPowerWatts: Double?   // outputPower.value              (W)
    let outputCurrentMA: Double?    // outputCurrent.value * 1000     (NetDB stores amperes)
    let outputVoltageV: Double?     // outputVoltage.value            (V)
    let temperatureC: Double?       // temperature.value              (°C, chip)
    let lldpEnabled: Bool?
}

/// LLDP neighbor per local port. Merged from multiple notification fragments — see
/// `NetDBPaths.lldpRemoteNeighbors`.
struct LLDPNeighbor: Hashable {
    let sysName: String?          // sysName.value.value           e.g. "Arista AP/Sensor C-230"
    let sysDesc: String?          // sysDesc.value.value
    let remotePortId: String?     // msap.portIdentifier.portId    e.g. "30:86:2d:42:c5:af"
    let remotePortDesc: String?   // portDesc.value.value
    let ttl: Int?                 // seconds until LLDP entry expires
}

/// Aggregate per-port state: each column is independently nullable so a partial-failure load
/// (e.g. PoE call timed out but LLDP succeeded) still renders sensible rows.
struct PortState: Identifiable, Hashable {
    let interfaceName: String
    let link: PortLinkInfo?
    let poe: PortPoEState?
    let lldp: LLDPNeighbor?
    let learnedMACs: [String]

    var id: String { interfaceName }
    var learnedMACCount: Int { learnedMACs.count }
}

// MARK: - Service

/// Fetches per-port state via `cloudvision.Connector` `RouterV1.Get`.
///
/// Each column has its own NetDB path. `fetchAllColumns(deviceSerial:)` runs them concurrently
/// and merges the results. Per-column methods are public so the port-detail screen (F.4) can
/// re-query just one column on demand, and so tests can exercise paths in isolation.
struct PortStateService {
    let client: ConnectorClient
    var slice: String = "1"  // fixed switches; modular chassis would override

    // MARK: Top-level aggregator

    /// Snapshot of all per-port columns. Caller can render rows that have *some* data even when
    /// a single column query fails — `partialErrors` lists which columns came back nil.
    struct Snapshot {
        let ports: [PortState]            // sorted naturally by interface name
        let asOf: Date
        let partialErrors: [String]       // e.g. ["lldp: timeout"]; empty on full success
    }

    func fetchAllColumns(deviceSerial: String) async throws -> Snapshot {
        async let linkTask  = wrap("link")  { try await fetchLinkState(deviceSerial: deviceSerial) }
        async let poeTask   = wrap("poe")   { try await fetchPoE(deviceSerial: deviceSerial) }
        async let lldpTask  = wrap("lldp")  { try await fetchLLDP(deviceSerial: deviceSerial) }
        async let macTask   = wrap("mac")   { try await fetchMACTable(deviceSerial: deviceSerial) }

        let (linkResult, poeResult, lldpResult, macResult) = await (linkTask, poeTask, lldpTask, macTask)

        var partialErrors: [String] = []
        let linkMap = linkResult.takeOrLog(into: &partialErrors)  ?? [:]
        let poeMap  = poeResult.takeOrLog(into: &partialErrors)   ?? [:]
        let lldpMap = lldpResult.takeOrLog(into: &partialErrors)  ?? [:]
        let macMap  = macResult.takeOrLog(into: &partialErrors)   ?? [:]

        // Union of interfaces from any successful column. If everything failed, no rows render.
        var portNames = Set<String>()
        portNames.formUnion(linkMap.keys)
        portNames.formUnion(poeMap.keys)
        portNames.formUnion(lldpMap.keys)
        portNames.formUnion(macMap.keys)

        let ports: [PortState] = portNames.map { name in
            PortState(
                interfaceName: name,
                link: linkMap[name],
                poe:  poeMap[name],
                lldp: lldpMap[name],
                learnedMACs: macMap[name] ?? []
            )
        }
        .sorted(by: Self.naturalOrder)

        return Snapshot(ports: ports, asOf: Date(), partialErrors: partialErrors)
    }

    // MARK: Per-column fetchers

    /// Link state per port. Tail of `path_elements` is the interface name.
    func fetchLinkState(deviceSerial: String) async throws -> [String: PortLinkInfo] {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.interfaceStatus(slice: slice)
        )

        var out: [String: PortLinkInfo] = [:]
        for notif in notifications {
            guard let intf = trailingName(notif: notif) else { continue }

            var linkStatus: String?
            var active: Bool?
            var mtu: Int?
            forEachUpdate(notif) { key, value in
                switch key {
                case "linkStatus": linkStatus = value.asDict?["Name"]?.stringValue
                case "active":     active = value.boolValue
                case "mtu":        mtu = value.intValue
                default: break
                }
            }
            // Merge with any prior fragment for the same port.
            let prior = out[intf]
            out[intf] = PortLinkInfo(
                linkStatus: linkStatus ?? prior?.linkStatus,
                active:     active     ?? prior?.active,
                mtu:        mtu        ?? prior?.mtu
            )
        }
        return out
    }

    /// PoE state per port. Tail is the interface name. Maps PRD fields per §1.5.
    func fetchPoE(deviceSerial: String) async throws -> [String: PortPoEState] {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.poePort
        )

        // Accumulator: collect every field across all fragments before constructing the struct.
        var acc: [String: PoEAccumulator] = [:]
        for notif in notifications {
            guard let intf = trailingName(notif: notif) else { continue }
            var a = acc[intf, default: PoEAccumulator()]
            forEachUpdate(notif) { key, value in a.absorb(key: key, value: value) }
            acc[intf] = a
        }
        return acc.mapValues { $0.frozen() }
    }

    /// LLDP neighbor per local port. Walks the deep `[..., portStatus, *, remoteSystem, *]` path
    /// and merges fragmented notifications by port. PRD targets the first neighbor only — if a
    /// port has multiple, later fragments overwrite earlier ones (good enough for MVP).
    func fetchLLDP(deviceSerial: String) async throws -> [String: LLDPNeighbor] {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.lldpRemoteNeighbors
        )

        // Path tail looks like: [..., "portStatus", "EthernetN", "remoteSystem", <int index>]
        // We want the EthernetN element — second-to-last-to-last-to-last (-3).
        var acc: [String: LLDPAccumulator] = [:]
        for notif in notifications {
            let pe = notif.pathElements
            // Expected path tail: [..., "portStatus", "EthernetN", "remoteSystem", <idx>]
            // So the local interface name is at index pe.count - 3.
            guard pe.count >= 4,
                  let intf = decodeString(pe[pe.count - 3]) else { continue }
            var a = acc[intf, default: LLDPAccumulator()]
            forEachUpdate(notif) { key, value in a.absorb(key: key, value: value) }
            acc[intf] = a
        }
        return acc.mapValues { $0.frozen() }
    }

    /// Learned MACs grouped by interface. Smash FDB returns one notification whose `updates`
    /// dict has one entry per FDB record (with complex map-keyed lookup keys).
    func fetchMACTable(deviceSerial: String) async throws -> [String: [String]] {
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: NetDBPaths.macTableFdb
        )

        var out: [String: [String]] = [:]
        for notif in notifications {
            for update in notif.updates {
                guard let key = try? NEATCodec.decode(update.key),
                      let value = try? NEATCodec.decode(update.value),
                      let intf = value.asDict?["intf"]?.stringValue,
                      let addr = key.asDict?["addr"]?.stringValue else { continue }
                out[intf, default: []].append(addr)
            }
        }
        return out
    }

    // MARK: - Helpers

    /// Decode the tail of a notification's `pathElements` as a string. Returns nil if the path
    /// has no elements or the last element doesn't decode to a string.
    private func trailingName(notif: Notification) -> String? {
        guard let last = notif.pathElements.last else { return nil }
        return decodeString(last)
    }

    private func decodeString(_ data: Data) -> String? {
        guard let v = try? NEATCodec.decode(data), case .string(let s) = v else { return nil }
        return s
    }

    /// Iterate decoded (key, value) pairs of a notification's updates.
    private func forEachUpdate(_ notif: Notification, body: (String, NEATValue) -> Void) {
        for update in notif.updates {
            guard let keyV = try? NEATCodec.decode(update.key),
                  case .string(let key) = keyV,
                  let valueV = try? NEATCodec.decode(update.value) else { continue }
            body(key, valueV)
        }
    }

    /// Wrap an async throwing call into a Result-like enum so the aggregator can collect errors
    /// without aborting.
    private enum ColumnResult<V> {
        case success(V)
        case failure(String)

        func takeOrLog(into errors: inout [String]) -> V? {
            switch self {
            case .success(let v): return v
            case .failure(let msg): errors.append(msg); return nil
            }
        }
    }

    private func wrap<V>(_ label: String, _ op: () async throws -> V) async -> ColumnResult<V> {
        do {
            return .success(try await op())
        } catch {
            return .failure("\(label): \(error.localizedDescription)")
        }
    }

    // MARK: - Sort

    private static func naturalOrder(_ a: PortState, _ b: PortState) -> Bool {
        let (aP, aN) = splitTrailingInt(a.interfaceName)
        let (bP, bN) = splitTrailingInt(b.interfaceName)
        if aP == bP { return (aN ?? .max) < (bN ?? .max) }
        return a.interfaceName < b.interfaceName
    }

    private static func splitTrailingInt(_ s: String) -> (String, Int?) {
        var digits = ""
        for c in s.reversed() {
            if c.isNumber { digits.insert(c, at: digits.startIndex) }
            else { break }
        }
        let num = digits.isEmpty ? nil : Int(digits)
        let prefix = String(s.dropLast(digits.count))
        return (prefix, num)
    }
}

// MARK: - Field accumulators (handle fragmentation + nested extraction)

/// Collects PoE fields across notification fragments for one port, then freezes into PortPoEState.
private struct PoEAccumulator {
    var portClass: String?
    var portState: String?
    var priority: String?
    var capacityWatts: Double?
    var grantedPowerWatts: Double?
    var outputPowerWatts: Double?
    var outputCurrentMA: Double?
    var outputVoltageV: Double?
    var temperatureC: Double?
    var lldpEnabled: Bool?

    mutating func absorb(key: String, value: NEATValue) {
        switch key {
        case "portStatus":
            // Nested: pdClass.Name, poePortState.Name, grantedPower.value
            let d = value.asDict
            portClass = d?["pdClass"]?.asDict?["Name"]?.stringValue ?? portClass
            portState = d?["poePortState"]?.asDict?["Name"]?.stringValue ?? portState
            grantedPowerWatts = d?["grantedPower"]?.asDict?["value"]?.doubleValue ?? grantedPowerWatts
        case "portPriority":
            priority = value.asDict?["Name"]?.stringValue ?? priority
        case "capacity":
            capacityWatts = value.asDict?["value"]?.doubleValue ?? capacityWatts
        case "outputPower":
            outputPowerWatts = value.asDict?["value"]?.doubleValue ?? outputPowerWatts
        case "outputCurrent":
            if let amps = value.asDict?["value"]?.doubleValue {
                outputCurrentMA = amps * 1000  // NetDB stores amperes; PRD names in mA
            }
        case "outputVoltage":
            outputVoltageV = value.asDict?["value"]?.doubleValue ?? outputVoltageV
        case "temperature":
            temperatureC = value.asDict?["value"]?.doubleValue ?? temperatureC
        case "lldpEnabled":
            lldpEnabled = value.boolValue ?? lldpEnabled
        default: break
        }
    }

    func frozen() -> PortPoEState {
        PortPoEState(
            portClass: portClass,
            portState: portState,
            priority: priority,
            capacityWatts: capacityWatts,
            grantedPowerWatts: grantedPowerWatts,
            outputPowerWatts: outputPowerWatts,
            outputCurrentMA: outputCurrentMA,
            outputVoltageV: outputVoltageV,
            temperatureC: temperatureC,
            lldpEnabled: lldpEnabled
        )
    }
}

/// Collects LLDP neighbor fields across fragments for one local port.
private struct LLDPAccumulator {
    var sysName: String?
    var sysDesc: String?
    var remotePortId: String?
    var remotePortDesc: String?
    var ttl: Int?

    mutating func absorb(key: String, value: NEATValue) {
        switch key {
        case "sysName":
            // {"isSet": true, "value": {"value": "<string>"}, "valueStr": {"value": "<string>"}}
            sysName = value.asDict?["valueStr"]?.asDict?["value"]?.stringValue
                   ?? value.asDict?["value"]?.asDict?["value"]?.stringValue
                   ?? sysName
        case "sysDesc":
            sysDesc = value.asDict?["value"]?.asDict?["value"]?.stringValue ?? sysDesc
        case "portDesc":
            remotePortDesc = value.asDict?["value"]?.asDict?["value"]?.stringValue ?? remotePortDesc
        case "msap":
            remotePortId = value.asDict?["portIdentifier"]?.asDict?["portId"]?.stringValue ?? remotePortId
        case "ttl":
            ttl = value.intValue ?? ttl
        default: break
        }
    }

    func frozen() -> LLDPNeighbor {
        LLDPNeighbor(sysName: sysName, sysDesc: sysDesc,
                     remotePortId: remotePortId, remotePortDesc: remotePortDesc, ttl: ttl)
    }
}

// MARK: - Small NEATValue conveniences not in NEATCodec.swift

private extension NEATValue {
    /// Double value if `.double`, `.float`, `.int`, or `.uint`. Handles the `{value: <num>}`
    /// pattern at the leaf — see PoE `capacity`, `outputPower`, etc.
    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .float(let f): return Double(f)
        case .int(let i): return Double(i)
        case .uint(let u): return Double(u)
        default: return nil
        }
    }
}
