import Foundation

/// CVaaS resource APIs return two envelope shapes:
///
/// Single-key GET (e.g. `/Device?key.deviceId=X`):
///   `{ "value": <T>, "time": "..." }`
///
/// `/all` streaming GET / POST (NDJSON, one row per line):
///   `{ "result": { "value": <T>, "time": "...", "type": "INITIAL" } }`
///
/// These wrappers let callers decode either shape generically.

struct SingleResult<T: Decodable>: Decodable {
    let value: T
    let time: String?
}

struct StreamRowEnvelope<T: Decodable>: Decodable {
    let result: StreamRow<T>
}

struct StreamRow<T: Decodable>: Decodable {
    let value: T
    let time: String?
    let type: String?
}
