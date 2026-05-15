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
    let error: String?

    var isEmpty: Bool { rxBps.isEmpty && txBps.isEmpty }

    var peakRxBps: Double { rxBps.map(\.bps).max() ?? 0 }
    var peakTxBps: Double { txBps.map(\.bps).max() ?? 0 }
}

// MARK: - Service

/// Fetches per-port throughput rates from the Turbine `analytics` dataset via
/// `RouterV1.Get`. The analytics pipeline produces pre-derived bps values at ~10s
/// granularity — no client-side delta computation needed.
///
/// Dataset: `{type: "device", name: "analytics"}`
/// Path:    `NetDBPaths.analyticsRates(deviceSerial:interfaceName:)`
/// Keys:    `inOctets` (RX bps), `outOctets` (TX bps) — float values.
///
/// Verified via Python gRPC probe against cv-prod-us-4, 2026-05-14: 362 notifications
/// over a 1h window, each containing float rate values with ~10s spacing.
struct InterfaceCountersService {
    let client: ConnectorClient

    static let defaultPointCount: Int = 60

    func fetchHistory(
        deviceSerial: String,
        interfaceName: String,
        window: TimeInterval = 3600,
        targetPointCount: Int = defaultPointCount
    ) async throws -> CounterSeries {
        let now = Date()
        let windowStart = now.addingTimeInterval(-window)
        let startNS = UInt64(windowStart.timeIntervalSince1970 * 1_000_000_000)
        let endNS = UInt64(now.timeIntervalSince1970 * 1_000_000_000)

        let path = NetDBPaths.analyticsRates(
            deviceSerial: deviceSerial,
            interfaceName: interfaceName
        )

        let notifications: [Notification]
        do {
            notifications = try await client.get(
                datasetType: "device",
                datasetName: "analytics",
                path: path,
                startNS: startNS,
                endNS: endNS,
                timeoutSeconds: 15
            )
        } catch {
            return CounterSeries(
                rxBps: [], txBps: [],
                windowStart: windowStart, windowEnd: now, asOf: now,
                error: String(describing: error)
            )
        }

        var rx: [CounterPoint] = []
        var tx: [CounterPoint] = []
        rx.reserveCapacity(notifications.count)
        tx.reserveCapacity(notifications.count)

        for notif in notifications {
            let ts = Date(
                timeIntervalSince1970:
                    TimeInterval(notif.timestamp.seconds)
                    + TimeInterval(notif.timestamp.nanos) / 1_000_000_000
            )
            for update in notif.updates {
                guard let keyV = try? NEATCodec.decode(update.key),
                      case .string(let key) = keyV,
                      let valueV = try? NEATCodec.decode(update.value),
                      let bps = Self.bpsValue(from: valueV) else { continue }
                switch key {
                case "inOctets":  rx.append(CounterPoint(timestamp: ts, bps: bps))
                case "outOctets": tx.append(CounterPoint(timestamp: ts, bps: bps))
                default: break
                }
            }
        }

        rx.sort { $0.timestamp < $1.timestamp }
        tx.sort { $0.timestamp < $1.timestamp }

        return CounterSeries(
            rxBps: Self.thinned(rx, maxCount: targetPointCount),
            txBps: Self.thinned(tx, maxCount: targetPointCount),
            windowStart: windowStart,
            windowEnd: now,
            asOf: now,
            error: nil
        )
    }

    private static func bpsValue(from v: NEATValue) -> Double? {
        switch v {
        case .float(let f): return Double(f)
        case .double(let d): return d
        case .uint(let u): return Double(u)
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    // MARK: - Thinning

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
