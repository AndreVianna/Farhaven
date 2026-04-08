# Known Issues & Platform Gotchas

> **Source:** Development experience, audit findings
> **Status:** ✅ Active
> **Last Updated:** 2026-04-01

## Godot 4.x Gotchas

### INSTANCE_CUSTOM — vertex() only
`INSTANCE_CUSTOM` is only available in the `vertex()` function in Godot 4.x shaders. To use per-instance data in `fragment()`, pass it through a `varying`. This applies to ALL MultiMesh shaders. **Note:** The hex grid renderer (feature-001) now uses a single ArrayMesh (not MultiMesh), so this only applies to the icon/resource/structure/fauna renderers (features 003, 004, 009, 010).

**Wrong:**
```glsl
void fragment() {
    float fog = INSTANCE_CUSTOM.r; // ERROR: Unknown identifier
}
```

**Correct:**
```glsl
varying float v_fog;
varying vec3 v_highlight;

void vertex() {
    v_fog = INSTANCE_CUSTOM.r;
    v_highlight = INSTANCE_CUSTOM.gba;
}

void fragment() {
    float fog = v_fog; // Works
}
```

### Mouse input on desktop
`InputEventScreenTouch` and `InputEventScreenDrag` don't fire from mouse input by default. For desktop testing of mobile games, project.godot MUST include:
```ini
[input_devices]
pointing/emulate_touch_from_mouse=true
pointing/emulate_mouse_from_touch=true
```

### GdUnit4 + Godot 4.6 compatibility
- Headless mode requires `--ignoreHeadlessMode` flag
- HTML reporter throws cosmetic null errors (`store_string`, `delete_path_index`) — not test failures
- Tests still pass with exit code 0 despite reporter warnings

### Typed arrays in GDScript 4.x
Inline array literals like `[{"key": value}]` create untyped `Array`. If a function expects `Array[Dictionary]`, you must declare the variable first:
```gdscript
# Wrong — runtime type error
some_system.apply_overlays([{"coords": pos, "radius": 2}])

# Correct
var sources: Array[Dictionary] = [{"coords": pos, "radius": 2}]
some_system.apply_overlays(sources)
```

### Scene tree wiring is not automatic
Nodes defined in specs as "child of X" must be explicitly added in `.tscn` files or via `add_child()`. Tests that instantiate systems directly may pass while the actual game has missing scene tree connections. Always verify the scene tree matches the spec.

### .tscn sub_resource ordering
All `[sub_resource]` blocks MUST appear before the first `[node]` block in `.tscn` files. Placing them after a node corrupts the scene silently — nodes disappear with no parse error. Also update `load_steps` to count all `ext_resource` + `sub_resource` entries + 1.

**Wrong** (sub_resource after first node):
```
[node name="Root" type="Node3D"]
[sub_resource type="BoxMesh" id="box"]   # TOO LATE — scene corrupts
[node name="Child" type="MeshInstance3D" parent="."]
```

**Correct:**
```
[sub_resource type="BoxMesh" id="box"]   # Before any node
[node name="Root" type="Node3D"]
[node name="Child" type="MeshInstance3D" parent="."]
mesh = SubResource("box")
```

## Project-Specific Issues

### Autoload initialization order
Godot processes autoloads in the order listed in project.godot. If systems depend on each other during _ready(), order matters:
1. PropRegistry (no dependencies — scans data/props/ at startup, project.godot line 25)
2. HexGrid (depends on PropRegistry for resource definitions, project.godot line 26)
3. DayNightCycle (registers hex/prop materials for lighting updates)
4. SaveManager (depends on all other systems for get_save_data)
