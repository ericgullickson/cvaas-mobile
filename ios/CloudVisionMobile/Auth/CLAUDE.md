# Auth/

Service-account JWT auth (MVP path). Production end-state is OAuth/OIDC per PRD §7 R2 — gated on internal Arista productization (R4).

## Files

| File | What | When to read |
|------|------|--------------|
| `AuthStore.swift` | `@MainActor` `ObservableObject` exposing `tenantURL`, `jwt`, `isConfigured` | Wiring auth into views, changing what counts as "configured", adding auth-derived state |
| `KeychainStore.swift` | Thin wrapper around `SecItem*` for read/write/delete of generic-password items | Changing storage backend, debugging Keychain access errors |

The settings UI itself lives under `Features/More/MoreView.swift`, which contains an embedded `TenantSettingsView` drill-down for tenant URL + JWT entry.
