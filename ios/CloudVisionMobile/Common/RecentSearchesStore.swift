import Foundation

/// UserDefaults-backed list of recent search terms for the Locate feature.
/// Capped at `Self.maxItems` entries, most-recent-first.
struct RecentSearchesStore {
    static let maxItems = 10
    private let key = "locate.recents.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func save(_ items: [String]) {
        defaults.set(Array(items.prefix(Self.maxItems)), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
