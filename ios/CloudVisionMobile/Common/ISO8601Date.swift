import Foundation

/// Permissive ISO 8601 parser. CVaaS responses sometimes include nanosecond-precision
/// timestamps (e.g. "2022-08-12T22:32:20.785182952Z") which `ISO8601DateFormatter` with
/// `.withFractionalSeconds` cannot parse (it tops out at millisecond precision).
enum ISO8601Date {
    static func parse(_ s: String) -> Date? {
        if let d = fracFormatter.date(from: s) { return d }
        if let d = basicFormatter.date(from: s) { return d }

        // Fall back: truncate fractional seconds beyond 3 digits and retry.
        guard let dotIdx = s.firstIndex(of: ".") else { return nil }
        let afterDot = s.index(after: dotIdx)
        let zoneIdx = s[afterDot...].firstIndex { !$0.isNumber } ?? s.endIndex
        let pre = s[..<afterDot]
        let frac = s[afterDot..<zoneIdx].prefix(3)
        let post = s[zoneIdx...]
        return fracFormatter.date(from: String(pre) + String(frac) + String(post))
    }

    private static let fracFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let basicFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
