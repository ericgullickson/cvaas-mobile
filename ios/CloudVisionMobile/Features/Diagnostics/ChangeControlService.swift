import Foundation

/// Client for `arista.changecontrol.v1.ChangeControlConfigService` and
/// `arista.changecontrol.v1.ApproveConfigService` via the REST/JSON gateway.
///
/// Flow (strict-mode, per F4.1 discovery on cv-prod-us-4):
///   1. `create(...)` posts the ChangeControl envelope with one stage. Returns the version
///      timestamp captured from the immediate read-back.
///   2. `approve(ccId:, version:)` posts ApproveConfig (required on strict-mode tenants).
///   3. `start(ccId:)` posts the start flag on ChangeControlConfig.
///   4. `get(ccId:)` polls the read-side until `.isTerminal`.
///
/// Lenient-mode tenants can skip step 2; the service exposes both verbs so callers can
/// branch on a 400 response from start.
struct ChangeControlService {
    let client: CVHTTPClient

    private static let ccConfigPath = "/api/resources/changecontrol/v1/ChangeControlConfig"
    private static let approveConfigPath = "/api/resources/changecontrol/v1/ApproveConfig"
    private static let ccReadPath = "/api/resources/changecontrol/v1/ChangeControl"

    /// Submit a new ChangeControl with one Action stage. Returns (cc_id, version_timestamp).
    /// The version timestamp is needed for the subsequent ApproveConfig call on strict-mode
    /// tenants.
    func create(
        ccId: String,
        name: String,
        actionKey: String,
        args: [String: String],
        notes: String? = nil
    ) async throws -> (id: String, version: String) {
        let body = ChangeControlConfigBody(
            key: ChangeControlKey(id: ccId),
            change: ChangeConfigBody(
                name: name,
                rootStageId: "s1",
                stages: StageConfigMapBody(values: [
                    "s1": StageConfigBody(
                        name: name,
                        action: ActionInvocationBody(
                            name: actionKey,
                            args: StringMap(values: args)
                        )
                    )
                ]),
                notes: notes
            ),
            start: nil
        )

        let _: SingleResult<ChangeControlConfigBody> = try await client.post(
            path: Self.ccConfigPath,
            body: body
        )

        // Read back to capture the version timestamp (= change.time on the read side).
        let read = try await get(ccId: ccId)
        guard let version = read.change?.time else {
            throw CVError.service(
                statusCode: 0,
                message: "ChangeControl created but version timestamp missing on read-back"
            )
        }
        return (ccId, version)
    }

    /// Approve the ChangeControl. Required on strict-mode tenants; failing softly on
    /// lenient-mode tenants is acceptable because the subsequent start succeeds anyway.
    func approve(ccId: String, version: String) async throws {
        let body = ApproveConfigBody(
            key: ChangeControlKey(id: ccId),
            approve: FlagValue(value: true),
            version: version
        )
        let _: SingleResult<ApproveConfigBody> = try await client.post(
            path: Self.approveConfigPath,
            body: body
        )
    }

    /// Flip the start flag to begin execution. CVaaS rejects this with HTTP 400
    /// ("cannot be started without approval") if the tenant is strict-mode and approval
    /// hasn't happened — surface to UI as "needs approval".
    func start(ccId: String) async throws {
        let body = ChangeControlConfigBody(
            key: ChangeControlKey(id: ccId),
            change: nil,
            start: FlagValue(value: true)
        )
        let _: SingleResult<ChangeControlConfigBody> = try await client.post(
            path: Self.ccConfigPath,
            body: body
        )
    }

    /// Read the live state of a ChangeControl. Suitable for polling.
    func get(ccId: String) async throws -> ChangeControl {
        let envelope: SingleResult<ChangeControl> = try await client.get(
            path: Self.ccReadPath,
            query: ["key.id": ccId]
        )
        return envelope.value
    }
}
