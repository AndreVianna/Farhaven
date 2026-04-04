# Domain Glossary

> **Source:** discovery-integrator
> **Status:** Active
> **Last Updated:** 2026-04-04

Terms extracted from code: class names, method names, constants, enums, comments, and documentation that encode business or domain concepts.

## Core World Concepts

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Hex Grid | The game world, composed of hexagonal tiles stored in a sparse Dictionary keyed by axial coordinates (Vector2i). Central data structure for all spatial queries. | `scripts/hex/hex_grid.gd:22` |
| Axial Coordinates | Two-axis hex coordinate system (q, r) stored as Vector2i. The primary coordinate system used throughout. Cube coordinate s is derived as -q-r. | `scripts/hex/hex_math.gd:4-5` |
| Cube Coordinates | Three-axis hex coordinate system (q, r, s) with constraint q+r+s=0. Used internally for distance calculations. | `scripts/hex/hex_math.gd:20` |
| HEX_SIZE | World-space radius of each hexagon (3.0 Godot units). Controls tile spacing and all hex-to-world conversions. | `scripts/hex/hex_math.gd:7` |
| Tile | A single hexagonal cell in the grid, represented by a HexTile Resource. Has biome, elevation, fog state, and a unified props array containing all placed content (resources, structures, anomalies, spawn markers). | `scripts/hex/hex_tile.gd` |
| Prop | A unified game object placed in a hex tile. All world content (resources, structures, anomalies, spawn markers) are props stored in `tile.props[]`. Each prop has a type, category, sub-hex coordinate, and optional footprint. Replaces the former separate `structure`, `resource_nodes`, and `anomaly` fields. | `scripts/hex/hex_tile.gd`, `docs/design/prop-taxonomy.md` |
| Sub-hex | A 1.2m hexagonal subdivision within a main 6m hex tile. Each tile contains 19 sub-hexes (1 center + 6 inner ring + 12 outer ring) addressed by axial coordinates (sq, sr). Sub-hex size = HEX_SIZE * 0.4 (SUB_HEX_SIZE = 1.2 at HEX_SIZE = 3.0). Used for precise prop placement within tiles. | `scripts/hex/hex_math.gd` |
| Footprint | An array of sub-hex coordinates `Array[Vector2i]` that a structure prop occupies within its parent hex tile. Used for placement validation — structures can coexist on the same tile as long as their footprints don't overlap. Small structures (torch, campfire) occupy 1 sub-hex; large structures (shelter) occupy multiple. | `scripts/hex/hex_tile.gd`, feature-009 SPEC |
| Props List | The `tile.props[]` array on each HexTile containing all placed content as prop dictionaries. Replaces the former separate `tile.structure`, `tile.resource_nodes`, and `tile.anomaly` fields. Queried by category for backward-compatible operations (e.g., checking for blocking structures). | `scripts/hex/hex_tile.gd` |
| Biome | The terrain type of a hex tile. Determines visual color, available resources, and traversability. Chapter 1 has 5: CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER. | `scripts/hex/hex_tile.gd:6-12` |
| Elevation | Integer height level (0-9) of a tile. Affects traversability (walking vs jumping), visual rendering (Y position = elevation * 0.5), and cliff face generation. | `scripts/hex/hex_tile.gd:20`, `scripts/player/player.gd:18` |
| Fog of War | Visibility system with three states: HIDDEN (no geometry rendered), REVEALED (seen before but not currently visible, dimmed), VISIBLE (currently in view range). | `scripts/hex/hex_tile.gd:14-18` |
| Fog State | Enum (HIDDEN=0, REVEALED=1, VISIBLE=2) tracking per-tile visibility. Drives terrain mesh generation, resource prop rendering, and label display. | `scripts/hex/hex_tile.gd:14-18` |
| Spawn | The starting tile where the player begins. Must be CRASH_SITE biome. Defined in map JSON as "spawn" array. | `scripts/hex/map_loader.gd:67` |

## Movement and Traversal

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Traversal Type | Enum classifying movement between tiles: WALK (elevation diff 0-1), JUMP (diff 2-3, going up), DROP (diff 2-3, going down), BLOCKED (diff 4+, water, non-walkable structures). | `scripts/hex/hex_grid.gd:17` |
| WALK | Movement type for flat or gentle slopes (elevation difference 0-1). Standard continuous movement. | `scripts/hex/hex_grid.gd:11` |
| JUMP | Movement type for climbing up significant elevation changes (diff 2-3). Triggers a tween arc animation. | `scripts/hex/hex_grid.gd:12` |
| DROP | Movement type for descending significant elevation changes (diff 2-3). Triggers a shorter hop-and-fall animation. | `scripts/hex/hex_grid.gd:12` |
| BLOCKED | Movement is impossible: water tiles, walls, or elevation difference >= 4. Player slides along the boundary instead. | `scripts/hex/hex_grid.gd:17` |
| Passable | A tile is passable from another if traversal type is not BLOCKED. Considers biome (water blocks), structure props with `blocks_movement` (queried from tile.props[]), and elevation difference. | `scripts/hex/hex_grid.gd:68-70` |
| Walkable Structure | A structure prop that does NOT block movement. List: shelter, torch, workbench, storage_chest, campfire. | `scripts/hex/hex_grid.gd:20` |
| Slide | When movement toward a BLOCKED tile is attempted, velocity is projected onto the boundary tangent, allowing the player to slide along the hex edge. | `scripts/player/player.gd:244` |
| MoveState | Player movement state machine: IDLE (stationary), WALKING (continuous joystick movement), JUMPING (mid-air tween, input buffered). | `scripts/player/player.gd:10` |
| Tile Transition | The moment the player's derived tile changes. Triggers tile_exited, tile_entered, fog refresh, and player_moved signals in that order. | `scripts/player/player.gd:307-319` |

## Input

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Tap | A short touch (< 0.3s, < 20px drag) that selects a tile. Only works on VISIBLE or REVEALED tiles. | `scripts/player/player_input.gd:8-9` |
| Joystick | Virtual joystick activated by dragging >= 20px. Controls player movement direction and speed via magnitude (0-1). | `scripts/player/player_input.gd:10` |
| JoystickOverlay | The visual representation of the virtual joystick -- a base circle at the touch origin with a knob following the finger, clamped to max_radius. | `ui/joystick_overlay.gd` |

## Resources and Gathering

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Resource Node | A gatherable resource instance on a tile, now stored as a prop with `category="resource"` in `tile.props[]`. Has type, remaining count, max amount, tool requirement, respawn time, and sub-hex position. Multiple can exist per tile. | `scripts/hex/resource_node.gd` |
| Resource Def (ResourceDef) | Static definition for a resource type. Defines gather time, gather amount, tool requirement, respawn time, yield mapping, tool speed multipliers, stack size, catalog entry link, and visual appearance. | `scripts/data/resource_def.gd` |
| Resource Registry | Autoload singleton that indexes all ResourceDef .tres files from data/resources/ at startup. Central lookup for resource metadata. | `scripts/data/resource_registry.gd` |
| Gather | The act of collecting resources from a Resource Node. Automatic (proximity-based), requires the node to be CATALOGED, and may require a specific tool. | `scripts/auto_interaction/auto_interaction_system.gd:130-143` |
| Gather Radius | World-space distance (0.75 Godot units) within which auto-gather activates. Represents arm's reach. | `scripts/auto_interaction/auto_interaction_system.gd:42` |
| Tool Gate | Resources that require a specific tool (e.g., stone_axe for wood, stone_pickaxe for ore) cannot be gathered without that tool equipped. Silently skipped. | `scripts/auto_interaction/auto_interaction_system.gd:135-143` |
| Catalog Gate | Resources cannot be gathered until their catalog entry is CATALOGED (fully scanned). Prevents gathering unknown props. | `scripts/auto_interaction/auto_interaction_system.gd:198-204` |
| Yield Type | Some resources yield a different item when gathered (e.g., loose_rock yields stone). If empty, the resource yields itself. | `scripts/data/resource_def.gd:14` |
| Depleted | A resource node with remaining = 0. Renders with a swapped mesh variant (e.g., tree stump instead of tree). May respawn after respawn_time seconds. | `scripts/auto_interaction/auto_interaction_system.gd:289-298` |
| Respawn | After depletion, resource nodes with respawn_time > 0 are added to a respawn queue. When the timer expires, remaining is reset to max_amount. Common: 30s, rare: 60s. | `scripts/auto_interaction/auto_interaction_system.gd:313-329` |
| Tool Priority | When multiple gatherable resources are within range, higher-priority tools are gathered first: stone_pickaxe=2, stone_axe=1, bare-hands=0. | `scripts/auto_interaction/auto_interaction_system.gd:27-31` |

## Resource Types (Chapter 1)

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Wood | Common resource from forest/grassland biomes. Gathered bare-handed or faster with stone_axe. Used in crafting. | `data/resources/wood.tres` |
| Stone | Common mineral resource. Gathered bare-handed. Used in crafting stone tools. | `data/resources/stone.tres` |
| Berries | Edible flora resource. Gathered bare-handed. Consumable item. | `data/resources/berries.tres` |
| Toxic Berries | Poisonous flora resource. Gathered bare-handed. Consumable with toxic warning dialog. | `data/resources/toxic_berries.tres` |
| Fiber | Plant-based resource from forest/grassland. Gathered bare-handed. Crafting material. | `data/resources/fiber.tres` |
| Ore | Mineral resource from rocky biomes. Requires stone_pickaxe to gather. | `data/resources/ore.tres` |
| Crystal | Rare mineral resource. Requires stone_pickaxe to gather. | `data/resources/crystal.tres` |
| Loose Rock | A rocky biome resource that yields stone when gathered. Example of yield_type mapping. | `data/resources/loose_rock.tres` |
| Anomaly Fragment | Mysterious alien artifact resource. Linked to anomaly entries in the catalog. | `data/resources/anomaly_fragment.tres` |
| Meat | Fauna drop (not a gatherable resource). Category: consumable. Max stack: 20. | `scripts/inventory/inventory.gd:16` |

## Inventory and Tools

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Inventory | Player-owned container with 12 base resource/consumable slots (expandable) and 4 fixed tool slots. RefCounted, not in the scene tree. | `scripts/inventory/inventory.gd` |
| Slot | A single inventory position holding one resource type with a quantity. Empty slots have type="" and quantity=0. Items stack up to max_stack. | `scripts/inventory/inventory.gd:24` |
| Tool Slot | One of 4 fixed equipment slots: axe, pickaxe, weapon, scanner. Each holds at most one tool. Tools are set via crafting, not manually. | `scripts/inventory/inventory.gd:28-33` |
| Stone Axe | Craftable tool. Equips in the axe slot. Speeds up wood gathering. Recipe: 2 wood + 1 stone. Pre-discovered. | `scripts/crafting/crafting_system.gd:15-20` |
| Stone Pickaxe | Craftable tool. Equips in the pickaxe slot. Required for ore/crystal gathering. Recipe: 3 wood + 2 stone. Pre-discovered. | `scripts/crafting/crafting_system.gd:21-27` |
| Survival Knife | Default weapon. Equipped at game start. Deals 10 damage for auto-defend. | `scripts/inventory/inventory.gd:20`, `scripts/auto_interaction/auto_interaction_system.gd:36` |
| Scanner | Default tool. Equipped at game start. Enables proximity auto-scan of nearby props. | `scripts/inventory/inventory.gd:21` |

## Crafting

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Recipe | A crafting formula defining ingredients, output type (tool or item), tool slot, discovery material, and workbench requirement. Stored in RECIPE_CONFIG constant. | `scripts/crafting/crafting_system.gd:14-31` |
| Pre-discovered | Recipes that are known from game start without needing to discover them. Stone axe and stone pickaxe are pre-discovered. | `scripts/crafting/crafting_system.gd:20,26` |
| Discovery Material | The resource type that triggers recipe discovery when first added to inventory. E.g., acquiring stone discovers stone tool recipes. | `scripts/crafting/crafting_system.gd:19` |
| Workbench | A placeable structure. Some recipes require workbench proximity (player tile or adjacent). Currently, stone tools do not require it. | `scripts/crafting/crafting_system.gd:145-156` |
| Workbench Proximity | Player is "near" a workbench if their current tile or any of 6 neighbors contains a workbench structure. | `scripts/crafting/crafting_system.gd:145-156` |

## Scanner and Catalog

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Catalog | The player's knowledge database of all discoverable flora, fauna, minerals, and anomalies. Tracks knowledge state per entry. | `scripts/scanner/catalog.gd` |
| Catalog Entry | A single discoverable item in the catalog. Has entry_id, category, display_name, description, icon, and properties dictionary. Loaded from .tres files. | `scripts/scanner/catalog_entry.gd` |
| Catalog Category | Classification of catalog entries: FLORA (0), FAUNA (1), MINERAL (2), ANOMALY (3). Determines scan duration, marker color, and UI tab. | `scripts/scanner/catalog.gd:6` |
| Knowledge State | Three-tier progression per catalog entry: UNKNOWN (0, never seen), ENCOUNTERED (1, fauna only -- seen but not fully scanned), CATALOGED (2, fully scanned). | `scripts/scanner/catalog.gd:7` |
| Scan | Proximity-based auto-scan. When the player is within SCAN_RANGE (1 hex) of a tile containing an uncataloged prop, scanning begins automatically. Progress advances in real-time. Interrupts if player leaves range. | `scripts/scanner/scanner_system.gd:15-27` |
| Scan Duration | Time in seconds to complete a scan. Varies by category: Flora=2s, Mineral=2s, Fauna=3s, Anomaly=3s. | `scripts/scanner/scanner_system.gd:17-22` |
| Passive Identification | When a tile becomes VISIBLE, the scanner checks all resource nodes and anomalies against the catalog and emits element_identified, element_unknown, or element_encountered signals. | `scripts/scanner/scanner_system.gd:187-219` |
| Surprise Encounter | When hostile fauna attacks the player and the species is UNKNOWN, it is automatically marked as ENCOUNTERED with label "Hostile." | `scripts/scanner/scanner_system.gd:153-161` |
| Scannable | A resource or anomaly that has a catalog entry and is not yet CATALOGED. ENCOUNTERED fauna are excluded from proximity scanning (need Trap/Sneak instead). | `scripts/scanner/catalog.gd:142-169` |

## Structures

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Structure | A prop with `category="structure"` placed on a hex tile via BuildingSystem or MapLoader. Stored in `tile.props[]`. Has a footprint defining which sub-hexes it occupies. Some block movement (walls), others are walkable. Multiple structures per hex allowed if footprints don't overlap. | `scripts/hex/hex_tile.gd`, feature-009 SPEC |
| Shelter | A walkable structure. Provides protection during night cycle. | `scripts/hex/hex_grid.gd:20` |
| Torch | A walkable structure. Provides light. | `scripts/hex/hex_grid.gd:20` |
| Storage Chest | A walkable structure. Provides additional storage. | `scripts/hex/hex_grid.gd:20` |
| Campfire | A walkable structure. Provides warmth/cooking. | `scripts/hex/hex_grid.gd:20` |

## Rendering

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| ArrayMesh | Godot mesh type used for the hex terrain. Built programmatically from SurfaceTool. One draw call for the entire grid. | `scenes/world/hex_grid_renderer.gd:1-4` |
| MultiMesh | Godot instancing system used for resource props. One MultiMesh pool per resource type, max 128 instances each. Efficient batch rendering. | `scripts/rendering/resource_renderer.gd:1-4` |
| Elevation Step | World-space Y offset per elevation level: 0.5 Godot units. Must match between HexGridRenderer and Player. | `scenes/world/hex_grid_renderer.gd:20`, `scripts/player/player.gd:18` |
| Cliff Face | Vertical geometry generated between adjacent tiles at different elevations. Darkened to 60% of tile color. | `scenes/world/hex_grid_renderer.gd:265-320` |
| Inner Ring | At 85% of hex radius, a ring of vertices with pure tile color. The outer 15% band transitions/blends with neighbor tile colors. | `scenes/world/hex_grid_renderer.gd:190` |
| Prop (render) | A 3D object placed on a tile representing any game object (resource, structure, anomaly). Currently placeholder meshes (cubes, cylinders, spheres). The term "prop" in rendering context refers to the visual instance; in data context it refers to a unified game object in `tile.props[]`. | `scripts/rendering/resource_renderer.gd` |
| Placeholder Mesh | Programmatic low-poly mesh shapes (cube, cylinder, sphere, octahedron, prism, box) used until real 3D art assets are created. | `scripts/rendering/resource_renderer.gd:81-89` |
| Fly-to-Player | Visual effect: a colored sphere tweens from the gathered resource position to the player with a parabolic arc, providing satisfying feedback. | `scripts/rendering/fly_to_player.gd` |
| Prop Label | 3D billboard marker above a prop showing knowledge state. Question mark for UNKNOWN (color-coded by category), warning for ENCOUNTERED, nothing for CATALOGED. | `scripts/rendering/prop_label_renderer.gd` |

## UI / HUD

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| HUD | Head-Up Display overlay containing stat bars, day counter, action buttons, floating text, notifications, and slide-out panels. | `scripts/hud/hud.gd` |
| Stat Bar | Progress bars for HP, Hunger, and Thirst. Color-coded: green (> 50%), yellow (25-50%), red (< 25%). Thirst uses blue instead of green. | `scripts/hud/stat_bars.gd` |
| Day Counter | HUD element showing current day number ("DAY 01") with phase-colored icon. | `scripts/hud/day_counter.gd` |
| Phase | Time-of-day period within the day/night cycle: DAY (yellow), DUSK (orange), NIGHT (purple), DAWN (peach). | `scripts/hud/day_counter.gd:4-9` |
| Floating Text | Temporary text label anchored to a 3D world position, rises and fades. Used for "+1 Wood", "INVENTORY FULL", damage numbers. | `scripts/hud/floating_text_manager.gd` |
| Notification | Toast-style message at screen bottom. Queued (max 3), with fade in/out. Used for "New recipe!", "Crafted Stone Axe!". | `scripts/hud/notification_manager.gd` |
| Craft Flash | Brief white fullscreen flash (0.25s) triggered on successful crafting. | `scripts/hud/craft_flash.gd` |
| Bottom Drawer | UI panel pattern used by Inventory, Catalog, and Crafting panels. Slides up from bottom, covers ~45% of screen. Mutually exclusive (only one open at a time). | `ui/inventory_panel.gd`, `ui/crafting_panel.gd`, `ui/catalog_panel.gd` |

## Serialization / Persistence

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Save Data | Dictionary format used for game state serialization. Each system (Player, HexGrid, Inventory, Catalog, CraftingSystem) has get_save_data() and load_save_data(). | `scripts/hex/hex_grid.gd:165-220` |
| Map JSON | Hand-designed level definition in JSON format. Contains tiles dictionary (keyed by "q,r"), spawn position, biome/elevation/resource/structure/anomaly data per tile. | `data/maps/ch1.json`, `scripts/hex/map_loader.gd` |
| Chapter | An episodic game level (the vision pivot replaced single procedural map with episodic chapters). Chapter 1 is the free demo. | `docs/vision-pivot-briefing.md` |

## Game Design Concepts

| Term | Definition (inferred from usage) | Source |
|------|----------------------------------|--------|
| Auto-Interaction | Core design principle: the player controls WHERE to go, the game handles the rest. Gathering, scanning, and defending happen automatically based on proximity. | `docs/vision-pivot-briefing.md:55-57` |
| Core Loop | EXPLORE -> GATHER -> CRAFT -> BUILD -> SURVIVE -> ESCAPE. Each day the player progresses through this cycle. | `docs/GDD.md:30-34` |
| Crash Site | The starting biome. Player wakes next to a wrecked ship. Safe starting area with basic resources. | `docs/GDD.md:72` |
| Anomaly | Mysterious alien artifact placed on specific tiles as a prop with `category="anomaly"` in `tile.props[]`. Part of the narrative mystery -- the planet shows signs of previous civilization. Scanned via the catalog system. | `scripts/hex/hex_tile.gd`, `docs/vision-pivot-briefing.md:16` |
| Day/Night Cycle | Game time system with 4 phases (DAY/DUSK/NIGHT/DAWN). Full cycle ~5 minutes real time. Night increases danger. Not yet implemented in code (planned for delivery-004). | `docs/GDD.md:74-79` |
| Anti-Predatory Monetization | Design philosophy: zero ads, zero IAP, zero fake currencies, zero timers. Free Chapter 1, paid chapters ~$2.50 each. | `docs/GDD.md:7`, `docs/vision-pivot-briefing.md:37-43` |
| Warm Horizon | The visual design system. Vibrant, warm, charming low-poly sci-fi aesthetic. Replaced the earlier "Tactical Brutalism" dark theme. | `docs/design/design-system.md`, `docs/vision-pivot-briefing.md:27-29` |
