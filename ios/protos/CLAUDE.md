# protos/

`cloudvision.Connector` proto definitions vendored from `aristanetworks/cloudvision-python` at `cloudvision/Connector/protobuf/` (Apache 2.0). Used by F2.

Regenerate the Swift stubs after modifying any file here:
```
cd ios && make generate
```

## Files

| File | What | When to read |
|------|------|--------------|
| `router.proto` | `RouterV1` service (Get, Subscribe, GetAndSubscribe, Publish, GetDatasets) + `Auth` and `Search` services. The most important file for F2 | Understanding the gRPC contract, looking up RPC signatures and request/response shapes |
| `notification.proto` | `Notification`, `NotificationBatch`, `Dataset`. The data-carrier types streamed by Get/Subscribe | Understanding the streamed response structure, adding fields to Notification handling |
| `ca.proto` | `CertificateAuthority` service for client cert enrollment (not used by MVP) | Adding mTLS support — relevant to PRD §7 R2's production end-state |
| `sharding.proto` | `Sharding` message for horizontal scaling of subscriptions. Not exercised by MVP | Optimizing subscriptions across multiple client instances (not relevant to a single mobile app) |
