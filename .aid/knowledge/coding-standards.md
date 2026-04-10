# Coding Standards

> **Source:** discovery-analyst
> **Status:** Active
> **Last Updated:** 2026-04-09 (updated for delivery-006a: Gear hierarchy, Events, IDs, SSH, mesh collision)

> All conventions below are inferred from code analysis unless marked CONFIRMED.

## Naming Conventions

### Files
- **snake_case** for all GDScript files: `hex_grid.gd`, `player_input.gd`, `auto_interaction_system.gd`
- **snake_case** for scene files: `hex_grid_renderer.tscn`, `catalog_panel.tscn`
- **snake_case** for data files: `crash_site.tres`, `anomaly_fragment.tres`
- **PropDef .tres files:** `P00NNN.tres` pattern (P-prefix + 5-digit zero-padded), e.g. `P00001.tres` (updated delivery-006a)
- **Recipe .tres files:** `R00NNN.tres` pattern (R-prefix + 5-digit zero-padded), e.g. `R00001.tres` (updated delivery-006a)
- **Event .tres files:** `discover_verb_noun.tres` pattern for discovery events, e.g. `discover_eat_berry.tres`, `discover_gather_tree.tres` (added delivery-006a)
- **Capability class files:** `snake_case_cap.gd`, e.g. `portable_cap.gd`, `placeable_cap.gd` (added delivery-005a)
- Test files prefixed with `test_`: `test_hex_math.gd`, `test_delivery_001.gd`
- Source: all files in `scripts/`, `ui/`, `tests/`, `data/`

### Classes
- **PascalCase** for class_name declarations: `HexMath`, `HexTile`, `BiomeData`, `PropNode`, `PlayerInput`, `AutoInteractionSystem`, `CatalogEntry`, `InventorySlotUI`, `RecipeEntryUI`
- **Capability classes** use PascalCase + `Cap` suffix: `PortableCap`, `PlaceableCap`, `ContainerCap`, `LightCap`, `MovableCap`, `StationCap`, `CatalogableCap` (added delivery-005a)
- **Gear hierarchy classes** (added delivery-006a): `Gear` (base), `ScriptBase` (extends Gear), `GameEvent` (extends ScriptBase — named GameEvent to avoid Godot's built-in Event class), `CollisionHelper`
- **Recipe system classes:** `Recipe` (extends ScriptBase), `RecipeInput`, `RecipeOutput`, `RecipeEffect`, `RecipeCondition`, `Predicate`, `WorldContext`, `PredicateEvaluator` (added delivery-005a, Recipe refactored delivery-006a)
- **Most scripts register class_name.** 30 of 41 source files use `class_name` (22 in scripts/, 8 in ui/). The 11 exceptions are: autoloads (`hex_grid.gd`, `prop_registry.gd`) which cannot use class_name due to initialization ordering, the bootstrap (`main.gd`), player core (`player.gd`, `player_camera.gd`), map loader (`map_loader.gd`), renderers (`prop_renderer.gd`, `prop_label_renderer.gd`, `scan_progress_renderer.gd`, `hex_grid_renderer.gd`), and crafting (`crafting_system.gd`).
- Source: anchored grep `^class_name` across `scripts/`, `ui/`, `scenes/world/`

### Functions
- **snake_case** for all functions: `get_tile()`, `axial_to_world()`, `_on_map_generated()`
- Private functions prefixed with underscore: `_wire_systems()`, `_snap_to_tile()`, `_rebuild_mesh()`
- Signal handlers prefixed with `_on_`: `_on_tile_entered()`, `_on_gather_tween_complete()`, `_on_craft_completed()`
- Lifecycle overrides use Godot conventions: `_ready()`, `_process()`, `_unhandled_input()`
- Source: consistent across all 44 scripts

### Variables
- **snake_case** for all variables: `current_tile`, `move_speed`, `spawn_facing_deg`
- Private variables prefixed with underscore: `_tiles`, `_grid`, `_is_gathering`, `_gather_tween`
- Constants in UPPER_SNAKE_CASE: `HEX_SIZE`, `WALK_MAX_DIFF`, `GATHER_RADIUS`, `MAX_INSTANCES`
- Source: consistent across all scripts

### Signals
- **snake_case** for signal names: `map_generated`, `tile_entered`, `auto_gather_completed`
- Signal names describe the event in past tense or present state: `craft_completed`, `inventory_full`, `workbench_proximity_changed`
- Source: all `signal` declarations in `scripts/`

### Enums
- **PascalCase** for enum names, **UPPER_SNAKE_CASE** for enum values: `Biome.CRASH_SITE`, `Prop.Origin.NATURAL`, `HexGrid.TraversalType.WALK`, `MoveState.IDLE`
- Source: `hex_tile.gd`, `hex_grid.gd`, `prop.gd`, `player.gd`, `player_input.gd`

### StringName Identifiers
- Resource types, tool names, structure names, and slot names use StringName literals: `&"wood"`, `&"stone_axe"`, `&"workbench"`, `&"axe"`
- Display names derived at runtime via `type.replace("_", " ").capitalize()`
- **Predicate kind names** (added delivery-005a): snake_case StringNames: `&"has_tool"`, `&"at_station"`, `&"player_stat"`, `&"cataloged"`, etc.
- **Tags** (added delivery-005a): `UPPER_CASE.sub_name` convention: `&"BURNABLE.log"`, `&"CONSUMABLE.edible"`, `&"METAL.iron"`. Tags are just StringNames at runtime — the dot notation is a readability convention, not a real hierarchy.
- **ID prefix convention** (added delivery-006a): All Gear IDs use a letter prefix to denote type:
  - `P` for PropDefs (e.g. `&"P00010"`)
  - `R` for Recipes (e.g. `&"R00001"`)
  - `E` for Events (e.g. `&"E0001"`)
  - `CS` for Cutscenes (future, e.g. `&"CS001"`)
  - `J` for Journal entries (future, e.g. `&"J0001"`)
  - EventRegistry asserts E-prefix on load. PropRegistry and RecipeRegistry use respective prefixes.
- **Recipe ids:** R-prefixed StringNames: `&"R00001"`, `&"R00002"` (renamed from verb_noun pattern in delivery-006a).
- **Event ids:** E-prefixed StringNames stored in `data/events/` .tres files.
- **Effect kinds:** snake_case StringNames: `&"stat_delta"`, `&"sound"`, `&"fx"`, `&"emit_light"`, `&"grant_recipe"`.
- Source: `gear.gd`, `recipe.gd`, `event.gd`, `predicate.gd`, `recipe_effect.gd`, `prop_def.gd`

## Error Handling

### Pattern: push_warning for non-fatal issues
- The codebase uses `push_warning()` for validation failures that should not crash the game but indicate data issues
- Examples: `push_warning("MapLoader: cannot open '%s'" % path)` in `map_loader.gd` line 46, `push_warning("MapLoader: tile count %d not in [%d,%d]")` in `map_loader.gd` line 143
- `push_error()` used only for critical failures: `push_error("PropRegistry: cannot open %s")` in `prop_registry.gd` line 14
- Source: `scripts/hex/map_loader.gd`, `scripts/data/prop_registry.gd`, `scripts/scanner/catalog.gd`

### Pattern: Null guards with early return
- All cross-system references check for null before use, returning silently rather than crashing
- Examples: `if tile == null: return` (pervasive), `if _grid == null: return` (pervasive), `if scanner == null: return` (`main.gd` line 73)
- has_method() checks before calling cross-system methods: `if player.has_method("get_inventory")` (`main.gd` line 31)
- has_signal() checks before connecting: `if _grid.has_signal("tile_entered")` (`crafting_system.gd` line 55)
- Source: virtually every script that references external nodes

### Pattern: No try/catch
- GDScript does not have try/catch. The codebase does not use any exception handling. All error paths use early returns and push_warning.
- Source: entire codebase

### Pattern: Validation on load, not on use
- MapLoader validates the entire map on load (tile count, biome presence, spawn tile, reachability) and logs all issues but still loads the map. Runtime code assumes data is valid.
- Source: `scripts/hex/map_loader.gd` lines 140-192

## Logging

### Framework
- Godot's built-in print system: `push_warning()` for warnings, `push_error()` for errors
- `project.godot` enables verbose stdout: `settings/stdout/verbose_stdout=true`
- No custom logging framework or log levels beyond Godot's defaults

### What Gets Logged
- Map validation issues (missing biomes, unreachable tiles, tile count out of range)
- File I/O failures (cannot open map file, JSON parse errors)
- Resource loading failures (PropRegistry cannot open directory)
- Invalid API calls (encounter_entry on non-fauna entry: `catalog.gd` line 126)
- No runtime gameplay logging (no "player moved to X", no "gathered Y")
- Source: `map_loader.gd`, `prop_registry.gd`, `catalog.gd`

### Log Format
- String interpolation with `%` operator: `"MapLoader: tile %s has invalid elevation %d" % [str(c), t.elevation]`
- Messages prefixed with system name: `"MapLoader: ..."`, `"PropRegistry: ..."`
- Source: all push_warning/push_error calls

## Configuration

### Autoloads (project.godot)
- Nine autoloads, loaded in order (updated delivery-006a):
  1. `PropRegistry` -- `scripts/data/prop_registry.gd` (scans data/props/ at startup)
  2. `HexGrid` -- `scripts/hex/hex_grid.gd` (map container singleton)
  3. `DayNightCycle` -- `scripts/day_night/day_night_cycle.gd` (time phase management)
  4. `LightingManager` -- `scripts/lighting/lighting_manager.gd` (local light tracking)
  5. `RecipeRegistry` -- `scripts/recipes/recipe_registry.gd` (scans data/recipes/ at startup)
  6. `EventRegistry` -- `scripts/core/event_registry.gd` (scans data/events/ at startup — added delivery-006a)
  7. `DiscoveryWatcher` -- `scripts/recipes/discovery_watcher.gd` (known-recipes list, watches events)
  8. `RecipeRuntime` -- `scripts/recipes/recipe_runtime.gd` (recipe execution engine)
  9. `SaveManager` -- `scripts/save/save_manager.gd` (persistence, depends on all others)
- Source: `project.godot`

### Game Constants
- Hardcoded as `const` in the relevant script, not in external config files
- Examples: `HEX_SIZE = 3.0` in `hex_math.gd`, `GATHER_RADIUS = 0.75` in `auto_interaction_system.gd`, `ELEVATION_STEP = 0.5` in `hex_grid_renderer.gd`, `SCAN_RANGE = 1` in `scanner_system.gd`
- Some constants are duplicated across files and documented as needing synchronization: `ELEVATION_SCALE` in `player.gd` says "MUST match HexGridRenderer.ELEVATION_STEP (0.5)"
- Source: all const declarations

### Tunable Parameters
- `@export` variables for editor-tunable values: `move_speed` (player.gd), `follow_speed` and `offset` (player_camera.gd), `tap_max_duration`, `tap_max_drag`, `drag_threshold` (player_input.gd), `max_radius`, `base_radius`, `knob_radius` (joystick_overlay.gd)
- Source: all `@export` declarations

### Data-Driven Configuration
- Resource definitions in `data/props/*.tres` files (scanned by PropRegistry)
- Recipe definitions in `data/recipes/*.tres` files (scanned by RecipeRegistry) — added delivery-005a
- Event definitions in `data/events/*.tres` files (scanned by EventRegistry) — added delivery-006a
- Biome definitions in `data/biomes/*.tres` files
- Catalog entries in `data/catalog/*.tres` files
- Map layout in `data/maps/ch1.json`
- ~~Recipe configuration hardcoded in `crafting_system.gd` RECIPE_CONFIG~~ — replaced by data-driven recipes in delivery-005a
- ~~Inventory item configuration hardcoded in `inventory.gd` ITEM_CONFIG~~ — removed in delivery-005a; all items are PropDefs
- Source: `data/` directory

### Secrets and Environment Variables
- None. Game is 100% offline, no network calls, no API keys, no environment variables.
- Source: entire codebase, `project.godot`

## File Organization

### Script Location Pattern
- Core game logic in `scripts/` organized by domain: `hex/`, `player/`, `inventory/`, `crafting/`, `auto_interaction/`, `scanner/`, `hud/`, `rendering/`, `audio/`, `data/`
- UI scripts in `ui/` (separate from `scripts/`) -- this is a **discrepancy** from the typical Godot convention of co-locating scripts with scenes. The project structure doc notes this as "unusual" (`project-structure.md` line 156).
- One renderer script lives with its scene: `scenes/world/hex_grid_renderer.gd` -- while all other rendering scripts are in `scripts/rendering/`. This is noted as inconsistent in `project-structure.md` line 156.
- Source: directory structure

### Scene Organization
- Scenes in `scenes/` by domain: `player/`, `ui/`, `world/`
- Main scene: `scenes/main.tscn` (entry point)
- UI scenes in `scenes/ui/` but UI scripts in `ui/` (split)
- World rendering scenes in `scenes/world/`
- Source: `scenes/` directory

### Data Organization
- All game data in `data/` organized by type: `biomes/`, `catalog/`, `maps/`, `resources/`
- Each PropDef is a separate .tres file in `data/props/`
- Each biome is a separate .tres file in `data/biomes/`
- Catalog entries grouped by category (flora.tres, fauna.tres, minerals.tres, anomalies.tres) -- each file contains multiple CatalogEntry sub-resources
- Source: `data/` directory

### Test Organization
- Tests in `tests/` with `unit/` and `integration/` subdirectories
- Unit tests named `test_{module}.gd` -- one per source module
- Integration tests named `test_delivery_{NNN}.gd` -- one per delivery milestone
- Source: `tests/` directory

### No Index Files
- No `__init__.gd` or barrel/index files. GDScript does not use module imports; scripts are loaded via `preload()` or `load()`.
- Source: entire codebase

## Code Style

### Static Typing
- **Consistent use of static type annotations** throughout the codebase
- Function return types always specified: `func _ready() -> void:`, `func get_tile(coords: Vector2i) -> Resource:`, `func distance(a: Vector2i, b: Vector2i) -> int:`
- Parameter types always specified: `func _on_tile_entered(coords: Vector2i) -> void:`
- Variable types specified on declaration: `var _tiles: Dictionary = {}`, `var _is_gathering: bool = false`
- Typed arrays used: `Array[Vector2i]`, `Array[Dictionary]`, `Array[StringName]`, `Array[Color]`
- Source: all scripts -- this is the most consistently applied convention

### Preload vs Load
- `preload()` used for script dependencies within the same project: `const _HexTile = preload("res://scripts/hex/hex_tile.gd")`
- `load()` used for runtime resource loading: `load(BIOME_DATA_PATHS[biome_int])`, `load("res://shaders/scan_progress.gdshader")`
- Preloaded scripts assigned to `const` with underscore-prefixed PascalCase name: `const _HexMath`, `const _Inventory`, `const _PropUtils`
- Source: all const preload declarations

### Dependency Injection for Testability
- External dependencies (HexGrid, PropRegistry) are stored in `var _grid: Node` with fallback to autoload in `_ready()`: `if _grid == null: _grid = HexGrid`
- This pattern is universal -- used in `player.gd`, `player_input.gd`, `crafting_system.gd`, `auto_interaction_system.gd`, `scanner_system.gd`, `prop_renderer.gd`, `prop_label_renderer.gd`, `scan_progress_renderer.gd`
- Tests inject mock objects by setting `_grid` before `_ready()` runs
- Source: all scripts that reference autoloads

### Signal-Driven Architecture
- Systems communicate via Godot signals, not direct method calls
- HexGrid emits core events: `map_generated`, `tile_entered`, `tile_exited`, `prop_depleted`, `prop_respawned`, `structure_placed`, `structure_destroyed`
- Renderers subscribe to HexGrid signals and react independently
- HUD connects to subsystem signals via `connect_*` methods
- Source: all signal declarations and connections

### Deferred Initialization
- `call_deferred()` used when initialization order matters: `_bootstrap_visible_tiles.call_deferred()` in `main.gd`, `_connect_scanner_signals.call_deferred()` in `prop_label_renderer.gd`, `call_deferred("_resolve_dependencies")` in `auto_interaction_system.gd`
- `@onready` used for child node references in scene-based scripts: `@onready var _stat_bars := $StatBars`
- Source: `main.gd`, `prop_label_renderer.gd`, `scan_progress_renderer.gd`, `auto_interaction_system.gd`, all HUD/UI scripts

### Comment Style
- **Doc comments** on classes/files: `## ClassName -- purpose description.` at top of file
- **Inline comments** explain non-obvious design decisions: why something is deferred, why a constant must match another file
- No excessive commenting -- simple code has no comments, complex logic is documented
- Section dividers using `# --- Section Name ---` pattern
- Source: all scripts

### Function Length
- Functions are generally short (5-30 lines). Largest functions are mesh-building routines: `_rebuild_mesh()` in `hex_grid_renderer.gd` (190 lines) is the outlier.
- Source: all scripts

### Async Patterns
- **Tween-based timing** for all time-delayed operations: gather duration, jump arcs, snap animations, UI transitions, fly-to-player particles
- No coroutines (`await`) in game logic -- all async via Tween callbacks
- `create_tween()` is the standard entry point; tweens are tracked in variables and killed on cancel
- Source: `player.gd`, `auto_interaction_system.gd`, `stat_bars.gd`, `notification_manager.gd`, `floating_text_manager.gd`, `fly_to_player.gd`

### Serialization Pattern
- Every stateful class provides `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary) -> void`
- Save data uses primitive types (String, int, float, Array, Dictionary) for JSON compatibility
- StringName values converted to String for serialization and back on load
- Source: `hex_grid.gd`, `player.gd`, `inventory.gd`, `crafting_system.gd`, `catalog.gd`

### Duplicate Constant Warning
- `ELEVATION_SCALE = 0.5` in `player.gd` and `ELEVATION_STEP = 0.5` in `hex_grid_renderer.gd` are documented as needing manual synchronization ("MUST match HexGridRenderer.ELEVATION_STEP"). `HEX_SIZE = 3.0` appears in `hex_math.gd`, `prop_renderer.gd`, and `prop_label_renderer.gd` independently.
- Source: `player.gd` line 18, `hex_grid_renderer.gd` line 20, `prop_renderer.gd` line 24, `prop_label_renderer.gd` line 19

## Discrepancies: Documentation vs Code

1. **Hex orientation:** `hex_math.gd` line 5 says "Flat-top hexagon layout" but `external-sources.md` line 23 says "Farhaven uses pointy-top hexagons". The conversion formulas in `hex_math.gd` (lines 26-31) use `3.0/2.0 * q` for x and `sqrt(3) * r` for y, which corresponds to **flat-top** orientation. The code is authoritative; the external-sources doc is incorrect about pointy-top.

2. **Renderer choice:** `docs/01-godot-engine-setup.md` recommends Compatibility renderer, but `project.godot` uses Mobile renderer. This is noted in `external-sources.md` as an unresolved gap.

3. **Assets directory:** `README.md` references an `assets/` directory that does not exist. The game uses programmatic rendering. Noted in `project-structure.md`.
