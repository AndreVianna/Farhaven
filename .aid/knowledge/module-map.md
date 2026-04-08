# Module Map

> **Source:** discovery-analyst
> **Status:** Active
> **Last Updated:** 2026-04-03

## Bootstrap (main.gd)
- **Path:** `scripts/main.gd`
- **Purpose:** Entry point. Loads the map, wires all subsystems together (player, scanner, auto-interaction, crafting, HUD, sound, fly-to-player visual effect). Bootstraps initial visible tiles for passive identification.
- **Size:** 1 file, 76 lines
- **Dependencies:**
  - Internal: `rendering/fly_to_player.gd`, `audio/gather_sound.gd`, HexGrid autoload
  - External: Godot Node
- **Test Coverage:** Covered indirectly by `tests/integration/test_delivery_001.gd` (572 lines) -- no dedicated unit test
- **Key Files:**
  - `scripts/main.gd` -- bootstrap, signal wiring, deferred tile initialization

## Hex Grid Core
- **Path:** `scripts/hex/`
- **Purpose:** Hex coordinate math, tile data model, biome definitions, map loading, resource node model. The foundational data layer for the game world. HexGrid is the sole autoload singleton exposing map queries, traversal checks, fog of war, and coordinate conversions.
- **Size:** 6 files, 552 lines
- **Dependencies:**
  - Internal: `data/prop_def.gd` (via PropRegistry autoload, for tool_required and respawn_time in MapLoader)
  - External: Godot Resource, RefCounted, FileAccess, JSON
- **Test Coverage:** `test_hex_math.gd` (138 lines), `test_map_loader.gd` (342 lines), `test_biome_data.gd` (29 lines)
- **Key Files:**
  - `hex_grid.gd` -- autoload singleton, tile dictionary, signals, traversal, fog of war, serialization (220 lines)
  - `hex_math.gd` -- pure static math: axial/cube conversions, distance, neighbors, ring, range (92 lines)
  - `hex_tile.gd` -- tile data resource: coords, biome enum, elevation, props (unified) (26 lines)
  - `map_loader.gd` -- loads JSON maps, creates tiles, validates reachability (193 lines)
  - `biome_data.gd` -- per-biome config resource: color, prop_table, elevation_range (11 lines)
  - `prop.gd` -- per-tile prop instance: type, category, origin, remaining, max_amount, tool_required, respawn_time, sub_hex, rotation, blocks_movement (replaces deprecated prop_node.gd)

## Data Layer
- **Path:** `scripts/data/`
- **Purpose:** Resource definitions and the PropRegistry autoload. Defines all gatherable resource types with their properties (gather time, tool requirements, yield mappings, stack sizes, visual placeholders). PropRegistry scans `data/props/` at startup and indexes all definitions.
- **Size:** 2 files, 88 lines
- **Dependencies:**
  - Internal: `data/props/*.tres` (9 resource definition files)
  - External: Godot Resource, DirAccess
- **Test Coverage:** No dedicated unit test. Exercised indirectly by auto-gather, crafting, and scanner tests.
- **Key Files:**
  - `prop_def.gd` -- PropDef schema: id, display_name, gather_time, tool_required, respawn_time, yield_type, tool_speed, max_stack, catalog_entry, visual placeholder config (40 lines)
  - `prop_registry.gd` -- autoload singleton, scans data/props/, provides get_def/has_def/get_yield_type/get_tool_speed (48 lines)

## Player
- **Path:** `scripts/player/`
- **Purpose:** Player character controller, continuous joystick movement with tile transitions, jump/drop arcs, slide-along-boundary, camera follow, touch input classification (tap vs joystick), and A* pathfinding.
- **Size:** 4 files, 663 lines
- **Dependencies:**
  - Internal: `hex/hex_math.gd`, `inventory/inventory.gd`, HexGrid autoload
  - External: Godot Node3D, Camera3D, AStar2D, Tween
- **Test Coverage:** `test_player.gd` (312 lines), `test_player_input.gd` (228 lines)
- **Key Files:**
  - `player.gd` -- movement state machine (IDLE/WALKING/JUMPING), joystick-driven continuous movement, elevation interpolation, tile transitions, serialization (340 lines)
  - `player_input.gd` -- touch classifier (tap vs joystick via duration/drag thresholds), screen-to-axial raycast (158 lines)
  - `player_camera.gd` -- lerp-follow camera with map AABB clamping (61 lines)
  - `player_pathfinder.gd` -- AStar2D wrapper, graph built on map_generated, updated on structure changes (104 lines)

## Inventory
- **Path:** `scripts/inventory/`
- **Purpose:** Inventory data layer with slot-based resource/consumable storage (12 base slots, expandable) and 4 fixed tool slots. Stack-based with configurable max_stack. Owned by Player, not in scene tree.
- **Size:** 1 file, 220 lines
- **Dependencies:**
  - Internal: PropRegistry autoload (for resource max_stack and category lookups)
  - External: Godot RefCounted
- **Test Coverage:** `test_inventory.gd` (447 lines)
- **Key Files:**
  - `inventory.gd` -- slot management, add/remove/use items, tool API, serialization (220 lines)

## Crafting
- **Path:** `scripts/crafting/`
- **Purpose:** Recipe-based crafting system. Owns recipe configuration, discovery tracking (material-triggered + pre-discovered), craft validation (ingredients, workbench proximity, already-owned check), and workbench adjacency detection.
- **Size:** 1 file, 190 lines
- **Dependencies:**
  - Internal: `inventory/inventory.gd`, HexGrid autoload
  - External: Godot Node
- **Test Coverage:** `test_crafting_system.gd` (504 lines), `test_crafting_panel.gd` (431 lines)
- **Key Files:**
  - `crafting_system.gd` -- recipe config (stone_axe, stone_pickaxe), discovery, craft validation, workbench proximity (190 lines)

## Auto-Interaction
- **Path:** `scripts/auto_interaction/`
- **Purpose:** Proximity-based automatic resource gathering, auto-defend (stub), auto-pickup (stub). Continuously checks player position against nearby resources within GATHER_RADIUS (0.75 world units). Handles tool gating, catalog gating, gather timing via tweens, resource depletion, and respawn queue.
- **Size:** 1 file, 409 lines
- **Dependencies:**
  - Internal: `inventory/inventory.gd`, `hex/prop.gd`, `hex/hex_tile.gd`, `scanner/catalog.gd`, `rendering/prop_utils.gd`, `hex/hex_math.gd`, PropRegistry autoload, HexGrid autoload
  - External: Godot Node, Tween
- **Test Coverage:** `test_auto_gather.gd` (781 lines), `test_auto_interaction_stubs.gd` (639 lines), `test_auto_interaction_system.gd` (235 lines)
- **Key Files:**
  - `auto_interaction_system.gd` -- proximity gather, tool/catalog gating, respawn queue, auto-defend stub, auto-pickup stub (409 lines)

## Scanner / Catalog
- **Path:** `scripts/scanner/`
- **Purpose:** Scanner system manages proximity auto-scan lifecycle (start/progress/complete/interrupt), passive identification on tile reveal, and surprise encounters. Catalog is the data layer tracking knowledge states (UNKNOWN/ENCOUNTERED/CATALOGED) for all discoverable entities.
- **Size:** 4 files, 470 lines
- **Dependencies:**
  - Internal: `hex/hex_tile.gd`, PropRegistry autoload, HexGrid autoload, `data/catalog/*.tres`
  - External: Godot Node, RefCounted, Resource
- **Test Coverage:** `test_scanner_system.gd` (558 lines), `test_catalog.gd` (492 lines), `test_catalog_panel_ui.gd` (300 lines)
- **Key Files:**
  - `scanner_system.gd` -- auto-scan lifecycle, passive identification, surprise encounter hooks (244 lines)
  - `catalog.gd` -- knowledge state tracking, scan eligibility, save/load (210 lines)
  - `catalog_data.gd` -- container resource for CatalogEntry arrays (7 lines)
  - `catalog_entry.gd` -- entry schema: entry_id, category, display_name, description, icon, properties (9 lines)

## HUD
- **Path:** `scripts/hud/`
- **Purpose:** HUD controller and sub-components. Manages stat bars (HP/Hunger/Thirst), day counter, floating text, notifications, craft flash effect. Acts as single entry point for all UI feedback wiring (inventory, catalog, crafting, auto-interaction, sound).
- **Size:** 6 files, 411 lines
- **Dependencies:**
  - Internal: `crafting/crafting_system.gd` (signals), `auto_interaction/auto_interaction_system.gd` (signals), `inventory/inventory.gd` (signals)
  - External: Godot Control, VBoxContainer, HBoxContainer, ProgressBar, Label, ColorRect, PanelContainer, Tween
- **Test Coverage:** `test_feedback_wiring.gd` (458 lines) -- tests HUD signal wiring
- **Key Files:**
  - `hud.gd` -- master controller, panel mutual exclusion, all connect_* methods (181 lines)
  - `stat_bars.gd` -- HP/Hunger/Thirst progress bars with color-coded thresholds (70 lines)
  - `notification_manager.gd` -- queued notification toast system (59 lines)
  - `floating_text_manager.gd` -- world-space floating text (+1 Wood, INVENTORY FULL) (47 lines)
  - `day_counter.gd` -- day number + phase color indicator (30 lines)
  - `craft_flash.gd` -- fullscreen white flash on craft success (24 lines)

## Rendering
- **Path:** `scripts/rendering/` + `scenes/world/hex_grid_renderer.gd`
- **Purpose:** All 3D visual rendering. HexGridRenderer builds a single-draw-call ArrayMesh for terrain with per-vertex color blending and cliff faces. PropRenderer uses MultiMesh pools per resource type. PropLabelRenderer shows marker icons (unknown/encountered/cataloged). ScanProgressRenderer shows a shader-based progress bar. FlyToPlayer animates gathered resource particles to the player.
- **Size:** 6 files, 1,348 lines (1,006 in scripts/rendering/ + 342 in scenes/world/)
- **Dependencies:**
  - Internal: `hex/hex_tile.gd`, `hex/hex_math.gd`, `scanner/catalog.gd`, `rendering/prop_utils.gd`, PropRegistry autoload, HexGrid autoload, `shaders/*.gdshader`
  - External: Godot Node3D, MeshInstance3D, MultiMeshInstance3D, ArrayMesh, SurfaceTool, ShaderMaterial, Label3D, StandardMaterial3D, Tween
- **Test Coverage:** `test_hex_grid_renderer.gd` (197 lines), `test_prop_renderer.gd` (378 lines), `test_prop_renderers.gd` (231 lines), `test_scan_progress_renderer.gd` (171 lines)
- **Key Files:**
  - `hex_grid_renderer.gd` -- single ArrayMesh terrain with corner color blending, cliff faces, fog dimming, highlights (342 lines)
  - `prop_renderer.gd` -- MultiMesh pools per PropDef, placeholder meshes, depleted/respawned swaps (473 lines)
  - `prop_label_renderer.gd` -- Label3D markers for unknown/encountered props (240 lines)
  - `scan_progress_renderer.gd` -- shader-based scan progress bar billboard (150 lines)
  - `fly_to_player.gd` -- arc-tween particle from resource to player on gather (111 lines)
  - `prop_utils.gd` -- shared offset/entry_id utilities (32 lines)

## Audio
- **Path:** `scripts/audio/`
- **Purpose:** Sound stub for gather and craft feedback. Currently silent (no AudioStream resources assigned), but the hook infrastructure is wired and emits signals for testing.
- **Size:** 1 file, 52 lines
- **Dependencies:**
  - External: Godot Node, AudioStreamPlayer
- **Test Coverage:** Covered indirectly by `test_feedback_wiring.gd`
- **Key Files:**
  - `gather_sound.gd` -- AudioStreamPlayer stubs for gather_ding and craft_success (52 lines)

## UI Panels
- **Path:** `ui/`
- **Purpose:** Bottom-drawer UI panels for inventory, crafting, and catalog. Plus joystick overlay and slot/entry display components. All built programmatically (no .tscn for individual widgets).
- **Size:** 8 files, 955 lines
- **Dependencies:**
  - Internal: `inventory/inventory.gd`, `crafting/crafting_system.gd`, `scanner/catalog.gd`, `scanner/catalog_entry.gd`, PropRegistry autoload
  - External: Godot PanelContainer, Control, GridContainer, VBoxContainer, HBoxContainer, TabContainer, Button, Label, ColorRect, ConfirmationDialog, ScrollContainer
- **Test Coverage:** `test_crafting_panel.gd` (431 lines), `test_catalog_panel_ui.gd` (300 lines) -- inventory panel tested indirectly via integration tests
- **Key Files:**
  - `inventory_panel.gd` -- bottom drawer with tool slots row + resource grid, consumable tap with toxic confirmation dialog (166 lines)
  - `crafting_panel.gd` -- recipe list with craft button states (affordable/unaffordable/owned) (130 lines)
  - `catalog_panel.gd` -- tabbed 4-category discovery viewer (108 lines)
  - `joystick_overlay.gd` -- floating virtual joystick visual (66 lines)
  - `inventory_slot_ui.gd` -- single resource slot with color-coded icon and quantity (117 lines)
  - `recipe_entry_ui.gd` -- single recipe row with ingredient cost display (174 lines)
  - `catalog_entry_ui.gd` -- single catalog entry with 2-mode display (cataloged/encountered) (117 lines)
  - `tool_slot_ui.gd` -- single tool slot display (77 lines)

## Shaders
- **Path:** `shaders/`
- **Purpose:** Custom GLSL shaders for hex terrain, billboard icons, and scan progress overlay.
- **Size:** 3 files, 85 lines
- **Dependencies:**
  - External: Godot Shading Language
- **Test Coverage:** No shader-specific tests (visual correctness only)
- **Key Files:**
  - `hex_tile.gdshader` -- terrain vertex color with fog of war (23 lines)
  - `icon_billboard.gdshader` -- billboard orientation for prop icons (36 lines)
  - `scan_progress.gdshader` -- horizontal progress bar fill via UV (26 lines)

## Game Data
- **Path:** `data/`
- **Purpose:** Static game data files: biome definitions, catalog entries, resource definitions, and hand-designed map.
- **Size:** 19 files (5 biome .tres, 4 catalog .tres, 9 resource .tres, 1 map .json)
- **Dependencies:**
  - Internal: `scripts/hex/biome_data.gd`, `scripts/scanner/catalog_data.gd`, `scripts/scanner/catalog_entry.gd`, `scripts/data/prop_def.gd`
- **Test Coverage:** Validated by `test_map_loader.gd` (map structure), exercised by all integration tests
- **Key Files:**
  - `maps/ch1.json` -- Chapter 1 hand-designed map (~250 tiles with biomes, elevations, resources, structures, anomalies)
  - `biomes/*.tres` -- 5 biome configs (crash_site, forest, grassland, rocky, water) with colors and resource tables
  - `catalog/*.tres` -- 4 catalog files (flora: 4 entries, fauna: 1 entry, minerals: 4 entries, anomalies: 1 entry)
  - `props/*.tres` -- ~28 prop definitions (source props 00001-00008, items 00010-00015, consumables 00020-00022, structures 00101-00105, tools 00201-00205)

## Tests
- **Path:** `tests/`
- **Purpose:** gdUnit4 test suites. Unit tests per module + integration tests per delivery milestone.
- **Size:** 23 files, 9,594 lines
- **Dependencies:**
  - External: gdUnit4 v6.0.3
- **Key Files:**
  - `integration/test_delivery_001.gd` -- Foundation tests (572 lines)
  - `integration/test_delivery_002.gd` -- Scanner + Auto-Interaction tests (911 lines)
  - `integration/test_delivery_003.gd` -- Crafting + feedback tests (1,236 lines)
  - `unit/test_auto_gather.gd` -- auto-gather flow tests (781 lines)
  - `unit/test_scanner_system.gd` -- scanner lifecycle tests (558 lines)
  - `unit/test_crafting_system.gd` -- recipe/craft validation tests (504 lines)

## Summary

| Module | Files | Lines | Test Lines | Test Ratio |
|--------|-------|-------|------------|------------|
| Hex Grid Core | 6 | 552 | 509 | 0.92 |
| Data Layer | 2 | 88 | 0 | 0.00 |
| Player | 4 | 663 | 540 | 0.81 |
| Inventory | 1 | 220 | 447 | 2.03 |
| Crafting | 1 | 190 | 935 | 4.92 |
| Auto-Interaction | 1 | 409 | 1,655 | 4.05 |
| Scanner/Catalog | 4 | 470 | 1,350 | 2.87 |
| HUD | 6 | 411 | 458 | 1.11 |
| Rendering | 6 | 1,348 | 977 | 0.72 |
| Audio | 1 | 52 | 0 | 0.00 |
| UI Panels | 8 | 955 | 731 | 0.77 |
| Shaders | 3 | 85 | 0 | 0.00 |
| Bootstrap | 1 | 76 | 0 | 0.00 |
| **Total Source** | **44** | **5,519** | **9,594** | **1.74** |

Note: Test ratio >1.0 indicates more test code than source code, reflecting thorough coverage. Data Layer and Audio have no dedicated tests but are exercised through integration tests. All test ratios are approximate as integration tests cover multiple modules.
