import Foundation

/// Client for `arista.action.v1.ActionService` — list and lookup of Action definitions.
///
/// In MVP F4 the only consumer is the tenant-prerequisite check: confirm that the well-known
/// built-in Action keys (`interfaceCableTest`, `interfaceCycle`) exist on this tenant before
/// surfacing the F4 entry point on PortDetail. This protects against tenants on older CVaaS
/// releases or tenants with these Actions disabled — CAP-4.6 / R11 defense-in-depth.
struct ActionService {
    let client: CVHTTPClient

    private static let listPath = "/api/resources/action/v1/Action/all"

    /// Returns the keys of all Actions defined on this tenant. Used to check whether
    /// `interfaceCableTest` / `interfaceCycle` are present.
    func availableActionKeys() async throws -> Set<String> {
        let actions: [CVAction] = try await client.getAll(path: Self.listPath)
        return Set(actions.map { $0.key.id })
    }

    /// Convenience: are both F4 diagnostic Actions installed on this tenant?
    func diagnosticActionsAvailable() async throws -> Bool {
        let keys = try await availableActionKeys()
        return keys.contains(CVAction.Builtin.cableTest)
            && keys.contains(CVAction.Builtin.interfaceCycle)
    }
}
