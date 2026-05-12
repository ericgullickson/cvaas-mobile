import Foundation

// Codable models for arista.endpointlocation.v1 over the REST gateway.
// JSON layout matches the proto with camelCase field names per gRPC-gateway convention.
// Reference: cloudvision-apis/arista/endpointlocation.v1/endpointlocation.proto
// Reference response: cloudvision-apis/docs/content/examples/REST/endpointlocation/index.md

struct EndpointLocationResponse: Decodable {
    let value: EndpointLocation
    let time: String?
}

struct EndpointLocation: Decodable {
    let key: EndpointLocationKey
    let deviceMap: DeviceMap?
}

struct EndpointLocationKey: Decodable {
    let searchTerm: String
}

struct DeviceMap: Decodable {
    let values: [String: EndpointRecord]?
}

/// `arista.endpointlocation.v1.Device` — a discovered endpoint (workstation, AP, etc.) or
/// an inventory device that matched the search term. Named `EndpointRecord` here to avoid
/// collision with `inventory.v1`'s managed-device `Device` type (used by F3).
struct EndpointRecord: Decodable {
    let identifierList: IdentifierList?
    let deviceType: DeviceType?
    let locationList: LocationList?
    let deviceStatus: DeviceStatus?
    let deviceInfo: DeviceInfo?
}

struct LocationList: Decodable {
    let values: [Location]?
}

struct Location: Decodable {
    let deviceId: String?
    let deviceStatus: DeviceStatus?
    let interface: String?
    let vlanId: Int?
    let learnedTime: String?
    let macType: MacType?
    let likelihood: Likelihood?
    let explanationList: ExplanationList?
    let identifierList: IdentifierList?
}

struct IdentifierList: Decodable {
    let values: [Identifier]?
}

struct Identifier: Decodable {
    let type: IdentifierType?
    let value: String?
    let sourceList: IdentifierSourceList?
}

struct IdentifierSourceList: Decodable {
    let values: [IdentifierSource]?
}

struct ExplanationList: Decodable {
    let values: [Explanation]?
}

struct DeviceInfo: Decodable {
    let deviceName: String?
    let mobile: Bool?
    let tablet: Bool?
    let score: Int?
    let version: String?
    let macVendor: String?
    let classification: String?
    let hierarchy: [String]?
}

// MARK: - Enums
//
// Each enum has a tolerant init(from:) so unknown values from CVaaS (added in future
// API versions) fall back to `.unspecified` rather than crashing the app.

enum DeviceType: String, Decodable {
    case unspecified = "DEVICE_TYPE_UNSPECIFIED"
    case inventory = "DEVICE_TYPE_INVENTORY"
    case endpoint = "DEVICE_TYPE_ENDPOINT"
    case wifiEndpoint = "DEVICE_TYPE_WIFI_ENDPOINT"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }
}

enum DeviceStatus: String, Decodable {
    case unspecified = "DEVICE_STATUS_UNSPECIFIED"
    case active = "DEVICE_STATUS_ACTIVE"
    case inactive = "DEVICE_STATUS_INACTIVE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }
}

enum Likelihood: String, Decodable {
    case unspecified = "LIKELIHOOD_UNSPECIFIED"
    case veryLikely = "LIKELIHOOD_VERY_LIKELY"
    case likely = "LIKELIHOOD_LIKELY"
    case somewhatLikely = "LIKELIHOOD_SOMEWHAT_LIKELY"
    case lessLikely = "LIKELIHOOD_LESS_LIKELY"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    var displayName: String {
        switch self {
        case .unspecified: return "Unknown"
        case .veryLikely: return "Very likely"
        case .likely: return "Likely"
        case .somewhatLikely: return "Somewhat likely"
        case .lessLikely: return "Less likely"
        }
    }
}

enum IdentifierType: String, Decodable {
    case unspecified = "IDENTIFIER_TYPE_UNSPECIFIED"
    case macAddr = "IDENTIFIER_TYPE_MAC_ADDR"
    case ipv4Addr = "IDENTIFIER_TYPE_IPV4_ADDR"
    case ipv6Addr = "IDENTIFIER_TYPE_IPV6_ADDR"
    case inventoryDeviceID = "IDENTIFIER_TYPE_INVENTORY_DEVICE_ID"
    case primaryManagementIP = "IDENTIFIER_TYPE_PRIMARY_MANAGEMENT_IP"
    case hostname = "IDENTIFIER_TYPE_HOSTNAME"
    case other = "IDENTIFIER_TYPE_OTHER"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }
}

enum IdentifierSource: String, Decodable {
    case unspecified = "IDENTIFIER_SOURCE_UNSPECIFIED"
    case fdb = "IDENTIFIER_SOURCE_FDB"
    case arp = "IDENTIFIER_SOURCE_ARP"
    case neighbor = "IDENTIFIER_SOURCE_NEIGHBOR"
    case deviceInventory = "IDENTIFIER_SOURCE_DEVICE_INVENTORY"
    case lldp = "IDENTIFIER_SOURCE_LLDP"
    case dhcp = "IDENTIFIER_SOURCE_DHCP"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    var shortLabel: String {
        switch self {
        case .unspecified: return "?"
        case .fdb: return "FDB"
        case .arp: return "ARP"
        case .neighbor: return "NDP"
        case .deviceInventory: return "Inventory"
        case .lldp: return "LLDP"
        case .dhcp: return "DHCP"
        }
    }
}

enum MacType: String, Decodable {
    case unspecified = "MAC_TYPE_UNSPECIFIED"
    case learnedDynamic = "MAC_TYPE_LEARNED_DYNAMIC"
    case learnedSecure = "MAC_TYPE_LEARNED_SECURE"
    case configuredDynamic = "MAC_TYPE_CONFIGURED_DYNAMIC"
    case configuredSecure = "MAC_TYPE_CONFIGURED_SECURE"
    case configuredStatic = "MAC_TYPE_CONFIGURED_STATIC"
    case peerDynamic = "MAC_TYPE_PEER_DYNAMIC"
    case peerStatic = "MAC_TYPE_PEER_STATIC"
    case peerSecure = "MAC_TYPE_PEER_SECURE"
    case learnedRemote = "MAC_TYPE_LEARNED_REMOTE"
    case configuredRemote = "MAC_TYPE_CONFIGURED_REMOTE"
    case receivedRemote = "MAC_TYPE_RECEIVED_REMOTE"
    case peerLearnedRemote = "MAC_TYPE_PEER_LEARNED_REMOTE"
    case peerConfiguredRemote = "MAC_TYPE_PEER_CONFIGURED_REMOTE"
    case peerReceivedRemote = "MAC_TYPE_PEER_RECEIVED_REMOTE"
    case evpnDynamicRemote = "MAC_TYPE_EVPN_DYNAMIC_REMOTE"
    case evpnConfiguredRemote = "MAC_TYPE_EVPN_CONFIGURED_REMOTE"
    case peerEvpnRemote = "MAC_TYPE_PEER_EVPN_REMOTE"
    case configuredRouter = "MAC_TYPE_CONFIGURED_ROUTER"
    case peerRouter = "MAC_TYPE_PEER_ROUTER"
    case evpnIntfDynamic = "MAC_TYPE_EVPN_INTF_DYNAMIC"
    case evpnIntfStatic = "MAC_TYPE_EVPN_INTF_STATIC"
    case authenticated = "MAC_TYPE_AUTHENTICATED"
    case peerAuthenticated = "MAC_TYPE_PEER_AUTHENTICATED"
    case pendingSecure = "MAC_TYPE_PENDING_SECURE"
    case softwareLearnedDynamic = "MAC_TYPE_SOFTWARE_LEARNED_DYNAMIC"
    case programmedStatic = "MAC_TYPE_PROGRAMMED_STATIC"
    case evpnVespaDynamic = "MAC_TYPE_EVPN_VESPA_DYNAMIC"
    case evpnIntfDynamicFrr = "MAC_TYPE_EVPN_INTF_DYNAMIC_FRR"
    case evpnIntfStaticFrr = "MAC_TYPE_EVPN_INTF_STATIC_FRR"
    case learnedDynamicFrr = "MAC_TYPE_LEARNED_DYNAMIC_FRR"
    case configuredStaticFrr = "MAC_TYPE_CONFIGURED_STATIC_FRR"
    case vplsDynamicRemote = "MAC_TYPE_VPLS_DYNAMIC_REMOTE"
    case configuredSys = "MAC_TYPE_CONFIGURED_SYS"
    case other = "MAC_TYPE_OTHER"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    /// Short, human-friendly label suitable for chips in result rows.
    var shortLabel: String {
        switch self {
        case .learnedDynamic, .softwareLearnedDynamic, .learnedDynamicFrr: return "Dynamic"
        case .learnedSecure, .configuredSecure, .peerSecure, .pendingSecure: return "Secure"
        case .configuredStatic, .configuredDynamic, .configuredStaticFrr, .programmedStatic: return "Static"
        case .peerDynamic, .peerStatic, .peerAuthenticated,
             .peerLearnedRemote, .peerConfiguredRemote, .peerReceivedRemote, .peerEvpnRemote, .peerRouter: return "MLAG peer"
        case .evpnDynamicRemote, .evpnConfiguredRemote, .evpnVespaDynamic,
             .evpnIntfDynamic, .evpnIntfStatic, .evpnIntfDynamicFrr, .evpnIntfStaticFrr: return "EVPN"
        case .learnedRemote, .configuredRemote, .receivedRemote, .vplsDynamicRemote: return "Remote"
        case .authenticated: return "802.1X"
        case .configuredRouter: return "Router"
        case .configuredSys: return "System"
        case .unspecified, .other: return ""
        }
    }
}

enum Explanation: String, Decodable {
    case unspecified = "EXPLANATION_UNSPECIFIED"
    case directConnection = "EXPLANATION_DIRECT_CONNECTION"
    case nonInventoryConnection = "EXPLANATION_NON_INVENTORY_CONNECTION"
    case noConnection = "EXPLANATION_NO_CONNECTION"
    case inventoryConnection = "EXPLANATION_INVENTORY_CONNECTION"
    case ownPortInventoryDevice = "EXPLANATION_OWN_PORT_INVENTORY_DEVICE"
    case directConnectionInventoryDevice = "EXPLANATION_DIRECT_CONNECTION_INVENTORY_DEVICE"
    case noConnectionInventoryDevice = "EXPLANATION_NO_CONNECTION_INVENTORY_DEVICE"
    case otherConnectionInventoryDevice = "EXPLANATION_OTHER_CONNECTION_INVENTORY_DEVICE"
    case virtual = "EXPLANATION_VIRTUAL"
    case wirelessConnection = "EXPLANATION_WIRELESS_CONNECTION"
    case accessPort = "EXPLANATION_ACCESS_PORT"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    var displayName: String {
        switch self {
        case .unspecified: return "Unknown"
        case .directConnection: return "Direct (LLDP)"
        case .nonInventoryConnection: return "Non-inventory link"
        case .noConnection: return "No direct connection"
        case .inventoryConnection: return "Inventory link"
        case .ownPortInventoryDevice: return "Own port"
        case .directConnectionInventoryDevice: return "Direct (inventory)"
        case .noConnectionInventoryDevice: return "No connection"
        case .otherConnectionInventoryDevice: return "Other link"
        case .virtual: return "Virtual"
        case .wirelessConnection: return "Wireless"
        case .accessPort: return "Access port"
        }
    }
}
