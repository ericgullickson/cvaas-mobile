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

## F4.1.c — NetDB path for Cable Test results (PENDING)

Owed: enumerate the NetDB path under `["Sysdb", "interface", ...]` (or similar) that holds the per-pair Cable Test result after a run. Strategy mirrors Sprint 2 §1.5: walk the Sysdb tree on a device that has run the test at least once, looking for `cableDiag` / `cableTest` / `tdr` patterns.

Constraint: this test device's `interfaceCableTest` has never been run (CVaaS web modal shows "Not Started"). To enumerate the path with populated data, we either need to (a) run the test once on a less-critical port, or (b) probe the tree by name for empty paths.

Next session.
