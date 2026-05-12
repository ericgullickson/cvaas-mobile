import Foundation
import MessagePack

// NEAT — Arista's wire codec for `cloudvision.Connector` key/value/path_element bytes.
// NEAT is MessagePack with two custom ExtType codes:
//   - PointerType (0)  → Path  (a list of NEAT-encoded keys)
//   - WildcardType (1) → Wildcard (matches any single path element)
//
// Reference implementation: cloudvision-python at
//   cloudvision/Connector/codec/{custom_types,encoder,decoder}.py
//
// Subtleties preserved from the Python reference:
//   1. Strings encode as MessagePack `bin` (NOT `str`). The Python encoder packs the UTF-8
//      bytes of the string via `packer.pack(bytes(s, 'utf-8', 'replace'))`, which produces
//      bin8/bin16/bin32, not fixstr/str8/str16/str32. We mirror this with `.binary(Data)`.
//   2. Map keys are sorted by encoded bytes for deterministic output.
//   3. On decode, MessagePack `bin` is converted back to `String` (UTF-8 with replacement).

/// Single element of a NetDB path query.
public enum NEATPathElement {
    case string(String)
    case wildcard
}

/// Decoded NEAT value tree.
public indirect enum NEATValue: Equatable {
    case `nil`
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case float(Float)
    case double(Double)
    case string(String)
    case array([NEATValue])
    case map([Pair])
    /// Decoded Path pointer (NEAT ExtType 0). Wraps the recursively-decoded key list.
    case path([NEATValue])
    /// Decoded Wildcard placeholder (NEAT ExtType 1). Rare in response values; usually appears
    /// in queries only.
    case wildcard

    public struct Pair: Equatable {
        public let key: NEATValue
        public let value: NEATValue
        public init(key: NEATValue, value: NEATValue) {
            self.key = key
            self.value = value
        }
    }
}

public extension NEATValue {
    /// String value if `.string`; otherwise nil.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Int value if `.int` or `.uint` (saturating).
    var intValue: Int? {
        switch self {
        case .int(let i): return Int(exactly: i)
        case .uint(let u): return Int(exactly: u)
        default: return nil
        }
    }

    /// Bool value if `.bool`; otherwise nil.
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Treat as a string-keyed dict. String keys are extracted; non-string keys are dropped.
    /// Use when the decoded value is known to be a map of string-keyed attributes.
    var asDict: [String: NEATValue]? {
        guard case .map(let pairs) = self else { return nil }
        var out: [String: NEATValue] = [:]
        for p in pairs {
            if case .string(let k) = p.key { out[k] = p.value }
        }
        return out
    }
}

public enum NEATCodec {
    public static let pointerExtType: Int8 = 0
    public static let wildcardExtType: Int8 = 1

    // MARK: - Encode primitives (used for Query path_elements)

    /// Encode a single string as NEAT bytes (msgpack `bin` of the UTF-8 bytes).
    public static func encode(string: String) -> Data {
        let utf8 = Data(string.utf8)
        return MessagePack.pack(.binary(utf8))
    }

    /// Encode a wildcard placeholder as NEAT bytes.
    public static func encodeWildcard() -> Data {
        MessagePack.pack(.extended(wildcardExtType, Data()))
    }

    /// Encode a single path element (string or wildcard) as NEAT bytes. Used to build the
    /// `path_elements: repeated bytes` field of a `Path` in a `Query`.
    public static func encode(pathElement: NEATPathElement) -> Data {
        switch pathElement {
        case .string(let s): return encode(string: s)
        case .wildcard: return encodeWildcard()
        }
    }

    /// Encode an arbitrary NEAT value tree. Maps are emitted with keys sorted by encoded bytes,
    /// matching the deterministic output of the Python reference encoder.
    public static func encode(_ value: NEATValue) -> Data {
        MessagePack.pack(toMessagePack(value))
    }

    // MARK: - Decode

    /// Decode NEAT bytes into a `NEATValue` tree. Throws on malformed input.
    public static func decode(_ data: Data) throws -> NEATValue {
        let (value, _) = try MessagePack.unpack(data)
        return fromMessagePack(value)
    }

    // MARK: - Conversion

    private static func toMessagePack(_ v: NEATValue) -> MessagePackValue {
        switch v {
        case .nil: return .nil
        case .bool(let b): return .bool(b)
        case .int(let i): return .int(i)
        case .uint(let u): return .uint(u)
        case .float(let f): return .float(f)
        case .double(let d): return .double(d)
        case .string(let s):
            // NEAT strings on the wire are msgpack `bin`, NOT `str`.
            return .binary(Data(s.utf8))
        case .array(let a):
            return .array(a.map(toMessagePack))
        case .map(let pairs):
            // Encode each (k, v) pair, sort by encoded key bytes for canonical output.
            let encoded: [(packed: Data, key: MessagePackValue, value: MessagePackValue)] = pairs.map { p in
                let mpKey = toMessagePack(p.key)
                return (MessagePack.pack(mpKey), mpKey, toMessagePack(p.value))
            }
            let sorted = encoded.sorted { $0.packed.lexicographicallyPrecedes($1.packed) }
            var dict: [MessagePackValue: MessagePackValue] = [:]
            for item in sorted { dict[item.key] = item.value }
            return .map(dict)
        case .path(let keys):
            // Path is ExtType(0, encode(keys-as-array))
            let inner = MessagePack.pack(.array(keys.map(toMessagePack)))
            return .extended(pointerExtType, inner)
        case .wildcard:
            return .extended(wildcardExtType, Data())
        }
    }

    private static func fromMessagePack(_ mp: MessagePackValue) -> NEATValue {
        switch mp {
        case .nil:
            return .nil
        case .bool(let b):
            return .bool(b)
        case .int(let i):
            return .int(i)
        case .uint(let u):
            return .uint(u)
        case .float(let f):
            return .float(f)
        case .double(let d):
            return .double(d)
        case .string(let s):
            // CVaaS shouldn't emit `str` (NEAT uses `bin` for strings), but handle gracefully.
            return .string(s)
        case .binary(let data):
            // NEAT encodes strings as msgpack `bin`. Decode bytes as UTF-8 with replacement.
            return .string(String(decoding: data, as: UTF8.self))
        case .array(let arr):
            return .array(arr.map(fromMessagePack))
        case .map(let dict):
            let pairs: [NEATValue.Pair] = dict.map {
                NEATValue.Pair(key: fromMessagePack($0.key), value: fromMessagePack($0.value))
            }
            return .map(pairs)
        case .extended(let code, let payload):
            switch code {
            case pointerExtType:
                // Path payload is itself NEAT-encoded; recurse.
                guard let inner = try? decode(payload),
                      case .array(let keys) = inner else {
                    return .nil
                }
                return .path(keys)
            case wildcardExtType:
                return .wildcard
            default:
                // Unknown ExtType — drop to nil. Future versions of NEAT may add codes.
                return .nil
            }
        }
    }
}
