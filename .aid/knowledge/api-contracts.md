# API Contracts

> **Source:** discovery-integrator
> **Status:** Active
> **Last Updated:** 2026-04-09 (updated for delivery-006a: Gear hierarchy, Events, IDs, SSH, mesh collision)

This project is a Godot 4.x game (GDScript) with no web APIs, no backend, and no external services. "APIs" here means the signal and method interfaces between game systems. Communication between systems uses Godot signals (observer pattern) and direct method calls.

## Autoload Singletons (Global API)

### PropRegistry
- **Type:** Autoload singleton (initialized before HexGrid)
- **Purpose:** Indexes all PropDef .tres files from `data/props/` and provides lookup by resource type id
- **Public Methods:**
  - `get_def(type: StringName) -> PropDef` -- returns resource definition or null
  - `has_def(type: StringName) -> bool` -- checks if definition exists
  - `get_all() -> Array` -- returns all PropDef instances
  - `get_yield_type(type: StringName) -> StringName` -- resolves yield mapping (e.g., loose_rock -> stone)
  - `get_tool_speed(type: StringName, tool_name: StringName) -> float` -- tool speed multiplier
- **Source:** `scripts/data/prop_registry.gd`

### RecipeRegistry (added delivery-005a)
- **Type:** Autoload singleton (initialized after PropRegistry + HexGrid)
- **Purpose:** Indexes all Recipe .tres files from `data/recipes/` and provides query API by input, tag, action, or station
- **Public Methods:**
  - `get_recipe(id: StringName) -> Recipe` -- returns recipe by id or null
  - `get_all_recipes() -> Array` -- returns all loaded recipes
  - `find_recipes_for_input(prop_ref: StringName) -> Array` -- recipes consuming the given prop ref
  - `find_recipes_for_tag(tag: StringName) -> Array` -- recipes consuming any prop with the given tag
  - `find_recipes_for_action(action: StringName) -> Array` -- recipes triggered by the given player action
  - `find_recipes_for_station(station_tag: StringName) -> Array` -- recipes requiring a station with the given tag
- **Source:** `scripts/recipes/recipe_registry.gd`

### EventRegistry (added delivery-006a)
- **Type:** Autoload singleton (initialized after RecipeRegistry, before DiscoveryWatcher)
- **Purpose:** Indexes all GameEvent .tres files from `data/events/` and provides query/fire API. Validates E-prefix on event IDs.
- **Signals:**
  - `event_fired(event_id: StringName, event: Resource)` -- event successfully fired (count incremented)
- **Public Methods:**
  - `get_event(id: StringName) -> GameEvent` -- returns event by id or null
  - `is_active(id: StringName) -> bool` -- event exists and has fired at least once (count >= 1)
  - `try_fire(event: GameEvent) -> bool` -- increments count if can_fire, emits event_fired on success
  - `get_all_events() -> Array` -- returns all loaded GameEvent instances
  - `get_save_data() -> Dictionary` -- returns events with count > 0 as {id_string: count}
  - `load_save_data(data: Dictionary) -> void` -- restores event counts from save
- **Source:** `scripts/core/event_registry.gd`

### GameEvent (added delivery-006a)
- **Type:** Resource (extends ScriptBase → Gear)
- **Purpose:** Tracks event occurrences — milestones (max_count=1), world flags (count >= 1), discovery triggers (grant_recipe effect), cycles (max_count=0).
- **Public Methods:**
  - `is_active() -> bool` -- returns `count >= 1`
  - `can_fire() -> bool` -- returns `max_count == 0 or count < max_count`
  - `fire() -> bool` -- increments count if can_fire, returns success
  - `reset() -> void` -- resets count to 0
- **Key Fields:** `count: int` (runtime state), `max_count: int` (0=unlimited, 1=one-shot, N=limited)
- **Source:** `scripts/core/event.gd`

### CollisionHelper (added delivery-006a)
- **Type:** RefCounted with static methods (not autoload)
- **Purpose:** Generates CollisionShape3D from PropDef placeholder_mesh_type and placeholder_params. Used by BuildingSystem and StructureRenderer.
- **Public Method:**
  - `create_collision_shape(prop_def: Resource) -> CollisionShape3D` -- creates shape matching the prop's placeholder mesh (box, cylinder, sphere, cube, or fallback)
- **Supported shapes:** cube (BoxShape3D), box (BoxShape3D), cylinder (CylinderShape3D), sphere (SphereShape3D), octahedron/prism (approximated as CylinderShape3D), fallback (small BoxShape3D)
- **Source:** `scripts/core/collision_helper.gd`

### RecipeRuntime (added delivery-005a)
- **Type:** Autoload singleton (initialized after DiscoveryWatcher)
- **Purpose:** Executes recipes — matches them against the world, manages pending recipes (in-progress cooking/growing/rotting), and resolves them
- **Signals:**
  - `recipe_started(recipe_id: StringName)` -- recipe entered pending queue
  - `recipe_resolved(recipe_id: StringName, outputs: Array, effects: Array)` -- recipe completed
  - `recipe_cancelled(recipe_id: StringName, reason: StringName)` -- recipe cancelled (sustain_failed, cancelled)
  - `effect_requested(effect: Resource)` -- effect delegated to external systems (sound, fx, light, etc.)
- **Public Methods:**
  - `try_start_recipe(recipe: Recipe, ctx: WorldContext) -> PendingRecipe | null` -- validates conditions, consumes inputs, enqueues (duration > 0) or instant-resolves (duration == 0)
  - `cancel_recipe(pending: PendingRecipe, reason: StringName)` -- returns inputs, removes from queue
  - `get_pending() -> Array` -- snapshot of pending recipe queue
- **PendingRecipe inner class:** `recipe`, `start_time`, `elapsed`, `bound_inputs`, `context`
- **Tick behavior (_process):** Iterates pending recipes each frame; re-checks sustain conditions; resolves when elapsed >= duration
- **Injectable:** `_registry` (RecipeRegistry), `_discovery` (DiscoveryWatcher), `_rng` (Callable for deterministic testing)
- **Source:** `scripts/recipes/recipe_runtime.gd`

### DiscoveryWatcher (added delivery-005a, rewritten delivery-006a)
- **Type:** Autoload singleton (initialized after RecipeRegistry + EventRegistry)
- **Purpose:** Owns the player's known-recipes list. Watches EventRegistry.event_fired for `grant_recipe` effects. Re-evaluates pending discovery events on Catalog.entry_cataloged.
- **Signals:**
  - `recipe_unlocked(recipe_id: StringName)` -- recipe newly granted
- **Public Methods:**
  - `is_known(recipe_id: StringName) -> bool` -- recipe is in known list
  - `grant_recipe(recipe_id: StringName) -> void` -- directly add to known list
  - `get_known_recipes() -> Array[StringName]` -- all known recipe ids
  - `check_unlocks(ctx: WorldContext) -> void` -- re-evaluate unfired discovery events against context
  - `get_save_data() / load_save_data(data: Dictionary)` -- persistence
- **Listens to:** EventRegistry.event_fired (processes grant_recipe effects), Catalog.entry_cataloged (re-evaluates pending discovery events)
- **Injectable:** `_registry` (RecipeRegistry), `_event_registry` (EventRegistry), `_catalog` (Catalog)
- **Discovery flow:** On `_ready()`, indexes all events with `grant_recipe` effects. Recipes with NO discovery event are known from start. When events fire, grant_recipe effects add to known list.
- **Source:** `scripts/recipes/discovery_watcher.gd`

### PredicateEvaluator (added delivery-005a)
- **Type:** RefCounted with static methods (not autoload)
- **Purpose:** Single source of truth for evaluating condition predicates. Dispatches on `pred.kind` to handler functions.
- **Public Method:**
  - `evaluate(pred: Predicate, ctx: WorldContext) -> bool` -- evaluates a single predicate against world state
- **Predicate Vocabulary (15 kinds):**

| Kind | Params | Notes |
|------|--------|-------|
| `has_tool` | `{tool: StringName}` | Player has tool equipped (by id, slot name, or PropDef.tool_slot) |
| `at_station` | `{tag: StringName}` | Station prop in context has StationCap with the given tag |
| `at_tile_type` | `{tag: StringName}` | Current tile biome matches the tag |
| `player_stat` | `{stat, op, value}` | Player stat (hp/hunger/thirst) satisfies comparison |
| `player_skill` | `{skill, op, value}` | STUB — returns false with warning |
| `player_knows_recipe` | `{recipe_id}` | STUB — returns true (DiscoveryWatcher handles this externally) |
| `time_of_day` | `{phase}` | DayNightCycle.current_phase matches (DAY/DUSK/NIGHT/DAWN) |
| `weather` | `{type}` | STUB — returns false with warning |
| `biome` | `{tag}` | Tile biome enum name matches tag |
| `adjacent_to` | `{tag, count_ge}` | N+ adjacent tiles/props match tag |
| `prop_state` | `{prop, field, op, value}` | Prop instance field comparison (e.g. fireplace.is_lit) |
| `world_flag` | `{name, value}` | Named world flag in ctx.world_flags |
| `animal_nearby` | `{radius, filter}` | STUB — returns false with warning |
| `container_has` | `{ref_or_tag, count_ge}` | Container has N+ matching items |
| `cataloged` | `{prop}` | Player has cataloged the prop via ctx.catalog |

- **Source:** `scripts/recipes/predicate_evaluator.gd`

### LightingManager (added delivery-005a)
- **Type:** Autoload singleton (initialized after DayNightCycle)
- **Purpose:** Tracks active light sources (placed structures + player torch). Provides light data to terrain shader.
- **Signals:**
  - `light_source_registered(position: Vector2, radius: float)` -- light added
  - `light_source_unregistered(position: Vector2)` -- light removed
  - `light_source_moved(position: Vector2)` -- player torch position updated
- **Public Methods:**
  - `get_active_lights() -> Array[Dictionary]` -- active lights for shader ({position, radius, color}). Empty during day.
  - `get_structure_light_count() -> int` -- number of registered structure lights
  - `is_night_active() -> bool` -- whether lighting should be visually active
  - `register_light(key, position, radius, color)` -- manual registration
  - `unregister_light(key)` -- manual removal
  - `set_player_light(position, radius, color)` -- set player torch
  - `clear_player_light()` -- remove player torch
  - `update_player_torch()` -- re-check equipped tools for EMITS_LIGHT
- **Constants:** MAX_LIGHTS = 8, DEFAULT_LIGHT_COLOR = warm orange
- **Listens to:** HexGrid.structure_placed, HexGrid.structure_destroyed, HexGrid.tile_entered
- **Source:** `scripts/lighting/lighting_manager.gd`

### HexGrid
- **Type:** Autoload singleton
- **Purpose:** Central map container and public API for all hex grid operations. All cross-feature interaction with the hex grid goes through this node.
- **Signals:**
  - `map_generated()` -- emitted after MapLoader finishes loading a map
  - `tile_entered(coords: Vector2i)` -- player entered a tile
  - `tile_exited(coords: Vector2i)` -- player exited a tile
  - `prop_depleted(coords: Vector2i, prop_type: StringName)` -- prop (resource node) exhausted
  - `prop_respawned(coords: Vector2i, prop_type: StringName)` -- prop regenerated
  - `structure_placed(coords: Vector2i, structure_type: StringName)` -- structure built
  - `structure_destroyed(coords: Vector2i, structure_type: StringName)` -- structure removed
- **Public Methods:**
  - `get_tile(coords: Vector2i) -> Resource` -- returns HexTile or null
  - `get_neighbors(coords: Vector2i) -> Array[Vector2i]` -- valid neighbor tiles
  - `get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]` -- tiles within radius
  - `distance(a: Vector2i, b: Vector2i) -> int` -- hex distance
  - `is_passable(from: Vector2i, to: Vector2i) -> bool` -- traversability check
  - `get_traversal(from: Vector2i, to: Vector2i) -> int` -- TraversalType enum (WALK/JUMP/DROP/BLOCKED)
  - `get_elevation_diff(from: Vector2i, to: Vector2i) -> int` -- absolute elevation difference
  - `axial_to_world(coords: Vector2i) -> Vector2` -- coordinate conversion
  - `world_to_axial(world_pos: Vector2) -> Vector2i` -- coordinate conversion
  - `axial_to_cube(coords: Vector2i) -> Vector3i` -- coordinate conversion
  - `load_map(path: String) -> bool` -- loads a JSON map file
  - `get_save_data() -> Dictionary` -- serialization
  - `load_save_data(data: Dictionary) -> void` -- deserialization
- **Constants:**
  - `WALK_MAX_DIFF: int = 1` -- max elevation diff for walking
  - `JUMP_MAX_DIFF: int = 3` -- max elevation diff for jumping/dropping
  - `WALKABLE_STRUCTURES: Array[StringName]` -- shelter, torch, workbench, storage_chest, campfire
- **Source:** `scripts/hex/hex_grid.gd`

---

## Player System APIs

### Player (Node3D)
- **Purpose:** Player character with continuous joystick movement, tile transitions, elevation traversal
- **Signals:**
  - `player_moved(from: Vector2i, to: Vector2i)` -- tile transition completed
- **Public Methods:**
  - `get_inventory() -> Inventory` -- returns the player's inventory instance
  - `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary) -> void`
- **Key Properties:**
  - `current_tile: Vector2i` -- derived from world position via HexMath
  - `move_state: MoveState` -- IDLE, WALKING, JUMPING
  - `facing_direction: Vector2` -- current movement direction
  - `inventory: Inventory` -- owned inventory instance
- **Listens to:** HexGrid.map_generated, PlayerInput.joystick_* signals
- **Emits to:** HexGrid.tile_entered, HexGrid.tile_exited (via direct emit on the autoload)
- **Source:** `scripts/player/player.gd`

### PlayerInput (Node)
- **Purpose:** Touch input classifier -- classifies touch events as TAP or JOYSTICK
- **Signals:**
  - `tap_tile(coords: Vector2i)` -- tap on a visible/revealed tile
  - `joystick_started(direction: Vector2)` -- drag threshold crossed
  - `joystick_moved(direction: Vector2, magnitude: float)` -- continuous joystick update
  - `joystick_released()` -- touch up during joystick mode
- **Exported Config:**
  - `tap_max_duration: float = 0.3`
  - `tap_max_drag: float = 20.0`
  - `drag_threshold: float = 20.0`
- **Source:** `scripts/player/player_input.gd`

### PlayerPathfinder (RefCounted)
- **Purpose:** AStar2D wrapper for hex grid pathfinding
- **Public Methods:**
  - `setup(grid: Node) -> void` -- initializes and connects signals
  - `find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]` -- returns path or empty
- **Listens to:** HexGrid.map_generated, HexGrid.structure_placed, HexGrid.structure_destroyed
- **Source:** `scripts/player/player_pathfinder.gd`

### PlayerCamera (Camera3D)
- **Purpose:** Lerp-follow camera with map AABB clamping
- **Public Methods:**
  - `set_follow_target(target: Node3D) -> void`
- **Exported Config:**
  - `follow_speed: float = 8.0`
  - `offset: Vector3 = Vector3(0, 12, 8)`
- **Listens to:** HexGrid.map_generated (computes map bounds)
- **Source:** `scripts/player/player_camera.gd`

---

## Inventory System API

### Inventory (RefCounted)
- **Purpose:** Slot-size based resource/consumable storage (12 base slots, expandable) plus 4 fixed tool slots
- **Updated 2026-04-08:** Refactored from slot-count to slot-size based capacity. Primary constraint is `capacity_size` (default 50.0). Item size from `PropDef.portable.size` (default 1.0 if no PORTABLE cap).
- **Signals:**
  - `inventory_changed()` -- any slot mutation
  - `item_added(type: StringName, amount: int)`
  - `item_removed(type: StringName, amount: int)`
  - `inventory_full(type: StringName, rejected: int)` -- overflow (size or slot)
  - `item_used(type: StringName)` -- consumable consumed
  - `tool_changed(slot: StringName, new_tool: StringName, old_tool: StringName)`
- **Public Methods (Resource/Consumable):**
  - `add_item(type: StringName, amount: int = 1) -> int` -- returns amount actually added. Checks size + slot capacity.
  - `remove_item(type: StringName, amount: int = 1) -> int` -- returns amount removed
  - `has_item(type: StringName, amount: int = 1) -> bool`
  - `get_count(type: StringName) -> int`
  - `get_slots() -> Array[Dictionary]` -- snapshot of all slots
  - `is_full() -> bool` -- true if remaining size < smallest item or all slots at max
  - `get_max_slots() -> int` / `get_used_slot_count() -> int`
  - `use_item(type: StringName) -> bool` -- consume one unit
  - `expand(additional_slots: int) -> void`
- **Public Methods (Size — added delivery-005a):**
  - `get_current_size() -> float` -- total size of all items
  - `get_capacity_size() -> float` -- maximum size capacity
  - `get_remaining_capacity() -> float` -- capacity_size - current_size
  - `get_size_display() -> String` -- formatted string like "32.5 / 50.0"
  - `get_stacks() -> Array[Dictionary]` -- items grouped by type with count, size_per_unit, total_size
- **Public Methods (Tools):**
  - `get_tool(slot: StringName) -> StringName` -- what is equipped in axe/pickaxe/weapon/scanner
  - `set_tool(slot: StringName, tool: StringName) -> StringName` -- returns previous tool
  - `has_tool_for(slot: StringName) -> bool`
- **Tool Slots:** axe, pickaxe, weapon, scanner
- **Source:** `scripts/inventory/inventory.gd`

---

## Crafting System API

### CraftingSystem (Node)
- **Purpose:** Recipe config, discovery tracking, craft validation/execution, workbench proximity
- **Signals:**
  - `recipe_discovered(recipe_name: StringName)`
  - `craft_completed(recipe_name: StringName)`
  - `craft_failed(recipe_name: StringName, reason: StringName)` -- reasons: unknown_recipe, no_workbench, already_owned, insufficient_materials
  - `workbench_proximity_changed(near: bool)`
- **Public Methods:**
  - `craft(recipe_name: StringName) -> bool`
  - `get_discovered_recipes() -> Array[StringName]`
  - `is_recipe_discovered(recipe_name: StringName) -> bool`
  - `is_near_workbench() -> bool`
  - `get_save_data() / load_save_data(data: Dictionary)`
- **Listens to:** Inventory.item_added, HexGrid.tile_entered, HexGrid.tile_exited, HexGrid.structure_placed, HexGrid.structure_destroyed
- **Source:** `scripts/crafting/crafting_system.gd`

---

## Scanner / Catalog System API

### ScannerSystem (Node)
- **Purpose:** Proximity auto-scan lifecycle, passive identification, surprise encounters
- **Signals:**
  - `scan_started(entry_id: StringName, coords: Vector2i)`
  - `scan_progress_updated(progress: float)`
  - `scan_completed(entry_id: StringName)`
  - `scan_interrupted()`
  - `entry_cataloged(entry_id: StringName, category: int)`
  - `entry_encountered(entry_id: StringName, label: String)`
  - `knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)`
  - `surprise_cataloged(entry_id: StringName)`
  - `element_identified(coords: Vector2i, entry_id: StringName)` -- tile has CATALOGED entry
  - `element_unknown(coords: Vector2i, entry_id: StringName, category: int)` -- tile has UNKNOWN entry
  - `element_encountered(coords: Vector2i, entry_id: StringName, label: String)` -- tile has ENCOUNTERED entry
- **Public Methods:**
  - `get_catalog() -> RefCounted` -- returns Catalog instance
  - `is_scanning() -> bool`
  - `get_scan_progress() -> float`
  - `bootstrap_visible() -> void` -- initial tile identification after map load
  - `on_fauna_attacked_player(fauna_id, damage, species_type: StringName)` -- surprise catalog
  - `on_fauna_fled(fauna_id, species_type: StringName)` -- passive fauna encounter
- **Listens to:** HexGrid.map_generated (bootstrap only)
- **Source:** `scripts/scanner/scanner_system.gd`

### Catalog (RefCounted)
- **Purpose:** Knowledge state tracking for all catalog entries (flora, fauna, minerals, anomalies)
- **Signals:**
  - `entry_cataloged(entry_id: StringName, category: int)`
  - `entry_encountered(entry_id: StringName, label: String)`
  - `knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)`
- **Public Methods:**
  - `get_knowledge_state(entry_id: StringName) -> int` -- UNKNOWN/ENCOUNTERED/CATALOGED
  - `is_cataloged / is_encountered / is_known` -- convenience bool checks
  - `get_entry(entry_id: StringName) -> CatalogEntry`
  - `get_discovered_entries() -> Array`
  - `get_discovered_by_category(category: int) -> Array`
  - `get_discovery_count() -> int` / `get_total_count() -> int` / `get_discovery_text() -> String`
  - `get_encounter_label(entry_id: StringName) -> String`
  - `catalog_entry(entry_id: StringName) -> void` -- sets CATALOGED state
  - `encounter_entry(entry_id: StringName, label: String) -> void` -- sets ENCOUNTERED (fauna only)
  - `get_scannable_at(coords: Vector2i) -> StringName` -- nearest uncataloged entry at tile
  - `get_save_data() / load_save_data(data: Dictionary)`
- **Source:** `scripts/scanner/catalog.gd`

---

## Auto-Interaction System API

### AutoInteractionSystem (Node)
- **Purpose:** Proximity-based auto-gather (delegates to RecipeRuntime), auto-defend stub, auto-pickup stub, respawn queue
- **Updated 2026-04-08:** Now queries RecipeRegistry for matching gather recipes, filters by DiscoveryWatcher (known recipes) and PredicateEvaluator (conditions). Old direct gather logic replaced. Legacy gather fallback kept for props without recipes.
- **Signals:**
  - `auto_gather_started(coords: Vector2i, prop_type: StringName)`
  - `auto_gather_completed(coords: Vector2i, prop_type: StringName, amount: int)`
  - `auto_gather_failed(coords: Vector2i, reason: StringName)` -- reason variants: `&"tool_required"`, `&"inventory_full"`
  - `auto_defend_triggered(fauna_id: int, damage: int)`
  - `ground_item_picked_up(item_name: StringName, amount: int)`
- **Constants:**
  - `GATHER_RADIUS: float = 0.75` -- world-space proximity in Godot units
  - `PROXIMITY_CHECK_INTERVAL: float = 0.1` -- throttle in seconds
  - `TOOL_SLOT_PRIORITY: Dictionary` -- DEPRECATED: kept for test compat only
  - `WEAPON_DAMAGE: Dictionary` -- damage values per equipped weapon
- **Dependencies:** HexGrid (autoload), PropRegistry (autoload), RecipeRegistry (autoload), DiscoveryWatcher (autoload), PredicateEvaluator (preload), WorldContext (preload), Inventory (from parent Player), Catalog (from sibling ScannerSystem)
- **Listens to:** HexGrid.tile_entered
- **Depends on (stubbed):** FaunaManager, SurvivalSystem -- neither exists yet
- **Source:** `scripts/auto_interaction/auto_interaction_system.gd`

---

## HUD / UI APIs

### HUD (Control)
- **Purpose:** Central UI coordinator -- stat bars, panels, notifications, floating text
- **Wiring Methods (called by Main._wire_systems):**
  - `connect_inventory(inv)` -- binds inventory panel plus overflow notifications
  - `connect_catalog(cat)` -- binds catalog panel
  - `connect_crafting(crafting_system: Node, inv)` -- binds crafting panel plus recipe/craft signals
  - `connect_auto_interaction(auto_interaction: Node)` -- binds gather/defend feedback
  - `connect_sound(sound_node: Node)` -- binds audio hooks
- **Pass-through Methods:**
  - `show_text(world_pos: Vector3, text: String, color: Color, duration: float = 1.0)`
  - `show_notification(text: String, duration: float = 2.0)`
  - `update_stat(stat_name: StringName, value: float, max_value: float)`
  - `update_day(day: int)` / `update_phase(phase: String)`
  - `show_placement_label(structure_type: StringName)` / `hide_placement_label()`
- **Source:** `scripts/hud/hud.gd`

### UI Panels
- **InventoryPanel** -- bottom drawer, tool slots + resource grid, consumable tap-to-use with toxic warning. Source: `ui/inventory_panel.gd`
- **CraftingPanel** -- bottom drawer, discovered recipes with ingredient costs, three states (affordable/unaffordable/already-owned). Source: `ui/crafting_panel.gd`
- **CatalogPanel** -- bottom drawer, 4 category tabs (Flora/Fauna/Minerals/Anomalies), 3-state display (UNKNOWN/ENCOUNTERED/CATALOGED). Source: `ui/catalog_panel.gd`
- **JoystickOverlay** -- floating joystick visual (base circle + knob), driven by PlayerInput. Source: `ui/joystick_overlay.gd`
- All panels emit `panel_opened()` for mutual exclusion (only one open at a time).

### GatherSound (Node)
- **Purpose:** Audio hook for gather/craft feedback (currently silent stubs -- no AudioStream assigned)
- **Signals:** `gather_ding_played`, `craft_success_played`
- **Methods:** `play_gather_ding()`, `play_craft_success()`, `set_gather_stream(stream)`, `set_craft_stream(stream)`
- **Source:** `scripts/audio/gather_sound.gd`

---

## Rendering APIs

### HexGridRenderer (Node3D)
- **Purpose:** Single-draw-call ArrayMesh for entire hex terrain with vertex color blending
- **Public Methods:**
  - `highlight_tiles(coords: Array[Vector2i], color: Color)` -- building placement preview
  - `clear_highlights()`
- **Listens to:** HexGrid.map_generated
- **Source:** `scenes/world/hex_grid_renderer.gd`

### PropRenderer (Node3D)
- **Purpose:** MultiMesh pools for 3D resource props, one pool per PropDef
- **Listens to:** HexGrid.map_generated, HexGrid.prop_depleted, HexGrid.prop_respawned
- **Testing API:** get_pool_visible_count(), get_tile_entries(), get_pool_count(), etc.
- **Source:** `scripts/rendering/prop_renderer.gd`

### PropLabelRenderer (Node3D)
- **Purpose:** 3D marker icons above props (question mark for UNKNOWN, warning for ENCOUNTERED, none for CATALOGED)
- **Listens to:** ScannerSystem element/entry signals
- **Source:** `scripts/rendering/prop_label_renderer.gd`

### ScanProgressRenderer (Node3D)
- **Purpose:** Billboard progress bar above scan target
- **Listens to:** ScannerSystem scan lifecycle signals
- **Source:** `scripts/rendering/scan_progress_renderer.gd`

### FlyToPlayer (Node3D)
- **Purpose:** Visual feedback -- sprite tweens from resource to player on gather completion
- **Methods:** `setup(player: Node)`, `spawn_fly(coords, resource_type, grid)`
- **Source:** `scripts/rendering/fly_to_player.gd`

---

## Data Layer APIs

### HexTile (Resource)
- **Properties:** coords, biome (Biome enum), elevation, props (Array[Prop])
- **Enums:** Biome (CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER)
- **Methods (updated delivery-005a):**
  - `get_props_with_tag(tag: StringName) -> Array` -- props whose PropDef has the given tag
  - `get_props_with_capability(cap_name: StringName) -> Array` -- props whose PropDef has the given capability
  - `get_props_by_category(category: int) -> Array` -- DEPRECATED: use tag/capability queries instead
- **Source:** `scripts/hex/hex_tile.gd`

### Prop (Resource)
- **Properties:** type, sub_hex, category (Category enum), origin (Origin enum), remaining, max_amount, tool_required, respawn_time, rotation_deg
- **Removed in delivery-006a:** ~~footprint~~, ~~blocks_movement~~ (collision is mesh-based via CollisionHelper + StaticBody3D)
- **Enums:** Category (PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE, STRUCTURE, VEHICLE, EQUIPMENT, STORAGE), Origin (NATURAL, CRAFTED, HUMAN, NATIVE_ALIEN, UNKNOWN)
- **Source:** `scripts/hex/prop.gd`

### PropDef (Resource, extends Gear)
- **Properties (from Gear):** id (P-prefix), display_name, short_description, long_description
- **Properties (own):** tags (Array[StringName]), catalog_entry, catalog_category, origin, tool_slot, max_stack, footprint (deprecated)
- **Capabilities:** portable (PortableCap), placeable (PlaceableCap: rotation_snap only — footprint/blocks_movement removed in 006a), container (ContainerCap), light (LightCap), movable (MovableCap), station (StationCap), catalogable (CatalogableCap) -- each null when not present
- **Deprecated fields (kept for backward compat):** gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed, is_consumable, hunger_restore, thirst_restore, health_restore, category, prop_category, emits_light, light_radius, is_respawn_point, is_crafting_station
- **Helper methods:** `has_capability(cap_name) -> bool`, `has_tag(tag) -> bool`
- **Visual properties:** mesh, depleted_mesh, material, placeholder_* config (unchanged)
- **Source:** `scripts/data/prop_def.gd`

### BiomeData (Resource)
- **Properties:** biome_name, elevation_range, prop_table, color, color_variations
- **Source:** `scripts/hex/biome_data.gd`

### CatalogEntry (Resource)
- **Properties:** entry_id, category, display_name, description, icon, properties (Dictionary)
- **Source:** `scripts/scanner/catalog_entry.gd`

### HexMath (static utility)
- **Purpose:** Pure static hex math -- no state, no dependencies
- **Constants:** HEX_SIZE = 3.0, DIRECTIONS (6 axial direction vectors)
- **Static Methods:** axial_to_cube, axial_to_world, world_to_axial, distance, get_neighbors, get_tiles_in_range, get_ring
- **SSH Methods (added delivery-006a):** snap_to_ssh(world_pos, tile) -> {sub_hex, ssh, snapped_world}, is_valid_ssh(ssh_coords) -> bool, get_all_sshs() -> Array[Vector2i], ssh_axial_to_world(q, r) -> Vector2, world_to_ssh_axial(offset) -> Vector2i
- **Source:** `scripts/hex/hex_math.gd`

### MapLoader (RefCounted)
- **Purpose:** Loads JSON level files, creates HexTile objects, validates map integrity
- **Methods:** `load_map(path: String) -> bool`
- **Validation:** tile count 200-300, spawn tile exists as CRASH_SITE, all required biomes present, anomaly exists, reachability from spawn
- **Source:** `scripts/hex/map_loader.gd`

---

## Signal Flow Summary

### Map Load to Render Pipeline
```
MapLoader.load_map()
  -> HexGrid.map_generated
    -> HexGridRenderer._on_map_generated (rebuild terrain mesh)
    -> PropRenderer._on_map_generated (populate resource pools)
    -> PlayerPathfinder._on_map_generated (build AStar2D graph)
    -> PlayerCamera._compute_bounds (compute map AABB)
    -> Player._on_map_generated (snap to spawn)
  -> Main._bootstrap_visible_tiles (deferred)
    -> ScannerSystem.bootstrap_visible
      -> element_identified/unknown/encountered
        -> PropLabelRenderer._on_element_* (create 3D markers)
```

### Player Movement to Consequences
```
PlayerInput.joystick_* -> Player._on_joystick_*
  -> Player._emit_tile_transition
    -> HexGrid.tile_exited(old)
      -> CraftingSystem._on_tile_exited (workbench check)
    -> HexGrid.tile_entered(new)
      -> AutoInteractionSystem._on_tile_entered (auto-pickup)
      -> CraftingSystem._on_tile_entered (workbench check)
    -> Player.player_moved (informational)
```

### Auto-Gather Flow
```
AutoInteractionSystem._check_gather_proximity (every 0.1s)
  -> _find_gather_candidates (world-space proximity + catalog gate + tool gate)
  -> _begin_gather (tween timer)
    -> auto_gather_started
  -> _on_gather_tween_complete
    -> Inventory.add_item
    -> auto_gather_completed
      -> HUD (floating text)
      -> FlyToPlayer.spawn_fly (visual)
      -> GatherSound.play_gather_ding (audio)
    -> HexGrid.prop_depleted (if remaining <= 0)
      -> PropRenderer (swap mesh)
      -> respawn_queue (if respawn_time > 0)
        -> HexGrid.prop_respawned (after timer)
    -> _try_gather_nearby (chain to next resource)
```

### Scan Flow
```
ScannerSystem._process (every frame)
  -> _start_nearest_scan (proximity check, catalog gate)
    -> scan_started -> ScanProgressRenderer
  -> _update_active_scan
    -> scan_progress_updated -> ScanProgressRenderer
    -> (if out of range) scan_interrupted -> ScanProgressRenderer
  -> _complete_scan
    -> Catalog.catalog_entry
    -> scan_completed -> ScanProgressRenderer
    -> entry_cataloged -> CatalogPanel, PropLabelRenderer
```

### Crafting Flow
```
CraftingPanel -> CraftingSystem.craft
  -> validate: workbench proximity, already owned, ingredients
  -> Inventory.remove_item (consume materials)
  -> Inventory.set_tool (produce tool)
  -> craft_completed
    -> HUD (notification + flash)
    -> GatherSound.play_craft_success (audio)
    -> CraftingPanel (refresh UI)
```

---

## Discrepancies: Documentation vs Code

1. **Hex orientation.** `external-sources.md` states "pointy-top hexagons (confirmed)." Code comment in `hex_math.gd` line 5 says "Flat-top hexagon layout." The axial_to_world formula in code uses flat-top math. The external sources document is incorrect -- the code uses **flat-top**.

2. **Biomes.** The GDD lists 8 biomes (including Desert, Swamp, Ruins, Volcanic). The code implements only 5: CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER. The vision pivot narrowed scope to Chapter 1 only.

3. **Procedural generation.** The GDD says "procedurally generated hex map per playthrough." The code uses a hand-designed JSON map (data/maps/ch1.json). The vision pivot changed this to episodic chapters with designed maps.

4. **FaunaManager / SurvivalSystem.** auto_interaction_system.gd references /root/FaunaManager and /root/SurvivalSystem via get_node_or_null. Neither exists as an autoload or anywhere in the codebase. These are forward-looking stubs for features not yet implemented.
