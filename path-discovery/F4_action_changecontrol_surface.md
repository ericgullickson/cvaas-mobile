# F4 Sprint 3 — discovery findings

## F4.1.a — action.v1 + changecontrol.v1 surface walk

Both services are exposed via the CVaaS REST/JSON gateway. Same auth model as F1/F3 (Bearer JWT). No new gRPC surface — F4 stays on `CVHTTPClient`.

### REST endpoints (relevant subset)

```
# Action definitions (read what's available, read-only)
GET  /api/resources/action/v1/Action/all                         # list all Actions, NDJSON stream
GET  /api/resources/action/v1/Action?key.id=<actionId>           # one Action

# ChangeControl config (envelope create + start, write)
POST /api/resources/changecontrol/v1/ChangeControlConfig         # Set (create or update)

# ChangeControl state (poll, read-only)
GET  /api/resources/changecontrol/v1/ChangeControl?key.id=<ccId> # one ChangeControl, has .status

# Approve (write — strict-mode tenants)
POST /api/resources/changecontrol/v1/ApproveConfig               # Set approval
```

### Submit-then-poll flow

The CVaaS web UI "Run Diagnostic" path follows this sequence; mobile will mirror it.

1. **Create the ChangeControl envelope** (`POST /api/resources/changecontrol/v1/ChangeControlConfig`):

   ```json
   {
     "key": { "id": "<uuid we generate>" },
     "change": {
       "name": "Cable Test on Ethernet14 (CVaaS Mobile)",
       "root_stage_id": "s1",
       "stages": {
         "values": {
           "s1": {
             "name": "Cable Test",
             "action": {
               "name": "interfaceCableTest",
               "args": {
                 "DeviceID": "<serial>",
                 "InterfaceID": "<intf-name>",
                 "FailOnErrDisabled": "false",
                 "SkipValidation": "false"
               }
             }
           }
         }
       }
     }
   }
   ```

   Note: `action.name` is the Action *key*, not the human-readable label. Cable Test = `interfaceCableTest`. Interface Cycle = `interfaceCycle`.

2. **(Strict-mode tenants only)** Approve the ChangeControl (`POST /api/resources/changecontrol/v1/ApproveConfig`):

   ```json
   { "key": { "enforcement": "...", "id": "<ccId>" }, "approve": { "value": true } }
   ```

   Lenient tenants skip this step. R12 covers the UX for the strict-mode case (display "Waiting for ChangeControl approval" rather than spinning silently).

3. **Start** the ChangeControl (a second `Set` on `ChangeControlConfig`):

   ```json
   { "key": { "id": "<ccId>" }, "start": { "value": true } }
   ```

4. **Poll** state (`GET /api/resources/changecontrol/v1/ChangeControl?key.id=<ccId>`) until terminal.

### Terminal status values (`ChangeControlStatus`)

| Value | Meaning |
|---|---|
| `CHANGE_CONTROL_STATUS_UNSPECIFIED` | unknown |
| `CHANGE_CONTROL_STATUS_SCHEDULED` | scheduled for future execution |
| `CHANGE_CONTROL_STATUS_RUNNING` | mid-execution |
| `CHANGE_CONTROL_STATUS_COMPLETED` | done (success XOR failure — read `.error` to disambiguate) |

`COMPLETED + error == ""` = success. `COMPLETED + error != ""` = failure. No separate FAILED enum value.

### Polling cadence

CVaaS web UI polls every ~1s during RUNNING. For mobile we'll use 2s to halve cellular cost. Cap at 60s total wait (well above the 10s disruption window).

---

## F4.1.b — tenant prerequisite check (R11 RESOLVED FAVORABLY)

**Result: Cable Test and Interface Cycle are stock built-in CVaaS Actions. No customer Studio package install required.**

Tenant probe (read-only) on `cv-prod-us-4`:

```
GET /api/resources/action/v1/Action/all
```

Returns 19 BUILT_IN Actions + 4 Studio-autofill/build-hook entries. The relevant pair:

| Action key | Display name | Type | Args |
|---|---|---|---|
| `interfaceCableTest` | Interface Cable Test | `ACTION_TYPE_CHANGECONTROL_BUILT_IN` | `DeviceID`, `InterfaceID`, `FailOnErrDisabled`, `SkipValidation` |
| `interfaceCycle` | Interface Cycle | `ACTION_TYPE_CHANGECONTROL_BUILT_IN` | `DeviceID`, `InterfaceID`, **`AdminStateCycle`**, **`PoeCycle`**, `FailOnErrDisabled`, `SkipValidation` |

### How the modal's two "Interface Cycle" methods map onto a single Action

The CVaaS web UI presents Interface Cycle as two methods (Administratively / PoE cycle). They are **one Action with two boolean flags**:

| UI method | `AdminStateCycle` | `PoeCycle` |
|---|---|---|
| Administratively | `"true"` | `"false"` |
| Power over Ethernet cycle | `"false"` | `"true"` |

(Args are typed `MapStringString` — values are passed as `"true"`/`"false"` strings, not booleans.)

### Tangentially useful other BUILT_IN Actions

(Out of F4 scope but recorded — Phase-2 candidates the mobile architecture would now trivially support):

`ping`, `traceroute`, `reboot`, `setImage`, `snapshot`, `setConfig`, `cleanFlash`, `enterZTP`, `exitZTP`, `deviceShowCmd`, `mlaghealthcheck`, `enterbgpmaintmode`, `exitbgpmaintmode`, `task`, `downloadFile`, `virtualTopoPing`, `virtualTopoTraceroute`.

### Impact on PRD §7 R11

R11 status: **discovery completed favorably — both Actions are stock.** The R11 mitigation ("publish a Studio package, gate F4 UI with tenant-prereq empty state") is now lower-priority but should still be implemented as a defense-in-depth: a future tenant that has somehow disabled these Actions, or a tenant on an older CVaaS release before these Actions were added, would still surface an empty state rather than a broken Run.

---

## F4.1.c — NetDB path for Cable Test results (RESOLVED)

A controlled `interfaceCableTest` was submitted via ChangeControl against `WTW25120383 / Ethernet14` on 2026-05-13 (user-authorized). Two unexpected findings surfaced during execution; both are load-bearing for the Swift client design.

### Finding 1 — tenant is strict-mode (R12 confirmed)

The first start attempt failed with HTTP 400 `Change Control cannot be started without approval`. The pilot tenant `cv-prod-us-4` is in strict ChangeControl mode. The full flow on this tenant is **create → read-back-to-get-version → approve → start → poll**, not the create/start/poll path the proto implies for permissive tenants.

`ApproveConfig` requires a `version` timestamp (read from the ChangeControl back-fetch) as an optimistic-lock token. The `version` field maps to `change.time` on the read-side `ChangeControl` message.

Swift client implication: `ChangeControlService` must support both flows. The MVP assumption that "submit then poll" is two API calls is wrong on this tenant — it's four. R12 mitigation needs to account for `Pending Approval` as a real state to surface.

### Finding 2 — REST response shape is `{"value": {...}, "time": "..."}`, not `{"result": {"value": {...}}}`

Both `Set` and `GetOne` responses on `ChangeControlConfigService` use a top-level `value` field, not `result.value`. The `Stream` endpoints (`/all`) wrap differently. This bit the first poll attempt (60s polling with status always "(unknown)" because the lookup path was wrong); fixed mid-probe.

### NetDB result path

Schema (verified live, populated data on Ethernet14):

```
Sysdb / hardware / phy / cabletest / status / slice / <slice> /
        PhyIsland-<slice> / cableTestStatus / <interface>
```

Where:
- `<slice>` = `FixedSystem` on fixed-config switches like the CCS-710P-16P. **NOT `"1"`** — different from the link-state path which uses numeric slice `"1"`. May differ on modular chassis.
- `<interface>` = EOS interface name (e.g. `Ethernet14`).

**Top-level fields at `cableTestStatus/<interface>`:**

| Field | Type | Notes |
|---|---|---|
| `name` / `intfId` | str | Both equal the interface name. Redundant. |
| `lengthUnit` | `{Name: "meters", Value: 1}` | Enum-style |
| `lengthAccuracy` | int | `±N` meters for all pair lengths (was `10` on test run) |
| `pairAStatus` / `pairBStatus` / `pairCStatus` / `pairDStatus` | Path pointers | Drill into one level deeper for per-pair data |
| `cableStatus` | dict | `{cableState: {Name: "cableStateOk", Value: 1}, stateChanges, stateLastChange}` — whole-cable summary |
| `diagnosticsStatus` | dict | `{changes, lastChange, cableTestRuns, diagnosticsState: {Name: "cableDiagnosticsRunStateCompleted", Value: 2}}` — run history meta |

**Per-pair fields** (drill one level via `pairAStatus/.../pairAStatus`):

| Field | Type | Notes |
|---|---|---|
| `pairLength` | int | Meters. Was `0` on our test (short patch cable on a working link). |
| `pairLengthChanges` | int | Counter |
| `pairLengthLastChange` | float | Epoch seconds |
| `pairState` | `{Name: "pairStateOk", Value: 1}` | Other observed/expected values: `pairStateOpen`, `pairStateShort`, etc. |
| `pairStateChanges` | int | |
| `pairStateLastChange` | float | |

**Speed display** ("5 Gbps" in the CVaaS web modal) does **not** come from the cabletest tree — it's the live `intfStatus` `speed` field, already in scope from F2.

### Implications for F4 Swift client

1. `NetDBPaths.swift` gets a new entry: `cableTestResult(slice: String, interfaceName: String)` returning the full path array.
2. The slice token is platform-dependent; on fixed-config switches it's `FixedSystem`. Code must accept any slice token (don't hardcode `"1"` or `"FixedSystem"`).
3. Per-pair status enum values worth knowing in advance for the Swift model: `pairStateOk`, `pairStateOpen`, `pairStateShort`, plus `pairStateUnknown` for ports that have never been tested.
4. Whole-cable enum values: `cableStateOk`, plus likely `cableStateFault`, `cableStateUnknown`.
5. Mid-run displays — before terminal — likely show `diagnosticsState: cableDiagnosticsRunStateInProgress`. UI should distinguish "in progress" from "completed" using this.

### What about Interface Cycle results?

Interface Cycle (admin shut/no-shut or PoE off/on) doesn't have a dedicated result tree. The user-visible "operational-state timeline" in the CVaaS web modal is constructed by reading the **existing** F2 link-state path (`Sysdb/interface/status/eth/phy/slice/1/intfStatus/<intf>`) and PoE path before/during/after the run and plotting transitions. No new NetDB path needed — F4 Swift client reuses what F2 already wires.

### Discovery summary

| | Result |
|---|---|
| Cable Test stock Action? | ✅ Yes (`interfaceCableTest`, BUILT_IN) |
| Interface Cycle stock Action? | ✅ Yes (`interfaceCycle`, BUILT_IN) |
| Tenant strict-mode? | ✅ Yes — approve step required |
| NetDB result path for Cable Test? | ✅ `Sysdb/hardware/phy/cabletest/status/slice/<slice>/PhyIsland-<slice>/cableTestStatus/<intf>` |
| NetDB result path for Interface Cycle? | N/A — reuse F2 link-state + PoE paths over the cycle window |
| Cable-test silicon limitation? | The 710P returned all `0m ±10m` for pair lengths on a working short cable. Real fault detection requires a longer cable and/or faulty pairs to confirm meaningful output. Document the "results may show 0m on short healthy cables" caveat in the pilot user guide. |
