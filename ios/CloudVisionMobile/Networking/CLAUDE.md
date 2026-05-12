# Networking/

HTTP/JSON client primitives for CVaaS REST resource APIs (used by F1 and F3). For gRPC/NEAT (F2), see `../Connector/`.

## Files

| File | What | When to read |
|------|------|--------------|
| `CVError.swift` | Typed error enum: `.auth`, `.notFound`, `.rateLimited(retryAfterSeconds:)`, `.service`, `.network`, `.decoding`, `.invalidURL`, `.notConfigured` | Adding error cases, changing error UX, mapping new HTTP statuses |
| `CVHTTPClient.swift` | `URLSession` wrapper. Auto-attaches `Authorization: Bearer <jwt>`. Provides `get<T>(...)` for single-key results and `getAll<T>(...)` for NDJSON `/all` streams | Adding POST support (for `partialEqFilter` payloads), changing timeouts, debugging request/response handling |
| `CVResultWrappers.swift` | `SingleResult<T>` (`{value, time}`) and `StreamRowEnvelope<T>` (`{result: {value, time, type}}`) — the two CVaaS REST gateway response shapes | Adapting to envelope changes, debugging decode failures |
