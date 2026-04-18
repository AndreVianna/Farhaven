#!/usr/bin/env python3
"""Patch 12 prop .tres files with scale + collision_shapes.

For walkthrough props, only the three MeshVariant scale values are
updated. For props with authored collision, additionally:
- Increments load_steps in the gd_resource header
- Adds one ext_resource line for collision_shape.gd script
- Inserts a [sub_resource] block per collision primitive
- Appends a collision_shapes Array[Resource] to the placeable sub_resource
"""
import re
import os
import sys

REPO = "/home/andre/projects/Farhaven"
PROPS_DIR = os.path.join(REPO, "data", "props")

# Per-prop plan: (scale, collision_shapes).
# collision_shapes is a list of (shape_type, (sx, sy, sz), (ox, oy, oz)).
# Empty list = walkthrough.
PROPS = {
    "P00001": (0.35, []),                                                              # Blade Grass
    "P00002": (0.25, []),                                                              # Tuft Moss
    "P00003": (0.85, [("cylinder", (0.15, 0.40, 0.0), (0.0, 0.20, 0.0))]),             # Seed Pod Bush
    "P00004": (1.00, [("cylinder", (0.18, 0.50, 0.0), (0.0, 0.25, 0.0))]),             # Thorn Shrub
    "P00005": (1.10, [("cylinder", (0.05, 0.60, 0.0), (0.0, 0.30, 0.0))]),             # Stalk Plant
    "P00006": (0.55, []),                                                              # Wild Herb
    "P00007": (0.80, [("cylinder", (0.04, 0.30, 0.0), (0.0, 0.15, 0.0))]),             # Spiral Fern
    "P01001": (1.20, [("cylinder", (0.35, 0.40, 0.0), (0.0, 0.20, 0.0))]),             # Boulder
    "P01002": (0.45, [("box",      (0.25, 0.15, 0.25), (0.0, 0.075, 0.0))]),           # Loose Stone
    "P01003": (0.35, [("cylinder", (0.20, 0.20, 0.0), (0.0, 0.10, 0.0))]),             # Flint Deposit
    "P01004": (0.55, []),                                                              # Clay Patch
    "P01005": (0.30, [("box",      (0.25, 0.20, 0.25), (0.0, 0.10, 0.0))]),            # Iron Nodule
}


def patch_scale(text: str, new_scale: float) -> str:
    """Replace all `scale = 1.0` lines (MeshVariant fields) with the new value.

    Only MeshVariant sub_resources carry a scale; PlaceableCap does not.
    """
    return re.sub(r"^scale = 1\.0$", f"scale = {new_scale}", text, flags=re.MULTILINE)


def _next_id_prefix(text: str) -> int:
    """Find the largest numeric prefix used in ExtResource ids (e.g. '9_mesh_v3')."""
    max_n = 0
    for m in re.finditer(r'id="(\d+)_', text):
        n = int(m.group(1))
        if n > max_n:
            max_n = n
    return max_n + 1


def _format_vec3(v):
    return f"Vector3({v[0]}, {v[1]}, {v[2]})"


def add_collision_shapes(text: str, shapes: list) -> str:
    if not shapes:
        return text

    # 1) Bump load_steps.
    def _bump(m):
        n = int(m.group(1))
        # +1 for the collision_shape.gd ext_resource, +N for sub_resources.
        return f"load_steps={n + 1 + len(shapes)}"
    text = re.sub(r"load_steps=(\d+)", _bump, text, count=1)

    # 2) Add ext_resource for collision_shape.gd, just before the first
    #    blank line after the existing ext_resource block.
    next_n = _next_id_prefix(text)
    collision_script_id = f'{next_n}_collision'
    ext_line = f'[ext_resource type="Script" path="res://scripts/data/capabilities/collision_shape.gd" id="{collision_script_id}"]\n'

    # Find the last ext_resource line and insert right after it.
    last_ext_match = None
    for m in re.finditer(r'^\[ext_resource [^\]]+\]\n', text, flags=re.MULTILINE):
        last_ext_match = m
    if last_ext_match is None:
        raise RuntimeError("No ext_resource block found")
    insert_at = last_ext_match.end()
    text = text[:insert_at] + ext_line + text[insert_at:]

    # 3) Add one sub_resource per collision shape, inserted just before the
    #    placeable_1 sub_resource.
    sub_blocks = []
    sub_ids = []
    for i, (stype, size, offset) in enumerate(shapes, start=1):
        sid = f"collision_{i}"
        sub_ids.append(sid)
        block = (
            f'[sub_resource type="Resource" id="{sid}"]\n'
            f'script = ExtResource("{collision_script_id}")\n'
            f'shape_type = &"{stype}"\n'
            f'size = {_format_vec3(size)}\n'
            f'offset = {_format_vec3(offset)}\n'
        )
        sub_blocks.append(block)
    sub_text = "\n".join(sub_blocks) + "\n"

    # Find "[sub_resource type=\"Resource\" id=\"placeable_1\"]" and insert before it.
    placeable_match = re.search(r'^\[sub_resource type="Resource" id="placeable_1"\]', text, flags=re.MULTILINE)
    if placeable_match is None:
        raise RuntimeError("No placeable_1 sub_resource found")
    insert_at = placeable_match.start()
    text = text[:insert_at] + sub_text + text[insert_at:]

    # 4) Append collision_shapes line inside the placeable_1 sub_resource,
    #    right after its `meshes = Array[Resource]([...])` line.
    refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
    line = f"collision_shapes = Array[Resource]([{refs}])"

    # Match the meshes= line (which contains nested parens from SubResource(...)).
    # Anchor: the line appears inside the placeable_1 sub_resource body.
    placeable_re = re.compile(
        r'(\[sub_resource type="Resource" id="placeable_1"\][^\[]*?meshes = Array\[Resource\]\(\[.*?\]\))',
        flags=re.DOTALL,
    )
    m = placeable_re.search(text)
    if m is None:
        raise RuntimeError("Could not locate placeable_1 meshes= line")
    insert_at = m.end()
    text = text[:insert_at] + "\n" + line + text[insert_at:]

    return text


def main():
    for prop_id, (scale, shapes) in PROPS.items():
        path = os.path.join(PROPS_DIR, f"{prop_id}.tres")
        with open(path) as f:
            text = f.read()

        new_text = patch_scale(text, scale)
        new_text = add_collision_shapes(new_text, shapes)

        if new_text == text:
            print(f"  {prop_id}: no changes (already patched?)")
            continue

        with open(path, "w") as f:
            f.write(new_text)

        note = f"scale={scale}"
        if shapes:
            note += f", {len(shapes)} collision shape(s)"
        else:
            note += ", walkthrough"
        print(f"  {prop_id}: {note}")


if __name__ == "__main__":
    main()
