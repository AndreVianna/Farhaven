# Known Issues & Platform Gotchas

> **Source:** Development experience, audit findings
> **Status:** ✅ Active
> **Last Updated:** 2026-04-01

## Godot 4.x Gotchas

### INSTANCE_CUSTOM — vertex() only
`INSTANCE_CUSTOM` is only available in the `vertex()` function in Godot 4.x shaders. To use per-instance data in `fragment()`, pass it through a `varying`. This applies to ALL MultiMesh shaders.

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
grid.refresh_visibility([{"coords": pos, "radius": 2}])

# Correct
var sources: Array[Dictionary] = [{"coords": pos, "radius": 2}]
grid.refresh_visibility(sources)
```

### Scene tree wiring is not automatic
Nodes defined in specs as "child of X" must be explicitly added in `.tscn` files or via `add_child()`. Tests that instantiate systems directly may pass while the actual game has missing scene tree connections. Always verify the scene tree matches the spec.

## Project-Specific Issues

### Fog reveal ownership transition
- **delivery-001:** Player._complete_tile_transition calls refresh_visibility directly (temporary)
- **delivery-004:** DayNightCycle takes ownership of ALL refresh_visibility calls. Player's direct call must be removed and replaced with signal-driven refresh from DayNightCycle
- **Risk:** If delivery-004 doesn't explicitly remove the player's direct call, fog will refresh twice per movement

### Autoload initialization order
Godot processes autoloads in the order listed in project.godot. If systems depend on each other during _ready(), order matters:
1. HexGrid (no dependencies)
2. DayNightCycle (depends on HexGrid for visibility)
3. SaveManager (depends on all other systems for get_save_data)
