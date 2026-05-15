import Foundation

// MARK: - Models

/// One rate point on the chart, in bits/sec.
struct CounterPoint: Identifiable, Hashable {
    let timestamp: Date
    let bps: Double
    var id: Date { timestamp }
}

/// Result of a historical rates fetch: two parallel series plus the window covered.
struct CounterSeries {
    let rxBps: [CounterPoint]
    let txBps: [CounterPoint]
    let windowStart: Date
    let windowEnd: Date
    let asOf: Date
    /// Raw-response introspection so the empty state can explain *why* it's empty.
    /// Populated for every fetch, not only failures.
    let diagnostic: Diagnostic

    var isEmpty: Bool { rxBps.isEmpty && txBps.isEmpty }

    var peakRxBps: Double { rxBps.map(\.bps).max() ?? 0 }
    var peakTxBps: Double { txBps.map(\.bps).max() ?? 0 }

    struct ProbeRow {
        let label: String
        let count: Int
        let error: String?
        let firstKey: String?
        let firstValue: String?
    }

    struct Diagnostic {
        let probes: [ProbeRow]
        let winningLabel: String?
        let historicalCount: Int
        let historicalError: String?
    }
}

// MARK: - Service

/// Fetches per-port cumulative byte counters over a time window via `cloudvision.Connector`
/// `RouterV1.Get` against the `device` dataset, then derives RX/TX rates client-side.
///
/// Path is `["Sysdb", "interface", "counter", "eth", "phy", "intfCounterDir", <intf>]`;
/// see `NetDBPaths.interfaceCounters`. Sysdb emits one notification per state change at this
/// leaf, each carrying a partial update (some fields, not necessarily all). We carry forward
/// the last-known `inOctets` / `outOctets` across notifications so a partial update is paired
/// with the most-recent value of the other counter. Rate is `(Δoctets × 8) / Δt`.
struct InterfaceCountersService {
    let client: ConnectorClient

    /// Default chart resolution. 60 points across a 1h window ≈ 1 point/min — readable on
    /// mobile without sacrificing the shape of bursts.
    static let defaultPointCount: Int = 60

    /// Probe the Turbine analytics rate path now that we know — per the wrpc reference
    /// (user-supplied 2026-05-14) — that the dataset is `{type: "device", name: "analytics"}`,
    /// not `{type: "analytics", name: ""}` as I previously tried. The leaf values are
    /// Turbine-derived bps rates keyed by `inOctets` / `outOctets`.
    private static func candidatePaths(deviceSerial: String, interfaceName: String)
    -> [(label: String, dsType: String, dsName: String, path: [NEATPathElement])] {
        [
            ("device/analytics · /Devices/<dev>/versioned-data/.../rates",
             "device", "analytics",
             [.string("Devices"), .string(deviceSerial),
              .string("versioned-data"), .string("interfaces"),
              .string("data"), .string(interfaceName),
              .string("rates")]),
            ("counter/eth/phy/intfCounterDir/<intf> (control: should still fail)",
             "device", deviceSerial,
             [.string("Sysdb"), .string("interface"), .string("counter"),
              .string("eth"), .string("phy"),
              .string("intfCounterDir"), .string(interfaceName)]),
        ]
    }

    /// Total collection wall-time for the Subscribe-based fetch. The chart will only show
    /// data from now to (now + collectionDuration). Setting this too low yields too few
    /// samples to derive a rate; too high makes the user wait.
    static let collectionDuration: TimeInterval = 30

    /// Probe each candidate path with a single latest-state Get. If the `device/analytics`
    /// candidate returns notifications, we have a working analytics-rates source. (Subscribe
    /// support comes next once the path is confirmed.)
    func fetchHistory(
        deviceSerial: String,
        interfaceName: String,
        window: TimeInterval = 3600,
        targetPointCount: Int = defaultPointCount
    ) async throws -> CounterSeries {
        let candidates = Self.candidatePaths(deviceSerial: deviceSerial, interfaceName: interfaceName)
        let started = Date()

        let probeResults: [GetProbeResult] = await withTaskGroup(
            of: GetProbeResult.self
        ) { group in
            for c in candidates {
                group.addTask {
                    do {
                        let notifs = try await client.get(
                            datasetType: c.dsType,
                            datasetName: c.dsName,
                            path: c.path,
                            timeoutSeconds: 10
                        )
                        return GetProbeResult(label: c.label, notifications: notifs, error: nil)
                    } catch {
                        return GetProbeResult(label: c.label, notifications: [],
                                              error: String(describing: error))
                    }
                }
            }
            var out: [GetProbeResult] = []
            for await r in group { out.append(r) }
            return out.sorted { $0.label < $1.label }
        }

        let winner = probeResults.max { $0.notifications.count < $1.notifications.count }
        let diagnostic = CounterSeries.Diagnostic(
            probes: probeResults.map {
                CounterSeries.ProbeRow(
                    label: $0.label,
                    count: $0.notifications.count,
                    error: $0.error,
                    firstKey: Self.firstUpdateSample($0.notifications).0,
                    firstValue: Self.firstUpdateSample($0.notifications).1
                )
            },
            winningLabel: (winner?.notifications.isEmpty == false) ? winner?.label : nil,
            historicalCount: winner?.notifications.count ?? 0,
            historicalError: nil
        )

        // Until we confirm a working path, ship empty series; UI shows the probe diagnostic.
        return CounterSeries(
            rxBps: [],
            txBps: [],
            windowStart: started,
            windowEnd: Date(),
            asOf: Date(),
            diagnostic: diagnostic
        )
    }

    private struct GetProbeResult {
        let label: String
        let notifications: [Notification]
        let error: String?
    }

    // MARK: - (Retained for future Subscribe wiring once a path is confirmed.)
    private struct SubscribeProbeResult {
        let label: String
        let notifications: [Notification]
        let error: String?
    }

    /// Open a Subscribe on one candidate path. Collect for `duration` seconds, then close.
    /// Returns the notifications received plus any error.
    private static func subscribeProbe(
        client: ConnectorClient,
        deviceSerial: String,
        label: String,
        path: [NEATPathElement],
        duration: TimeInterval
    ) async -> SubscribeProbeResult {
        var collected: [Notification] = []
        var errorString: String?
        let stream = client.subscribe(
            datasetType: "device",
            datasetName: deviceSerial,
            path: path
        )

        // Race the stream consumer against a duration timer. Whichever completes first
        // wins; the other is cancelled.
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    for try await notif in stream {
                        collected.append(notif)
                        if Task.isCancelled { return }
                    }
                } catch {
                    errorString = String(describing: error)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            await group.next()  // wait for whichever finishes first
            group.cancelAll()
        }
        return SubscribeProbeResult(label: label, notifications: collected, error: errorString)
    }

    // MARK: - Decoding (raw cumulative samples)

    /// One sample of cumulative byte counters at a specific instant. Either side may be nil
    /// if that field wasn't present in the source notification (Sysdb partial updates).
    struct Sample: Hashable {
        let timestamp: Date
        let inOctets: UInt64?
        let outOctets: UInt64?
    }

    /// Walk notifications and extract per-timestamp (inOctets, outOctets) partial samples.
    /// Output is sorted by timestamp ascending.
    static func decodeSamples(notifications: [Notification]) -> [Sample] {
        var out: [Sample] = []
        out.reserveCapacity(notifications.count)
        for notif in notifications {
            let ts = Date(
                timeIntervalSince1970:
                    TimeInterval(notif.timestamp.seconds)
                    + TimeInterval(notif.timestamp.nanos) / 1_000_000_000
            )
            var inOctets: UInt64?
            var outOctets: UInt64?
            for update in notif.updates {
                guard let keyV = try? NEATCodec.decode(update.key),
                      case .string(let key) = keyV,
                      let valueV = try? NEATCodec.decode(update.value) else { continue }
                switch key {
                case "inOctets":  inOctets  = uint64(from: valueV) ?? inOctets
                case "outOctets": outOctets = uint64(from: valueV) ?? outOctets
                default: break
                }
            }
            if inOctets != nil || outOctets != nil {
                out.append(Sample(timestamp: ts, inOctets: inOctets, outOctets: outOctets))
            }
        }
        return out.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Rate derivation with carry-forward

    /// Compute bps between consecutive samples. A partial update inherits the carried-forward
    /// value of any field it doesn't refresh, so a notification that only contains `inOctets`
    /// still contributes a TX rate (using the last-known `outOctets`).
    /// Counter resets (negative delta) drop the point in the affected direction.
    static func deriveRates(from samples: [Sample]) -> (rx: [CounterPoint], tx: [CounterPoint]) {
        var rx: [CounterPoint] = []
        var tx: [CounterPoint] = []
        var lastIn: (ts: Date, value: UInt64)?
        var lastOut: (ts: Date, value: UInt64)?

        for sample in samples {
            if let v = sample.inOctets {
                if let prev = lastIn {
                    let dt = sample.timestamp.timeIntervalSince(prev.ts)
                    if dt > 0, v >= prev.value {
                        let bps = Double(v - prev.value) * 8.0 / dt
                        rx.append(CounterPoint(timestamp: sample.timestamp, bps: bps))
                    }
                }
                lastIn = (sample.timestamp, v)
            }
            if let v = sample.outOctets {
                if let prev = lastOut {
                    let dt = sample.timestamp.timeIntervalSince(prev.ts)
                    if dt > 0, v >= prev.value {
                        let bps = Double(v - prev.value) * 8.0 / dt
                        tx.append(CounterPoint(timestamp: sample.timestamp, bps: bps))
                    }
                }
                lastOut = (sample.timestamp, v)
            }
        }
        return (rx, tx)
    }

    private static func uint64(from v: NEATValue) -> UInt64? {
        switch v {
        case .uint(let u): return u
        case .int(let i):  return i >= 0 ? UInt64(i) : nil
        case .map:
            // Sysdb sometimes wraps numeric leaves as {value: <num>}.
            return v.asDict?["value"].flatMap(uint64(from:))
        default: return nil
        }
    }

    /// Summarize a notification list: the **union of all keys across all notifications**
    /// (so we don't miss `inOctets`/`outOctets` when they're in a notification that isn't
    /// the first), plus a sample value preferring octet-like fields if present, plus the
    /// path tail of the first notification.
    static func firstUpdateSample(_ notifs: [Notification]) -> (String?, String?, String?) {
        guard let first = notifs.first else { return (nil, nil, nil) }
        var tail: String?
        if let last = first.pathElements.last,
           case .string(let s) = (try? NEATCodec.decode(last)) ?? .nil {
            tail = s
        }
        var allKeysSet = Set<String>()
        var sampleValue: String?
        for notif in notifs {
            for update in notif.updates {
                guard let k = try? NEATCodec.decode(update.key),
                      case .string(let s) = k else { continue }
                allKeysSet.insert(s)
                if sampleValue == nil,
                   ["inOctets", "outOctets"].contains(s),
                   let v = try? NEATCodec.decode(update.value) {
                    sampleValue = "\(s)=\(renderShort(v))"
                }
            }
        }
        let allKeys = allKeysSet.isEmpty ? nil : allKeysSet.sorted().joined(separator: ", ")
        if sampleValue == nil, let firstUpdate = first.updates.first,
           let v = try? NEATCodec.decode(firstUpdate.value) {
            sampleValue = renderShort(v)
        }
        return (allKeys, sampleValue, tail)
    }

    private static func renderShort(_ v: NEATValue, depth: Int = 0) -> String {
        switch v {
        case .nil: return "nil"
        case .bool(let b): return String(b)
        case .int(let i): return String(i)
        case .uint(let u): return String(u)
        case .float(let f): return String(f)
        case .double(let d): return String(d)
        case .string(let s): return "\"\(s)\""
        case .wildcard: return "<*>"
        case .array(let arr):
            if depth > 1 { return "[…\(arr.count)…]" }
            let inner = arr.prefix(4).map { renderShort($0, depth: depth + 1) }.joined(separator: ", ")
            return "[\(inner)\(arr.count > 4 ? ", …" : "")]"
        case .map(let pairs):
            if depth > 1 { return "{…\(pairs.count)…}" }
            let inner = pairs.prefix(4).map {
                "\(renderShort($0.key, depth: depth + 1)): \(renderShort($0.value, depth: depth + 1))"
            }.joined(separator: ", ")
            return "{\(inner)\(pairs.count > 4 ? ", …" : "")}"
        case .path(let keys):
            return "Path(\(keys.map { renderShort($0, depth: depth + 1) }.joined(separator: "/")))"
        }
    }

    // MARK: - Thinning

    /// Reduce a long series to at most `maxCount` items by evenly-spaced index sampling.
    /// Preserves the first and last samples so the chart anchors to the window endpoints.
    static func thinned(_ points: [CounterPoint], maxCount: Int) -> [CounterPoint] {
        guard maxCount > 1, points.count > maxCount else { return points }
        var out: [CounterPoint] = []
        out.reserveCapacity(maxCount)
        let step = Double(points.count - 1) / Double(maxCount - 1)
        for i in 0..<maxCount {
            let idx = Int((Double(i) * step).rounded())
            out.append(points[min(idx, points.count - 1)])
        }
        return out
    }
}
