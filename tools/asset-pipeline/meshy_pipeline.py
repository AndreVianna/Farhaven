#!/usr/bin/env python3
"""Meshy image-to-3D pipeline: image-to-3d -> remesh -> retexture -> download.

Usage:
  meshy_pipeline.py P01001:1 P01001:2 ...     # specific prop:variant pairs
  meshy_pipeline.py P01001                    # all 3 variants of one prop
  meshy_pipeline.py                           # default: all P01001-P01005, all 3 variants

Requires env var MESHY_API_KEY.
"""
import os
import sys
import json
import base64
import time
import urllib.request
import urllib.error

BASE = "https://api.meshy.ai"
KEY = os.environ.get("MESHY_API_KEY")
ASSETS = "/home/andre/projects/Farhaven/assets/props"
POLL_INTERVAL = 8
MAX_POLL_SECONDS = 15 * 60

if not KEY:
    sys.stderr.write("MESHY_API_KEY not set\n")
    sys.exit(1)

AUTH = {"Authorization": f"Bearer {KEY}"}


def http(method: str, url: str, body: dict | None = None, headers: dict | None = None) -> dict:
    hdrs = dict(AUTH)
    if headers:
        hdrs.update(headers)
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        hdrs["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} on {method} {url}: {body_text[:500]}") from e


def encode_image_data_uri(path: str) -> str:
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    return f"data:image/png;base64,{b64}"


def poll_task(endpoint: str, task_id: str, label: str) -> dict:
    """Poll until task SUCCEEDED. Returns final task body."""
    deadline = time.time() + MAX_POLL_SECONDS
    last_progress = -1
    while True:
        info = http("GET", f"{BASE}{endpoint}/{task_id}")
        status = info.get("status")
        progress = info.get("progress", 0)
        if progress != last_progress:
            print(f"  [{label}] {status} {progress}%", flush=True)
            last_progress = progress
        if status == "SUCCEEDED":
            return info
        if status in {"FAILED", "CANCELED", "EXPIRED"}:
            raise RuntimeError(f"{label} task {task_id} ended {status}: {info.get('task_error')}")
        if time.time() > deadline:
            raise TimeoutError(f"{label} task {task_id} exceeded {MAX_POLL_SECONDS}s")
        time.sleep(POLL_INTERVAL)


def create_image_to_3d(image_data_uri: str) -> str:
    body = {
        "image_url": image_data_uri,
        "image_enhancement": True,
        "enable_pbr": True,
        "ai_model": "latest",
        "topology": "triangle",
        "target_polycount": 30000,
        "symmetry_mode": "auto",
    }
    resp = http("POST", f"{BASE}/openapi/v1/image-to-3d", body)
    return resp["result"]


def create_remesh(input_task_id: str) -> str:
    body = {
        "input_task_id": input_task_id,
        "target_formats": ["glb"],
        "topology": "triangle",
        "target_polycount": 3000,
        "origin_at": "bottom",
    }
    resp = http("POST", f"{BASE}/openapi/v1/remesh", body)
    return resp["result"]


def create_retexture(input_task_id: str, image_data_uri: str) -> str:
    body = {
        "input_task_id": input_task_id,
        "image_style_url": image_data_uri,
        "enable_original_uv": True,
        "enable_pbr": True,
        "ai_model": "latest",
        "target_formats": ["glb"],
    }
    resp = http("POST", f"{BASE}/openapi/v1/retexture", body)
    return resp["result"]


def download(url: str, out_path: str) -> int:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = resp.read()
    with open(out_path, "wb") as f:
        f.write(data)
    return len(data)


def process(prop_id: str, variant: int) -> None:
    src = f"{ASSETS}/{prop_id}/reference_v{variant}.png"
    dst = f"{ASSETS}/{prop_id}/mesh_v{variant}.glb"
    label = f"{prop_id} v{variant}"
    print(f"\n=== {label} ===", flush=True)
    print(f"  src: {src}")
    print(f"  dst: {dst}")

    img_uri = encode_image_data_uri(src)

    print("  step 1: image-to-3d create...")
    i23d_id = create_image_to_3d(img_uri)
    print(f"    task_id: {i23d_id}")
    poll_task("/openapi/v1/image-to-3d", i23d_id, f"{label} img2-3d")

    print("  step 2: remesh create...")
    rm_id = create_remesh(i23d_id)
    print(f"    task_id: {rm_id}")
    poll_task("/openapi/v1/remesh", rm_id, f"{label} remesh")

    print("  step 3: retexture create...")
    rt_id = create_retexture(rm_id, img_uri)
    print(f"    task_id: {rt_id}")
    final = poll_task("/openapi/v1/retexture", rt_id, f"{label} retexture")

    urls = final.get("model_urls", {})
    glb_url = urls.get("glb")
    if not glb_url:
        raise RuntimeError(f"no glb url in final response: {json.dumps(final)[:500]}")
    print(f"  step 4: download {glb_url[:80]}...")
    size = download(glb_url, dst)
    print(f"  DONE {label}: {size} bytes -> {dst}", flush=True)


def expand_targets(args: list[str]) -> list[tuple[str, int]]:
    if not args:
        return [(f"P0100{i}", v) for i in range(1, 6) for v in (1, 2, 3)]
    result: list[tuple[str, int]] = []
    for arg in args:
        if ":" in arg:
            pid, v = arg.split(":", 1)
            result.append((pid, int(v)))
        else:
            result.extend([(arg, v) for v in (1, 2, 3)])
    return result


def main() -> None:
    from concurrent.futures import ThreadPoolExecutor, as_completed

    targets = expand_targets(sys.argv[1:])
    max_workers = int(os.environ.get("MESHY_PARALLEL", "5"))
    print(f"targets ({len(targets)}): {targets}")
    print(f"parallel workers: {max_workers}")

    failures: list[tuple[str, int, str]] = []
    results: list[tuple[str, int]] = []
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(process, pid, v): (pid, v) for pid, v in targets}
        for fut in as_completed(futures):
            pid, v = futures[fut]
            try:
                fut.result()
                results.append((pid, v))
            except Exception as e:
                print(f"  FAIL {pid} v{v}: {e!r}", flush=True)
                failures.append((pid, v, str(e)))

    print(f"\ndone. {len(results)}/{len(targets)} succeeded.")
    if failures:
        print("failures:")
        for pid, v, err in failures:
            print(f"  {pid} v{v}: {err[:200]}")
        sys.exit(1)


if __name__ == "__main__":
    main()
