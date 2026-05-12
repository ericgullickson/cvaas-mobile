# Connector

## Overview

`cloudvision.Connector` is Arista's gRPC service for streaming NetDB telemetry to clients. It is distinct from the higher-level resource APIs (`endpointlocation.v1`, `inventory.v1`, etc.) used by F1 and F3 — those go over REST. F2 needs per-port state that the resource APIs do not expose, so we hit Connector directly.

Wire format at this layer is **NEAT**, not protobuf. `Notification.Update.key` and `.value` are `bytes` in the .proto, but the contents are MessagePack with two custom ExtType codes.

## Architecture

```
SwiftUI View
   │
   ▼
ConnectorClient.get(datasetType:, datasetName:, path:)
   │  build Query{ Dataset, Path{ pathElements = [NEATCodec.encode(...)] } }
   ▼
grpc-swift (HTTP/2 + TLS), authorization: Bearer <jwt> metadata
   │
   ▼
CVaaS RouterV1.Get  (server-streams NotificationBatch)
   │
   ▼
NEATCodec.decode(update.key / update.value)  →  NEATValue tree
```

## Design Decisions

- **Native Swift gRPC, no backend service.** Hard project constraint (PRD §6, R1 resolution). We use grpc-swift v1.x from the `release/1.x` branch — v2 reorganized codegen and isn't compatible with our Makefile flow.
- **`RouterV1.Get` (unary → server-stream)**, not `Subscribe`. Mobile shouldn't keep long-lived subscriptions open (battery, backgrounding, reconnect complexity). We poll Get from the View's `.task`.
- **NEAT strings serialize as MessagePack `bin`, not `str`.** The Python reference packs the UTF-8 bytes of the string directly; Swift mirrors via `.binary(Data(s.utf8))`. Using `.string(s)` would produce wire-incompatible output that CVaaS rejects.
- **Map keys are sorted by encoded bytes** for deterministic output, matching the Python encoder.

## Invariants

- NEAT ExtType codes are immutable: `PointerType = 0`, `WildcardType = 1`. Do not change.
- NetDB path strings are an internal CVaaS contract (PRD §7 R8) — they can drift between CVP/EOS versions. Keep all path strings centralized in feature services (e.g. `PortStateService`), never scattered through views.
- Slice `"1"` is hard-coded for fixed switches (710P, 7050-X, etc.). Modular chassis use the linecard number — generalizing this is a Sprint 2 concern.
- The `release/1.x` branch of grpc-swift must be used. v2 changes the API surface; switching would require a code migration.
- Reference implementation for NEAT lives at `cloudvision-python/cloudvision/Connector/codec/{custom_types,encoder,decoder}.py`. If round-trip ever fails, port the test fixtures from `cloudvision-python/test/test_codec.yml` and run them as Swift unit tests.
