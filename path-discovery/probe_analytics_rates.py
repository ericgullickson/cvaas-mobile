"""
Probe the Turbine analytics rates dataset for per-interface throughput data.

Context:
  The iOS app's InterfaceCountersChart needs per-port RX/TX rates (bps).
  The CVaaS web UI fetches these from the "analytics" dataset at:
    dataset: {type: "device", name: "analytics"}
    path:    /Devices/<deviceId>/versioned-data/interfaces/data/<intf>/rates

  The wrpc.txt reference shows the device ID as a 32-char hex hash
  (e.g. F14C1163843117B62F1AD8D222F167EB), not the EOS serial number.
  This script discovers the correct device ID and probes the analytics path.

Usage:
  CVAAS_JWT=<token> .venv/bin/python path-discovery/probe_analytics_rates.py
  Optional env:
    CVAAS_TENANT  (default: www.cv-prod-us-4.arista.io:443)
    CVAAS_DEVICE  (default: WTW25120383)
"""

import os
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Any, List

from cloudvision.Connector.grpc_client import GRPCClient, create_query
from cloudvision.Connector.codec import Wildcard


DEFAULT_TENANT = "www.cv-prod-us-4.arista.io:443"
DEFAULT_DEVICE = "WTW25120383"
DEFAULT_INTF = "Ethernet14"


def shape_of(value: Any, depth: int = 0) -> str:
    if depth > 3:
        return "..."
    if isinstance(value, dict):
        if not value:
            return "{}"
        sample_keys = list(value.keys())[:6]
        more = "" if len(value) <= 6 else f" (+{len(value) - 6} more)"
        inner = {k: shape_of(value[k], depth + 1) for k in sample_keys}
        return f"dict[{len(value)}]={inner}{more}"
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        return f"list[{len(value)}, head={shape_of(value[0], depth + 1)}]"
    if isinstance(value, str):
        return f"str({value[:60]!r})"
    return f"{type(value).__name__}({value!r})"[:80]


def probe(client: GRPCClient, label: str, dataset_name: str, dataset_type: str,
          path_elts: List[Any], keys: List[Any], max_notifs: int = 5,
          start_ts: datetime = None, end_ts: datetime = None) -> list:
    print(f"\n## PROBE: {label}")
    print(f"  dataset: type={dataset_type!r} name={dataset_name!r}")
    print(f"  path: {[w if not isinstance(w, Wildcard) else '*' for w in path_elts]}")
    if start_ts:
        delta = (end_ts - start_ts).total_seconds()
        print(f"  time range: {start_ts.isoformat()} -> {end_ts.isoformat()} ({delta:.0f}s window)")

    try:
        q = create_query([(path_elts, keys)], dId=dataset_name, dtype=dataset_type)
        notifs_collected = []
        update_count = 0

        for batch in client.get([q], timeout=15.0, start=start_ts, end=end_ts):
            for n in batch.get("notifications", []):
                notifs_collected.append(n)
                pe = n.get("path_elements", [])
                updates = n.get("updates", {})
                update_count += len(updates)
                if len(notifs_collected) <= 3:
                    print(f"  notif[{len(notifs_collected)-1}] path_tail={pe[-3:] if len(pe) > 3 else pe}")
                    ts = n.get("timestamp")
                    if ts:
                        print(f"    timestamp: {ts}")
                    for k, v in list(updates.items())[:4]:
                        print(f"    {k!r:30s} = {shape_of(v)}")
                    deletes = n.get("deletes", [])
                    if deletes:
                        print(f"    deletes: {deletes[:3]}")
                if len(notifs_collected) >= max_notifs:
                    break
            if len(notifs_collected) >= max_notifs:
                break

        print(f"  RESULT: OK  notifications={len(notifs_collected)}  updates~={update_count}")
        return notifs_collected
    except Exception as exc:
        print(f"  RESULT: FAIL  {type(exc).__name__}: {exc}")
        return []


def main() -> int:
    jwt = (os.environ.get("CVAAS_JWT") or os.environ.get("CVAAS_TOKEN") or "").strip()
    if not jwt:
        print("ERROR: CVAAS_JWT env var is empty.", file=sys.stderr)
        return 2
    tenant = os.environ.get("CVAAS_TENANT", DEFAULT_TENANT).strip()
    # Strip scheme if present -- GRPCClient expects host:port, not a URL
    for scheme in ("https://", "http://"):
        if tenant.startswith(scheme):
            tenant = tenant[len(scheme):]
    if ":" not in tenant:
        tenant = tenant + ":443"
    device = os.environ.get("CVAAS_DEVICE", DEFAULT_DEVICE).strip()
    intf = os.environ.get("CVAAS_INTF", DEFAULT_INTF).strip()

    print(f"# tenant: {tenant}")
    print(f"# device: {device}")
    print(f"# interface: {intf}")
    print(f"# jwt: <set, {len(jwt)} chars>")

    client = GRPCClient(tenant, tokenValue=jwt)
    now = datetime.now(tz=timezone.utc)

    try:
        # ========== Phase 1: Discover device IDs in the analytics dataset ==========
        print("\n# ========== Phase 1: Discover analytics device IDs ==========")

        # 1a. List all device-type datasets to see what names exist
        print("\n## DATASETS: type='device'")
        try:
            datasets = list(client.get_datasets(types=["device"]))
            device_names = [getattr(d, "name", "?") for d in datasets]
            print(f"  count: {len(datasets)}")
            if device in device_names:
                print(f"  '{device}' found as a dataset name (serial-based)")
            else:
                print(f"  '{device}' NOT found as dataset name")
            if "analytics" in device_names:
                print(f"  'analytics' found as a dataset name")
            else:
                print(f"  'analytics' NOT found as dataset name")
            print(f"  first 10: {device_names[:10]}")
        except Exception as exc:
            print(f"  FAIL: {type(exc).__name__}: {exc}")

        # 1b. Enumerate top-level children of the analytics dataset
        probe(client, "analytics root children",
              dataset_name="analytics", dataset_type="device",
              path_elts=[], keys=[Wildcard()])

        # 1c. Look for /Devices in the analytics dataset
        probe(client, "analytics /Devices children",
              dataset_name="analytics", dataset_type="device",
              path_elts=["Devices"], keys=[Wildcard()],
              max_notifs=10)

        # 1d. Try the device serial directly in the analytics path
        probe(client, f"analytics /Devices/{device} (serial) children",
              dataset_name="analytics", dataset_type="device",
              path_elts=["Devices", device], keys=[Wildcard()])

        # 1e. Try /Devices/<serial>/versioned-data subtree
        probe(client, f"analytics /Devices/{device}/versioned-data children",
              dataset_name="analytics", dataset_type="device",
              path_elts=["Devices", device, "versioned-data"], keys=[Wildcard()])

        # ========== Phase 2: Probe the actual rates path ==========
        print("\n# ========== Phase 2: Probe rates path (using serial) ==========")

        rates_path = ["Devices", device, "versioned-data", "interfaces", "data", intf, "rates"]

        # 2a. Latest state (no time bounds)
        probe(client, f"analytics rates for {intf} (latest state)",
              dataset_name="analytics", dataset_type="device",
              path_elts=rates_path, keys=[Wildcard()])

        # 2b. Time-bounded (last 1 hour)
        probe(client, f"analytics rates for {intf} (last 1h)",
              dataset_name="analytics", dataset_type="device",
              path_elts=rates_path, keys=[Wildcard()],
              start_ts=now - timedelta(hours=1), end_ts=now)

        # 2c. Time-bounded (last 5 minutes, for denser signal)
        probe(client, f"analytics rates for {intf} (last 5min)",
              dataset_name="analytics", dataset_type="device",
              path_elts=rates_path, keys=[Wildcard()],
              start_ts=now - timedelta(minutes=5), end_ts=now)

        # ========== Phase 3: Try the per-device dataset with Sysdb counter path ==========
        print("\n# ========== Phase 3: Sysdb counter path (device dataset, control) ==========")

        sysdb_counter_path = ["Sysdb", "interface", "counter", "eth", "phy",
                              "intfCounterDir", intf]

        # 3a. Latest state
        probe(client, f"device/{device} Sysdb counter for {intf} (latest)",
              dataset_name=device, dataset_type="device",
              path_elts=sysdb_counter_path, keys=[Wildcard()])

        # 3b. Time-bounded (last 1h)
        probe(client, f"device/{device} Sysdb counter for {intf} (last 1h)",
              dataset_name=device, dataset_type="device",
              path_elts=sysdb_counter_path, keys=[Wildcard()],
              start_ts=now - timedelta(hours=1), end_ts=now)

        # ========== Phase 4: Try alternate dataset configs from wrpc.txt ==========
        print("\n# ========== Phase 4: Alternative dataset configurations ==========")

        # 4a. Dataset name="" type="device" (the dataset might be unnamed)
        probe(client, f"device/'' rates for {intf}",
              dataset_name="", dataset_type="device",
              path_elts=rates_path, keys=[Wildcard()])

        # 4b. Dataset name="analytics" type="analytics"
        probe(client, f"analytics/analytics rates for {intf}",
              dataset_name="analytics", dataset_type="analytics",
              path_elts=rates_path, keys=[Wildcard()])

        # 4c. The cv dataset might have an analytics-to-serial mapping
        probe(client, "cv DatasetInfo/Devices (device ID mapping)",
              dataset_name="", dataset_type="cv",
              path_elts=["DatasetInfo", "Devices"], keys=[Wildcard()],
              max_notifs=10)

    finally:
        client.close()

    print("\n# done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
