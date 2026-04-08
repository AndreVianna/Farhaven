# Architecture

> **Source:** discovery-architect
> **Status:** Active
> **Last Updated:** 2026-04-03

## Project Type

Single-player mobile game (portrait, 1080x1920). Monolithic Godot 4.6 project, not a monorepo. Ships as a single scene tree with autoload singletons. Target platforms: Android and iOS (no export presets configured yet).

## Folder Structure

```
Farhaven/
+-- scripts/           # Core game logic (32 .gd files), organized by system
|   +-- main.gd        # Bootstrap: loads map, wires all systems together
|   +-- audio/          # Sound effects (gather ding, craft success)
|   +-- auto_interaction/  # Proximity-based auto-gather, auto-defend, respawn queue
|   +-- crafting/       # Recipe config, discovery tracking, craft validation
|   +-- data/           # PropDef resource class + PropRegistry autoload
|   +-- hex/            # Hex grid core: math, tile model, biome data, map loader
|   +-- hud/            # HUD controller, stat bars, notifications, floating text
|   +-- inventory/      # Slot-based inventory with tool slots
|   +-- player/         # Player controller (movement, camera, input, pathfinding)
|   +-- rendering/      # Visual renderers (resources, labels, scan progress, fly-to-player)
|   +-- scanner/        # Scanner/catalog system (proximity auto-scan, knowledge states)
+-- scenes/            # Godot scene files (.tscn)
|   +-- main.tscn       # Root scene: game entry point
|   +-- player/         # Player character scene (player.tscn)
|   +-- ui/             # UI panel scenes (hud, inventory, catalog, crafting)
|   +-- world/          # World renderers (hex grid, resources, labels, scan progress)
+-- ui/                # UI scripts (8 .gd files): panels, slots, joystick overlay
+-- data/              # Game data resources
|   +-- biomes/         # BiomeData .tres (5 biomes: crash_site, grassland, forest, rocky, water)
|   +-- catalog/        # CatalogEntry .tres (anomalies, fauna, flora, minerals)
|   +-- maps/           # Hand-designed map JSON (ch1.json)
|   +-- resources/      # PropDef .tres (9 files: wood, stone, berries, etc.)
+-- shaders/           # GLSL shaders (3: hex_tile, icon_billboard, scan_progress)
+-- tests/             # gdUnit4 test suites (23 .gd files)
|   +-- integration/    # 3 delivery-level integration tests
|   +-- unit/           # 20 unit test files
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
- **Files:** hex_grid.gd, hex_math.gd, hex_tile.gd, biome_data.gd, map_loader.gd, prop_node.gd
- **Responsibility:** Map data model, coordinate math, tile queries, fog of war, traversal rules, serialization
- **Dependencies:** None (self-contained)
- **Consumers:** Every other module reads from HexGrid autoload

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
- **Responsibility:** Continuous world-space proximity gathering (throttled 0.1s checks), tool gating, respawn queue, auto-defend stub, auto-pickup stub
- **Dependencies:** HexGrid, PropRegistry, Inventory (from parent Player), Catalog (from sibling ScannerSystem)
- **Cross-module:** Resolves sibling dependencies via call_deferred("_resolve_dependencies") (auto_interaction_system.gd line 81)

### crafting/ -- Crafting System
- **Files:** crafting_system.gd
- **Responsibility:** Recipe configuration, discovery tracking (material-based + pre-discovered), craft validation (ingredients + workbench proximity), tool production
- **Dependencies:** HexGrid (autoload), Inventory (from parent Player)

### inventory/ -- Inventory Management
- **Files:** inventory.gd
- **Responsibility:** Slot-based resource/consumable storage (12 base slots), 4 fixed tool slots, stack management, save/load
- **Dependencies:** PropRegistry (autoload, for stack size lookups)
- **Note:** Extends RefCounted (not Node) -- pure data, not in scene tree

### data/ -- Resource Definitions
- **Files:** prop_def.gd, prop_registry.gd
- **Responsibility:** Data-driven resource configuration (gather time, yield type, tool speed, visual params). PropRegistry autoload scans data/props/*.tres at startup.
- **Dependencies:** None

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
          -> HexGrid.tile_exited(old) + tile_entered(new)
          -> HexGrid.refresh_visibility() -> fog updates -> renderer rebuilds
          -> player_moved signal
```

### Auto-Gather Flow
```
AutoInteractionSystem._process() [throttled 0.1s]
  -> _check_gather_proximity()
    -> _find_gather_candidates(): scan player tile + 6 neighbors
      -> Filter: world-space distance < GATHER_RADIUS (0.75u)
      -> Filter: catalog gate (must be CATALOGED)
      -> Filter: tool gate (inventory tool match)
    -> Sort by tool priority desc, distance asc
    -> _begin_gather(): create tween timer (effective_time = base * tool_speed)
      -> auto_gather_started signal
    -> _on_gather_tween_complete():
      -> Resolve yield_type (e.g. loose_rock -> stone)
      -> Inventory.add_item()
      -> auto_gather_completed signal -> HUD floating text + fly-to-player VFX
      -> If depleted: resource_depleted signal -> add to respawn queue
      -> Chain: re-check for next nearby resource
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

1. **Autoload singletons** (project.godot lines 25-26):
   - PropRegistry -> scripts/data/prop_registry.gd (loaded first)
   - HexGrid -> scripts/hex/hex_grid.gd
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
| scenes/main.tscn | Main scene (game start) | project.godot line 19: run/main_scene |
| scripts/main.gd | Bootstrap: wires systems, loads map | Attached to Main node in main.tscn line 14 |
| scripts/data/prop_registry.gd | First autoload: indexes resource .tres files | project.godot line 25 |
| scripts/hex/hex_grid.gd | Second autoload: map container, signal bus, public API | project.godot line 26 |

## Discrepancies: Documentation vs Code

1. **Hex orientation:** scripts/hex/hex_math.gd line 5 says "Flat-top hexagon layout" and uses flat-top direction vectors. external-sources.md (line 23) states "Farhaven uses pointy-top hexagons." The code (axial_to_world formula at hex_math.gd lines 29-30 uses 3/2 * q for X) is consistent with **flat-top**, not pointy-top. The external-sources claim appears incorrect.

2. **Renderer choice:** project.godot line 49 uses mobile renderer. docs/01-godot-engine-setup.md recommends Compatibility renderer for broadest device support. These are different renderers with different device compatibility profiles. (Noted in external-sources.md lines 89-91.)

3. **Procedural vs hand-designed maps:** The GDD mentions procedural generation, but the vision pivot moved to episodic chapters with hand-designed maps loaded from JSON (data/maps/ch1.json via map_loader.gd). (Noted in project-structure.md line 157.)

4. **README describes assets/ directory** that does not exist. The game currently uses programmatic rendering (ArrayMesh, MultiMesh) with placeholder geometry. (Noted in project-structure.md line 154.)
