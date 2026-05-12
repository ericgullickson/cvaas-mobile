# App/

## Files

| File | What | When to read |
|------|------|--------------|
| `CloudVisionMobileApp.swift` | `@main` app entry; constructs `AuthStore` and injects it as `EnvironmentObject` | Changing app entry, root state injection, scene-phase handling |
| `RootView.swift` | `TabView` wiring Locate / Switches / Settings tabs | Changing tab order, adding tabs, modifying top-level navigation |
| `ConfigureCTA.swift` | Shared "configure in Settings" empty state used by feature tabs when `auth.isConfigured == false` | Modifying the not-configured empty state, adding new auth-gated feature tabs |
