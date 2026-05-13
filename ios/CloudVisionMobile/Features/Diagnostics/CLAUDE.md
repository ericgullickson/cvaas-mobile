# Diagnostics/

F4 Interface Diagnostics. The only write surface in the MVP (PRD §5d). Wraps two built-in
CVaaS Actions in a ChangeControl envelope and renders the result.

## Architecture

Submit-then-poll over REST/JSON gateway. Strict-mode tenants (like `cv-prod-us-4`) require
explicit ApproveConfig before Start succeeds — see `path-discovery/F4_action_changecontrol_surface.md`
for the discovery findings driving this design.

Flow: create envelope → read-back for version timestamp → approve → start → poll until
terminal → (cable test only) fetch result from NetDB via `cloudvision.Connector`.

## Files

| File | What | When to read |
|------|------|--------------|
| `DiagnosticModels.swift` | All Codable types: `CVAction`, `ChangeControlConfigBody`, `ApproveConfigBody`, `ChangeControl` (read-side), `CableTestResult`. Action keys (`interfaceCableTest`, `interfaceCycle`) and the `ChangeControl.isTerminal` / `displayProgress` computed properties | Adding new diagnostic types, adapting to API schema changes |
| `ActionService.swift` | Read-only client for `action.v1/Action/all`. Used by tenant-prereq check (R11 defense-in-depth) | Disabling F4 when stock Actions are unavailable on a tenant |
| `ChangeControlService.swift` | The four-verb client: `create`, `approve`, `start`, `get`. Covers both strict-mode and lenient-mode flows | Modifying the submit/start sequence, debugging 4xx responses |
| `DiagnosticRunner.swift` | Async-stream orchestrator. Exposes `RunEvent` (submitted → approving → starting → running → completed/failed). 2s poll cadence, 60s ceiling | Changing the runtime flow, adjusting poll cadence, debugging timeouts |
| `CableTestResultService.swift` | Reads `Sysdb/hardware/phy/cabletest/.../cableTestStatus/<intf>` over Connector. Slice defaults to `"FixedSystem"` for fixed switches | Adapting to modular chassis (different slice token), adding result fields |
| `DiagnosticsLauncherView.swift` | Sheet root with state machine: launcher → confirm → in-flight → completed/failed. Routes user choice into `DiagnosticRunner.DiagnosticKind`. Owns `DiagnosticTelemetry` for confirmation cancel/commit hooks | Adding new diagnostic kinds, changing launcher layout |
| `DiagnosticConfirmationView.swift` | R10 gate. Full-screen confirmation with orange disruption banner, action summary, audit-log notice. Confirm-button red, deliberately not adjacent to the trigger | Tuning the confirmation UX, A/B-testing gate layouts |
| `DiagnosticInFlightView.swift` | Vertical stepper showing run progression (Submitted → Approved → Started → Running → Completed). Drives `DiagnosticRunner` over an AsyncStream | Adjusting stepper visuals, surfacing strict-mode "Pending Approval" hint |
| `DiagnosticResultView.swift` | Terminal-state view. Cable Test: whole-cable status + per-pair table (length, OK/Open/Short). Interface Cycle: outcome + disruption duration. Both: audit summary with cc_id + initiator + approver. `DiagnosticFailedView` is the failure variant | Adjusting result density, adding new result fields |
