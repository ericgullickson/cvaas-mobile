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
| `SwitchesView.swift` | "Devices" tab root: searchable device list, sectioned Online/Offline, hamburger filter sheet. Polls every 10 s while visible | Modifying device list UI, changing poll cadence, adding sort/filter options |
| `DeviceHealthView.swift` | Device-detail screen: `DeviceHeroBand` (navy + HEALTHY pill + favorite star), Overview KV card, Quick Actions 2×2 grid (Ports / Alerts / Events / Open in CVaaS web), Recent Activity. Favorites persist via `FavoritesStore`. | Modifying summary UI, adding health fields, changing quick actions, adjusting hero band |
| `DeviceEventsView.swift` | Full-screen 24h event list scoped to one device. Reached from the Quick Actions grid on Device Detail | Changing per-device events layout, adjusting filters |
| `AlertsListView.swift` | Drill-down list of currently-firing events for one device (severity ≥ WARNING, `delete_time` unset). Reached from Device Detail's Quick Actions. | Changing alert-row UI, adding ack actions (Phase 2) |
| `EventRowView.swift` | One event row with severity icon, title, optional description, and relative time | Adjusting event card layout, severity icon mapping |
| `PortStateService.swift` | Fetches per-port link state via Connector. Slice `"1"` hard-coded for fixed switches. Adds natural-sort for `EthernetN` interfaces | Adding per-port attributes (PoE, errors, LLDP — Sprint 2), generalizing for modular chassis |
| `PortInspectorView.swift` | "Port Snapshot" — F2 port table with edge color strip, monospace port ID, trailing status pill (PoE watts / Link Down / Not PoE). Search + filter sheet. | Tuning row visuals, adding columns, changing filter taxonomy |
| `PortDetailView.swift` | Per-port detail: header card with status pill + edge bar, Throughput (1h) chart, Diagnostics CTA, Link / PoE / LLDP / MACs / Errors-unavailable note / 24 h events sections, all rendered as card groups | Adjusting per-port detail layout, adding fields, changing section ordering |
| `InterfaceCountersService.swift` | Time-bounded fetch of per-port bitrates from the Turbine `analytics` dataset (path `Devices/<dev>/versioned-data/interfaces/data/<intf>/rates`). Values arrive **pre-derived as bps** for `inOctets` / `outOctets` keys; no client-side rate math. Sample thinning to ~60 points per window. Verified against the CV Web UI's `cv.worker.js` 2026-05-14. | Changing time window, adjusting thinning, swapping in the aggregated (1m / 15m) variant for longer windows, adding packet/error metrics |
| `InterfaceCountersChart.swift` | Two-line Swift Charts view (RX = Brand.sky, TX = Brand.navy) with auto-scaled bps units, peak-rate legend, 1h x-axis, monospaced axis labels matching the rest of the screen | Restyling chart, adding tooltips/selection, changing color mapping or unit format |
