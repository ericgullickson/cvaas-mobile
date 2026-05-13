# Features/

Feature areas, one subdirectory per major feature. Each holds its own Codable models, service wrappers, and views.

## Subdirectories

| Directory | What | When to read |
|-----------|------|--------------|
| `Locate/` | F1 Endpoint Locator — find which switch/port a MAC, IP, or hostname is connected to. Surfaced under the **Tools** tab. | Modifying endpoint search, result rendering, recent searches |
| `Switches/` | F2 Switch & Port Inspector + F3 Device Health Summary + per-device event drill-down. Surfaced under the **Devices** tab. | Modifying device list, device health, port inspector, port detail, per-device events |
| `Diagnostics/` | F4 Interface Diagnostics — Cable Test + Interface Cycle. The only write surface in MVP. Wraps built-in CVaaS Actions in a ChangeControl. Reached from `Features/Switches/PortDetailView.swift` | Modifying the F4 flow, adjusting the confirmation gate, adding new diagnostic kinds |
| `Alerts/` | Org-wide active-alerts view (severity ≥ WARNING, last 24 h). Reuses `EventService.recentEvents` — no new API surface. Surfaced under the **Alerts** tab. | Modifying alerts grouping, alert-row layout, severity filters |
| `More/` | Account info, preferences, support, sign-out — the "Settings" surface. Includes an embedded `TenantSettingsView` drill-down for tenant URL + JWT entry. Surfaced under the **More** tab. | Modifying settings UI, adding preferences, changing JWT masking behavior |
