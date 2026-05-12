import Foundation

// Codable models for arista.inventory.v1 over the REST gateway.
// Reference: cloudvision-apis/arista/inventory.v1/inventory.proto
// Reference response: cloudvision-apis/docs/content/examples/REST/inventory/index.md

struct Device: Decodable, Identifiable, Hashable {
    let key: DeviceKey
    let softwareVersion: String?
    let modelName: String?
    let hardwareRevision: String?
    let fqdn: String?
    let hostname: String?
    let domainName: String?
    let systemMacAddress: String?
    let bootTime: String?
    let streamingStatus: StreamingStatus?
    let extendedAttributes: ExtendedAttributes?

    var id: String { key.deviceId }

    var bootDate: Date? { bootTime.flatMap(ISO8601Date.parse) }

    /// Best display name preference: hostname → fqdn → deviceId.
    var displayName: String {
        if let h = hostname, !h.isEmpty { return h }
        if let f = fqdn, !f.isEmpty { return f }
        return key.deviceId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.deviceId)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.key.deviceId == rhs.key.deviceId
    }
}

struct DeviceKey: Decodable, Hashable {
    let deviceId: String
}

struct ExtendedAttributes: Decodable {
    let featureEnabled: [String: Bool]?
}

enum StreamingStatus: String, Decodable {
    case unspecified = "STREAMING_STATUS_UNSPECIFIED"
    case active = "STREAMING_STATUS_ACTIVE"
    case inactive = "STREAMING_STATUS_INACTIVE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    var isActive: Bool { self == .active }

    var label: String {
        switch self {
        case .active: return "Streaming"
        case .inactive: return "Not streaming"
        case .unspecified: return "Unknown"
        }
    }
}
