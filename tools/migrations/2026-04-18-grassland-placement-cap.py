#!/usr/bin/env python3
"""Add PlacementCap to 12 grassland prop .tres files (feature-011 rollout).

Per Discord discussion: plants get NORMAL scatter (7 instances per sub-hex,
sibling scale 0.5) so grassland feels dense rather than sparse. Boulder gets
SINGLE (massive blocker, no scatter). Minor minerals get SPROUTING (7
instances, sibling 0.3 — small satellites around parent) to feel clustered
without overwhelming.

This script:
1. Adds ext_resource for placement_cap.gd if missing
2. Adds a sub_resource `placement_1` with the chosen preset
3. Sets `placement = SubResource("placement_1")` on the PropDef's [resource] block
4. Bumps load_steps

Idempotent — skips any file that already declares `placement_1` sub_resource
or a `placement = SubResource(...)` line on [resource].
"""
from __future__ import annotations

import os
import re

REPO = "/home/andre/projects/Farhaven"
PROPS_DIR = os.path.join(REPO, "data", "props")

# Preset int values match PlacementPreset.Preset enum:
#   0 = SINGLE, 1 = NORMAL, 2 = DENSE, 3 = SPROUTING, 4 = SPREAD
PRESET_NORMAL = 1
PRESET_SPROUTING = 3

# Per-prop placement.
PROPS = {
    "P00001": PRESET_NORMAL,      # Blade Grass
    "P00002": PRESET_NORMAL,      # Tuft Moss
    "P00003": PRESET_NORMAL,      # Seed Pod Bush
    "P00004": PRESET_NORMAL,      # Thorn Shrub
    "P00005": PRESET_NORMAL,      # Stalk Plant
    "P00006": PRESET_NORMAL,      # Wild Herb
    "P00007": PRESET_NORMAL,      # Spiral Fern
    # Minerals — boulder stays SINGLE (massive blocker); smaller minerals
    # scatter to read as "a cluster of ore" rather than a lone specimen.
    "P01001": 0,                  # Boulder — SINGLE
    "P01002": PRESET_SPROUTING,   # Loose Stone
    "P01003": PRESET_SPROUTING,   # Flint Deposit
    "P01004": PRESET_SPROUTING,   # Clay Patch
    "P01005": PRESET_SPROUTING,   # Iron Nodule
}


def _next_id(text: str) -> int:
    max_n = 0
    for m in re.finditer(r'id="(\d+)_', text):
        max_n = max(max_n, int(m.group(1)))
    return max_n + 1


def _already_applied(text: str) -> bool:
    if re.search(r'id="placement_1"', text):
        return True
    # [resource] block already declares placement = SubResource(...)
    m = re.search(r"\[resource\][\s\S]*$", text)
    if m and re.search(r"^placement = SubResource", m.group(0), flags=re.MULTILINE):
        return True
    return False


def patch(text: str, preset: int) -> str:
    if _already_applied(text):
        return text

    # 1) Bump load_steps by 2 (one ext_resource, one sub_resource).
    def _bump(m):
        return f"load_steps={int(m.group(1)) + 2}"
    text = re.sub(r"load_steps=(\d+)", _bump, text, count=1)

    # 2) Add ext_resource for placement_cap.gd after the last ext_resource line.
    next_n = _next_id(text)
    ext_id = f"{next_n}_placement"
    ext_line = (
        f'[ext_resource type="Script" '
        f'path="res://scripts/data/capabilities/placement_cap.gd" '
        f'id="{ext_id}"]\n'
    )
    last_ext = None
    for m in re.finditer(r"^\[ext_resource [^\]]+\]\n", text, flags=re.MULTILINE):
        last_ext = m
    if last_ext is None:
        raise RuntimeError("No ext_resource block in file")
    text = text[: last_ext.end()] + ext_line + text[last_ext.end():]

    # 3) Insert a sub_resource before the [resource] block.
    sub_block = (
        f'[sub_resource type="Resource" id="placement_1"]\n'
        f'script = ExtResource("{ext_id}")\n'
        f'placement = {preset}\n\n'
    )
    res_match = re.search(r"^\[resource\]", text, flags=re.MULTILINE)
    if res_match is None:
        raise RuntimeError("No [resource] block in file")
    text = text[: res_match.start()] + sub_block + text[res_match.start():]

    # 4) Append `placement = SubResource("placement_1")` to the [resource]
    # block after the last cap reference (simple: after the closing line
    # of the [resource] block we just added).
    text = re.sub(
        r"(\[resource\][\s\S]*?)(\Z)",
        r'\1placement = SubResource("placement_1")\n\2',
        text,
        count=1,
    )
    return text


def main() -> None:
    for prop_id, preset in PROPS.items():
        path = os.path.join(PROPS_DIR, f"{prop_id}.tres")
        with open(path) as f:
            text = f.read()
        new_text = patch(text, preset)
        if new_text == text:
            print(f"  {prop_id}: already has placement — skipping")
            continue
        with open(path, "w") as f:
            f.write(new_text)
        name = {
            0: "SINGLE", 1: "NORMAL", 2: "DENSE",
            3: "SPROUTING", 4: "SPREAD",
        }[preset]
        print(f"  {prop_id}: placement = {name}")


if __name__ == "__main__":
    main()
