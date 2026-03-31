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
| 2026-03-31 | Redesign: requirements updated — SPEC needs reconciliation | /aid-interview |
| 2026-03-31 | SPEC reset — full rewrite with three-outcome input, scan forwarding, no movement locks | /aid-specify |
| 2026-03-31 | SPEC reset + all sections rewritten — simplified input (no tap-to-interact), scan forwarding | /aid-specify |

## Source

- REQUIREMENTS.md §5 F2 (Player Movement & Controls)
- REQUIREMENTS.md §9 AC2 (Movement acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The player moves through the hex world via two simultaneous input modes: tap-to-move (tap a revealed tile → character pathfinds via A* along the shortest route) and a floating joystick (touch-and-hold anywhere on screen → joystick appears at touch point for fine continuous movement). Both modes are always available — no toggle needed. Touches on HUD elements are ignored. Press-and-hold toward unknown elements initiates scanning (owned by feature-003, not this feature). There is no stamina bar; the player can always move freely.

## User Stories

- As a player, I want to tap a tile to move there automatically so navigation feels effortless
- As a player, I want a floating joystick for fine control when I need precise positioning
- As a player, I want movement to feel responsive (<100ms) so the game feels snappy on my phone

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Tap any revealed tile → character arrives via shortest path
- [ ] Path avoids impassable tiles (water, structures) and too-steep elevation changes
- [ ] Joystick appears at touch point on hold, character moves continuously
- [ ] Both input modes work without settings toggle
- [ ] Input-to-first-movement-frame < 100ms (measured)
- [ ] Press-and-hold toward unknown element initiates scan (feature-003 integration)

## Save Integration

Adds player position (current tile coordinates) to save data.

---

## Technical Specification

### Data Model

#### Player State (properties on Player Node3D)

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

**No GATHERING or ATTACKING states.** Pre-redesign had cross-feature movement locks
(`is_gathering`, `is_attacking` flags from feature-003/008). The redesign replaces
tap-to-interact with auto-interaction (feature-004), which triggers by proximity
and does NOT lock movement. The player is never movement-locked by other systems.

#### Movement Architecture: Node3D + Tween

The player is a `Node3D`, not a `CharacterBody3D`. Movement is discrete tile-to-tile
with visual interpolation via `Tween`. No physics engine involvement:

- **Passability** handled by `HexGrid.is_passable()` and `AStar2D` — checked before
  movement begins, not via collision layers
- **Visual interpolation** via `Tween` on `position` property — smooth, lightweight
- **Elevation** reflected in Y component (from `HexGrid.axial_to_world()` + elevation offset)

#### A* Pathfinding via AStar2D

Godot's built-in `AStar2D` (C++ under the hood). Populated from HexGrid on
`map_generated`:

```
Setup:
  _coord_to_id: Dictionary[Vector2i, int]  # axial coords → AStar2D point IDs
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

Dictionary ID mapping with incrementing counter — safe with negative axial coords.

**Pathfinder updates on world changes:**
- `structure_placed` / `structure_destroyed` → disconnect/reconnect affected tile edges
- Resources don't block movement → no updates
- Elevation and water immutable after worldgen → no updates

#### Player Signals

```gdscript
# Emitted by player.gd — consumed by downstream systems
signal player_moved(from: Vector2i, to: Vector2i)  # after tile transition complete
```

Player also calls HexGrid methods to emit `tile_entered`/`tile_exited` (HexGrid owns
those signals per feature-001's ownership pattern).

#### Save Data

```json
{
  "player": {
    "tile_col": 0,
    "tile_row": 0
  }
}
```

Only `current_tile` is saved. `move_state`, `move_path`, `target_tile`, `facing_direction`
are transient — player loads at rest on saved tile. Serialization uses `tile_col`/`tile_row`
convention.

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
| IDLE | Joystick held (on empty ground) | WALKING | Move continuously in joystick direction |
| PATHFINDING | Reach destination | IDLE | Clear `move_path`, snap to destination tile |
| PATHFINDING | Tap different tile | PATHFINDING | Cancel current tween, recompute A* from `current_tile` |
| PATHFINDING | Joystick held | WALKING | Cancel path immediately, switch to joystick |
| WALKING | Joystick released | IDLE | Snap tiebreaker (>50% → forward, ≤50% → back) |
| WALKING | Tap tile | PATHFINDING | Snap to nearest tile, compute A* from there |

**Priority rule:** Joystick always wins — holding joystick during pathfinding cancels
the path instantly. Direct control overrides automation.

**Tap during pathfinding:** Replaces current path, does not queue.

**Scan hold does NOT appear in the state machine.** Scan hold is classified by
`player_input.gd` before reaching `player.gd`. If input is classified as scan,
it never reaches the movement state machine (see Input Classification below).

#### Walking Snap Tiebreaker

When joystick is released mid-tween between tile A (origin) and tile B (target):

- **Tween progress > 50%** → snap to tile B (moving toward)
- **Tween progress ≤ 50%** → snap back to tile A (origin)

Measured as the tween's elapsed fraction, not world distance. On snap: kill active
tween, create short tween (~0.1s) to chosen tile center. Update `current_tile`.

#### Three-Outcome Input Classification

`player_input.gd` classifies every touch into exactly one of three outcomes:

```
Touch DOWN received
  │
  ├─ Wait for classification threshold:
  │     Track duration (frames since DOWN) and drag distance
  │
  ├─ OUTCOME 1: TAP (movement)
  │     Touch UP before 300ms AND drag distance < 20px
  │     → Emit tap_tile(coords: Vector2i)
  │     → player.gd handles: pathfind to tile
  │
  ├─ OUTCOME 2: POTENTIAL SCAN HOLD
  │     Duration reaches 300ms AND drag < 20px
  │     → Convert touch to coords: HexGrid.world_to_axial(world_pos)
  │     → Emit scan_hold_started(coords: Vector2i) — just coords, nothing else
  │     → Feature-003 checks if anything scannable exists at coords
  │       → If yes: feature-003 claims input, starts scan progress
  │       → If no: feature-003 emits scan_rejected(coords)
  │              → player_input falls back to JOYSTICK behavior
  │     → On touch UP: emit scan_hold_ended()
  │
  ├─ OUTCOME 3: JOYSTICK (continuous movement)
  │     Drag distance reaches 20px (regardless of duration or location)
  │     OR scan_rejected received from feature-003 after hold threshold
  │     → Emit joystick_start(direction: Vector2)
  │     → JoystickOverlay shows at touch origin
  │     → player.gd handles: continuous tile-to-tile movement
  │     → On touch UP: emit joystick_stop()
  │
  └─ END
```

**Hold threshold classification:** When duration reaches 300ms (and drag < 20px),
`player_input.gd` does ONE thing:

```
1. Project touch screen position to world space via Camera3D.project_position()
2. Convert to axial: HexGrid.world_to_axial(world_pos) → coords
3. Emit scan_hold_started(coords)
4. Wait for response from feature-003:
   → Feature-003 claims (scannable element found) → stay in SCAN HOLD
   → Feature-003 rejects (scan_rejected signal) → fall back to JOYSTICK
```

**player_input.gd does NOT query the catalog, FaunaManager, or tile contents.**
It converts screen position to tile coords (one HexGrid dependency) and asks
feature-003 "is there anything scannable here?" via signal. Feature-003 owns all
scan-eligibility logic — it checks resource_nodes, fauna, anomalies, and catalog
state internally.

**Edge cases:**

- **Finger slides off target during scan hold:** Once feature-003 claims the input,
  it stays scan until touch UP. Feature-003 handles "out of range" (cancel scan
  progress, show feedback) using `scan_hold_update` screen position. `player_input.gd`
  doesn't reclassify mid-hold.

- **Drag triggers joystick even over ❓:** If drag distance reaches 20px before the
  300ms threshold, it's ALWAYS joystick — regardless of what's under the touch. This
  prevents accidental scan when the player starts dragging immediately. Drag = intent
  to move, not intent to scan.

- **Mid-pathfind encounters ❓ tile:** Movement continues through the tile. ❓ elements
  don't block pathfinding or movement. The player walks past them. To scan, the player
  must stop and press-hold on the ❓. Auto-interaction (feature-004) also ignores
  uncataloged elements — no auto-gather on ❓ tiles.

- **Joystick walk through ❓ tile:** Same — joystick movement passes through. No
  automatic scanning while walking. Scanning requires deliberate press-and-hold while
  stationary or while the character approaches. The scan input is intentional, not
  incidental.

- **Scan hold during PATHFINDING or WALKING:** If the player is mid-pathfind or
  joystick-walking and lifts their finger, movement continues to the next tile
  (pathfinding) or snaps (joystick). A NEW touch starting as scan hold does not
  cancel existing movement — it's a second touch intent. On single-touch devices,
  the previous touch must end (UP) before a new classification begins.

#### Input Pipeline — Tap-to-Move (Outcome 1)

```
Touch DOWN + UP (duration < 300ms, drag < 20px)
  │
  ├─ Reject if touch hits HUD Control node (Godot _gui_input consumes it)
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

**No input priority stack.** Pre-redesign had fauna > gather > movement disambiguation.
That's eliminated — movement is the sole tap consumer. All interactions are
proximity-based (feature-004) or scan-based (feature-003).

#### Input Pipeline — Floating Joystick (Outcome 3)

```
Hold ≥ 300ms on empty ground, OR drag ≥ 20px (any location)
  │
  ├─ Reject if touch originated on HUD Control node
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
  │       (project direction onto 6 hex neighbor directions, pick closest)
  │
  │     if HexGrid.is_passable(current_tile, candidate_tile):
  │       Tween toward candidate_tile at move_speed * magnitude
  │       On arrival: update current_tile, trigger tile transition sequence
  │     else:
  │       Don't move (player bumps against impassable)
  │
  └─ Touch UP:
       Apply snap tiebreaker (>50% → forward, ≤50% → back)
       Hide joystick visual
       Set move_state = IDLE
```

#### Input Pipeline — Scan Hold (Outcome 2, feature-003 owned)

```
Hold ≥ 300ms, drag < 20px
  │
  ├─ player_input.gd converts touch to coords (HexGrid.world_to_axial)
  ├─ Emits scan_hold_started(coords: Vector2i)
  │
  ├─ Feature-003 (scanner) receives signal:
  │     Checks if anything scannable at coords (resource_nodes, fauna, anomaly + catalog state)
  │     ├─ Scannable found:
  │     │     Claims input — starts scan progress bar (2-3 seconds)
  │     │     Handles proximity validation (is player close enough?)
  │     │     Handles completion (add to catalog) or cancellation
  │     └─ Nothing scannable:
  │           Emits scan_rejected(coords: Vector2i)
  │           → player_input.gd receives rejection → falls back to JOYSTICK
  │
  ├─ While held (if claimed by feature-003):
  │     player_input.gd emits scan_hold_update(screen_pos: Vector2) each frame
  │     Feature-003 uses this to track if finger drifted off target
  │     Movement does NOT start — player.gd is not involved
  │
  └─ Touch UP:
       player_input.gd emits scan_hold_ended()
       Feature-003 cancels scan if not yet complete
       No movement state change
```

**Ownership boundary:** `player_input.gd` is a dumb classifier — it converts screen
position to coords (one HexGrid dependency) and emits. Feature-003 owns ALL scan
logic: eligibility check, progress, completion, cancellation, catalog update.
`player.gd` (movement) is never involved in scan holds.

**Rejection fallback:** If feature-003 rejects (nothing scannable at coords),
`player_input.gd` falls back to joystick behavior as if the hold had been on empty
ground. The joystick appears at the original touch origin and movement begins.

#### Tile Transition Sequence

Every time the player moves from tile A to tile B (both tap and joystick):

```
1. Emit HexGrid.tile_exited(A)          — player left A
2. Update Player.current_tile = B       — internal state
3. Emit HexGrid.tile_entered(B)         — player arrived at B
4. Emit player_moved(A, B)              — convenience for systems that need both
```

Movement does NOT call fog updates. DayNightCycle (feature-008) listens to
`tile_entered` and calls `HexGrid.refresh_visibility(sources)` with phase-based
radius + torch sources.

**Downstream consumers of `tile_entered`:**

| Consumer | Feature | Reaction |
|----------|---------|----------|
| Auto-interaction | feature-004 | Proximity check: auto-gather cataloged resources, auto-pickup ground items |
| Scanner passive ID | feature-003 | Auto-identify cataloged elements entering scanner range |
| Day/Night fog | feature-008 | `refresh_visibility` with phase radius + torch sources |
| Survival | feature-007 | Biome-specific stat effects (future: Desert heat) |

#### HUD Touch Filtering

No custom implementation. Godot's built-in input propagation:
- HUD buttons: `Control` nodes with `mouse_filter = STOP`
- `_gui_input` on Control consumes touch event
- `player_input.gd` uses `_unhandled_input` — only receives unclaimed touches

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
       │    └─ PlayerInput (Node)                 ← three-outcome input classifier
       └─ Camera3D                                ← NEW
  └─ JoystickOverlay (CanvasLayer)                ← NEW (screen-space joystick)
```

**Autoloads:** `HexGrid` only (feature-001). No new singletons for movement.

#### File Structure

```
scripts/
  player/
    player.gd              # Node3D — state machine, tile transitions, tween orchestration
    player_input.gd        # Node (child of Player) — _unhandled_input, three-outcome classifier
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
| `player.gd` | Owns `MoveState` machine, `current_tile`, tween lifecycle. Orchestrates tile transitions (exit → enter). Emits `player_moved`. Receives tap_tile and joystick signals from player_input. Does NOT receive scan signals. | `HexGrid` (API), `player_input.gd` (move signals only), `player_pathfinder.gd` |
| `player_input.gd` | Child Node of Player. `_unhandled_input`. Three-outcome classification: tap (→ player.gd), joystick (→ player.gd via joystick_overlay), potential scan hold (→ feature-003 decides). Converts screen pos to coords at hold threshold — does NOT query catalog, fauna, or tile contents. Falls back to joystick on `scan_rejected`. | `joystick_overlay.gd` (drag signals), `HexGrid` (world_to_axial only), feature-003 (`scan_rejected` signal) |
| `player_pathfinder.gd` | RefCounted owned by player.gd. AStar2D graph build on `map_generated`, update on `structure_placed`/`destroyed`. `find_path(from, to) -> Array[Vector2i]`. | `HexGrid` (API + signals) |
| `player_camera.gd` | Script on Camera3D (sibling of Player, not child). Lerp follow with exported `follow_speed` (8.0) and `offset`. Map AABB clamping computed on `map_generated`. | `Player.position`, `HexGrid` (map bounds) |
| `joystick_overlay.gd` | CanvasLayer. Shows/hides joystick at touch origin. Emits drag vector + magnitude each frame. Disappears on release. | Touch input only |

#### Signal Wiring — Complete

```
joystick_overlay.gd                     player_input.gd
  signal joystick_started(origin)   ──►
  signal joystick_moved(dir, mag)   ──►
  signal joystick_released()        ──►

player_input.gd                         player.gd (movement)
  signal tap_tile(coords: Vector2i)          ──►  pathfind to tile
  signal joystick_start(dir: Vector2)        ──►  begin walking
  signal joystick_move(dir: Vector2, m: float) ──►  continue walking
  signal joystick_stop()                     ──►  snap tiebreaker, IDLE

player_input.gd                         feature-003 (scanner)
  signal scan_hold_started(coords: Vector2i)                            ──►
  signal scan_hold_update(screen_pos: Vector2)                          ──►
  signal scan_hold_ended()                                              ──►

feature-003 (scanner)                   player_input.gd
  signal scan_rejected(coords: Vector2i)                                ──►  fall back to joystick

player.gd                              HexGrid (centralized signals)
  calls tile_exited(A)                 ──►  downstream consumers
  calls tile_entered(B)                ──►  downstream consumers
```

**Connection setup (in `player.gd._ready()`):**

1. `player_input` connects to `joystick_overlay` signals (sibling in scene tree —
   injected reference or `get_node()`)
2. `player.gd` connects to `player_input` movement signals: `tap_tile`,
   `joystick_start`, `joystick_move`, `joystick_stop`
3. `player.gd` does NOT connect to scan signals — feature-003 connects to those
   directly on `player_input`
4. `player_pathfinder` connects to `HexGrid.map_generated`, `structure_placed`,
   `structure_destroyed` (player.gd wires these during setup since pathfinder is
   RefCounted)

**Why player_input is a child Node:** `_unhandled_input()` is a Node callback.
RefCounted can't receive it.

**Why player_pathfinder is RefCounted:** No `_unhandled_input` or `_process` needed.
Pure data structure queried on demand.

#### Camera Follow

```gdscript
# player_camera.gd — on Camera3D, sibling of Player
@export var follow_speed: float = 8.0
@export var offset: Vector3 = Vector3(0, 15, 10)

var _target: Node3D
var _map_bounds: Rect2

func _ready():
    HexGrid.map_generated.connect(_compute_bounds)

func _process(delta):
    var desired = _target.position + offset
    desired.x = clampf(desired.x, _map_bounds.position.x, _map_bounds.end.x)
    desired.z = clampf(desired.z, _map_bounds.position.y, _map_bounds.end.y)
    position = position.lerp(desired, follow_speed * delta)
```

**Why sibling, not child:** Avoids tween interpolation jitter. Independent camera
with lerp follow is smoother and allows bounds clamping without fighting parent
transform.

**Map bounds:** AABB of all tile world positions + configurable padding (~2 tile widths).
Computed once on `map_generated`.

### Mobile Specs

#### Input Latency (AC2: <100ms input-to-first-movement-frame)

| Path | Breakdown | Total |
|------|-----------|-------|
| Tap-to-move | Input poll (~16ms worst case) + `world_to_axial` O(1) + `AStar2D.get_point_path` (<1ms, C++ native, 300 nodes) + Tween creation (~1ms) | ~21ms worst case |
| Joystick | Input poll (~16ms) + drag vector read + `is_passable` check + Tween creation | ~21ms worst case |
| Scan hold | Input poll (~16ms) + world_to_axial O(1) + emit signal (~0ms) + feature-003 response (~1ms, within 1 frame) | ~17ms to coords, +16ms for response = ~33ms total |

All within 100ms. Scan hold classification at 300ms is intentional — the 300ms wait
is the design threshold, not latency. Once classified, the signal fires in <2ms.

#### Three-Outcome Touch Discrimination — Thresholds

| Parameter | Value | Exported | Rationale |
|-----------|-------|----------|-----------|
| `tap_max_duration` | 300ms | Yes | Standard mobile tap threshold |
| `tap_max_drag` | 20px | Yes | Prevents drag-taps from triggering pathfind |
| `hold_threshold` | 300ms | Yes | Same as tap max — classification happens at this moment |
| `drag_threshold` | 20px | Yes | Drag triggers joystick immediately (even over ❓) |

**Classification timeline:**

```
t=0ms     Touch DOWN. Start tracking duration + drag.
t<300ms   If drag ≥ 20px → JOYSTICK immediately (drag = intent to move).
          If touch UP → TAP (duration < 300ms, drag < 20px).
t=300ms   Hold threshold reached. Convert to coords, emit scan_hold_started(coords).
          Wait for feature-003 response:
          → Claimed (scannable found) → SCAN HOLD.
          → Rejected (scan_rejected) → JOYSTICK fallback.
          Response expected within 1 frame (~16ms). If no response within
          2 frames → default to JOYSTICK (defensive timeout).
t>300ms   Already classified. No reclassification.
```

**Key rule:** Drag always wins over scan. If the player drags ≥ 20px before 300ms,
it's joystick — never scan. This prevents accidental scans when the player's finger
moves.

**Rejection latency:** Feature-003's eligibility check (tile lookup + catalog query)
is O(1) — expected <1ms. The scan_rejected response arrives within 1 frame. A 2-frame
defensive timeout (32ms) catches edge cases without perceptible delay.

#### Touch Target Sizes

- Hex tiles: ~54–72px at 1080×1920 portrait. Above 48dp minimum.
- ❓ elements: positioned on hex tiles, same touch target size.
- Joystick: no fixed zone — appears at touch point.

#### Platform Differences

None. `InputEventScreenTouch` / `InputEventScreenDrag` work identically on iOS and
Android in Godot. No platform-specific code.

#### Memory

Player node + AStar2D (300 points, ~600 edges) + Camera + JoystickOverlay = negligible.
Hit-test at hold threshold: one-time query, no ongoing memory.
