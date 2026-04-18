#!/usr/bin/env python3
"""Merge PlacementCap into PlaceableCap across 12 grassland .tres files.

After Andre's UX feedback, scatter preset moved from a separate
PlacementCap capability to an inline `placement` int field on
PlaceableCap. This script performs the structural migration:

1. Read the `placement = N` value from the `[sub_resource id="placement_1"]` block.
2. Inject `placement = N` into the `[sub_resource id="placeable_1"]` block.
3. Delete the `[sub_resource id="placement_1"]` block.
4. Delete the `placement_cap.gd` ext_resource line.
5. Remove the `placement = SubResource("placement_1")` line from [resource].
6. Decrement load_steps by 2 (one ext_resource + one sub_resource removed).

Idempotent — skips any file that no longer has a placement_1 sub_resource.
"""
from __future__ import annotations

import os
import re

PROPS_DIR = "/home/andre/projects/Farhaven/data/props"


def migrate(text: str) -> str:
    # Bail early if this .tres has already been migrated.
    if re.search(r'id="placement_1"', text) is None:
        return text

    # 1) Extract the preset int from placement_1 sub_resource.
    preset_match = re.search(
        r'\[sub_resource type="Resource" id="placement_1"\][^\[]*?placement\s*=\s*(-?\d+)',
        text,
        flags=re.DOTALL,
    )
    if preset_match is None:
        raise RuntimeError("placement_1 block missing placement = ... line")
    preset = int(preset_match.group(1))

    # 2) Inject `placement = N` into placeable_1 sub_resource as the last field.
    def _inject(m: re.Match) -> str:
        body = m.group(0).rstrip() + f"\nplacement = {preset}\n"
        return body

    new_text = re.sub(
        r'\[sub_resource type="Resource" id="placeable_1"\](?:[^\[]|\[(?!sub_resource|resource))*?(?=\n\n|\n\[)',
        _inject,
        text,
        count=1,
        flags=re.DOTALL,
    )

    # 3) Delete the placement_1 sub_resource block (its heading + fields
    # up to the next blank line or bracketed section).
    new_text = re.sub(
        r'\[sub_resource type="Resource" id="placement_1"\][^\[]*?(?=\n\[|\Z)',
        "",
        new_text,
        count=1,
        flags=re.DOTALL,
    )

    # 4) Delete the placement_cap.gd ext_resource line.
    new_text = re.sub(
        r'^\[ext_resource [^\]]*placement_cap\.gd[^\]]*\]\n',
        "",
        new_text,
        count=1,
        flags=re.MULTILINE,
    )

    # 5) Remove the `placement = SubResource("placement_1")` field from [resource].
    new_text = re.sub(
        r'^placement = SubResource\("placement_1"\)\n',
        "",
        new_text,
        count=1,
        flags=re.MULTILINE,
    )

    # 6) Decrement load_steps by 2.
    def _bump(m: re.Match) -> str:
        return f"load_steps={max(1, int(m.group(1)) - 2)}"
    new_text = re.sub(r"load_steps=(\d+)", _bump, new_text, count=1)

    # Tidy up any triple blank lines left behind by deletions.
    new_text = re.sub(r"\n{3,}", "\n\n", new_text)

    return new_text


def main() -> None:
    for name in sorted(os.listdir(PROPS_DIR)):
        if not name.endswith(".tres"):
            continue
        path = os.path.join(PROPS_DIR, name)
        with open(path) as f:
            text = f.read()
        new_text = migrate(text)
        if new_text == text:
            print(f"  {name}: already migrated — skipping")
            continue
        with open(path, "w") as f:
            f.write(new_text)
        preset = re.search(r"placement = (\d+)$", new_text, flags=re.MULTILINE)
        label = {0: "SINGLE", 1: "NORMAL", 2: "DENSE", 3: "SPROUTING", 4: "SPREAD"}
        print(f"  {name}: inlined placement = {label.get(int(preset.group(1)), '?') if preset else '?'}")


if __name__ == "__main__":
    main()
