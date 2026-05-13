import Foundation

/// Reads cable-test results from NetDB via `cloudvision.Connector`. Used by F4.5 to render
/// per-pair results after `interfaceCableTest` completes.
///
/// Two Get calls are required:
///   1. Top-level path → produces fields like `cableStatus`, `lengthAccuracy`, `diagnosticsStatus`.
///   2. One-level-deeper enum → produces the four pair records (`pairAStatus` etc.).
///
/// Combined into a single `CableTestResult`. Returns `nil` if no data exists at the path
/// (the interface has never been cable-tested — empty state).
struct CableTestResultService {
    let client: ConnectorClient

    /// Slice token. Discovery showed fixed switches like the CCS-710P-16P use `"FixedSystem"`
    /// for the cabletest tree's slice key — different from the link-state tree's `"1"`.
    let slice: String

    init(client: ConnectorClient, slice: String = "FixedSystem") {
        self.client = client
        self.slice = slice
    }

    func fetch(deviceSerial: String, interfaceName: String) async throws -> CableTestResult? {
        async let topTask = fetchTopLevel(deviceSerial: deviceSerial, interfaceName: interfaceName)
        async let pairTask = fetchPairs(deviceSerial: deviceSerial, interfaceName: interfaceName)
        let (top, pairs) = try await (topTask, pairTask)

        // Empty state: neither call produced any data → port has never been cable-tested.
        if top == nil && pairs.isEmpty {
            return nil
        }

        return CableTestResult(
            interfaceName: interfaceName,
            cableState: top?.cableState,
            lengthAccuracyMeters: top?.lengthAccuracyMeters,
            lengthUnit: top?.lengthUnit,
            diagnosticsState: top?.diagnosticsState,
            cableTestRuns: top?.cableTestRuns,
            pairs: pairs
        )
    }

    // MARK: - Top-level fetch

    private struct TopLevel {
        var cableState: String?
        var lengthAccuracyMeters: Int?
        var lengthUnit: String?
        var diagnosticsState: String?
        var cableTestRuns: Int?
    }

    private func fetchTopLevel(deviceSerial: String, interfaceName: String) async throws -> TopLevel? {
        let path = NetDBPaths.cableTestResult(slice: slice, interfaceName: interfaceName)
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: path
        )
        guard !notifications.isEmpty else { return nil }

        var acc = TopLevel()
        for notif in notifications {
            forEachUpdate(notif) { key, value in
                switch key {
                case "cableStatus":
                    acc.cableState = value.asDict?["cableState"]?.asDict?["Name"]?.stringValue
                case "lengthAccuracy":
                    acc.lengthAccuracyMeters = value.intValue
                case "lengthUnit":
                    acc.lengthUnit = value.asDict?["Name"]?.stringValue
                case "diagnosticsStatus":
                    if let d = value.asDict {
                        acc.diagnosticsState = d["diagnosticsState"]?.asDict?["Name"]?.stringValue
                        acc.cableTestRuns = d["cableTestRuns"]?.intValue
                    }
                default: break
                }
            }
        }
        return acc
    }

    // MARK: - Pair fetch

    private func fetchPairs(deviceSerial: String, interfaceName: String) async throws -> [CableTestResult.PairResult] {
        let path = NetDBPaths.cableTestPairResults(slice: slice, interfaceName: interfaceName)
        let notifications = try await client.get(
            datasetType: "device",
            datasetName: deviceSerial,
            path: path
        )
        guard !notifications.isEmpty else { return [] }

        // Accumulate by pair record name (e.g. "pairAStatus"). Multiple notifications can share
        // the same pair record with disjoint fields — merge.
        var acc: [String: (length: Int?, state: String?)] = [:]
        for notif in notifications {
            guard let last = notif.pathElements.last,
                  let pairRecord = decodeString(last) else { continue }
            var entry = acc[pairRecord, default: (nil, nil)]
            forEachUpdate(notif) { key, value in
                switch key {
                case "pairLength":
                    entry.length = value.intValue ?? entry.length
                case "pairState":
                    entry.state = value.asDict?["Name"]?.stringValue ?? entry.state
                default: break
                }
            }
            acc[pairRecord] = entry
        }

        // Map pair-record names ("pairAStatus" -> "A") in canonical A/B/C/D order.
        let canonicalOrder = ["A", "B", "C", "D"]
        return canonicalOrder.compactMap { label in
            let recordName = "pair\(label)Status"
            guard let entry = acc[recordName] else { return nil }
            let pinPair = CableTestResult.PairResult.pinPairs[label] ?? "?"
            return CableTestResult.PairResult(
                label: label,
                pinPair: pinPair,
                lengthMeters: entry.length,
                pairState: entry.state
            )
        }
    }

    // MARK: - Helpers (mirror PortStateService patterns)

    private func forEachUpdate(_ notif: Notification, body: (String, NEATValue) -> Void) {
        for update in notif.updates {
            guard let keyV = try? NEATCodec.decode(update.key),
                  case .string(let key) = keyV,
                  let valueV = try? NEATCodec.decode(update.value) else { continue }
            body(key, valueV)
        }
    }

    private func decodeString(_ data: Data) -> String? {
        guard let v = try? NEATCodec.decode(data), case .string(let s) = v else { return nil }
        return s
    }
}
