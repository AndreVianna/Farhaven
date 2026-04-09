# Architecture

> **Source:** discovery-architect
> **Status:** Active
> **Last Updated:** 2026-04-08 (updated for delivery-005a: Props & Recipes engine)

> **Authoritative design spec for Props & Recipes:** `.aid/work-001-core/delivery-005a/DESIGN.md`

## Project Type

Single-player mobile game (portrait, 1080x1920). Monolithic Godot 4.6 project, not a monorepo. Ships as a single scene tree with autoload singletons. Target platforms: Android and iOS (no export presets configured yet).

## Folder Structure

```
Farhaven/
+-- scripts/           # Core game logic (57 .gd files in scripts/ + 13 in ui/), organized by system
|   +-- main.gd        # Bootstrap: loads map, wires all systems together
|   +-- audio/          # Sound effects (gather ding, craft success)
|   +-- auto_interaction/  # Proximity-based auto-gather (delegates to RecipeRuntime), auto-defend, respawn queue
|   +-- crafting/       # Legacy crafting system (being replaced by Recipe system)
|   +-- data/           # PropDef resource class + PropRegistry autoload
|   |   +-- capabilities/  # Capability inner Resources (PortableCap, PlaceableCap, etc.)
|   +-- hex/            # Hex grid core: math, tile model, biome data, map loader
|   +-- hud/            # HUD controller, stat bars, notifications, floating text
|   +-- inventory/      # Weight-based inventory with tool slots
|   +-- lighting/       # LightingManager autoload — shader-based local lighting
|   +-- player/         # Player controller (movement, camera, input, pathfinding)
|   +-- recipes/        # Recipe system: Recipe resources, RecipeRegistry, RecipeRuntime, DiscoveryWatcher, PredicateEvaluator
|   +-- rendering/      # Visual renderers (resources, labels, scan progress, fly-to-player)
|   +-- scanner/        # Scanner/catalog system (proximity auto-scan, knowledge states)
+-- scenes/            # Godot scene files (.tscn)
|   +-- main.tscn       # Root scene: game entry point
|   +-- player/         # Player character scene (player.tscn)
|   +-- ui/             # UI panel scenes (hud, inventory, catalog, crafting)
|   +-- world/          # World renderers (hex grid, resources, labels, scan progress)
+-- ui/                # UI scripts (13 .gd files): panels, slots, joystick overlay
+-- data/              # Game data resources (53 .tres + 1 .json)
|   +-- biomes/         # BiomeData .tres (5 biomes: crash_site, grassland, forest, rocky, water)
|   +-- catalog/        # CatalogEntry .tres (anomalies, fauna, flora, minerals)
|   +-- maps/           # Hand-designed map JSON (ch1.json)
|   +-- props/          # PropDef .tres (37 files: source props, items, structures, tools, consumables)
|   +-- recipes/        # Recipe .tres (16 files: gather, craft, cook, consume, passive recipes)
+-- shaders/           # GLSL shaders (3: hex_tile, icon_billboard, scan_progress)
+-- tests/             # gdUnit4 test suites (41 .gd files)
|   +-- integration/    # Delivery-level integration tests
|   +-- unit/           # Unit test files
+-- addons/            # Godot addons
|   +-- gdUnit4/        # Unit testing framework (934 files)
+-- docs/              # Design documentation (GDD, design system, mockups)
+-- .aid/              # AID methodology workspace (knowledge base, work packages)
```

## Architectural Pattern

**Component-based scene tree with signal-driven communication.** This follows the standard Godot node composition pattern rather than a classical OOP architecture like MVC or MVVM.

Evidence:
- Player systems (input, scanner, crafting, auto-interaction) are child nodes composed into scenes/player/player.tscn
- Systems communicate via Godot signals, not direct method calls between peers
- scripts/main.gd acts as the composition root, wiring signals between systems at startup
- HexGrid autoload (scripts/hex/hex_grid.gd) serves as a global event bus with 10+ signals

The pattern is closest to **Entity-Component-System** adapted for Godot scene tree:
- **Entity:** Player node with composed child systems
- **Components:** ScannerSystem, AutoInteractionSystem, CraftingSystem, PlayerInput (all child nodes)
- **System coordination:** main.gd bootstrap + HexGrid signal bus

There is also a clear **data/presentation separation:**
- Data layer: Inventory (RefCounted, no scene tree), Catalog (RefCounted), HexTile (Resource), PropDef (Resource)
- Presentation layer: HUD, InventoryPanel, CatalogPanel, CraftingPanel (all Control nodes)
- Wiring: main.gd connects data owners to presentation via connect_inventory(), connect_catalog(), connect_crafting()

## Module Boundaries

### hex/ -- Hex Grid Core
- **Files:** hex_grid.gd, hex_math.gd, hex_tile.gd, biome_data.gd, map_loader.gd, prop.gd
- **Responsibility:** Map data model, coordinate math, tile queries, traversal rules, serialization
- **Dependencies:** PropRegistry (autoload, for tag/capability queries on HexTile helper methods)
- **Consumers:** Every other module reads from HexGrid autoload
- **Updated 2026-04-08:** HexTile gained `get_props_with_tag()` and `get_props_with_capability()` methods. Old category-based behavioral code is deprecated; origin-based checks remain.

### player/ -- Player Controller
- **Files:** player.gd, player_input.gd, player_camera.gd, player_pathfinder.gd
- **Responsibility:** Joystick movement (continuous, not tile-snapping), jump/drop traversal, camera follow, touch input classification (tap vs joystick)
- **Dependencies:** HexGrid (autoload), HexMath (preload)
- **Owns:** Inventory instance (created at declaration time in player.gd line 26)

### scanner/ -- Scanner and Catalog
- **Files:** scanner_system.gd, catalog.gd, catalog_data.gd, catalog_entry.gd
- **Responsibility:** Proximity auto-scan lifecycle, passive identification on tile reveal, knowledge state tracking (UNKNOWN/ENCOUNTERED/CATALOGED), catalog data management
- **Dependencies:** HexGrid (autoload), PropRegistry (autoload)
- **Owns:** Catalog instance (RefCounted)

### auto_interaction/ -- Auto-Gather and Auto-Defend
- **Files:** auto_interaction_system.gd
- **Responsibility:** Proximity-based auto-gather (delegates to RecipeRuntime for recipe matching), auto-defend stub, auto-pickup stub, respawn queue
- **Dependencies:** HexGrid, PropRegistry, Inventory (from parent Player), Catalog (from sibling ScannerSystem), RecipeRegistry (autoload), DiscoveryWatcher (autoload), PredicateEvaluator
- **Updated 2026-04-08:** Now queries RecipeRegistry for gather recipes matching nearby props, filters by DiscoveryWatcher (known recipes) and PredicateEvaluator (conditions). Old direct gather logic removed. A legacy gather fallback path still exists for props not yet covered by recipes.

### crafting/ -- Crafting System
- **Files:** crafting_system.gd
- **Responsibility:** Recipe configuration, discovery tracking (material-based + pre-discovered), craft validation (ingredients + workbench proximity), tool production
- **Dependencies:** HexGrid (autoload), Inventory (from parent Player)

### inventory/ -- Inventory Management
- **Files:** inventory.gd
- **Responsibility:** Weight-based resource/consumable storage (12 base slots, primary constraint is weight capacity 50.0), 4 fixed tool slots, stack management, save/load
- **Dependencies:** PropRegistry (autoload, for stack size and weight lookups via PortableCap)
- **Note:** Extends RefCounted (not Node) -- pure data, not in scene tree
- **Updated 2026-04-08:** Refactored from slot-count to weight-based. `capacity_weight`, `_current_weight` fields added. Weight derived from `PropDef.portable.weight`. Items without PORTABLE default to 1.0. No hardcoded ITEM_CONFIG -- all items are PropDefs.

### data/ -- Prop Definitions and Capabilities
- **Files:** prop_def.gd, prop_registry.gd, capabilities/*.gd (7 files: portable_cap, placeable_cap, container_cap, light_cap, movable_cap, station_cap, catalogable_cap)
- **Responsibility:** Data-driven prop configuration via composable capabilities + tags. PropRegistry autoload scans data/props/*.tres at startup. Deprecated gather/consumable fields kept for backward compat.
- **Dependencies:** None
- **Updated 2026-04-08:** PropDef now carries 7 capability fields (small inner Resources) and a tags array. Old category-based fields deprecated.

### recipes/ -- Recipe System (added delivery-005a)
- **Files:** recipe.gd, recipe_input.gd, recipe_output.gd, recipe_effect.gd, recipe_condition.gd, predicate.gd, predicate_evaluator.gd, world_context.gd, recipe_registry.gd, recipe_runtime.gd, discovery_watcher.gd
- **Responsibility:** Unified Recipe system that handles crafting, gathering, cooking, consuming, burning, decaying, growing, and traps. RecipeRegistry indexes recipes from data/recipes/*.tres. RecipeRuntime executes pending recipes with sustain checks. DiscoveryWatcher manages the player's known-recipes list. PredicateEvaluator is the single source of truth for condition evaluation (15 predicate kinds).
- **Dependencies:** PropRegistry (autoload), HexGrid (autoload), DayNightCycle (autoload, for time predicates)
- **Consumers:** AutoInteractionSystem, future UI (crafting panel refresh)

### lighting/ -- Local Lighting (added delivery-005a)
- **Files:** lighting_manager.gd
- **Responsibility:** Tracks active light sources (structures with EMITS_LIGHT capability + player torch). Provides light data to terrain shader for local brightness at night. No visible effect during day phases.
- **Dependencies:** HexGrid (autoload, for structure_placed/destroyed signals), DayNightCycle (autoload, for phase checks), PropRegistry (autoload, for LightCap lookups)
- **Note:** Autoload singleton. MAX_LIGHTS = 8 for shader budget.

### rendering/ -- Visual Renderers
- **Files:** prop_renderer.gd, prop_label_renderer.gd, scan_progress_renderer.gd, fly_to_player.gd, prop_utils.gd
- **Responsibility:** 3D rendering of resource props (MultiMesh instancing), floating labels, scan progress bars, fly-to-player animation
- **Dependencies:** HexGrid (autoload), PropRegistry (autoload), ScannerSystem (signals)

### hud/ -- HUD Controller
- **Files:** hud.gd, stat_bars.gd, day_counter.gd, floating_text_manager.gd, notification_manager.gd, craft_flash.gd
- **Responsibility:** Top-level UI controller, stat display, notifications, floating text feedback
- **Dependencies:** Connected to systems via main.gd wiring

### ui/ -- UI Panels
- **Files:** inventory_panel.gd, catalog_panel.gd, crafting_panel.gd, inventory_slot_ui.gd, tool_slot_ui.gd, catalog_entry_ui.gd, recipe_entry_ui.gd, joystick_overlay.gd
- **Responsibility:** Bottom-drawer panels (inventory, catalog, crafting), individual UI element rendering, virtual joystick overlay
- **Dependencies:** Inventory, Catalog, CraftingSystem (injected via setter methods)

### audio/ -- Sound Effects
- **Files:** gather_sound.gd
- **Responsibility:** Gather ding + craft success audio
- **Dependencies:** Connected via main.gd

## Data Flow

### Game Startup
```
project.godot
  -> PropRegistry autoload (_ready: scans data/props/*.tres)
  -> HexGrid autoload (_ready: waits for load_map call)
  -> main.tscn loaded as main scene
    -> main.gd._ready()
      -> _wire_systems(): connects Player systems <-> HUD via signals
      -> HexGrid.load_map("ch1.json"): MapLoader parses JSON -> populates HexGrid._tiles
      -> _bootstrap_visible_tiles() [deferred]: ScannerSystem.bootstrap_visible()
```

### Player Movement -> World Response
```
Touch input (PlayerInput._unhandled_input)
  -> Classified as JOYSTICK drag
    -> joystick_moved signal -> Player._on_joystick_move()
      -> Player._process_walking(): continuous XZ movement
        -> Crosses tile boundary: checks HexGrid.get_traversal()
          -> WALK: move + emit tile transition
          -> JUMP/DROP: tween arc animation
          -> BLOCKED: slide along boundary
        -> _emit_tile_transition():
          -> HexGrid.tile_exited(old) + HexGrid.tile_entered(new)
          -> player_moved signal
```

### Auto-Gather Flow (updated delivery-005a)
```
AutoInteractionSystem._process() [throttled 0.1s]
  -> _check_gather_proximity()
    -> For each prop within GATHER_RADIUS on current tile + neighbors:
      -> Query RecipeRegistry.find_recipes_for_input(prop.type)
      -> Filter: DiscoveryWatcher.is_known(recipe.id)
      -> Filter: PredicateEvaluator.evaluate(condition, WorldContext)
      -> If matching recipe found:
        -> _begin_gather(): create tween timer using recipe.time
          -> auto_gather_started signal
        -> _on_gather_tween_complete():
          -> RecipeRuntime resolves outputs + effects
          -> Inventory.add_item() via output delivery
          -> auto_gather_completed signal -> HUD floating text + fly-to-player VFX
          -> If prop depleted: prop_depleted signal -> respawn queue (or regrow_* recipe)
      -> Legacy fallback: if no recipe found, uses deprecated PropDef gather fields
```

### Recipe Matching Flow (added delivery-005a)
```
World state change (prop interaction, tool equip, station enter)
  -> RecipeRegistry query (by input ref, tag, action, or station tag)
    -> Candidate recipes returned
  -> Filter by DiscoveryWatcher.is_known(recipe.id)
  -> Filter by PredicateEvaluator.evaluate(all conditions, WorldContext)
  -> If actions non-empty: wait for player action trigger
  -> If actions empty (passive): start immediately
  -> RecipeRuntime.try_start_recipe(recipe, ctx)
    -> Validate inputs available, consume them
    -> If time == 0: resolve instantly
    -> If time > 0: enqueue as PendingRecipe
      -> recipe_started signal
      -> Each tick: re-check sustain conditions
        -> Sustain fails -> cancel_recipe() -> return inputs -> recipe_cancelled signal
        -> Time elapsed -> _resolve() -> produce outputs + effects -> recipe_resolved signal
```

### Recipe Discovery Flow (added delivery-005a)
```
External event (Catalog.entry_cataloged, tool equipped, world flag changed)
  -> DiscoveryWatcher._on_entry_cataloged (or check_unlocks)
    -> For each unknown recipe with unlock_when predicates:
      -> PredicateEvaluator.evaluate(all unlock_when, context)
      -> If all pass: grant_recipe(recipe_id)
        -> recipe_unlocked signal -> HUD notification
```

### Auto-Scan Flow
```
ScannerSystem._process() [every frame]
  -> If scanning: check range, advance progress, complete if >= 1.0
  -> If not scanning: _start_nearest_scan()
    -> Scan player tile + neighbors for uncataloged entries
    -> Start timer (2-3s depending on category)
  -> On completion: catalog_entry() -> entry_cataloged signal -> renderers update labels
```

## Dependency Injection

There is no formal DI framework. Dependencies are resolved through four mechanisms:

1. **Autoload singletons** (project.godot, loaded in order):
   - PropRegistry -> scripts/data/prop_registry.gd (loaded first, no dependencies)
   - HexGrid -> scripts/hex/hex_grid.gd
   - DayNightCycle -> scripts/day_night/day_night_cycle.gd
   - LightingManager -> scripts/lighting/lighting_manager.gd (after DayNightCycle)
   - RecipeRegistry -> scripts/recipes/recipe_registry.gd (after PropRegistry + HexGrid)
   - DiscoveryWatcher -> scripts/recipes/discovery_watcher.gd (after RecipeRegistry)
   - RecipeRuntime -> scripts/recipes/recipe_runtime.gd (after DiscoveryWatcher)
   - SaveManager -> scripts/save/save_manager.gd (last — depends on all others)
   - Accessed as global names in any script (e.g., HexGrid.get_tile(coords))

2. **Scene tree composition** (parent/sibling resolution):
   - Child systems call get_parent() to access Player (auto_interaction_system.gd line 78, crafting_system.gd line 43)
   - Sibling resolution via get_parent().get_node_or_null("ScannerSystem") (auto_interaction_system.gd line 92)
   - Deferred resolution with call_deferred("_resolve_dependencies") to handle _ready() ordering

3. **Manual wiring in main.gd** (_wire_systems(), lines 23-63):
   - Fetches Player, ScannerSystem, AutoInteractionSystem, CraftingSystem, HUD
   - Calls hud.connect_inventory(inv), hud.connect_catalog(cat), hud.connect_crafting(crafting, inv)
   - Creates and attaches runtime nodes (FlyToPlayer, GatherSound)

4. **Test substitution** via nullable _grid fields:
   - Most systems have var _grid: Node = null defaulting to HexGrid in _ready() if null
   - Tests inject a mock grid before _ready() fires (e.g., player.gd line 38-39)

## Entry Points

| File | Role | Evidence |
|------|------|----------|
| scenes/main.tscn | Main scene (game start) | project.godot: run/main_scene |
| scripts/main.gd | Bootstrap: wires systems, loads map | Attached to Main node in main.tscn |
| scripts/data/prop_registry.gd | Autoload: indexes PropDef .tres files | project.godot autoload |
| scripts/hex/hex_grid.gd | Autoload: map container, signal bus, public API | project.godot autoload |
| scripts/recipes/recipe_registry.gd | Autoload: indexes Recipe .tres files, query API | project.godot autoload (added 005a) |
| scripts/recipes/discovery_watcher.gd | Autoload: manages known-recipes list | project.godot autoload (added 005a) |
| scripts/recipes/recipe_runtime.gd | Autoload: executes pending recipes, tick loop | project.godot autoload (added 005a) |
| scripts/lighting/lighting_manager.gd | Autoload: tracks active light sources | project.godot autoload (added 005a) |

## Discrepancies: Documentation vs Code

1. **Hex orientation:** scripts/hex/hex_math.gd line 5 says "Flat-top hexagon layout" and uses flat-top direction vectors. external-sources.md (line 23) states "Farhaven uses pointy-top hexagons." The code (axial_to_world formula at hex_math.gd lines 29-30 uses 3/2 * q for X) is consistent with **flat-top**, not pointy-top. The external-sources claim appears incorrect.

2. **Renderer choice:** project.godot line 49 uses mobile renderer. docs/01-godot-engine-setup.md recommends Compatibility renderer for broadest device support. These are different renderers with different device compatibility profiles. (Noted in external-sources.md lines 89-91.)

3. **Procedural vs hand-designed maps:** The GDD mentions procedural generation, but the vision pivot moved to episodic chapters with hand-designed maps loaded from JSON (data/maps/ch1.json via map_loader.gd). (Noted in project-structure.md line 157.)

4. **README describes assets/ directory** that does not exist. The game currently uses programmatic rendering (ArrayMesh, MultiMesh) with placeholder geometry. (Noted in project-structure.md line 154.)

## Lighting System (added delivery-005a)

`LightingManager` autoload tracks light sources and feeds them to the terrain shader for local brightness at night. Two types of light sources:

- **Structure lights:** Registered when a prop with `EMITS_LIGHT` capability (via LightCap) is placed. Keyed by "coords:prop_type". Unregistered on structure_destroyed.
- **Player torch:** Updated on tile enter. If any equipped tool has `emits_light` on its PropDef, the player emits light at their position.

During day phases (DAY, DAWN), `get_active_lights()` returns an empty array — the sun overrides local lights. During DUSK and NIGHT, the shader uses up to MAX_LIGHTS (8) light positions/radii.

Signals: `light_source_registered(position, radius)`, `light_source_unregistered(position)`, `light_source_moved(position)`.

Source: `scripts/lighting/lighting_manager.gd`
