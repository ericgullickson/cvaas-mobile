# Switches/

F2 Switch & Port Inspector (first-light) + F3 Device Health Summary. F3 uses REST resource APIs (`inventory.v1`, `event.v1`); F2 uses `cloudvision.Connector` via `../../Connector/`.

In CVaaS, what users call "alerts" are `event.v1` events with severity ≥ WARNING — **not** `alert.v1` (which models alert *configuration* such as broadcast groups and SMTP endpoints). PRD §5c.v reflects this.

## Files

| File | What | When to read |
|------|------|--------------|
| `InventoryModels.swift` | Codable `Device` model (note: NOT the F1 `EndpointRecord`) + `StreamingStatus`. Matches `arista.inventory.v1` | Adapting to inventory schema changes, adding device fields |
| `InventoryService.swift` | `devices()` (NDJSON `/all`), `device(id:)` (single key lookup) | Changing inventory queries, adding `partialEqFilter` filters |
| `EventModels.swift` | Codable `Event`, `EventSeverity` (Comparable), `ComponentType`. Includes `mentionsDevice(id:)` helper used for client-side device filtering | Adding event fields, changing severity mapping, modifying client-side filter logic |
| `EventService.swift` | `recentEvents(hours:)` over `event.v1` time-range GET. Tenant-wide fetch; filtered to device client-side | Changing time window, switching to server-side device filter via `partialEqFilter`, debugging event volumes |
| `SwitchesView.swift` | Tab root: searchable device list. Polls every 10 s while visible | Modifying device list UI, changing poll cadence, adding sort/filter options |
| `DeviceHealthView.swift` | F3 health summary: serial, model, EOS, MAC, uptime, alert count, recent events. Navigates to Ports and Alerts | Modifying summary UI, adding health fields, changing what counts as an active alert |
| `AlertsListView.swift` | Drill-down list of currently-firing events (severity ≥ WARNING, `delete_time` unset) | Changing alert list UI, adding ack actions (Sprint 2+) |
| `EventRowView.swift` | One event row with severity icon, title, optional description, and relative time | Adjusting event card layout, severity icon mapping |
| `PortStateService.swift` | Fetches per-port link state via Connector. Slice `"1"` hard-coded for fixed switches. Adds natural-sort for `EthernetN` interfaces | Adding per-port attributes (PoE, errors, LLDP — Sprint 2), generalizing for modular chassis |
| `PortInspectorView.swift` | F2 first-light port table — interface name + link-state dot + status label | Expanding to full F2 (PoE column, errors, LLDP, MAC table), adding pull-to-refresh polish |
