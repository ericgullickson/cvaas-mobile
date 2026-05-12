import Foundation

/// Single source of truth for `cloudvision.Connector` NetDB path strings.
///
/// Risk R8 (Sprint 1 plan §1.3): NetDB paths are internal EOS implementation details, not a
/// stable public contract. They can change between EOS versions and break the app silently.
/// Centralizing them here lets the F.7 CI smoke test sweep every active path on each push.
///
/// Query semantics — verified against `WTW25120383` on `cv-prod-us-4` (Sprint 2 §1.5):
///   - To enumerate children at a path: put `.wildcard` in `path_elements`, leave the
///     query's `keys` empty. (Putting wildcards in `keys` returns zero notifications.)
///   - `RouterV1.Get` then returns one notification per matched child, with the resolved
///     child name in the tail of `path_elements` and the child's fields as `updates`.
///
/// Slice convention: fixed switches (710P, 7050X, 7280R, ...) use slice "1". Modular
/// chassis (7500R, etc.) use the linecard number. MVP targets fixed; modular support is a
/// post-Sprint-2 concern.
enum NetDBPaths {

    // MARK: - Per-port

    /// Per-port interface status (link state, MAC addr, MTU, etc.).
    /// Returns one notification per Ethernet interface; tail element is the interface name.
    /// Verified by Sprint 1 F2 first-light.
    static func interfaceStatus(slice: String = "1") -> [NEATPathElement] {
        [
            .string("Sysdb"), .string("interface"), .string("status"),
            .string("eth"), .string("phy"), .string("slice"), .string(slice),
            .string("intfStatus"), .wildcard,
        ]
    }

    /// Per-port PoE state. Verified Sprint 2 F.1.c against a 710P (Ethernet14 live PoE fixture).
    /// Returns one notification per port; tail is the interface name. Per-port keys include:
    ///   - `portStatus` (nested map: `pdClass.Name`, `poePortState.Name`, `grantedPower.value`, ...)
    ///   - `portPriority.Name` (e.g. "low")
    ///   - `capacity.value` (W), `outputPower.value` (W), `outputCurrent.value` (A),
    ///     `outputVoltage.value` (V), `temperature.value` (°C), `pseApprovedPower.value` (W;
    ///     -Infinity when not approved), `lldpEnabled` (bool)
    /// Path is independent of slice number (PoE is in `environment`, not `interface`).
    static let poePort: [NEATPathElement] = [
        .string("Sysdb"), .string("environment"), .string("power"),
        .string("status"), .string("poePort"), .wildcard,
    ]

    /// LLDP remote-neighbor entries, one notification fragment per (localPort, remoteIndex,
    /// keys-subset). Verified Sprint 2 §1.5: only ports with active LLDP neighbors produce
    /// notifications, and a single (port, remoteIndex) appears across multiple notifications
    /// with disjoint key sets — the Swift aggregator **must merge by path tail** before
    /// extracting fields. Useful keys (under each remoteSystem record):
    ///   - `sysName.value.value` (string)  — neighbor system name
    ///   - `sysDesc.value.value` (string)  — neighbor system description
    ///   - `msap.portIdentifier.portId` (string)  — remote port id
    ///   - `portDesc.value.value` (string)  — remote port description (if sent)
    ///   - `ttl` (int)  — seconds until LLDP entry expires
    /// Path tail at the leaf: `[..., "portStatus", "<EthernetN>", "remoteSystem", <index>]`.
    /// The `<index>` is typically 1 but may be higher if multiple neighbors are detected.
    static let lldpRemoteNeighbors: [NEATPathElement] = [
        .string("Sysdb"), .string("l2discovery"), .string("lldp"), .string("status"),
        .string("local"), .string("1"), .string("portStatus"), .wildcard,
        .string("remoteSystem"), .wildcard,
    ]

    // MARK: - Per-switch

    /// MAC table for the whole switch. PRD §5 F2 §v.
    /// One notification at the leaf; value is a list of FDB entries (vlan + mac + port).
    /// Verified reachable Sprint 2 §1.5 ("Smash/bridging/status/smashFdbStatus" present on the
    /// 710P). Per-port MAC counts must be derived client-side by grouping entries by port.
    static let macTableFdb: [NEATPathElement] = [
        .string("Smash"), .string("bridging"), .string("status"),
        .string("smashFdbStatus"),
    ]

    // MARK: - F.7 smoke-test surface

    /// Every path the F.7 CI smoke test should sweep. Each entry pairs a label for failure
    /// reporting with the path. `interfaceStatus` is keyed on default slice "1".
    static var smokeTestSurface: [(label: String, path: [NEATPathElement])] {
        [
            ("interfaceStatus(slice=1)", interfaceStatus()),
            ("poePort", poePort),
            ("lldpRemoteNeighbors", lldpRemoteNeighbors),
            ("macTableFdb", macTableFdb),
        ]
    }
}
