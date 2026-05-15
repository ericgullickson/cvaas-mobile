import SwiftUI

/// Debug screen for verifying the Connector gRPC pipeline (D.4 first-light).
///
/// Issues `RouterV1.Get` against `cv` / `["DatasetInfo", "Devices"]` — a system-level path
/// from cloudvision-python's `get_endpoints_ext.py` that doesn't require a specific device.
/// If at least one notification comes back and NEAT decodes the first update, all of the
/// architecture pieces work end-to-end: gRPC channel, TLS, JWT auth, NEAT codec.
///
/// Once D.4 passes, this view stays as a debug entry point; D.5+ will hit per-device paths.
struct ConnectorTestView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var state: TestState = .idle
    @State private var query: TestQuery = .interfaceStatus
    @State private var deviceSerial: String = "WTW25120369"
    @State private var interfaceName: String = "Ethernet14"
    @State private var timeBounded: Bool = false

    enum TestQuery: String, CaseIterable, Identifiable {
        case datasetInfo = "cv  ·  DatasetInfo/Devices"
        case interfaceStatus = "device  ·  Sysdb/.../intfStatus/*"
        case interfaceCounters = "device  ·  Sysdb/.../intfCounterDir/<intf>"
        var id: Self { self }
    }

    enum TestState {
        case idle
        case running
        case success(SuccessSummary)
        case failure(String)
    }

    struct SuccessSummary {
        let elapsedSeconds: Double
        let notificationCount: Int
        let totalUpdates: Int
        let sampleKey: String?
        let sampleValue: String?
    }

    var body: some View {
        Form {
            Section("Target") {
                LabeledContent("Tenant") { Text(auth.tenantURL).lineLimit(1).truncationMode(.head) }
                LabeledContent("Service") { Text("RouterV1.Get").font(.body.monospaced()) }
                Picker("Query", selection: $query) {
                    ForEach(TestQuery.allCases) { q in
                        Text(q.rawValue).font(.caption.monospaced()).tag(q)
                    }
                }
                if query == .interfaceStatus || query == .interfaceCounters {
                    TextField("Device serial", text: $deviceSerial)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if query == .interfaceCounters {
                    TextField("Interface", text: $interfaceName)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Time-bounded (last 60 s)", isOn: $timeBounded)
                }
            }

            Section {
                Button {
                    Task { await runTest() }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run RouterV1.Get")
                    }
                }
                .disabled(!auth.isConfigured || isRunning || needsDeviceSerialEmpty)
            }

            resultSection
        }
        .navigationTitle("Connector test")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var resultSection: some View {
        switch state {
        case .idle:
            EmptyView()
        case .running:
            Section {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        case .success(let s):
            Section("Result") {
                LabeledContent("Elapsed", value: String(format: "%.2f s", s.elapsedSeconds))
                LabeledContent("Notifications", value: "\(s.notificationCount)")
                LabeledContent("Updates", value: "\(s.totalUpdates)")
                if let k = s.sampleKey {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("First update key").font(.caption).foregroundStyle(.secondary)
                        Text(k).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if let v = s.sampleValue {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("First update value").font(.caption).foregroundStyle(.secondary)
                        Text(v).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
        case .failure(let msg):
            Section("Error") {
                Text(msg).font(.caption.monospaced()).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private var needsDeviceSerialEmpty: Bool {
        switch query {
        case .datasetInfo: return false
        case .interfaceStatus, .interfaceCounters: return deviceSerial.isEmpty
        }
    }

    private func runTest() async {
        guard let url = URL(string: auth.tenantURL) else {
            state = .failure("Invalid tenant URL")
            return
        }
        state = .running

        let started = Date()
        do {
            let client = try ConnectorClient(tenantURL: url, jwt: auth.jwt)
            let notifications: [Notification]
            switch query {
            case .datasetInfo:
                notifications = try await client.get(
                    datasetType: "cv",
                    datasetName: "",
                    path: [.string("DatasetInfo"), .string("Devices")]
                )
            case .interfaceStatus:
                // Verified-working path from cloudvision-python's get_intf_status.py.
                // Slice "1" is the right value for fixed (non-modular) switches.
                notifications = try await client.get(
                    datasetType: "device",
                    datasetName: deviceSerial,
                    path: [
                        .string("Sysdb"), .string("interface"), .string("status"),
                        .string("eth"), .string("phy"), .string("slice"), .string("1"),
                        .string("intfStatus"), .wildcard
                    ]
                )
            case .interfaceCounters:
                let (startNS, endNS): (UInt64?, UInt64?) = {
                    guard timeBounded else { return (nil, nil) }
                    let now = Date().timeIntervalSince1970
                    return (UInt64((now - 60) * 1_000_000_000),
                            UInt64(now * 1_000_000_000))
                }()
                notifications = try await client.get(
                    datasetType: "device",
                    datasetName: deviceSerial,
                    path: NetDBPaths.interfaceCounters(interfaceName: interfaceName),
                    startNS: startNS,
                    endNS: endNS
                )
            }
            await client.shutdown()

            let totalUpdates = notifications.reduce(0) { $0 + $1.updates.count }
            var sampleKey: String?
            var sampleValue: String?
            if let firstUpdate = notifications.lazy.flatMap({ $0.updates }).first {
                if let k = try? NEATCodec.decode(firstUpdate.key) {
                    sampleKey = prettyPrint(k)
                }
                if let v = try? NEATCodec.decode(firstUpdate.value) {
                    sampleValue = prettyPrint(v)
                }
            }

            state = .success(.init(
                elapsedSeconds: Date().timeIntervalSince(started),
                notificationCount: notifications.count,
                totalUpdates: totalUpdates,
                sampleKey: sampleKey,
                sampleValue: sampleValue
            ))
        } catch {
            state = .failure("\(type(of: error)): \(error.localizedDescription)")
        }
    }

    /// Compact textual rendering of a NEATValue for debug display.
    private func prettyPrint(_ value: NEATValue, depth: Int = 0) -> String {
        switch value {
        case .nil: return "nil"
        case .bool(let b): return String(b)
        case .int(let i): return String(i)
        case .uint(let u): return String(u)
        case .float(let f): return String(f)
        case .double(let d): return String(d)
        case .string(let s): return "\"\(s)\""
        case .wildcard: return "<wildcard>"
        case .array(let arr):
            let inner = arr.prefix(8).map { prettyPrint($0, depth: depth + 1) }.joined(separator: ", ")
            let suffix = arr.count > 8 ? ", …(+\(arr.count - 8))" : ""
            return "[\(inner)\(suffix)]"
        case .path(let keys):
            return "Path(\(keys.map { prettyPrint($0) }.joined(separator: "/")))"
        case .map(let pairs):
            let inner = pairs.prefix(8).map { p in
                "\(prettyPrint(p.key, depth: depth + 1)): \(prettyPrint(p.value, depth: depth + 1))"
            }.joined(separator: ", ")
            let suffix = pairs.count > 8 ? ", …(+\(pairs.count - 8))" : ""
            return "{\(inner)\(suffix)}"
        }
    }
}
