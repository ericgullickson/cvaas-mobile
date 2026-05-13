import Foundation

/// UserDefaults-backed set of device IDs the user has starred. Local-only — no PRD scope for
/// syncing favorites to the tenant. Cheap polish that survives app relaunch.
final class FavoritesStore {
    private static let key = "favorite-device-ids"

    static let shared = FavoritesStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func contains(_ deviceId: String) -> Bool {
        ids().contains(deviceId)
    }

    func toggle(_ deviceId: String) {
        var current = ids()
        if current.contains(deviceId) {
            current.remove(deviceId)
        } else {
            current.insert(deviceId)
        }
        defaults.set(Array(current), forKey: Self.key)
    }

    func all() -> Set<String> { ids() }

    private func ids() -> Set<String> {
        let raw = defaults.array(forKey: Self.key) as? [String] ?? []
        return Set(raw)
    }
}
