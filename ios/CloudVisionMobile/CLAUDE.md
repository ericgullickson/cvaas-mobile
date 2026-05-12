# CloudVisionMobile/

Swift source tree for the iOS app. Sprint 1 close: F1 (Endpoint Locator) + F3 (Device Health Summary) over CVaaS REST resource APIs; F2 first-light (Switch & Port Inspector) via `cloudvision.Connector` gRPC + NEAT codec.

## Subdirectories

| Directory | What | When to read |
|-----------|------|--------------|
| `App/` | App entry point, root TabView, shared UI primitives | Modifying app shell, tab structure, app-wide state injection |
| `Auth/` | `AuthStore` (`ObservableObject`), Keychain wrapper, Settings screen | Changing auth model, modifying tenant/JWT storage, debugging sign-in/out |
| `Common/` | Cross-feature utilities — ISO 8601 date parsing, recent-searches store | Adding cross-feature helpers, fixing date parsing |
| `Networking/` | `URLSession` client for CVaaS REST resource APIs (used by F1 and F3) | Adding new REST endpoints, changing error handling, debugging request/response decoding |
| `Connector/` | `cloudvision.Connector` gRPC client + NEAT wire codec (used by F2) | Modifying F2 architecture, adding NetDB path queries, debugging gRPC issues |
| `Features/` | Feature views grouped by feature area | Adding a feature, modifying screen flow within a feature |
