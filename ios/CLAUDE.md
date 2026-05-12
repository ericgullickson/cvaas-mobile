# ios/

## Files

| File | What | When to read |
|------|------|--------------|
| `project.yml` | XcodeGen project specification — declares the iOS target, SPM dependencies, deployment target, Info.plist keys | Adding SPM dependencies, changing the iOS deployment target, debugging the Xcode project structure |
| `Makefile` | Codegen for `cloudvision.Connector` gRPC stubs from `protos/*.proto`. Header documents one-time tool setup | Regenerating Swift stubs, debugging protoc invocations, setting up `protoc-gen-grpc-swift` |
| `.gitignore` | Ignores `*.xcodeproj/` and `CloudVisionMobile/Connector/Generated/` (both regenerated on demand) | Adding new generated artifacts that should not be committed |

## Subdirectories

| Directory | What | When to read |
|-----------|------|--------------|
| `CloudVisionMobile/` | Swift source tree — App entry, auth, features, networking, Connector | All app code lives here |
| `protos/` | Vendored `cloudvision.Connector` .proto files (Apache 2.0 from `cloudvision-python`) | Modifying the vendored proto versions, understanding the gRPC contract |
