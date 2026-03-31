# Player Movement & Controls

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F2, §9 AC2 | /aid-interview |
| 2026-03-30 | Data Model written — Node3D + Tween, AStar2D with Dictionary ID mapping | /aid-specify |
| 2026-03-30 | Data Model fix: save keys tile_q/tile_r → tile_col/tile_row (readability convention) | /aid-specify |
| 2026-03-30 | Feature Flow written — state machine, snap tiebreaker, merged fog method | /aid-specify |
| 2026-03-30 | Layers & Components written — player_input as child Node, signal wiring defined | /aid-specify |
| 2026-03-30 | Mobile Specs written — input latency, touch discrimination, memory | /aid-specify |
| 2026-03-31 | Tile transition no longer calls fog directly — DayNightCycle owns visibility | /aid-specify (feature-007) |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |

## Source

- REQUIREMENTS.md §5 F2 (Player Movement & Controls)
- REQUIREMENTS.md §9 AC2 (Movement acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The player moves through the hex world via two simultaneous input modes: tap-to-move (tap a revealed tile → character pathfinds via A* along the shortest route) and a floating joystick (touch-and-hold anywhere on screen → joystick appears at touch point for fine continuous movement). Both modes are always available — no toggle needed. Touches on HUD elements are ignored by the movement system. There is no stamina bar; the player can always move freely.

## User Stories

- As a player, I want to tap a tile to move there automatically so navigation feels effortless
- As a player, I want a floating joystick for fine control when I need precise positioning
- As a player, I want movement to feel responsive (<100ms) so the game feels snappy on my phone

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Tap any revealed tile → character arrives via shortest path
- [ ] Path avoids impassable tiles (water, structures)
- [ ] Joystick appears at touch point on hold, character moves continuously
- [ ] Both input modes work without settings toggle
- [ ] Input-to-first-movement-frame < 100ms (measured)

## Save Integration

Adds player position (current tile coordinates) to save data.

---

## Technical Specification

### Data Model

#### Player State

Properties on the Player node (Node3D). Runtime state, not a separate Resource.

| Property | Type | Description |
|----------|------|-------------|
| `current_tile` | `Vector2i` | Axial coords of tile the player occupies |
| `target_tile` | `Vector2i` | Pathfinding destination (= `current_tile` when idle) |
| `move_state` | `MoveState` | Current movement mode |
| `move_path` | `Array[Vector2i]` | Remaining path tiles (pathfinding), empty when idle/walking |
| `move_speed` | `float` | World units/sec (exported, tunable) |
| `facing_direction` | `Vector2` | Normalized, for character orientation |

#### MoveState Enum

```gdscript
enum MoveState { IDLE, WALKING, PATHFINDING }
```

- `IDLE` — no input, standing still
- `WALKING` — joystick held, continuous movement frame-by-frame
- `PATHFINDING` — tap destination set, following `move_path` tile-by-tile

#### Movement Architecture: Node3D + Tween

The player is a `Node3D`, not a `CharacterBody3D`. Movement is discrete tile-to-tile
with visual interpolation via `Tween`. No physics engine involvement:

- **Passability** is handled entirely by `HexGrid.is_passable()` and `AStar2D` — checked
  before movement begins, not via collision layers.
- **Visual interpolation** between tile centers uses `Tween` on the node's `position`
  property. Smooth, lightweight, no velocity/physics overhead.
- **Elevation** is reflected in the Y component of the tween target (from
  `HexGrid.axial_to_world()` extended to 3D with elevation-based Y offset).

This matches the actual movement model: snap to tile logically, animate between visually.
`CharacterBody3D` would add physics overhead and collision semantics that don't apply.

#### A* Pathfinding via AStar2D

Godot's built-in `AStar2D` (C++ under the hood). Populated from HexGrid on `map_generated`:

```
Setup:
  _coord_to_id: Dictionary[Vector2i, int]  # maps axial coords → AStar2D point IDs
  _next_id: int = 0                         # incrementing counter

  For each tile in HexGrid._tiles:
    id = _next_id; _next_id += 1
    _coord_to_id[tile.coords] = id
    AStar2D.add_point(id, HexGrid.axial_to_world(tile.coords))

  For each tile:
    For each neighbor in HexGrid.get_neighbors(tile.coords):
      if HexGrid.is_passable(tile.coords, neighbor):
        AStar2D.connect_points(_coord_to_id[tile.coords], _coord_to_id[neighbor])
```

Tile ID mapping uses `Dictionary[Vector2i, int]` with an incrementing counter — safe
with negative axial coords (which are guaranteed since the grid centers at 0,0).

**Pathfinder updates on world changes:**
- `structure_placed` / `structure_destroyed` → disconnect/reconnect affected tile edges
- Resources don't block movement → no pathfinding updates needed
- Elevation and water are immutable after worldgen → no updates needed

#### Save Data Addition

Player position added to save file (save/load handled by feature-007 at dawn, shape defined here):

```json
{
  "player": {
    "tile_col": 0,
    "tile_row": 0
  }
}
```

**Serialization convention:** Code uses `q`/`r` (hex grid standard). Serialized JSON uses
`tile_col`/`tile_row` for human readability. Applied across all features that serialize
tile positions.

### Feature Flow

#### Movement State Machine

```
                 ┌──────────────────────────────────┐
                 │                                  │
                 ▼                                  │
            ┌────────┐   joystick held         ┌─────────┐
            │  IDLE  │ ─────────────────────► │ WALKING  │
            └────────┘                         └─────────┘
               │  ▲                              │  ▲
    tap tile   │  │ path complete                │  │ joystick held
               │  │ or destination reached       │  │ (cancels path)
               ▼  │                              │  │
          ┌─────────────┐    joystick held       │  │
          │ PATHFINDING │ ───────────────────────┘  │
          └─────────────┘                           │
               │                                    │
               │  tap new tile ─────────────────────┘
               └─► (cancel current path, re-pathfind from current tile)
```

#### Transition Rules

| From | Trigger | To | What Happens |
|------|---------|-----|-------------|
| IDLE | Tap revealed, passable tile | PATHFINDING | Compute A* path, start tween to first tile |
| IDLE | Joystick held | WALKING | Move continuously in joystick direction |
| PATHFINDING | Reach destination | IDLE | Clear `move_path`, snap to destination tile |
| PATHFINDING | Tap different tile | PATHFINDING | Cancel current tween, recompute A* from `current_tile` |
| PATHFINDING | Joystick held | WALKING | Cancel path immediately, switch to joystick |
| WALKING | Joystick released | IDLE | Snap to tile (see tiebreaker rule below) |
| WALKING | Tap tile | PATHFINDING | Snap to nearest tile, compute A* from there |

**Priority rule:** Joystick always wins. Holding the joystick during pathfinding cancels
the path instantly — direct control overrides automation.

**Tap during pathfinding:** Replaces the current path, does not queue.

#### Walking Snap Tiebreaker

When the joystick is released mid-tween between tile A (origin) and tile B (target):

- **Tween progress > 50%** → snap to tile B (moving toward)
- **Tween progress ≤ 50%** → snap back to tile A (origin)

This prevents edge-case jitter when the player is exactly midway. The 50% threshold
is measured as the tween's elapsed fraction, not world distance.

On snap: kill the active tween, create a short tween (~0.1s) to the chosen tile center
for smooth visual. Update `current_tile` to the snapped tile.

#### Input Pipeline — Tap-to-Move

```
Touch DOWN + UP (duration < 300ms, drag distance < threshold)
  │
  ├─ Reject if touch hits a HUD Control node (Godot's _gui_input consumes it)
  │
  ├─ Screen coords → Camera3D.project_position() → world_pos on ground plane
  │
  ├─ HexGrid.world_to_axial(world_pos) → target_coords
  │
  ├─ Validate:
  │     ✗ tile doesn't exist → reject (off-map)
  │     ✗ tile.fog_state == HIDDEN → reject (can't tap unexplored)
  │     ✗ target_coords == current_tile → reject (no self-pathfind)
  │
  ├─ AStar2D.get_point_path(current_id, target_id) → path
  │     ✗ path empty → reject, no valid route (optional: visual feedback)
  │
  └─ Set move_state = PATHFINDING
     move_path = path (excluding current_tile)
     Start tween to first tile in path
```

#### Input Pipeline — Floating Joystick

```
Touch DOWN + HOLD (duration ≥ 300ms OR drag distance ≥ threshold)
  │
  ├─ Reject if touch originated on a HUD Control node
  │
  ├─ Record touch origin as joystick_center
  │     Show joystick visual at touch point (CanvasLayer UI overlay)
  │
  ├─ Each frame while held (_process):
  │     drag_vector = current_touch_pos - joystick_center
  │     direction = drag_vector.normalized()
  │     magnitude = clamp(drag_vector.length() / max_radius, 0.0, 1.0)
  │
  │     Pick candidate_tile: nearest neighbor of current_tile in direction
  │       (project direction onto the 6 hex neighbor directions, pick closest)
  │
  │     if HexGrid.is_passable(current_tile, candidate_tile):
  │       Tween toward candidate_tile at move_speed * magnitude
  │       On arrival: update current_tile, trigger tile transition sequence
  │     else:
  │       Don't move (player bumps against impassable — no tween started)
  │
  └─ Touch UP:
       Apply snap tiebreaker (>50% → forward, ≤50% → back)
       Hide joystick visual
       Set move_state = IDLE
```

#### Tile Transition Sequence

Every time the player moves from tile A to tile B (both tap and joystick):

```
1. Emit HexGrid.tile_exited(A)
2. Update Player.current_tile = B
3. Emit HexGrid.tile_entered(B)
```

Movement does NOT call fog updates directly. DayNightCycle (feature-007) listens to
`tile_entered` and calls `HexGrid.refresh_visibility(sources)` with the appropriate
phase-based radius and torch sources. This centralizes visibility control and avoids
the need for movement to know about time of day or torch positions.

**Downstream signal consumers:**
- Gathering (feature-003): `tile_entered` → check for resources, show gather prompt
- Survival stats (feature-006): `tile_entered` → biome-specific effects (future: Desert heat)
- Building (feature-008): `tile_entered` near structure → show interaction options
- Renderer: `tile_revealed` / `tile_visibility_changed` → update MultiMesh instances

#### HUD Touch Filtering

No custom implementation needed. Godot's built-in input propagation handles this:
- HUD buttons are `Control` nodes with `mouse_filter = STOP`
- `_gui_input` on the Control consumes the touch event
- The movement system's `_unhandled_input` only receives touches that passed through HUD
- This is Godot's standard pattern — no raycasting, no manual hit-testing

Only `current_tile` is saved. `move_state`, `move_path`, `target_tile` are transient —
player loads at rest on their saved tile.

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       │    ├─ MultiMeshInstance3D [CRASH_SITE]
       │    ├─ MultiMeshInstance3D [GRASSLAND]
       │    ├─ MultiMeshInstance3D [FOREST]
       │    ├─ MultiMeshInstance3D [ROCKY]
       │    └─ MultiMeshInstance3D [WATER]
       ├─ Player (Node3D)                        ← NEW
       │    ├─ PlayerVisual (Node3D)              ← mesh/sprite placeholder
       │    └─ PlayerInput (Node)                 ← input classification
       └─ Camera3D                                ← NEW
  └─ JoystickOverlay (CanvasLayer)                ← NEW (screen-space UI)
```

**Autoloads:** Unchanged. `HexGrid` only. No new singletons for movement.

#### File Structure

```
scripts/
  player/
    player.gd              # Node3D — state machine, tile transitions, tween orchestration
    player_input.gd        # Node (child of Player) — _unhandled_input, tap vs joystick
    player_pathfinder.gd   # RefCounted — AStar2D wrapper, coord↔id mapping, path queries
    player_camera.gd       # Camera3D script — lerp follow, map bounds clamping

scenes/
  player/
    player.tscn            # Player + PlayerVisual + PlayerInput as children

ui/
  joystick_overlay.gd      # CanvasLayer — floating joystick visual
  joystick_overlay.tscn    # Scene — joystick circle + drag indicator
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `player.gd` | Owns `MoveState` machine, `current_tile`, tween lifecycle. Orchestrates tile transitions and signal emission via HexGrid. | `HexGrid` (API), `player_input.gd` (signals), `player_pathfinder.gd` (path queries) |
| `player_input.gd` | Child Node of Player. Receives `_unhandled_input`. Classifies touch events as tap or joystick-start. Tracks active joystick state. Emits signals to player.gd. | `joystick_overlay.gd` (signals for drag updates) |
| `player_pathfinder.gd` | RefCounted owned by player.gd. Wraps `AStar2D`. Builds graph on `map_generated`. Updates graph on `structure_placed`/`destroyed`. Exposes `find_path(from, to) -> Array[Vector2i]`. | `HexGrid` (API + signals) |
| `player_camera.gd` | Script on Camera3D. Lerp follow toward player position. Clamp to map AABB. | `Player.position`, `HexGrid` (map bounds) |
| `joystick_overlay.gd` | CanvasLayer. Shows/hides joystick at touch point. Emits drag vector + magnitude each frame while active. | Touch input only |

#### Signal Wiring

```
joystick_overlay.gd                     player_input.gd                    player.gd
  │                                       │                                  │
  ├─ signal joystick_started(origin)  ──► │                                  │
  ├─ signal joystick_moved(dir, mag)  ──► │                                  │
  ├─ signal joystick_released()       ──► │                                  │
  │                                       │                                  │
  │                                       ├─ signal tap_tile(coords)     ──► │
  │                                       ├─ signal joystick_start(dir)  ──► │
  │                                       ├─ signal joystick_move(dir,m) ──► │
  │                                       ├─ signal joystick_stop()      ──► │
  │                                       │                                  │
  │                                       │                          player.gd calls:
  │                                       │                          HexGrid.tile_entered()
  │                                       │                          HexGrid.tile_exited()
  │                                       │                          (DayNightCycle handles visibility via tile_entered)
```

**Connection setup (in `player.gd._ready()`):**

1. `player_input` connects to `joystick_overlay` signals via `get_node()` or
   injected reference (joystick is a sibling in the scene tree, not a child of Player)
2. `player.gd` connects to `player_input` signals (child node — `$PlayerInput.tap_tile.connect(...)`)
3. `player_pathfinder` connects to `HexGrid.map_generated`, `HexGrid.structure_placed`,
   `HexGrid.structure_destroyed` (player.gd passes these during setup since pathfinder is RefCounted)

**Why player_input is a child Node, not RefCounted:** `_unhandled_input()` is a Node
callback — only Nodes in the scene tree receive it. Making `player_input.gd` a child
Node of Player gives it natural access to the input system. It still does pure input
classification (no movement logic, no tile knowledge) — the "pure input processing"
role is unchanged.

**Why player_pathfinder stays RefCounted:** It never needs `_unhandled_input` or
`_process`. It's a data structure (AStar2D wrapper) queried on demand. player.gd owns
it, calls `find_path()` when needed, and manually connects HexGrid signals to it during
`_ready()`.

#### Camera Follow

Script on `Camera3D`, sibling of Player in the World node (not a child of Player).

```gdscript
# player_camera.gd — attached to Camera3D
@export var follow_speed: float = 8.0
@export var offset: Vector3 = Vector3(0, 15, 10)  # top-down-ish angle

var _target: Node3D  # Player reference, set in _ready or exported
var _map_bounds: Rect2  # AABB of all tile world positions + padding

func _ready():
    # Compute bounds from HexGrid on map_generated
    HexGrid.map_generated.connect(_compute_bounds)

func _process(delta):
    var desired = _target.position + offset
    desired.x = clampf(desired.x, _map_bounds.position.x, _map_bounds.end.x)
    desired.z = clampf(desired.z, _map_bounds.position.y, _map_bounds.end.y)
    position = position.lerp(desired, follow_speed * delta)
```

**Why sibling, not child of Player:** Parenting Camera3D to Player makes it inherit
tween interpolation frame-by-frame, causing micro-jitter during tile transitions.
Independent camera with lerp produces smoother results and allows bounds clamping
without fighting the parent transform.

**Map bounds:** Computed once on `map_generated`. Axis-aligned bounding box of all tile
world positions + configurable padding (e.g., 2 tile-widths). Prevents the camera from
showing void beyond map edges.

### Mobile Specs

#### Input Latency (AC2: <100ms input-to-first-movement-frame)

| Path | Breakdown | Total |
|------|-----------|-------|
| Tap-to-move | Input poll (~16ms worst case) + `world_to_axial` O(1) + `AStar2D.get_point_path` (<1ms, C++ native, 300 nodes) + Tween creation (~1ms) | ~21ms worst case |
| Joystick | Input poll (~16ms) + drag vector read + `is_passable` check + Tween creation | ~21ms worst case |

Both well within 100ms. Bottleneck is Godot's per-frame input polling (touch lands
just after a frame = one frame wait), not application logic.

#### Touch Discrimination — Tap vs Joystick

Dual-threshold approach prevents false joystick activation on imprecise mobile taps:

- **Tap:** Touch DOWN + UP in <300ms with drag distance < threshold → classify as tap
- **Joystick:** Hold ≥300ms OR drag distance ≥ threshold → classify as joystick start

Both thresholds must be tunable (exported vars) for device testing.

#### Touch Target Sizes

- Hex tiles: ~54–72px at 1080×1920 portrait (confirmed in feature-001). Above 48dp minimum.
- Joystick: no fixed zone — appears at touch point. No target size concern.

#### Platform Differences

None. `InputEventScreenTouch` / `InputEventScreenDrag` work identically on iOS and
Android in Godot. No platform-specific input code needed.

#### Memory

Player node + AStar2D (300 points, ~600 edges) + Camera + JoystickOverlay = negligible.
No memory concerns for this feature.
