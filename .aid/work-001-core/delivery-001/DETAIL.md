# delivery-001: World Foundation

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-001-hex-grid, feature-002-player-movement
**Depends on:** -- (foundation)
**Cumulative state:** Walk and explore

## Execution Graph

```
task-001 (Hex Math)
  │
  ▼
task-002 (Data Resources)
  │
  ▼
task-003 (HexGrid Autoload)
  │
  ▼
task-004 (World Generation)
  │
  ├──────────────────┐
  ▼                  ▼
task-005           task-006
(Renderer)         (Player + Pathfinder)
  │                  │
  │                  ▼
  │              task-007 (Input + Joystick)
  │                  │
  └──────┬───────────┘
         ▼
     task-008 (Camera + Integration)
```

**Parallel group:** task-005 and task-006 have no code dependency on each other.
Both depend on task-003 (HexGrid API) and task-004 (worldgen populates the grid).
They can be executed concurrently.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 001 | Hex Math Utility Library | IMPLEMENT | -- | -- |
| 002 | HexTile, ResourceNode, BiomeData Resources | IMPLEMENT | 001 | -- |
| 003 | HexGrid Autoload — Data Container and API | IMPLEMENT | 002 | -- |
| 004 | World Generation Pipeline | IMPLEMENT | 003 | -- |
| 005 | Hex Grid Renderer and Shader | IMPLEMENT | 003, 004 | 006 |
| 006 | Player Node, State Machine, and Pathfinder | IMPLEMENT | 003, 004 | 005 |
| 007 | Input System and Joystick Overlay | IMPLEMENT | 006 | -- |
| 008 | Camera Follow and Scene Integration | IMPLEMENT | 005, 006, 007 | -- |

## Task Details

### task-001: Hex Math Utility Library [IMPLEMENT]

**Scope:** Create `scripts/hex/hex_math.gd` — pure static utility class (`class_name HexMath`).

**Implements:**
- Axial-to-cube conversion (`axial_to_cube(Vector2i) -> Vector3i`)
- Axial-to-world position (`axial_to_world(Vector2i) -> Vector2`)
- World-to-axial (`world_to_axial(Vector2) -> Vector2i`) for input hit-testing
- Hex distance (`distance(Vector2i, Vector2i) -> int`)
- Get neighbors (`get_neighbors(Vector2i) -> Array[Vector2i]`)
- Get tiles in range (`get_tiles_in_range(Vector2i, int) -> Array[Vector2i]`)
- Ring iteration for worldgen expansion

**Criteria:**
- [ ] All public static methods have unit tests (GdUnit4)
- [ ] Test values verified against Red Blob Games reference
- [ ] Zero state — no instance variables, all static functions
- [ ] `class_name HexMath` registered, callable as `HexMath.distance(a, b)`
- [ ] Build passes with zero warnings

---

### task-002: HexTile, ResourceNode, and BiomeData Resources [IMPLEMENT]

**Scope:** Create data-only Resources and enums.

**Files:**
- `scripts/hex/hex_tile.gd` — Resource with properties: coords, biome, elevation, fog_state, structure, resource_nodes
- `scripts/hex/resource_node.gd` — Resource with properties: type, remaining, max_amount, tool_required, respawn_time
- `scripts/hex/biome_data.gd` — Resource with exported properties for per-biome config
- Biome enum (`CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER`)
- FogState enum (`HIDDEN, REVEALED, VISIBLE`)
- 5 `.tres` biome files under `data/biomes/`

**Criteria:**
- [ ] All properties match feature-001 SPEC Data Model exactly
- [ ] BiomeData `.tres` files loadable and contain correct resource tables + elevation ranges
- [ ] Unit tests for enum values and resource property defaults
- [ ] ResourceNode is data definition only — no gathering behavior (GatherSystem, respawn queue, tool-gating belongs to delivery-002)
- [ ] Build passes with zero warnings

---

### task-003: HexGrid Autoload — Data Container and API [IMPLEMENT]

**Scope:** Create `scripts/hex/hex_grid.gd` as autoload singleton. Full API implementation.

**Implements:**
- `_tiles: Dictionary[Vector2i, HexTile]` storage
- Core queries: `get_tile`, `get_neighbors`, `get_tiles_in_range`, `distance`
- Traversability: `is_passable(from, to)`, `get_elevation_diff(from, to)`
  - MVP rules: water = impassable, elevation_diff > MAX_ELEVATION_DIFF = impassable, structure with blocks_movement = impassable
- Fog: `refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]`
  - Multi-source API from day one (feature-007 design)
  - Single pass: demote all VISIBLE → REVEALED, then promote per source within radius
  - Emits `tile_revealed` (HIDDEN → VISIBLE) and `tile_visibility_changed` per transition
  - Delivery-001 calls with one source: `[{ "coords": player_tile, "radius": 2 }]`
- Coordinate conversions: delegates to HexMath
- All signal declarations (map_generated, tile_revealed, tile_visibility_changed, tile_entered, tile_exited, resource_depleted, resource_respawned, tile_contents_changed, structure_placed, structure_destroyed)
- Register as autoload in Project Settings

**Criteria:**
- [ ] Unit tests for `is_passable` — water blocking, elevation blocking, structure blocking
- [ ] Unit tests for `refresh_visibility` — HIDDEN→VISIBLE, VISIBLE→REVEALED transitions, multi-source (player + simulated torch), overlapping radii
- [ ] Unit tests for `get_neighbors` — center tiles return 6, edge tiles return fewer
- [ ] API signature is `refresh_visibility(sources: Array[Dictionary])` — no `update_fog`, no default radius parameter
- [ ] Autoload registered and accessible globally as `HexGrid`
- [ ] Build passes with zero warnings

---

### task-004: World Generation Pipeline [IMPLEMENT]

**Scope:** Create `scripts/hex/world_generator.gd` (RefCounted). Full 10-step pipeline.

**Implements:**
1. Crash Site placement at (0,0) + neighbors, elevation 0
2. Ring-by-ring expansion (BFS) to 200-300 tiles
3. Noise-based biome assignment (FastNoiseLite) with distance-from-center weighting
4. Water cluster placement (algorithm TBD per SPEC — candidate approaches documented)
5. Cluster post-processing — flood-fill, swap edge tiles if cluster > 5
6. Elevation generation via noise, clamped to biome ranges
7. Resource node population from BiomeData tables
8. Validation — tile count, biome presence, Crash Site proximity, cluster check, reachability (A* from Crash Site to each non-WATER biome)
9. Fog initialization (all HIDDEN, Crash Site area VISIBLE)
10. Emit `map_generated()`

**Criteria:**
- [ ] Unit tests for validation rules:
  - Tile count in 200-300 range
  - All 4 biomes present (CRASH_SITE, GRASSLAND, FOREST, ROCKY)
  - Crash Site within 3 hexes of center
  - No same-biome cluster exceeds 5 tiles
  - Passable path exists from Crash Site to at least one tile of each non-WATER biome
- [ ] Worldgen completes successfully on 3 different seeds
- [ ] Worldgen completes within 10 retry attempts on all tested seeds
- [ ] Resource nodes match BiomeData tables (correct types, tool requirements)
- [ ] Crash Site has Wood, Stone, Fiber (enough for first Workbench)
- [ ] RefCounted — no scene tree presence after generation completes
- [ ] Build passes with zero warnings

---

### task-005: Hex Grid Renderer and Shader [IMPLEMENT]

**Scope:** Create rendering layer for the hex world.

**Files:**
- `scenes/world/hex_grid_renderer.gd` + `.tscn` — Node3D with 5 MultiMeshInstance3D children (one per biome)
- Hex tile mesh (flat-top hexagon, 6 triangles, <20 tris)
- 5 biome materials (distinct colors per biome)
- `shaders/hex_tile.gdshader` — reads instance custom data for fog tinting (dim vs full)
- Create `Main` scene with `World > HexGridRenderer` structure

**Implements:**
- On `map_generated()`: allocate MultiMesh instances, set transforms (position from `axial_to_world` + elevation Y offset)
- HIDDEN tiles: zero scale (not visible)
- REVEALED tiles: dimmed via shader custom data
- VISIBLE tiles: full brightness via shader custom data
- Signal-driven updates: `tile_revealed` / `tile_visibility_changed` → update affected instance
- `highlight_tiles(coords, color)` / `clear_highlights()` API for future placement mode (feature-008)

**Criteria:**
- [ ] Generated map renders with visually distinct biomes
- [ ] HIDDEN = not visible, REVEALED = dimmed, VISIBLE = full brightness
- [ ] Draw calls approximately 5 for the hex grid (one per biome MultiMesh)
- [ ] Elevation creates visible Y offset between tiles
- [ ] Highlight API exists and is callable (no callers yet in this delivery)
- [ ] Build passes with zero warnings

**Parallel with:** task-006

---

### task-006: Player Node, State Machine, and Pathfinder [IMPLEMENT]

**Scope:** Create player entity with movement state machine and A* pathfinding.

**Files:**
- `scripts/player/player.gd` — Node3D, MoveState enum (IDLE, WALKING, PATHFINDING), tween-based tile-to-tile movement
- `scripts/player/player_pathfinder.gd` — RefCounted, AStar2D wrapper with Dictionary[Vector2i, int] ID mapping
- `scenes/player/player.tscn` — Player + PlayerVisual (placeholder mesh) + PlayerInput (empty Node, wired in task-007)

**Implements:**
- MoveState machine with transition rules per SPEC table
- Tween interpolation between tile centers (Node3D + Tween, not CharacterBody3D)
- Tile transition sequence: emit `tile_exited(A)` → update `current_tile` → emit `tile_entered(B)` → call `HexGrid.refresh_visibility([{ "coords": B, "radius": 2 }])`
- Snap tiebreaker on joystick release: >50% → forward, ≤50% → back (measured by tween elapsed fraction)
- Pathfinder: build AStar2D on `map_generated`, `find_path(from, to) -> Array[Vector2i]`, update on `structure_placed`/`structure_destroyed`
- `facing_direction` updated on movement for character orientation

**Criteria:**
- [ ] Unit tests for pathfinder: valid paths returned, impassable tiles avoided, empty array for unreachable
- [ ] Unit tests for snap tiebreaker logic (>50% forward, ≤50% back)
- [ ] State machine transitions match SPEC transition table (7 transitions)
- [ ] Tile transition emits signals in correct order (exit → enter → fog)
- [ ] `refresh_visibility` called with `[{ "coords": tile, "radius": 2 }]` (not old update_fog API)
- [ ] All existing tests still pass
- [ ] Build passes with zero warnings

**Parallel with:** task-005

---

### task-007: Input System and Joystick Overlay [IMPLEMENT]

**Scope:** Create input classification and floating joystick UI.

**Files:**
- `scripts/player/player_input.gd` — Node (child of Player), `_unhandled_input` handler
- `ui/joystick_overlay.gd` + `ui/joystick_overlay.tscn` — CanvasLayer, floating joystick visual

**Implements:**
- Touch classification: tap (<300ms + minimal drag) vs joystick (≥300ms OR drag ≥ threshold)
- Dual-threshold approach (both exported, tunable)
- Screen-to-world coordinate projection for tap targets (`Camera3D.project_position()` → `HexGrid.world_to_axial()`)
- HUD touch filtering via Godot's `_unhandled_input` (HUD Controls use `mouse_filter = STOP`)
- Joystick visual: appears at touch origin, reports drag vector + magnitude via signals
- Signal chain: `joystick_overlay` → `player_input` → `player.gd`
- Signals: `tap_tile(coords)`, `joystick_start(dir)`, `joystick_move(dir, magnitude)`, `joystick_stop()`

**Criteria:**
- [ ] Tap on revealed tile emits `tap_tile` with correct axial coords
- [ ] Joystick hold emits directional signals with magnitude 0-1
- [ ] HUD button touches do not trigger movement (mouse_filter = STOP)
- [ ] Both input modes work without settings toggle
- [ ] Tap/joystick thresholds are exported and tunable
- [ ] Joystick visual appears at touch point and disappears on release
- [ ] Build passes with zero warnings

---

### task-008: Camera Follow and Scene Integration [IMPLEMENT]

**Scope:** Camera system and final delivery integration.

**Files:**
- `scripts/player/player_camera.gd` — script on Camera3D

**Implements:**
- Lerp follow: `position.lerp(target + offset, follow_speed * delta)`
- `follow_speed` and `offset` exported for tuning
- Map bounds clamping: compute AABB of all tile world positions on `map_generated`, clamp camera each frame
- Camera3D and Player added to World scene as siblings (not parent-child)
- Final integration: verify complete startup flow:
  1. App launch
  2. Worldgen runs
  3. Map renders (5 biomes, fog, elevation)
  4. Player spawns at Crash Site
  5. Camera frames the scene
  6. Tap-to-move works
  7. Joystick works
  8. Fog reveals on movement
- Player position save data shape: `{ "tile_col": int, "tile_row": int }`

**Criteria:**
- [ ] Camera follows player smoothly without jitter during tween movement
- [ ] Camera does not show void beyond map edges (bounds clamping)
- [ ] Player spawns at Crash Site tile on startup
- [ ] Complete flow runs from launch to walking around the map
- [ ] Input-to-first-movement-frame < 100ms (AC2 requirement)
- [ ] Save data shape includes `tile_col`/`tile_row` for player position
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created — approved | /aid-detail |
