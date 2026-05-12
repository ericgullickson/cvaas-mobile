# Common/

Cross-feature utilities. Anything that lives here must be used by 2+ features.

## Files

| File | What | When to read |
|------|------|--------------|
| `ISO8601Date.swift` | Permissive ISO 8601 parser; handles nanosecond-precision timestamps from CVaaS that `ISO8601DateFormatter.withFractionalSeconds` cannot parse natively | Parsing any CVaaS timestamp field, debugging date rendering |
| `RecentSearchesStore.swift` | UserDefaults-backed list of recent search terms for F1, capped at `maxItems` | Modifying recent-search persistence, changing the cap, clearing recents on sign-out |
