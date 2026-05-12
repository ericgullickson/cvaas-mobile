# Code generation for the cloudvision.Connector gRPC stubs.
#
# The .proto files in `protos/` are vendored from `aristanetworks/cloudvision-python`
# at `cloudvision/Connector/protobuf/`. Generated Swift stubs land in
# `CloudVisionMobile/Connector/Generated/` and are gitignored — regenerate after pulling.
#
# One-time tool setup
# -------------------
#   brew install protobuf swift-protobuf
#
#   # grpc-swift's default branch is v2 (uses an SPM build plugin, no standalone binary).
#   # v1.x — the line that ships `protoc-gen-grpc-swift` as an executable — lives on
#   # the `release/1.x` branch. Clone that branch and build the product:
#   git clone -b release/1.x https://github.com/grpc/grpc-swift /tmp/grpc-swift
#   (cd /tmp/grpc-swift && swift build -c release --product protoc-gen-grpc-swift)
#   sudo cp /tmp/grpc-swift/.build/release/protoc-gen-grpc-swift /usr/local/bin/
#
# Regenerate stubs
# ----------------
#   make generate
#
# Then in Xcode: Cmd+B. The Generated/ files are auto-discovered by XcodeGen
# (project.yml's `sources: [{path: CloudVisionMobile}]` recurses).

PROTO_DIR := protos
OUT_DIR := CloudVisionMobile/Connector/Generated

.PHONY: generate clean check-tools

generate: check-tools
	@mkdir -p $(OUT_DIR)
	protoc \
		--proto_path=$(PROTO_DIR) \
		--swift_out=$(OUT_DIR) \
		--swift_opt=Visibility=Public \
		--grpc-swift_out=$(OUT_DIR) \
		--grpc-swift_opt=Client=true,Server=false,Visibility=Public \
		$(PROTO_DIR)/*.proto
	@echo "Generated Swift stubs in $(OUT_DIR)/"
	@ls -1 $(OUT_DIR)/

clean:
	rm -rf $(OUT_DIR)

check-tools:
	@command -v protoc                 >/dev/null || { echo "missing: protoc (brew install protobuf)"; exit 1; }
	@command -v protoc-gen-swift       >/dev/null || { echo "missing: protoc-gen-swift (brew install swift-protobuf)"; exit 1; }
	@command -v protoc-gen-grpc-swift  >/dev/null || { echo "missing: protoc-gen-grpc-swift (see Makefile header)"; exit 1; }
