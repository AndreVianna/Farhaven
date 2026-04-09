# Known Issues & Platform Gotchas

> **Source:** Development experience, audit findings
> **Status:** Active
> **Last Updated:** 2026-04-08 (updated for delivery-005a: Props & Recipes engine)

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
1. PropRegistry (no dependencies — scans data/props/ at startup)
2. HexGrid (depends on PropRegistry for resource definitions)
3. DayNightCycle (registers hex/prop materials for lighting updates)
4. LightingManager (depends on HexGrid for structure signals, DayNightCycle for phase checks) — added delivery-005a
5. RecipeRegistry (scans data/recipes/, depends on PropRegistry) — added delivery-005a
6. DiscoveryWatcher (depends on RecipeRegistry for recipe list) — added delivery-005a
7. RecipeRuntime (depends on RecipeRegistry + DiscoveryWatcher) — added delivery-005a
8. SaveManager (depends on all other systems for get_save_data)

### Prop.Category enum kept for backward compatibility (delivery-005a)
The `Prop.Category` enum (PLANT=0..STORAGE=9) still exists in `prop.gd` and the `prop_category` field still exists on `PropDef`. These are deprecated but kept because:
- Some existing code paths still reference `prop.category` for rendering/display
- Map JSON still includes `category` in prop entries
- `HexTile.get_props_by_category()` still works but is deprecated

New code should use `PropDef.has_capability()`, `PropDef.has_tag()`, `HexTile.get_props_with_tag()`, and `HexTile.get_props_with_capability()` instead. The old Category fields will be fully removed in a future delivery.

### Legacy gather path in AutoInteractionSystem (delivery-005a)
AutoInteractionSystem still has a legacy gather fallback that uses deprecated PropDef fields (gather_time, yield_type, tool_required) for any prop not yet covered by a Recipe .tres file. This fallback should be removed once all gather interactions have corresponding recipe files.

### Deprecated PropDef fields (delivery-005a)
The following fields on PropDef are deprecated but present for backward compat: gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed, is_consumable, hunger_restore, thirst_restore, health_restore, category, prop_category, emits_light, light_radius, is_respawn_point, is_crafting_station. The Recipe system and capability model replace all of these. They will be removed in a future cleanup pass.

### PredicateEvaluator stubs (delivery-005a)
Three predicate kinds in PredicateEvaluator return false with a push_warning because their backing systems don't exist yet:
- `player_skill` — skill system not implemented
- `weather` — weather system not implemented
- `animal_nearby` — FaunaManager not implemented

`player_knows_recipe` always returns true (stub) — actual known-recipe checking is handled externally by DiscoveryWatcher.
