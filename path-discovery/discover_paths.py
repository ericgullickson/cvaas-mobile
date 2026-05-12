"""
NetDB path discovery for Sprint 2 F.1.

Why this exists:
  Sprint 2 needs verified NetDB path strings for per-port PoE state and per-port
  interface error counters on the test 710P. The PRD (§5 F2 §v) locks the field
  *schema* empirically (portClass, outputPower, etc.) but the *path* string
  through Sysdb is not documented and can vary by EOS version. Iterating in
  Swift means a 30s app rebuild per probe; iterating in Python is ~2s. So we
  discover here, then port the result to ios/CloudVisionMobile/Connector/NetDBPaths.swift.

Usage:
  CVAAS_JWT=<token> .venv/bin/python path-discovery/discover_paths.py
  Optional env:
    CVAAS_TENANT  (default: www.cv-prod-us-4.arista.io:443)
                  Note: the web UI URL ends in /cv/, but gRPC ignores the path;
                  pass host:port only.
    CVAAS_DEVICE  (default: WTW25120383 -- the 710P test fixture)

Run order:
  1. Sanity: list datasets, confirm device is reachable.
  2. Baseline: Sprint 1 link-state path. Must work or auth/transport is broken.
  3. PoE per-port candidates (Sprint 2 §F.1.c).
  4. Interface error-counter candidates (Sprint 2 §F.1.d).

Output is machine-readable: one '## FINDING' block per probe, capturing
the path tried, success/failure, sample keys, sample value shape.
"""

import os
import sys
from typing import Any, List, Tuple

from cloudvision.Connector.grpc_client import GRPCClient, create_query
from cloudvision.Connector.codec import Wildcard


DEFAULT_TENANT = "www.cv-prod-us-4.arista.io:443"
DEFAULT_DEVICE = "WTW25120383"

# Path probes. (label, path_elts, keys)
# - path_elts: list of strings or Wildcard() instances. Trailing Wildcard means
#   "fetch all immediate children at this prefix" when paired with keys=[Wildcard()].
# - keys: usually [Wildcard()] to enumerate; [] would mean "only the path itself".

# Sprint 1 baseline: link state on slice 1. Must work.
BASELINE_LINK_STATE: Tuple[str, List[Any], List[Any]] = (
    "link-state (Sprint 1 baseline)",
    ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "intfStatus"],
    [Wildcard()],
)

# Sprint 2 F.1.c PoE candidates, in PRD-listed order. First hit wins.
POE_CANDIDATES: List[Tuple[str, List[Any], List[Any]]] = [
    (
        "poe.A hardware.poe.port.*",
        ["Sysdb", "hardware", "poe", "port"],
        [Wildcard()],
    ),
    (
        "poe.B intf.status.eth.phy.slice.1.poeStatus.*",
        ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "poeStatus"],
        [Wildcard()],
    ),
    (
        "poe.C interface.poe.*",
        ["Sysdb", "interface", "poe"],
        [Wildcard()],
    ),
    # Adjacent guesses based on EOS Sysdb conventions:
    (
        "poe.D hardware.poe (root)",
        ["Sysdb", "hardware", "poe"],
        [Wildcard()],
    ),
    (
        "poe.E hardware.poe.status.*",
        ["Sysdb", "hardware", "poe", "status"],
        [Wildcard()],
    ),
]

# Sprint 2 F.1.d error-counter candidates.
COUNTER_CANDIDATES: List[Tuple[str, List[Any], List[Any]]] = [
    (
        "ctr.A interface.counter.eth.phy.slice.1.*",
        ["Sysdb", "interface", "counter", "eth", "phy", "slice", "1"],
        [Wildcard()],
    ),
    (
        "ctr.B interface.counter.eth.phy.slice.1.intfCounter.*",
        ["Sysdb", "interface", "counter", "eth", "phy", "slice", "1", "intfCounter"],
        [Wildcard()],
    ),
    (
        "ctr.C interface.counter.eth.slice.1.*",
        ["Sysdb", "interface", "counter", "eth", "slice", "1"],
        [Wildcard()],
    ),
    (
        "ctr.D interface.status.eth.phy.slice.1.intfCounter.*",
        ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "intfCounter"],
        [Wildcard()],
    ),
    (
        "ctr.E interface.counter (root)",
        ["Sysdb", "interface", "counter"],
        [Wildcard()],
    ),
]


def shape_of(value: Any, depth: int = 0) -> str:
    """Compact, human-readable summary of a decoded value's structure."""
    if depth > 3:
        return "..."
    if isinstance(value, dict):
        if not value:
            return "{}"
        sample_keys = list(value.keys())[:5]
        more = "" if len(value) <= 5 else f" (+{len(value) - 5} more)"
        inner = {k: shape_of(value[k], depth + 1) for k in sample_keys}
        return f"dict[{len(value)}]={inner}{more}"
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        return f"list[{len(value)}, head={shape_of(value[0], depth + 1)}]"
    if isinstance(value, (bytes, bytearray)):
        return f"bytes[{len(value)}]"
    if isinstance(value, str):
        return f"str({value[:40]!r}{'...' if len(value) > 40 else ''})"
    return f"{type(value).__name__}({value!r})"[:80]


def try_path(client: GRPCClient, device: str, label: str,
             path_elts: List[Any], keys: List[Any], max_notifications: int = 3) -> None:
    """Run one Get probe; emit a FINDING block."""
    print(f"\n## FINDING: {label}")
    print(f"path: {[w if not isinstance(w, Wildcard) else '*' for w in path_elts]}")
    print(f"keys: {['*' if isinstance(k, Wildcard) else k for k in keys]}")
    try:
        q = create_query([(path_elts, keys)], device)
        notif_count = 0
        update_count = 0
        sample_pairs = []
        # client.get yields decoded NotificationBatch dicts:
        # {'dataset': ..., 'notifications': [{'timestamp', 'path_elements', 'updates': {k: v}, 'deletes': [...]}, ...]}
        for batch in client.get([q], timeout=15.0):
            for n in batch.get("notifications", []):
                notif_count += 1
                pe = n.get("path_elements", [])
                updates = n.get("updates", {})
                update_count += len(updates)
                if len(sample_pairs) < 4 and updates:
                    sample_pairs.append((pe, dict(list(updates.items())[:3])))
            if notif_count >= max_notifications:
                break
        print(f"result: OK  notifications={notif_count}  updates_total~{update_count}")
        for i, (pe, kv) in enumerate(sample_pairs):
            print(f"  sample[{i}] path_elements_tail={pe[-3:] if len(pe) > 3 else pe}")
            for k, v in kv.items():
                print(f"    key={k!r:60s} value={shape_of(v)}")
        if notif_count == 0:
            print("  (zero notifications — path exists in schema but no data, OR path doesn't exist; cannot distinguish)")
    except Exception as exc:
        print(f"result: FAIL  {type(exc).__name__}: {exc}")


def main() -> int:
    jwt = os.environ.get("CVAAS_JWT", "").strip()
    if not jwt:
        print("ERROR: CVAAS_JWT env var is empty. Export the service-account JWT and re-run.", file=sys.stderr)
        return 2
    tenant = os.environ.get("CVAAS_TENANT", DEFAULT_TENANT).strip()
    device = os.environ.get("CVAAS_DEVICE", DEFAULT_DEVICE).strip()

    print(f"# tenant: {tenant}")
    print(f"# device: {device}")
    print(f"# jwt:    <set, {len(jwt)} chars>")

    client = GRPCClient(tenant, tokenValue=jwt)
    try:
        # Sanity: device dataset is reachable.
        print("\n## SANITY: get_datasets(['device'])")
        try:
            datasets = list(client.get_datasets(types=["device"]))
            print(f"  count: {len(datasets)}")
            match = [d for d in datasets if getattr(d, "name", "") == device]
            print(f"  exact-match for {device!r}: {len(match)}")
            if not match:
                # Print a few names so the user can correct CVAAS_DEVICE.
                head = [getattr(d, "name", "?") for d in datasets[:8]]
                print(f"  first datasets: {head}")
        except Exception as exc:
            print(f"  FAIL: {type(exc).__name__}: {exc}")
            print("  Auth/transport likely broken. Aborting before probes.")
            return 3

        # Baseline: Sprint 1 known-good link-state path.
        try_path(client, device, *BASELINE_LINK_STATE)

        # F.1.c PoE candidates.
        print("\n# ==================== F.1.c PoE candidates ====================")
        for cand in POE_CANDIDATES:
            try_path(client, device, *cand)

        # F.1.d Interface error-counter candidates.
        print("\n# ============== F.1.d Error-counter candidates =================")
        for cand in COUNTER_CANDIDATES:
            try_path(client, device, *cand)
    finally:
        client.close()

    print("\n# done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
