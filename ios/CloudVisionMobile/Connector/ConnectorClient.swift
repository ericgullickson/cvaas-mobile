import Foundation
import GRPC
import NIO
import SwiftProtobuf

/// Process-wide singletons for the Connector gRPC runtime. The EventLoopGroup is shared
/// across all ConnectorClient instances and lives for the app's lifetime — creating a fresh
/// group per client would leak threads if shutdown is missed.
enum ConnectorRuntime {
    static let eventLoopGroup: MultiThreadedEventLoopGroup = {
        MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }()
}

/// Wraps `RouterV1` (cloudvision.Connector) over an authenticated gRPC channel. Sends the
/// service-account JWT as the `authorization: Bearer <jwt>` metadata on every RPC.
///
/// Lifecycle: construct, issue calls, then call `shutdown()` to release the channel. The
/// shared `ConnectorRuntime.eventLoopGroup` is not closed — it lives for the app.
final class ConnectorClient {
    private let channel: GRPCChannel
    private let routerClient: RouterV1AsyncClient
    private let jwt: String

    init(tenantURL: URL, jwt: String) throws {
        guard let host = tenantURL.host else { throw CVError.invalidURL }
        let port = tenantURL.port ?? 443
        self.jwt = jwt

        let tls = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL()
        self.channel = try GRPCChannelPool.with(
            target: .host(host, port: port),
            transportSecurity: .tls(tls),
            eventLoopGroup: ConnectorRuntime.eventLoopGroup
        )
        self.routerClient = RouterV1AsyncClient(channel: channel)
    }

    /// Issue a one-shot Get against the RouterV1 service for a single dataset + path.
    /// Drains the server stream to completion and returns the flat list of Notifications.
    ///
    /// Examples (from cloudvision-python):
    ///   - System-level device inventory:
    ///       datasetType: "cv", datasetName: "", path: ["DatasetInfo", "Devices"]
    ///   - Per-device interface status:
    ///       datasetType: "device", datasetName: <serial>,
    ///       path: ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "intfStatus", .wildcard]
    func get(
        datasetType: String,
        datasetName: String,
        path: [NEATPathElement],
        timeoutSeconds: Int = 15
    ) async throws -> [Notification] {
        var ds = Dataset()
        ds.type = datasetType
        ds.name = datasetName

        var p = Path()
        p.pathElements = path.map { NEATCodec.encode(pathElement: $0) }

        var query = Query()
        query.dataset = ds
        query.paths = [p]

        var request = GetRequest()
        request.query = [query]

        var options = CallOptions()
        options.customMetadata.add(name: "authorization", value: "Bearer \(jwt)")
        options.timeLimit = .timeout(.seconds(Int64(timeoutSeconds)))

        var notifications: [Notification] = []
        for try await batch in routerClient.get(request, callOptions: options) {
            notifications.append(contentsOf: batch.notifications)
        }
        return notifications
    }

    /// Best-effort channel close. Safe to call multiple times.
    func shutdown() async {
        _ = try? await channel.close().get()
    }
}
