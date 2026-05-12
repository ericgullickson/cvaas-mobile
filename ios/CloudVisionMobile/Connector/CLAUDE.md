# Connector/

`cloudvision.Connector` gRPC client + NEAT wire codec. Used by F2 (Switch & Port Inspector). Architecture and invariants live in `README.md` — read it before modifying any file here.

## Files

| File | What | When to read |
|------|------|--------------|
| `README.md` | NEAT wire format, design decisions, invariants (slice convention, gRPC v1.x pin, ExtType codes) | Before modifying the codec or path strings; before adding new NetDB queries |
| `NEATCodec.swift` | Swift NEAT — MessagePack + 2 ExtType codes. Encodes path elements; decodes notification key/value bytes | Modifying wire format, adding new value types, debugging decoded values |
| `ConnectorClient.swift` | Wraps `RouterV1AsyncClient` over a TLS gRPC channel; injects `authorization: Bearer <jwt>` metadata | Adding new RPCs, changing the auth header, debugging connection or TLS issues |
| `ConnectorTestView.swift` | Debug screen reachable from Settings → "Connector test (D.4)". Runs one Get against a selectable path and shows decoded result | Verifying the Connector pipeline after changes, debugging path queries against a real tenant |

## Subdirectories

| Directory | What | When to read |
|-----------|------|--------------|
| `Generated/` | protoc output (gitignored). Run `make generate` from `ios/` to (re)create | Never — these are regenerated; modify `ios/protos/*.proto` instead |
