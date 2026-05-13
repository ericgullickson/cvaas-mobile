"""
F4.1.c — Run a controlled Cable Test on Ethernet14 and probe NetDB for the result path.

User explicitly authorized this controlled run (2026-05-13). Cable Test will put
Ethernet14 on WTW25120383 out of operation for ~10 seconds.

What this does:
  1. Generate a fresh UUID for the ChangeControl.
  2. POST a ChangeControlConfig with one stage running `interfaceCableTest`
     against (WTW25120383, Ethernet14).
  3. POST again setting start.value = true.
  4. Poll the read-side ChangeControl every 2s until terminal
     (CHANGE_CONTROL_STATUS_COMPLETED). Hard cap at 60s.
  5. After terminal, probe NetDB under likely cable-diag paths to find where the
     result data landed. Print path + sample data shape.

Usage:
  CVAAS_JWT=<token> .venv/bin/python path-discovery/F4_run_cable_test.py

Env overrides:
  CVAAS_TENANT_HTTPS  default https://www.cv-prod-us-4.arista.io
  CVAAS_TENANT_GRPC   default www.cv-prod-us-4.arista.io:443
  CVAAS_DEVICE        default WTW25120383
  CVAAS_INTERFACE     default Ethernet14
"""
import json
import os
import sys
import time
import uuid
from typing import Any, Dict, List, Tuple

import urllib.request
import urllib.error

from cloudvision.Connector.grpc_client import GRPCClient, create_query
from cloudvision.Connector.codec import Wildcard


DEFAULT_HTTPS = "https://www.cv-prod-us-4.arista.io"
DEFAULT_GRPC = "www.cv-prod-us-4.arista.io:443"
DEFAULT_DEVICE = "WTW25120383"
DEFAULT_INTERFACE = "Ethernet14"


def _http_request(method: str, url: str, jwt: str, body: Dict[str, Any] | None = None) -> Tuple[int, Dict[str, Any]]:
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {jwt}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20.0) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        return e.code, _parse(raw)
    return 200, _parse(raw)


def _parse(raw: str) -> Dict[str, Any]:
    raw = raw.strip()
    if not raw:
        return {}
    # CVaaS GETs sometimes stream NDJSON; we treat the first object as the answer.
    if raw.startswith("{"):
        try:
            # If it's NDJSON (multiple JSON objects), take the first.
            first_line = raw.splitlines()[0]
            return json.loads(first_line)
        except Exception:
            return {"_raw": raw[:400]}
    return {"_raw": raw[:400]}


def submit_cable_test(https_base: str, jwt: str, device: str, interface: str) -> str:
    """Create a ChangeControl with one cable-test stage. Returns the cc_id."""
    cc_id = str(uuid.uuid4())
    body = {
        "key": {"id": cc_id},
        "change": {
            "name": f"F4.1.c probe — Cable Test on {device}/{interface}",
            "rootStageId": "s1",
            "stages": {
                "values": {
                    "s1": {
                        "name": f"Cable Test {interface}",
                        "action": {
                            "name": "interfaceCableTest",
                            "args": {
                                "values": {
                                    "DeviceID": device,
                                    "InterfaceID": interface,
                                    "FailOnErrDisabled": "false",
                                    "SkipValidation": "false",
                                }
                            },
                        },
                    }
                }
            },
            "notes": "Automated F4 discovery probe — disruption ~10s acknowledged.",
        },
    }
    code, resp = _http_request("POST", f"{https_base}/api/resources/changecontrol/v1/ChangeControlConfig", jwt, body)
    if code != 200:
        raise SystemExit(f"create ChangeControl FAILED: HTTP {code} {resp}")
    print(f"create ChangeControl OK — cc_id={cc_id}")
    print(f"  response: {json.dumps(resp)[:300]}")
    return cc_id


def get_version_timestamp(https_base: str, jwt: str, cc_id: str) -> str:
    """Read the ChangeControl back to capture its current version timestamp.

    Required as the optimistic-lock token for ApproveConfig.version per proto.
    Tries time fields on the read-side ChangeControl message in fallback order.
    """
    code, resp = _http_request(
        "GET", f"{https_base}/api/resources/changecontrol/v1/ChangeControl?key.id={cc_id}", jwt
    )
    if code != 200:
        raise SystemExit(f"read ChangeControl FAILED: HTTP {code} {resp}")
    value = (resp.get("result") or {}).get("value") or {}
    # Try several locations; CVaaS REST gateway is camelCase.
    change = value.get("change") or {}
    creation = value.get("creation") or {}
    ts = change.get("time") or creation.get("time") or resp.get("time")
    if not ts:
        # Dump for diagnostics.
        raise SystemExit(f"could not locate version timestamp; full response:\n{json.dumps(resp, indent=2)[:1500]}")
    print(f"version timestamp: {ts}")
    return ts


def approve_cable_test(https_base: str, jwt: str, cc_id: str, version_ts: str) -> None:
    body = {
        "key": {"id": cc_id},
        "approve": {"value": True},
        "version": version_ts,
    }
    code, resp = _http_request("POST", f"{https_base}/api/resources/changecontrol/v1/ApproveConfig", jwt, body)
    if code != 200:
        raise SystemExit(f"approve ChangeControl FAILED: HTTP {code} {resp}")
    print(f"approve ChangeControl OK — cc_id={cc_id}")
    print(f"  response: {json.dumps(resp)[:300]}")


def start_cable_test(https_base: str, jwt: str, cc_id: str) -> None:
    body = {"key": {"id": cc_id}, "start": {"value": True}}
    code, resp = _http_request("POST", f"{https_base}/api/resources/changecontrol/v1/ChangeControlConfig", jwt, body)
    if code != 200:
        raise SystemExit(f"start ChangeControl FAILED: HTTP {code} {resp}")
    print(f"start ChangeControl OK — cc_id={cc_id}")
    print(f"  response: {json.dumps(resp)[:300]}")


def poll_until_terminal(https_base: str, jwt: str, cc_id: str, max_wait_s: float = 60.0) -> Dict[str, Any]:
    deadline = time.time() + max_wait_s
    last_status = None
    while time.time() < deadline:
        code, resp = _http_request(
            "GET", f"{https_base}/api/resources/changecontrol/v1/ChangeControl?key.id={cc_id}", jwt
        )
        value = (resp.get("result") or {}).get("value") or {}
        status = value.get("status") or "(unknown)"
        err = value.get("error") or ""
        if status != last_status:
            print(f"  status={status}  err={err!r}")
            last_status = status
        if status == "CHANGE_CONTROL_STATUS_COMPLETED":
            return value
        time.sleep(2.0)
    raise SystemExit(f"poll timeout after {max_wait_s}s — last status={last_status}")


# Candidate NetDB paths for Cable Test result. First hit wins.
CABLE_DIAG_CANDIDATES: List[Tuple[str, List[Any]]] = [
    ("cd.A intf.status.eth.phy.slice.1.cableDiag.*",
     ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "cableDiag"]),
    ("cd.B intf.status.eth.phy.slice.1.cableDiagStatus.*",
     ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "cableDiagStatus"]),
    ("cd.C intf.status.eth.phy.slice.1.tdr.*",
     ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "tdr"]),
    ("cd.D intf.status.eth.phy.slice.1.tdrStatus.*",
     ["Sysdb", "interface", "status", "eth", "phy", "slice", "1", "tdrStatus"]),
    ("cd.E hardware.phy.cableDiag.*",
     ["Sysdb", "hardware", "phy", "cableDiag"]),
    ("cd.F interface.cableDiag.*",
     ["Sysdb", "interface", "cableDiag"]),
    ("cd.G hardware.cableDiag.*",
     ["Sysdb", "hardware", "cableDiag"]),
    ("cd.H Smash/interface/cableDiag",
     ["Smash", "interface", "cableDiag"]),
]


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
    if isinstance(value, (bytes, bytearray)):
        return f"bytes[{len(value)}]"
    if isinstance(value, str):
        return f"str({value[:80]!r}{'...' if len(value) > 80 else ''})"
    return f"{type(value).__name__}({value!r})"[:100]


def probe_netdb_paths(grpc_host: str, jwt: str, device: str, interface: str) -> None:
    print(f"\n# Probing NetDB on {device} for cable-test result path...")
    client = GRPCClient(grpc_host, tokenValue=jwt)
    try:
        for label, path_elts in CABLE_DIAG_CANDIDATES:
            print(f"\n## PROBE: {label}")
            print(f"  path: {path_elts}")
            try:
                q = create_query([(path_elts, [Wildcard()])], device)
                notif_count = 0
                update_count = 0
                samples = []
                for batch in client.get([q], timeout=10.0):
                    for n in batch.get("notifications", []):
                        notif_count += 1
                        pe = n.get("path_elements", [])
                        updates = n.get("updates", {})
                        update_count += len(updates)
                        # Prefer samples that mention our test interface
                        prefer = any(interface in str(k) for k in pe)
                        if (prefer or len(samples) < 3) and updates:
                            samples.append((pe, dict(list(updates.items())[:4])))
                    if notif_count >= 30:
                        break
                print(f"  result: notifications={notif_count}  updates_total~{update_count}")
                for i, (pe, kv) in enumerate(samples[:4]):
                    tail = pe[-4:] if len(pe) > 4 else pe
                    print(f"  sample[{i}] path_tail={tail}")
                    for k, v in kv.items():
                        print(f"    key={k!r:60s} value={shape_of(v)}")
            except Exception as exc:
                print(f"  FAIL: {type(exc).__name__}: {exc}")
    finally:
        client.close()


def main() -> int:
    jwt = os.environ.get("CVAAS_JWT", "").strip()
    if not jwt:
        print("ERROR: CVAAS_JWT empty", file=sys.stderr)
        return 2
    https_base = os.environ.get("CVAAS_TENANT_HTTPS", DEFAULT_HTTPS).rstrip("/")
    grpc_host = os.environ.get("CVAAS_TENANT_GRPC", DEFAULT_GRPC)
    device = os.environ.get("CVAAS_DEVICE", DEFAULT_DEVICE)
    interface = os.environ.get("CVAAS_INTERFACE", DEFAULT_INTERFACE)

    print(f"# https: {https_base}")
    print(f"# grpc:  {grpc_host}")
    print(f"# device: {device}  interface: {interface}")
    print(f"# jwt:   <set, {len(jwt)} chars>")
    print(f"\n# --- Phase 1: submit Cable Test (ChangeControl) ---")

    cc_id = submit_cable_test(https_base, jwt, device, interface)
    version_ts = get_version_timestamp(https_base, jwt, cc_id)
    approve_cable_test(https_base, jwt, cc_id, version_ts)
    start_cable_test(https_base, jwt, cc_id)

    print(f"\n# --- Phase 2: poll until terminal ---")
    final = poll_until_terminal(https_base, jwt, cc_id)
    err = final.get("error") or ""
    print(f"\nterminal: status={final.get('status')}  error={err!r}")
    if err:
        print("Cable Test reported an error. Continuing to NetDB probe anyway — partial result may still be present.")

    # Brief settle pause for the result data to propagate into NetDB.
    time.sleep(3)

    print(f"\n# --- Phase 3: probe NetDB for result path ---")
    probe_netdb_paths(grpc_host, jwt, device, interface)

    print(f"\n# done — cc_id was {cc_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
