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
task-006 (Player movement + pathfinding + camera)
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
| 004 | HexGridRenderer — MultiMesh + fog shader | IMPLEMENT | 003 | 005 |
| 005 | HUD framework — layout, bars, counter, text, notifications | IMPLEMENT | 003 | 004 |
| 006 | Player movement — state machine, pathfinding, camera | IMPLEMENT | 003, 004 | -- |
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

### task-004: HexGridRenderer — MultiMesh + Fog Shader [IMPLEMENT]

**Source:** feature-001 → Layers & Components

**Scope:**
- `scenes/world/hex_grid_renderer.gd` + `.tscn` — Node3D with 5 MultiMeshInstance3D
  children (one per biome: CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER)
- Hex tile mesh: flat-top hexagon, 6 triangles, <20 tris
- 5 biome materials (distinct placeholder colors)
- `shaders/hex_tile.gdshader`: per-instance custom data for fog tinting
  (0.0=hidden/zero-scale, 0.5=revealed/dimmed, 1.0=visible/full) + highlight channel
- On `map_generated()`: allocate instances, set transforms (position + elevation Y)
- On `tile_revealed`/`tile_visibility_changed`: update affected instance custom data
- `highlight_tiles(coords, color)` / `clear_highlights()` API (no callers yet)
- HIDDEN = zero scale (invisible). REVEALED = dimmed. VISIBLE = full brightness.

**Criteria:**
- [ ] Map renders with visually distinct biome colors
- [ ] HIDDEN tiles not visible, REVEALED dimmed, VISIBLE full
- [ ] Elevation creates visible Y offset between tiles
- [ ] Draw calls: ~5 for hex grid (one MultiMesh per biome)
- [ ] `highlight_tiles` colors specified tiles, `clear_highlights` resets
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

### task-006: Player Movement — State Machine, Pathfinding, Camera [IMPLEMENT]

**Source:** feature-002 → Data Model + Feature Flow

**Scope:**
- `scripts/player/player.gd` — Node3D:
  - MoveState enum: IDLE, WALKING, PATHFINDING
  - State machine with 7 transitions per SPEC table
  - Tween-based tile-to-tile movement (Node3D + Tween, not CharacterBody3D)
  - Tile transition sequence: tile_exited(A) → current_tile=B → tile_entered(B) → player_moved(A,B)
  - Snap tiebreaker: >50% forward, ≤50% back
  - Properties: current_tile, target_tile, move_state, move_path, move_speed, facing_direction
  - `get_save_data()` / `load_save_data()`
- `scripts/player/player_pathfinder.gd` — RefCounted:
  - AStar2D wrapper with Dictionary[Vector2i, int] ID mapping
  - Build on `map_generated`, update on `structure_placed`/`destroyed`
  - `find_path(from, to) -> Array[Vector2i]`
- `scripts/player/player_camera.gd` — on Camera3D:
  - Lerp follow: `position.lerp(target + offset, follow_speed * delta)`
  - Map AABB clamping on `map_generated`
  - Exported: follow_speed (8.0), offset
- `scenes/player/player.tscn` — Player + PlayerVisual (placeholder) + PlayerInput (empty Node)
- Add Player + Camera3D to World scene as siblings

**Criteria:**
- [ ] Pathfinder unit tests: valid paths, avoids water/elevation/structures, empty for unreachable
- [ ] State machine transitions match SPEC table (7 transitions)
- [ ] Tile transition emits 4 signals in order (exited, current update, entered, moved)
- [ ] Snap tiebreaker: >50% snaps forward, ≤50% snaps back
- [ ] Camera follows smoothly, no jitter during tween
- [ ] Camera clamps to map bounds (no void visible)
- [ ] Player spawns at Crash Site on startup
- [ ] Save data: tile_col/tile_row round-trip
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-007: Player Input — Three-Outcome Classifier + Joystick [IMPLEMENT]

**Source:** feature-002 → Feature Flow (input pipelines) + Mobile Specs

**Scope:**
- `scripts/player/player_input.gd` — child Node of Player, `_unhandled_input`:
  - Three-outcome classification:
    - TAP: touch UP <300ms, drag <20px → emit `tap_tile(coords: Vector2i)`
    - SCAN HOLD: hold ≥300ms, drag <20px → emit `scan_hold_started(coords: Vector2i)`,
      `scan_hold_update(screen_pos: Vector2)`, `scan_hold_ended()`
    - JOYSTICK: drag ≥20px (any time) OR scan_rejected fallback →
      emit `joystick_start/move/stop`
  - Drag always wins over scan (drag ≥20px before 300ms = joystick, never scan)
  - `scan_rejected(coords)` from feature-003 → fall back to joystick (2-frame timeout)
  - Screen→world→axial conversion via Camera3D.project_position + HexGrid.world_to_axial
  - HUD filtering: `_unhandled_input` only (buttons use mouse_filter=STOP)
  - Exported thresholds: tap_max_duration (300ms), tap_max_drag (20px),
    hold_threshold (300ms), drag_threshold (20px)
- `ui/joystick_overlay.gd` + `ui/joystick_overlay.tscn` — CanvasLayer layer 10:
  - Appears at touch origin on joystick activation
  - Emits: `joystick_started(origin)`, `joystick_moved(dir, mag)`, `joystick_released()`
  - Disappears on release
- Wire: joystick_overlay → player_input → player.gd (movement signals)
- Wire: player_input → (scan signals emitted, no consumer yet — feature-003 future)
- Joystick walking: direction→nearest hex neighbor, is_passable check, tween

**Criteria:**
- [ ] Tap <300ms on revealed tile → pathfinding starts
- [ ] Hold ≥300ms → `scan_hold_started` emits with correct axial coords
- [ ] Drag ≥20px → joystick immediately (even over ❓ elements)
- [ ] `scan_rejected` → falls back to joystick behavior
- [ ] Joystick visual appears at touch origin, disappears on release
- [ ] Player moves continuously with joystick (direction + magnitude)
- [ ] Snap tiebreaker on joystick release
- [ ] HUD button taps do NOT trigger movement
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
  - Tap to move → fog reveals → pathfinding works
  - Joystick movement → continuous, snap tiebreaker
  - Hold → scan_hold signals emit (no consumer yet — verify signals fire)
  - HUD: stat bars visible, day counter visible, 5 buttons visible, CraftButton hidden
  - FloatingTextManager projection (now Camera3D exists from task-006)
  - Panel mutual exclusion (mock panels)
- All AC1 criteria via automated tests
- All AC2 criteria (except scan consumer — feature-003 not present)
- HUD layout verification
- Document manual-only scenarios (visual rendering quality, joystick feel, camera smoothness)

**Criteria:**
- [ ] All AC1 automated: tile count, biomes, Crash Site position, clusters, fog, anomaly
- [ ] AC2: tap pathfinding, impassable avoidance, joystick both modes, <100ms latency
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
    - HexGridRenderer (Node3D, script: hex_grid_renderer.gd) — 5 MultiMeshInstance3D children auto-created
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
- [ ] Colored hexagon tiles visible (brown Crash Site center, surrounding biomes)
- [ ] Blue cube (player) standing on center tile
- [ ] Fog of war — tiles beyond radius 2 are hidden/dimmed
- [ ] Click a visible tile → player moves there, new tiles reveal
- [ ] Click-and-drag → joystick appears, player moves continuously
- [ ] HUD elements visible: stat bar area top-left, day counter top-right, buttons bottom-right
- [ ] Camera follows player from above at an angle

### Dev Environment
- Mouse→touch emulation enabled in project.godot (see known-issues.md)
- GdUnit4 headless: use `--ignoreHeadlessMode` flag

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (001-008) — approved | /aid-detail |
