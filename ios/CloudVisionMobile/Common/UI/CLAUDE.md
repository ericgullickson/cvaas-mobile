# Common/UI/

Reusable SwiftUI components shared across feature tabs. Each component is a single source of
truth for its visual pattern — adding a new HEALTHY pill should NOT introduce a new local
implementation; it should use `StatusPill`.

## Files

| File | What | When to read |
|------|------|--------------|
| `StatusPill.swift` | Unified status pill — HEALTHY, PoE 30W, Link Down, Not PoE, etc. Three intents (success/warning/danger/neutral/info), filled or outlined styles, regular or small sizes. Status semantics use iOS system semantic colors per PRD §9.2 | Adding new status labels, tuning pill density |
| `DeviceHeroBand.swift` | Navy hero band for device detail: switch icon, hostname, model+address subtitle, HEALTHY/UNHEALTHY pill, favorite-star toggle | Adjusting hero density, adding hero actions |
| `SkeletonRow.swift` | Shimmer placeholder row used during list loads. Mirrors `PortRow` shape (4 pt leading bar + two text rectangles + pill) | Tweaking shimmer animation, adding row variants |
| `EmptyStateView.swift` | Custom empty/error state — soft circular icon + title + message + optional action button. Replaces `ContentUnavailableView` where brand styling is preferred | Adding new empty states, adjusting iconography |
| `SectionLabel.swift` | Small-caps brand-graphite section header ("OVERVIEW", "QUICK ACTIONS", etc.) for card-grouped layouts | Adjusting section header style |
