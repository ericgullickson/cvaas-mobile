import Foundation

/// High-level orchestrator for F4 diagnostic runs. Hides the strict-mode-vs-lenient flow
/// behind a single `run(...)` that yields progress updates.
///
/// Caller invokes `for await event in runner.run(...)` and receives `RunEvent` values:
/// `.submitted(ccId:)` → `.approving` → `.starting` → `.running` → `.completed(result:)`
/// or `.failed(reason:)`. The stream is cancellable via standard Task semantics.
///
/// Polling cadence: 2s while non-terminal, ceiling 60s. Polling caps protect against the
/// edge cases R12 calls out (strict-mode approval stuck pending) — the UI should surface a
/// "still waiting" hint rather than spin forever.
struct DiagnosticRunner {
    enum DiagnosticKind {
        case cableTest
        case interfaceCycleAdmin
        case interfaceCyclePoe

        var actionKey: String {
            switch self {
            case .cableTest:            return CVAction.Builtin.cableTest
            case .interfaceCycleAdmin,
                 .interfaceCyclePoe:    return CVAction.Builtin.interfaceCycle
            }
        }

        var displayName: String {
            switch self {
            case .cableTest:            return "Cable Test"
            case .interfaceCycleAdmin:  return "Interface Cycle (admin shut/no-shut)"
            case .interfaceCyclePoe:    return "Interface Cycle (PoE off/on)"
            }
        }

        /// Args specific to this diagnostic kind. DeviceID/InterfaceID are added by the runner.
        var kindSpecificArgs: [String: String] {
            switch self {
            case .cableTest:
                return [:]
            case .interfaceCycleAdmin:
                return ["AdminStateCycle": "true", "PoeCycle": "false"]
            case .interfaceCyclePoe:
                return ["AdminStateCycle": "false", "PoeCycle": "true"]
            }
        }
    }

    enum RunEvent {
        case submitted(ccId: String)
        case approving
        case starting
        case running
        case completed(ChangeControl)
        case failed(reason: String)
    }

    let service: ChangeControlService
    let kind: DiagnosticKind
    let deviceId: String
    let interfaceName: String

    /// Drives the full lifecycle. Yields progress events to the caller.
    func run() -> AsyncStream<RunEvent> {
        AsyncStream { continuation in
            let task = Task {
                let ccId = UUID().uuidString.lowercased()
                let name = "\(kind.displayName) on \(deviceId)/\(interfaceName)"
                var args: [String: String] = [
                    "DeviceID": deviceId,
                    "InterfaceID": interfaceName,
                    "FailOnErrDisabled": "false",
                    "SkipValidation": "false"
                ]
                args.merge(kind.kindSpecificArgs) { _, new in new }

                do {
                    // 1. Submit
                    let (id, version) = try await service.create(
                        ccId: ccId,
                        name: name,
                        actionKey: kind.actionKey,
                        args: args,
                        notes: "Initiated from CloudVision Mobile."
                    )
                    continuation.yield(.submitted(ccId: id))

                    // 2. Approve (strict-mode tenants require this; lenient tenants accept it
                    //    as a no-op). Try always; treat 4xx as fatal because it indicates a
                    //    real auth/permission problem worth surfacing.
                    continuation.yield(.approving)
                    try await service.approve(ccId: id, version: version)

                    // 3. Start
                    continuation.yield(.starting)
                    try await service.start(ccId: id)

                    // 4. Poll. 2s cadence, 60s ceiling. CVaaS web UI uses ~1s polling; 2s
                    //    halves cellular cost while still feeling live.
                    continuation.yield(.running)
                    let deadline = Date().addingTimeInterval(60)
                    var lastReported: String? = nil
                    var reachedTerminal = false
                    poll: while Date() < deadline {
                        if Task.isCancelled { break poll }
                        let snap = try await service.get(ccId: id)
                        if snap.isTerminal {
                            reachedTerminal = true
                            if snap.didSucceed {
                                continuation.yield(.completed(snap))
                            } else {
                                continuation.yield(.failed(
                                    reason: snap.error ?? "ChangeControl completed with unspecified error"
                                ))
                            }
                            break poll
                        }
                        // Suppress duplicate "running" yields when status didn't change.
                        if snap.status != lastReported {
                            lastReported = snap.status
                            continuation.yield(.running)
                        }
                        try? await Task.sleep(for: .seconds(2))
                    }
                    if !reachedTerminal && !Task.isCancelled {
                        // Reached deadline without terminal status — surface as failure.
                        continuation.yield(.failed(
                            reason: "Timed out waiting for ChangeControl to complete (60s). " +
                                    "Check the CVaaS web UI for the run status."
                        ))
                    }
                } catch let err as CVError {
                    continuation.yield(.failed(reason: err.localizedDescription))
                } catch {
                    continuation.yield(.failed(reason: "\(type(of: error)): \(error.localizedDescription)"))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
