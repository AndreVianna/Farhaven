# delivery-001: Foundation — Walk the World

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-001-hex-grid, feature-002-player-movement, feature-012-hud
**Depends on:** -- (foundation)
**Cumulative state:** Walk around an alien hex world with fog of war, camera, HUD shell

## Execution Graph

```
task-001 (Project setup + autoload skeleton)
  │
  ▼
task-002 (HexMath + HexTile + ResourceNode data layer)
  │
  ▼
task-003 (HexGrid autoload + WorldGenerator pipeline)  ← HEAVIEST TASK
  │
  ├──────────────────┐
  ▼                  ▼
task-004           task-005
(HexGridRenderer)  (HUD framework)
  │                  │
  └──────┬───────────┘
         ▼
task-006 (Player movement — continuous + camera)
  │
  ▼
task-007 (Player input — 3-outcome classifier + joystick)
  │
  ▼
task-008 (Integration test — Walk the World end-to-end)
```

**Parallel group:** task-004 + task-005 — renderer and HUD both depend on task-003
(HexGrid API) but not on each other.

**Note:** task-005 FloatingTextManager needs Camera3D (task-006) for world→screen
projection. Projection testing deferred to task-008 (integration). Not a blocker
for task-005 implementation.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 001 | Godot project setup + autoload skeleton | CONFIGURE | -- | -- |
| 002 | HexMath + HexTile + ResourceNode data layer | IMPLEMENT | 001 | -- |
| 003 | HexGrid autoload + WorldGenerator pipeline | IMPLEMENT | 002 | -- |
| 004 | HexGridRenderer — single ArrayMesh + per-vertex color blending | IMPLEMENT | 003 | 005 |
| 005 | HUD framework — layout, bars, counter, text, notifications | IMPLEMENT | 003 | 004 |
| 006 | Player movement — continuous joystick, derived tile, camera | IMPLEMENT | 003, 004 | -- |
| 007 | Player input — 3-outcome classifier + joystick | IMPLEMENT | 006 | -- |
| 008 | Integration test — Walk the World end-to-end | TEST | all above | -- |

## Task Details

### task-001: Godot Project Setup + Autoload Skeleton [CONFIGURE]

**Source:** feature-001 + feature-002 + feature-012 (shared foundation)

**Scope:**
- Create Godot 4.x project with directory structure from all three SPECs:
  `scripts/hex/`, `scripts/player/`, `scripts/hud/`, `scripts/building/`,
  `scripts/fauna/`, `scripts/scanner/`, `scripts/inventory/`, `scripts/crafting/`,
  `scripts/survival/`, `scripts/journal/`, `scripts/day_night/`, `scripts/save/`,
  `scripts/auto_interaction/`, `scripts/rendering/`,
  `scenes/`, `scenes/world/`, `scenes/player/`, `scenes/ui/`,
  `data/`, `data/biomes/`, `data/catalog/`, `data/journal/`,
  `shaders/`, `ui/`
- Register `HexGrid` autoload in Project Settings
- Create skeleton scene tree: Main (Node) → World (Node3D), HUD (CanvasLayer layer 20),
  JoystickOverlay (CanvasLayer layer 10), ScreenFade (CanvasLayer layer 30)
- Install GdUnit4 test framework
- Configure gdlint
- Set portrait 1080×1920 viewport in Project Settings
- Set up export presets placeholder (Android/iOS)

**Criteria:**
- [ ] Project opens in Godot 4.x without errors
- [ ] Directory structure matches all 12 feature SPECs
- [ ] HexGrid autoload registered and accessible as `HexGrid`
- [ ] GdUnit4 installed, trivial test runs and passes
- [ ] gdlint runs clean on empty project
- [ ] Viewport: 1080×1920 portrait mode
- [ ] CanvasLayer ordering: Joystick=10, HUD=20, ScreenFade=30
- [ ] Build passes with zero warnings

---

### task-002: HexMath + HexTile + ResourceNode Data Layer [IMPLEMENT]

**Source:** feature-001 → Data Model

**Scope:**
- `scripts/hex/hex_math.gd` — static class (`class_name HexMath`):
  `axial_to_cube`, `axial_to_world`, `world_to_axial`, `distance`,
  `get_neighbors`, `get_tiles_in_range`, ring iteration
- `scripts/hex/hex_tile.gd` — Resource with all properties: coords, biome, elevation,
  fog_state, structure, resource_nodes, anomaly. Biome + FogState enums.
- `scripts/hex/resource_node.gd` — Resource: type, remaining, max_amount, tool_required
- `scripts/hex/biome_data.gd` — Resource script for .tres biome configs
- 5 BiomeData `.tres` files: crash_site, grassland, forest, rocky, water
  with resource tables + elevation ranges from SPEC
- Unit tests: all HexMath functions (6 neighbors, distance, rings, conversions)

**Criteria:**
- [ ] HexMath unit tests pass: all 6 neighbor directions, distance calculations,
      ring generation, axial↔cube↔world conversions verified against Red Blob Games
- [ ] HexTile instantiates with all typed properties (including anomaly: StringName)
- [ ] ResourceNode instantiates with all typed properties
- [ ] BiomeData .tres files load without error, contain correct resource tables
- [ ] Biome enum: CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER
- [ ] FogState enum: HIDDEN, REVEALED, VISIBLE
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-003: HexGrid Autoload + WorldGenerator Pipeline [IMPLEMENT]

**Source:** feature-001 → Data Model (HexGrid API) + Feature Flow (pipeline)

**Scope:**
- `scripts/hex/hex_grid.gd` autoload:
  - Storage: `_tiles: Dictionary[Vector2i, HexTile]`, `_seed: int`
  - Constant: `MAX_ELEVATION_DIFF = 1`
  - Core API: `get_tile`, `get_neighbors`, `get_tiles_in_range`, `distance`,
    `is_passable`, `get_elevation_diff`, `refresh_visibility`, coordinate conversions
  - 11 signals: `map_generated`, `tile_revealed`, `tile_visibility_changed`,
    `tile_entered`, `tile_exited`, `resource_depleted`, `resource_respawned`,
    `tile_contents_changed`, `structure_placed`, `structure_destroyed`
  - `get_save_data()` / `load_save_data()`
- `scripts/hex/world_generator.gd` (RefCounted) — 11-step pipeline:
  1. Crash Site at (0,0) + neighbors
  2. Ring-by-ring BFS expansion (200-300 tiles)
  3. Noise-based biome assignment (distance-weighted)
  4. Water cluster placement
  5. Cluster post-processing (flood-fill, swap if >5)
  6. Elevation generation (noise clamped to biome ranges)
  7. Resource node population from BiomeData
  8. Reachability BFS + anomaly placement (≥70% max distance, reachable)
  9. Validation (tile count, biomes, Crash Site, clusters, reachability, anomaly)
  10. Fog initialization (HIDDEN, Crash Site VISIBLE)
  11. Emit `map_generated()`
- `is_passable` rules: water=impassable, elevation_diff>1=impassable,
  structure with blocks_movement=true=impassable (Shelter/Torch walkable)
- `refresh_visibility(sources)`: demote VISIBLE→REVEALED, promote per source,
  emit tile_revealed + tile_visibility_changed
- Serialization: tile_col/tile_row convention, anomaly field

**Criteria:**
- [ ] WorldGenerator produces valid maps across 10 different seeds
- [ ] AC1: tile count 200-300, all biomes present, Crash Site within 3 hexes,
      clusters ≤5, fog correct, at least 1 anomaly
- [ ] `is_passable` rejects water, steep elevation, blocking structures
- [ ] `is_passable` allows Shelter and Torch tiles (blocks_movement: false)
- [ ] `refresh_visibility` single-source works (player radius 2)
- [ ] `refresh_visibility` multi-source works (player + torch)
- [ ] Serialization round-trip: get_save_data → load_save_data preserves all state
- [ ] Worldgen completes within 10 retry attempts on all tested seeds
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

**Note:** This is the heaviest task (~2-3x others). If anything fails in delivery-001,
it will likely be here. The SPEC is detailed enough for execution.

---

### task-004: HexGridRenderer — Single ArrayMesh + Per-Vertex Color Blending [IMPLEMENT]

**Source:** feature-001 → Layers & Components

**Scope:**
- `scenes/world/hex_grid_renderer.gd` + `.tscn` — Node3D with single MeshInstance3D child
- Build single ArrayMesh from HexGrid tile data on `map_generated`:
  - 7 vertices per hex (1 center + 6 corners)
  - Center vertex color = biome color variation (from BiomeData, noise-selected)
  - Corner/edge vertex color: at same elevation = average of adjacent tiles' colors (smooth blending); at different elevation = each hex owns its own vertices (hard cliff edge)
  - Y position = elevation offset per tile
  - HIDDEN tiles = degenerate triangles (zero area)
- `shaders/hex_tile.gdshader`: per-vertex color pass-through with fog modulation
  (REVEALED = dimmed, VISIBLE = full brightness, HIDDEN = culled)
- On `tile_revealed`/`tile_visibility_changed`: update ONLY affected hex + neighbor vertices
  (partial mesh update, not full rebuild)
- `highlight_tiles(coords, color)` / `clear_highlights()` API (vertex color override)
- BiomeData .tres files: add `color_variations: Array[Color]` (2-3 entries per biome)
- Elevation subtly lightens color (+5% per elevation level)

**[PIVOT]** Single ArrayMesh with per-vertex color blending replaces 5 MultiMeshInstance3D.
Biome transitions smooth at shared edges. Elevation differences create natural cliff edges.
1 draw call for entire grid.

**Criteria:**
- [ ] Map renders with visually distinct biome colors (2-3 variations per biome)
- [ ] Biome transitions smooth at shared edges/corners (per-vertex color blending)
- [ ] Elevation differences create hard cliff edges (no vertex sharing across elevation gaps)
- [ ] HIDDEN tiles not visible, REVEALED dimmed, VISIBLE full
- [ ] Elevation creates visible Y offset between tiles
- [ ] Draw calls: ~1 for hex grid (single ArrayMesh)
- [ ] `highlight_tiles` colors specified tiles, `clear_highlights` resets
- [ ] Fog updates only affect changed tile + neighbors (partial mesh update)
- [ ] Signal-driven updates (no per-frame queries)
- [ ] Build passes with zero warnings

**Parallel with:** task-005

---

### task-005: HUD Framework — Layout, Bars, Counter, Text, Notifications [IMPLEMENT]

**Source:** feature-012 → all sections

**Scope:**
- `scripts/hud/hud.gd` — root Control on HUD CanvasLayer
- `scripts/hud/stat_bars.gd` — 3 ProgressBars (HP green→yellow→red, Hunger same,
  Thirst blue→yellow→red). Tween smooth. `mouse_filter = IGNORE`.
- `scripts/hud/day_counter.gd` — "DAY 07" label + phase icon. Warm palette.
  `mouse_filter = IGNORE`.
- `scripts/hud/floating_text_manager.gd` — `show_text(world_pos, text, color, duration)`.
  Spawn Label, tween rise 60px + fade 1.0s, stack vertically.
- `scripts/hud/notification_manager.gd` — `show_notification(text, duration)`.
  Queue max 3, first=2.0s, queued=1.5s, overflow dropped.
- `scenes/ui/hud.tscn` — complete layout: TopBar (StatBars + DayCounter),
  BottomBar (5 button slots 64×64px), FloatingTextContainer, NotificationContainer,
  PlacementLabel (hidden).
- Panel mutual exclusion: `panel_opened` signal, symmetric close pattern
- Buttons: InventoryButton, BuildButton, CraftButton (hidden), ScannerButton, JournalButton
- `show_placement_label()` / `hide_placement_label()`

**Criteria:**
- [ ] HUD renders in portrait 1080×1920 with correct zone layout
- [ ] Stat bars update via tween on mock `stat_changed` signal
- [ ] Day counter updates on mock `day_started` / `phase_changed`
- [ ] Floating text spawns, rises, fades, stacks vertically
- [ ] Notifications queue: max 3, faster dismiss for items 2+, overflow drops
- [ ] Panel mutual exclusion: opening one panel closes others
- [ ] CraftButton hidden by default
- [ ] All buttons 64×64px, all close buttons 48×48px
- [ ] `mouse_filter`: STOP on buttons/panels, IGNORE on stat bars/day counter
- [ ] Build passes with zero warnings

**Parallel with:** task-004

**Note:** FloatingTextManager world→screen projection needs Camera3D (task-006).
Projection testing deferred to task-008. Implementation is complete without camera.

---

### task-006: Player Movement — Continuous Joystick + Derived Tile + Camera [IMPLEMENT]

**Source:** feature-002 → Data Model + Feature Flow

**Scope:**
- `scripts/player/player.gd` — Node3D:
  - MoveState enum: IDLE, WALKING (no PATHFINDING)
  - Continuous movement: position updated per-frame by joystick input
  - `current_tile` derived from `HexMath.world_to_axial(position)`, updated on boundary cross
  - Tile transition sequence: tile_exited(A) → current_tile=B → tile_entered(B) → player_moved(A,B)
  - Impassable boundary: slide along hex edge (smooth rejection)
  - On joystick release: tween snap to current_tile center (~0.1s)
  - Elevation Y interpolation during cross-tile movement
  - Properties: current_tile (derived), move_state, move_speed, facing_direction
  - `get_save_data()` / `load_save_data()` (snap to center on load)
- `scripts/player/player_camera.gd` — on Camera3D:
  - Lerp follow: `position.lerp(target + offset, follow_speed * delta)`
  - Map AABB clamping on `map_generated`
  - Exported: follow_speed (8.0), offset
- `scenes/player/player.tscn` — Player + PlayerVisual (placeholder) + PlayerInput (empty Node)
- Add Player + Camera3D to World scene as siblings

**[PIVOT] Removed:** PlayerPathfinder, A* graph, PATHFINDING state, tap-to-move transitions.
A* pathfinding preserved for fauna (feature-010, delivery-005).

**Criteria:**
- [ ] Player moves continuously with joystick (direction + magnitude)
- [ ] current_tile updates when hex boundary crossed
- [ ] Tile transition emits 4 signals in order (exited, current update, entered, moved)
- [ ] Impassable tiles block movement (slide along boundary, no hard stop)
- [ ] Snap to tile center on joystick release (~0.1s tween)
- [ ] Elevation Y interpolation smooth during boundary crossing
- [ ] Camera follows smoothly, no jitter
- [ ] Camera clamps to map bounds
- [ ] Player spawns at Crash Site on startup
- [ ] Save data: tile_col/tile_row round-trip, loads snapped to center
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-007: Player Input — Two-Outcome Classifier + Joystick [IMPLEMENT]

**Source:** feature-002 → Feature Flow (input pipelines) + Mobile Specs

**Scope:**
- `scripts/player/player_input.gd` — child Node of Player, `_unhandled_input`:
  - Two-outcome classification (tap is no longer movement):
    - TAP: touch UP <300ms, drag <20px → no-op in delivery-001
      (future: emit `tap_world(coords)` for building/interaction)
    - SCAN HOLD: hold ≥300ms, drag <20px → emit `scan_hold_started(coords)`,
      `scan_hold_update(screen_pos)`, `scan_hold_ended()`
    - JOYSTICK: drag ≥20px (any time) OR scan_rejected fallback →
      emit `joystick_start/move/stop`
  - Drag always wins over scan (drag ≥20px before 300ms = joystick)
  - `scan_rejected(coords)` → fall back to joystick
  - Screen→world→axial conversion via Camera3D + HexGrid.world_to_axial
  - Exported thresholds: tap_max_duration, tap_max_drag, hold_threshold, drag_threshold
- `ui/joystick_overlay.gd` + `ui/joystick_overlay.tscn` — CanvasLayer layer 10
- Wire: joystick_overlay → player_input → player.gd (joystick signals only)

**[PIVOT]** Tap on world = no movement. Tap reserved for future interactions.

**Criteria:**
- [ ] Tap on world does NOT trigger movement
- [ ] Hold ≥300ms → `scan_hold_started` emits with correct axial coords
- [ ] Drag ≥20px → joystick immediately
- [ ] `scan_rejected` → falls back to joystick behavior
- [ ] Joystick visual appears at touch origin, disappears on release
- [ ] Player moves continuously with joystick (direction + magnitude)
- [ ] Snap to tile center on joystick release
- [ ] HUD button taps do NOT trigger movement or world interactions
- [ ] All thresholds exported and tunable
- [ ] Input-to-first-movement < 100ms
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-008: Integration Test — Walk the World End-to-End [TEST]

**Source:** AC1 + AC2 + feature-012 AC subset

**Scope:**
- Integration tests verifying delivery-001 playable state:
  - Generate map → renders → player spawns at Crash Site
  - Joystick movement → continuous, fog reveals, snap on release
  - Tap on world → no movement (verify no-op)
  - Hold → scan_hold signals emit (no consumer yet — verify signals fire)
  - Biome color blending visible at hex boundaries
  - HUD: stat bars visible, day counter visible, 5 buttons visible, CraftButton hidden
  - FloatingTextManager projection (now Camera3D exists from task-006)
  - Panel mutual exclusion (mock panels)
- All AC1 criteria via automated tests
- All AC2 criteria (joystick-only, no tap-to-move)
- HUD layout verification
- Document manual-only scenarios (visual rendering quality, joystick feel, color blending)

**Criteria:**
- [ ] All AC1 automated: tile count, biomes, Crash Site position, clusters, fog, anomaly
- [ ] AC2: joystick movement, impassable avoidance, snap on release, <100ms latency
- [ ] Biome color blending visible at hex boundaries (visual — document for manual check)
- [ ] Tap on world = no movement (verify no-op)
- [ ] HUD: stat bars top-left, day counter top-right, buttons bottom-right, CraftButton hidden
- [ ] FloatingTextManager projects world→screen correctly with Camera3D
- [ ] Scan hold signals fire with correct coords (no consumer — just verify emission)
- [ ] Panel mutual exclusion works with mock panels
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
After this delivery, `main.tscn` MUST contain:
- Main (Node, script: main.gd)
  - World (Node3D)
    - HexGridRenderer (Node3D, script: hex_grid_renderer.gd) — single MeshInstance3D child (per-vertex color blending)
    - WorldEnvironment + DirectionalLight3D — basic lighting
  - Player (from player.tscn)
    - PlayerVisual (MeshInstance3D — placeholder blue cube 0.4×0.8×0.4)
    - PlayerInput (Node)
    - PlayerCamera (Camera3D, rotation.x ≈ -34°, isometric overhead)
  - JoystickOverlay (CanvasLayer, layer=10)
  - HUD (CanvasLayer, layer=20)
    - StatBars (top-left, placeholder shells)
    - DayCounter (top-right, placeholder shell)
    - 5 ActionButtons (bottom-right: Inventory, Build, Craft, Scanner, Journal)
    - CraftButton (hidden — no workbench proximity)
    - FloatingTextManager
    - NotificationManager
  - ScreenFade (CanvasLayer, layer=30)

### Bootstrap Changes
This IS the bootstrap baseline. See REQUIREMENTS.md §11.

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Colored hexagon tiles with smooth biome transitions at edges
- [ ] Blue cube (player) standing on center tile
- [ ] Fog of war — tiles beyond radius 2 are hidden/dimmed
- [ ] Click-and-drag → joystick appears, player moves continuously
- [ ] Click on a tile → player does NOT move (tap reserved for interactions)
- [ ] New tiles reveal as player moves (fog of war works)
- [ ] HUD elements visible: stat bar area top-left, day counter top-right, buttons bottom-right
- [ ] Camera follows player from above at an angle

### Dev Environment
- Mouse→touch emulation enabled in project.godot (see known-issues.md)
- GdUnit4 headless: use `--ignoreHeadlessMode` flag

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (001-008) — approved | /aid-detail |
| 2026-04-01 | [PIVOT] Single mesh renderer, joystick-only movement, tasks 004/006/007/008 updated | /design-pivot |
