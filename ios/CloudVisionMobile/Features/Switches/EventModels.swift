import Foundation

// Codable models for arista.event.v1 over the REST gateway.
// Reference: cloudvision-apis/arista/event.v1/event.proto
// Reference responses: cloudvision-apis/docs/content/examples/REST/events/index.md
//
// Note: In CVaaS, what the web UI calls "alerts" are Events with severity >= WARNING and
// `delete_time` unset (i.e. still firing). The alert.v1 service models alert *configuration*
// (broadcast groups, SMTP settings) — not alert instances.

struct Event: Decodable {
    let key: EventKey
    let severity: EventSeverity?
    let title: String?
    let description: String?
    let eventType: String?
    let data: EventData?
    let components: EventComponents?
    let ack: EventAck?
    let lastUpdatedTime: String?
    let deleteTime: String?
    let ruleId: String?
}

struct EventKey: Decodable {
    let key: String?
    let timestamp: String?
}

struct EventData: Decodable {
    let data: [String: String]?
}

struct EventComponents: Decodable {
    let components: [EventComponent]?
}

struct EventComponent: Decodable {
    let type: ComponentType?
    let components: [String: String]?
}

struct EventAck: Decodable {
    let ack: Bool?
    let acker: String?
    let ackTime: String?
}

enum EventSeverity: String, Decodable, Comparable {
    case unspecified = "EVENT_SEVERITY_UNSPECIFIED"
    case info = "EVENT_SEVERITY_INFO"
    case warning = "EVENT_SEVERITY_WARNING"
    case error = "EVENT_SEVERITY_ERROR"
    case critical = "EVENT_SEVERITY_CRITICAL"
    case debug = "EVENT_SEVERITY_DEBUG"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    /// Lower rank = less severe. Used for `<` comparisons.
    var orderRank: Int {
        switch self {
        case .debug: return 0
        case .unspecified: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }

    static func < (lhs: EventSeverity, rhs: EventSeverity) -> Bool {
        lhs.orderRank < rhs.orderRank
    }

    var displayName: String {
        switch self {
        case .unspecified: return "Unknown"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        case .debug: return "Debug"
        }
    }
}

enum ComponentType: String, Decodable {
    case unspecified = "COMPONENT_TYPE_UNSPECIFIED"
    case device = "COMPONENT_TYPE_DEVICE"
    case interface = "COMPONENT_TYPE_INTERFACE"
    case turbine = "COMPONENT_TYPE_TURBINE"
    case vds = "COMPONENT_TYPE_VDS"
    case vdsInterface = "COMPONENT_TYPE_VDS_INTERFACE"
    case vm = "COMPONENT_TYPE_VM"
    case vmInterface = "COMPONENT_TYPE_VM_INTERFACE"
    case workloadServer = "COMPONENT_TYPE_WORKLOAD_SERVER"
    case workloadServerInterface = "COMPONENT_TYPE_WORKLOAD_SERVER_INTERFACE"
    case application = "COMPONENT_TYPE_APPLICATION"
    case cvpNode = "COMPONENT_TYPE_CVP_NODE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }
}

extension Event {
    /// Composite identifier for SwiftUI's ForEach. EventKey alone is { key, timestamp }; combining
    /// them produces a stable id that doesn't collide across instances of the same event over time.
    var stableId: String {
        "\(key.key ?? "")_\(key.timestamp ?? "")"
    }

    /// True when the event has not been resolved (`delete_time` is unset or empty).
    var isActive: Bool {
        deleteTime == nil || deleteTime?.isEmpty == true
    }

    /// Event start time, parsed from the `key.timestamp` field.
    var startDate: Date? {
        key.timestamp.flatMap(ISO8601Date.parse)
    }

    /// True if any component or `data.deviceId` references the given device id.
    /// Used for client-side filtering because nested-component matching via partialEqFilter is
    /// awkward against the REST gateway; revisit if event volumes hurt performance.
    func mentionsDevice(id: String) -> Bool {
        if data?.data?["deviceId"] == id { return true }
        for comp in components?.components ?? [] {
            if comp.components?["deviceId"] == id { return true }
        }
        return false
    }

    /// True if the event is scoped to a specific (device, interface) pair. Interface-typed
    /// events from CVaaS surface the interface name in `data.data.interfaceId` and also under
    /// `components.components[].components.interfaceId` — empirically verified Sprint 2 §F.5.
    /// Both axes (device + interface) must match.
    func mentionsInterface(deviceId: String, interfaceName: String) -> Bool {
        guard mentionsDevice(id: deviceId) else { return false }
        if data?.data?["interfaceId"] == interfaceName { return true }
        for comp in components?.components ?? [] {
            if comp.type == .interface, comp.components?["interfaceId"] == interfaceName {
                return true
            }
        }
        return false
    }
}
