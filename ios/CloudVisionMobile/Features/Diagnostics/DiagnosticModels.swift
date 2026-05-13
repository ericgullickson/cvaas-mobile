import Foundation

// Codable models for arista.action.v1 and arista.changecontrol.v1 over the REST gateway.
//
// Wire-format notes captured during F4.1 discovery (see path-discovery/F4_action_changecontrol_surface.md):
//
// 1. Response envelope is `{ "value": <T>, "time": "..." }` at the top level — NOT
//    `{ "result": { "value": <T>, ... } }` like the `/all` streams. Reuse `SingleResult<T>`.
// 2. ChangeControlConfig POST body is the raw `value` object (key + change | start | etc.),
//    NOT wrapped in `{ value: ... }`.
// 3. The pilot tenant cv-prod-us-4 is strict-mode: every ChangeControl requires an explicit
//    ApproveConfig.Set with `version` (the timestamp from `change.time` on the read-side
//    ChangeControl) before Start will succeed.

// MARK: - Common

struct ChangeControlKey: Codable {
    let id: String
}

struct FlagValue: Codable {
    let value: Bool
}

struct StringMap: Codable {
    let values: [String: String]
}

// MARK: - Action (action.v1)

/// One Action definition read from `/api/resources/action/v1/Action/all` or `?key.id=<id>`.
struct CVAction: Codable {
    let key: CVActionKey
    let core: CVActionCore?
}

struct CVActionKey: Codable {
    let id: String
}

struct CVActionCore: Codable {
    let name: String?
    let type: String?           // ACTION_TYPE_CHANGECONTROL_BUILT_IN, etc.
    let description: String?
}

extension CVAction {
    /// Stable map of well-known built-in Action keys we drive from the app.
    /// Discovery confirmed both are stock on cv-prod-us-4 (R11 resolved 2026-05-13).
    enum Builtin {
        static let cableTest = "interfaceCableTest"
        static let interfaceCycle = "interfaceCycle"
    }
}

// MARK: - ChangeControlConfig request bodies

/// Used by all three writes to `ChangeControlConfigService.Set`:
/// - create: key + change
/// - start:  key + start (value: true)
/// - cancel: key + start (value: false)  *(unused in MVP)*
struct ChangeControlConfigBody: Codable {
    let key: ChangeControlKey
    var change: ChangeConfigBody?
    var start: FlagValue?
}

struct ChangeConfigBody: Codable {
    let name: String
    let rootStageId: String
    let stages: StageConfigMapBody
    var notes: String?
}

struct StageConfigMapBody: Codable {
    let values: [String: StageConfigBody]
}

struct StageConfigBody: Codable {
    let name: String
    let action: ActionInvocationBody
}

struct ActionInvocationBody: Codable {
    /// `name` here is the Action *key* (e.g. "interfaceCableTest"), not a free-form label.
    let name: String
    let args: StringMap
}

// MARK: - ApproveConfig request body

struct ApproveConfigBody: Codable {
    let key: ChangeControlKey
    let approve: FlagValue
    /// RFC3339 timestamp (matches the read-side `ChangeControl.change.time`). Optimistic-lock
    /// token: rejected if the ChangeControl has been mutated since this version was observed.
    let version: String
}

// MARK: - ChangeControl response (read-side)

struct ChangeControl: Codable {
    let key: ChangeControlKey
    let change: Change?
    let approve: Flag?
    let start: Flag?
    let status: String?         // CHANGE_CONTROL_STATUS_*
    let error: String?
}

struct Change: Codable {
    let name: String?
    let rootStageId: String?
    let stages: StageMap?
    /// Version timestamp; required when approving. See ApproveConfigBody.version.
    let time: String?
    let user: String?
}

struct StageMap: Codable {
    let values: [String: Stage]?
}

struct Stage: Codable {
    let name: String?
    let status: String?         // STAGE_STATUS_*
    let error: String?
    let startTime: String?
    let endTime: String?
}

struct Flag: Codable {
    let value: Bool?
    let notes: String?
    let time: String?
    let user: String?
}

// MARK: - ChangeControlStatus terminal values

extension ChangeControl {
    /// True once the ChangeControl has reached a terminal status (no further transitions).
    var isTerminal: Bool {
        status == "CHANGE_CONTROL_STATUS_COMPLETED"
    }

    /// True iff terminal and `.error` is empty/nil. CVaaS doesn't expose a separate FAILED
    /// enum value — failure is COMPLETED with a non-empty error string.
    var didSucceed: Bool {
        isTerminal && (error?.isEmpty ?? true)
    }

    /// Friendly progress label for the in-flight UI. See CAP-4.5 + R12 (strict-mode
    /// approval waiting state).
    var displayProgress: String {
        switch status {
        case "CHANGE_CONTROL_STATUS_RUNNING":   return "Running"
        case "CHANGE_CONTROL_STATUS_SCHEDULED": return "Scheduled"
        case "CHANGE_CONTROL_STATUS_COMPLETED":
            return didSucceed ? "Completed" : "Failed"
        default:
            if approve?.value != true {
                return "Pending approval"
            }
            if start?.value != true {
                return "Pending start"
            }
            return "Pending"
        }
    }
}

// MARK: - Cable test result (read from NetDB via Connector)

/// Decoded view of `Sysdb/hardware/phy/cabletest/.../cableTestStatus/<intf>` content,
/// flattened from the NetDB notifications stream.
///
/// Per-interface schema confirmed live 2026-05-13 — see path-discovery doc.
struct CableTestResult: Equatable {
    let interfaceName: String
    let cableState: String?        // e.g. "cableStateOk", "cableStateFault", "cableStateUnknown"
    let lengthAccuracyMeters: Int?
    let lengthUnit: String?        // e.g. "meters"
    let diagnosticsState: String?  // e.g. "cableDiagnosticsRunStateCompleted"
    let cableTestRuns: Int?
    let pairs: [PairResult]        // 0–4 entries; usually 4

    struct PairResult: Equatable {
        let label: String          // "A" / "B" / "C" / "D"
        let pinPair: String        // "1 & 2" etc — Cat5/6 cable-pin pair convention
        let lengthMeters: Int?
        let pairState: String?     // e.g. "pairStateOk", "pairStateOpen", "pairStateShort"
    }
}

extension CableTestResult.PairResult {
    /// Map A/B/C/D to the conventional Cat5/6 pin pair the cable diag reports against.
    static let pinPairs: [String: String] = [
        "A": "1 & 2",
        "B": "3 & 6",
        "C": "4 & 5",
        "D": "7 & 8"
    ]
}
