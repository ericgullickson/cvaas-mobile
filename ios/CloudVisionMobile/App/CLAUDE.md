# App/

## Files

| File | What | When to read |
|------|------|--------------|
| `CloudVisionMobileApp.swift` | `@main` app entry; constructs `AuthStore`, calls `Appearance.apply()` for global UIKit chrome, shows `SplashView` as the first scene | Changing app entry, root state injection, scene-phase handling |
| `RootView.swift` | Custom 4-tab shell (Devices / Alerts / Search / More) and the `CustomTabBar` component. iOS 26's floating glass tab bar cannot be solid-tinted via standard appearance APIs, so we render our own navy bar. | Changing tab order, adding/removing tabs, modifying top-level navigation, debugging tab bar appearance |
| `SplashView.swift` | Brand splash with `ARISTA` wordmark; transitions to `RootView` after ~700 ms. Sits on top of the system `LaunchBackground` color asset for a seamless system-launch → SwiftUI handoff | Adjusting splash duration, animation timing, replacing wordmark |
| `Theme.swift` | Brand palette (Color/UIColor), typography (`TypeScale`), and `Appearance.apply()` — global `UINavigationBarAppearance` (and best-effort `UITabBarAppearance`). The tab bar is largely rendered by `CustomTabBar`. | Adding new colors/fonts, changing nav bar chrome, debugging color tokens |
| `ConfigureCTA.swift` | Shared "configure in Settings" empty state used by feature tabs when `auth.isConfigured == false` | Modifying the not-configured empty state, adding new auth-gated feature tabs |
