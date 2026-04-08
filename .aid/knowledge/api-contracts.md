# API Contracts

> **Source:** discovery-integrator
> **Status:** Active
> **Last Updated:** 2026-04-03

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

### HexGrid
- **Type:** Autoload singleton
- **Purpose:** Central map container and public API for all hex grid operations. All cross-feature interaction with the hex grid goes through this node.
- **Signals:**
  - `map_generated()` -- emitted after MapLoader finishes loading a map
  - `tile_revealed(coords: Vector2i)` -- HIDDEN to non-HIDDEN transition
  - `tile_visibility_changed(coords: Vector2i, state: int)` -- any fog state change
  - `tile_entered(coords: Vector2i)` -- player entered a tile
  - `tile_exited(coords: Vector2i)` -- player exited a tile
  - `resource_depleted(coords: Vector2i, resource_type: StringName)` -- resource node exhausted
  - `resource_respawned(coords: Vector2i, resource_type: StringName)` -- resource node regenerated
  - `tile_contents_changed(coords: Vector2i)` -- generic content change
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
  - `refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]` -- fog of war update
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
- **Purpose:** Resource/consumable slots (12 base, expandable) plus 4 fixed tool slots
- **Signals:**
  - `inventory_changed()` -- any slot mutation
  - `item_added(type: StringName, amount: int)`
  - `item_removed(type: StringName, amount: int)`
  - `inventory_full(type: StringName, rejected: int)` -- overflow
  - `item_used(type: StringName)` -- consumable consumed
  - `tool_changed(slot: StringName, new_tool: StringName, old_tool: StringName)`
- **Public Methods (Resource/Consumable):**
  - `add_item(type: StringName, amount: int = 1) -> int` -- returns amount actually added
  - `remove_item(type: StringName, amount: int = 1) -> int` -- returns amount removed
  - `has_item(type: StringName, amount: int = 1) -> bool`
  - `get_count(type: StringName) -> int`
  - `get_slots() -> Array[Dictionary]` -- snapshot of all slots
  - `is_full() -> bool`
  - `get_max_slots() -> int` / `get_used_slot_count() -> int`
  - `use_item(type: StringName) -> bool` -- consume one unit
  - `expand(additional_slots: int) -> void`
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
- **Listens to:** HexGrid.tile_revealed, HexGrid.tile_visibility_changed
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
- **Purpose:** Proximity-based auto-gather, auto-defend stub, auto-pickup stub, respawn queue
- **Signals:**
  - `auto_gather_started(coords: Vector2i, resource_type: StringName)`
  - `auto_gather_completed(coords: Vector2i, resource_type: StringName, amount: int)`
  - `auto_gather_failed(coords: Vector2i, reason: StringName)` -- reasons: inventory_full
  - `auto_defend_triggered(fauna_id: int, damage: int)`
  - `ground_item_picked_up(item_name: StringName, amount: int)`
- **Public Methods:**
  - `can_gather(node: Resource, inventory: RefCounted) -> bool` -- tool gate check
- **Constants:**
  - `GATHER_RADIUS: float = 0.75` -- world-space proximity in Godot units
  - `PROXIMITY_CHECK_INTERVAL: float = 0.1` -- throttle in seconds
  - `TOOL_PRIORITY: Dictionary` -- determines gather order
  - `WEAPON_DAMAGE: Dictionary` -- damage values per equipped weapon
- **Listens to:** HexGrid.tile_entered
- **Depends on (stubbed):** FaunaManager (via /root/FaunaManager), SurvivalSystem (via /root/SurvivalSystem) -- neither exists yet
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
- **Purpose:** Single-draw-call ArrayMesh for entire hex terrain with vertex color blending and fog
- **Public Methods:**
  - `highlight_tiles(coords: Array[Vector2i], color: Color)` -- building placement preview
  - `clear_highlights()`
- **Listens to:** HexGrid.map_generated, HexGrid.tile_revealed, HexGrid.tile_visibility_changed
- **Source:** `scenes/world/hex_grid_renderer.gd`

### PropRenderer (Node3D)
- **Purpose:** MultiMesh pools for 3D resource props, one pool per PropDef
- **Listens to:** HexGrid.map_generated, HexGrid.tile_visibility_changed, HexGrid.resource_depleted, HexGrid.resource_respawned
- **Testing API:** get_pool_visible_count(), get_tile_entries(), get_pool_count(), etc.
- **Source:** `scripts/rendering/prop_renderer.gd`

### PropLabelRenderer (Node3D)
- **Purpose:** 3D marker icons above props (question mark for UNKNOWN, warning for ENCOUNTERED, none for CATALOGED)
- **Listens to:** ScannerSystem element/entry signals, HexGrid.tile_visibility_changed
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
- **Properties:** coords, biome (Biome enum), elevation, fog_state (FogState enum), structure, prop_nodes, anomaly
- **Enums:** Biome (CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER), FogState (HIDDEN, REVEALED, VISIBLE)
- **Source:** `scripts/hex/hex_tile.gd`

### PropNode (Resource)
- **Properties:** type, remaining, max_amount, tool_required, respawn_time, offset, rotation_deg
- **Source:** `scripts/hex/prop_node.gd`

### PropDef (Resource)
- **Properties:** id, display_name, gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed, max_stack, category, catalog_entry, visual properties (mesh, material, placeholder config)
- **Source:** `scripts/data/prop_def.gd`

### BiomeData (Resource)
- **Properties:** biome_name, elevation_range, resource_table, color, color_variations
- **Source:** `scripts/hex/biome_data.gd`

### CatalogEntry (Resource)
- **Properties:** entry_id, category, display_name, description, icon, properties (Dictionary)
- **Source:** `scripts/scanner/catalog_entry.gd`

### HexMath (static utility)
- **Purpose:** Pure static hex math -- no state, no dependencies
- **Constants:** HEX_SIZE = 3.0, DIRECTIONS (6 axial direction vectors)
- **Static Methods:** axial_to_cube, axial_to_world, world_to_axial, distance, get_neighbors, get_tiles_in_range, get_ring
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
    -> HexGrid.refresh_visibility
      -> HexGrid.tile_revealed / tile_visibility_changed
        -> HexGridRenderer (update terrain)
        -> PropRenderer (show/hide props)
        -> ScannerSystem (passive ID)
          -> element_* -> PropLabelRenderer
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
    -> HexGrid.resource_depleted (if remaining <= 0)
      -> PropRenderer (swap mesh)
      -> respawn_queue (if respawn_time > 0)
        -> HexGrid.resource_respawned (after timer)
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
