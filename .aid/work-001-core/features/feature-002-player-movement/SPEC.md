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
| 2026-04-01 | [PIVOT] 3-tier traversal: WALK (0-1) / JUMP-DROP (2-3) / BLOCKED (4+). JUMPING state added. Asymmetric gravity. | /design-pivot |
| 2026-04-01 | [PIVOT] Joystick-only movement. Tap-to-move removed. Continuous position. current_tile derived. A* pathfinder removed (fauna uses it in F-010). | /design-pivot |
| 2026-04-01 | C3: Camera offset updated to Vector3(0, 12, 8) for HEX_SIZE=3.0. C4: move_speed default 5.0 units/sec (deliberate exploration pace, not tripled). I2: Touch target estimate marked [TUNING_REQUIRED]. I3: Jump arc peak now proportional to gap_height × ELEVATION_STEP, marked [TUNING_REQUIRED]. I8: Snap tween updated to ~0.2s, marked [TUNING_REQUIRED]. I10: Flow diagram labels updated (TAP = no-op path, SCAN = Outcome 1, JOYSTICK = Outcome 2). | /pivot-cascade |

## Source

- REQUIREMENTS.md §5 F2 (Player Movement & Controls)
- REQUIREMENTS.md §9 AC2 (Movement acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The player moves through the hex world exclusively via a floating joystick (touch-and-hold anywhere on screen → joystick appears at touch point for continuous movement). Tap is reserved for UI buttons and world interactions (building placement, future object inspect). Press-and-hold toward unknown elements initiates scanning (owned by feature-003, not this feature). There is no stamina bar; the player can always move freely. Player position is continuous (not snapped to tile centers during movement). `current_tile` is derived from position — `tile_entered`/`tile_exited` signals fire when the player crosses a hex boundary.

## User Stories

- As a player, I want a floating joystick for intuitive movement so I can explore freely
- As a player, I want movement to feel smooth and responsive (<100ms) so the game feels alive
- As a player, I want to tap objects to interact with them, not accidentally move there

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Joystick appears at touch point on hold/drag, character moves continuously
- [ ] Player avoids impassable tiles (water, structures, elevation diff 4+)
- [ ] Elevation diff 2-3: auto-jump (up) / auto-drop (down) with arc animation
- [ ] Elevation diff 0-1: smooth walk with Y interpolation
- [ ] Input-to-first-movement-frame < 100ms (measured)
- [ ] Tap on world = no movement (reserved for interactions)
- [ ] Press-and-hold toward unknown element initiates scan (feature-003 integration)
- [ ] On joystick release, player snaps smoothly to current tile center

## Save Integration

Adds player position (current tile coordinates) to save data.

---

## Technical Specification

### Data Model

#### Player State (properties on Player Node3D)

| Property | Type | Description |
|----------|------|-------------|
| `current_tile` | `Vector2i` | Axial coords of tile the player is on — **derived** from `HexMath.world_to_axial(position)`, updated when hex boundary crossed |
| `move_state` | `MoveState` | Current movement mode |
| `move_speed` | `float` | World units/sec — default `5.0` (exported, tunable). Calibrated for HEX_SIZE=3.0 as a deliberate exploration pace (NOT tripled from a HEX_SIZE=1.0 baseline — slower crossing feels right for the curiosity/story genre). |
| `facing_direction` | `Vector2` | Normalized, for character orientation |

**[PIVOT] Removed:** `target_tile`, `move_path` — no pathfinding. Position is continuous Vector3 on the Node3D. `current_tile` is computed, not set directly.

#### MoveState Enum

```gdscript
enum MoveState { IDLE, WALKING, JUMPING }
```

- `IDLE` — no input, standing still (snapped to tile center)
- `WALKING` — joystick held, continuous movement frame-by-frame
- `JUMPING` — auto-jump/drop in progress (~0.2-0.3s). Joystick input buffered, movement resumes on land.

**[PIVOT] Removed:** `PATHFINDING` — no tap-to-move, no A* pathfinding for the player.
**[PIVOT] Added:** `JUMPING` — triggered by 2-3 elevation difference at tile boundary.

#### Movement Architecture: Node3D + Continuous Position

The player is a `Node3D`, not a `CharacterBody3D`. Movement is continuous (not discrete tile-to-tile):

- **Position:** `position` updated every `_process(delta)` frame by joystick input
- **Traversal:** checked before entering a new tile via `HexGrid.get_traversal(current_tile, candidate_tile)`:
  - WALK → seamless crossing, smooth Y interpolation
  - JUMP → auto-jump animation (~0.3s arc up), then continue
  - DROP → auto-drop animation (~0.2s arc down), then continue
  - BLOCKED → slide along boundary
- **Elevation:** Y component smoothly interpolated based on hex elevations (WALK). Jump/Drop uses arc trajectory.
- **Tile transitions:** `current_tile` is derived from `HexMath.world_to_axial(position)`. When it changes, `tile_entered`/`tile_exited` fire
- **On stop:** Short tween (~0.2s, tunable) snaps to current tile center — prevents player from standing between hexes when idle. **[TUNING_REQUIRED]** — at HEX_SIZE=3.0 max snap distance is ~1.5 units; 0.1s may feel too fast/jarring.

**[PIVOT] No Tween-based tile-to-tile movement.** Player moves smoothly through world space. The hex grid is the logical layer; the player's physical position is independent.

#### Pathfinding

**[PIVOT] Player no longer uses A* pathfinding.** Joystick-only movement means the player always has direct control.

A* pathfinding (`AStar2D`) is needed for NPC/fauna movement in feature-010. The `PlayerPathfinder` class is removed from this feature. Feature-010 will implement `FaunaPathfinder` when needed.

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

Only `current_tile` (derived) is saved. On load, player snaps to the center of the saved tile. All other state is transient. Serialization uses `tile_col`/`tile_row` convention.

### Feature Flow

#### Movement State Machine

```
        ┌─────────┐   joystick held    ┌──────────┐
        │  IDLE   │ ─────────────────► │ WALKING  │
        └─────────┘                    └──────────┘
             ▲         ▲                    │ │
             │         │  land              │ │ elevation diff 2-3
             │         └────────────────────┼─┘
             │     joystick released   ┌────▼─────┐
             │     (snap to center)    │ JUMPING  │
             └─────────────────────────└──────────┘
```

Three states. Jump/drop is brief and automatic.

#### Transition Rules

| From | Trigger | To | What Happens |
|------|---------|-----|-------------|
| IDLE | Joystick held (drag ≥ threshold) | WALKING | Move continuously in joystick direction |
| WALKING | Joystick released | IDLE | Snap to current tile center (~0.2s tween, tunable) |
| WALKING | Tile boundary with elevation diff 2-3 | JUMPING | Auto-jump (up ~0.3s) or auto-drop (down ~0.2s) arc |
| JUMPING | Arc animation completes | WALKING | Resume movement, process buffered joystick input |
| JUMPING | Joystick released during jump | IDLE | Land, then snap to tile center |

**[PIVOT] Removed:** All PATHFINDING transitions, tap-to-move pipeline, path cancellation, joystick-cancels-path logic.
**[PIVOT] Added:** JUMPING state for auto-jump/drop. Player cannot change direction mid-air. Joystick input is buffered (read on land).

#### Joystick Release Snap

When joystick is released, player may be between hex centers:
- Short tween (~0.2s, tunable) to `current_tile` center position
- `current_tile` is already correct (derived from position continuously)
- No tiebreaker needed — the player is always "on" exactly one tile

#### Two-Outcome Input Classification

**[PIVOT]** Tap no longer triggers movement. Classification simplified:

```
Touch DOWN received
  │
  ├─ Track duration and drag distance
  │
  ├─ NO-OP PATH: TAP (interaction — NOT movement)
  │     Touch UP before 300ms AND drag distance < 20px
  │     → In delivery-001: no-op on world (no interactable objects yet)
  │     → Future: emit tap_world(coords: Vector2i) for building placement,
  │       object inspection, etc.
  │     → UI buttons: consumed by Godot _gui_input before reaching player_input
  │
  ├─ OUTCOME 1: POTENTIAL SCAN HOLD
  │     Duration reaches 300ms AND drag < 20px
  │     → Convert touch to coords: HexGrid.world_to_axial(world_pos)
  │     → Emit scan_hold_started(coords: Vector2i)
  │     → Feature-003 claims or rejects
  │       → Claimed: scan in progress, movement blocked
  │       → Rejected: emit scan_rejected → fall back to JOYSTICK
  │     → On touch UP: emit scan_hold_ended()
  │
  ├─ OUTCOME 2: JOYSTICK (movement)
  │     Drag distance reaches 20px (regardless of duration)
  │     OR scan_rejected received
  │     → Show joystick at touch origin
  │     → Player moves continuously
  │     → On touch UP: snap to tile center, hide joystick
  │
  └─ END
```

**Key change:** TAP on the game world does NOT move the player. Tap is reserved for:
- UI buttons (Godot handles via _gui_input)
- Building placement (feature-009, future delivery)
- Object interaction (future)

In delivery-001, tap on world = no-op. Only joystick moves the player.

**Edge cases:**

- **Joystick walk near ❓ element:** Movement continues past. No auto-scan. Scanning requires deliberate press-and-hold while stationary or moving slowly.

- **Impassable boundary (BLOCKED):** Player slides along the edge of BLOCKED tiles (no hard stop). Movement direction projects onto the hex boundary, allowing diagonal sliding past obstacles.

- **Multiple boundary crossings per frame:** At high speed, player might cross multiple tile boundaries in one frame. Process each crossing sequentially (fire tile_exited/entered for each).

- **Scan hold during WALKING:** If player is joystick-walking and lifts finger, movement stops (snap to center). A NEW touch starting as scan hold is independent — player must be stopped or will stop first.

#### Input Pipeline — Tap on World (Outcome 1)

```
Touch DOWN + UP (duration < 300ms, drag < 20px)
  │
  ├─ Reject if touch hits HUD Control node (Godot _gui_input consumes it)
  │
  ├─ delivery-001: no-op (no world interactions yet)
  │
  ├─ Future deliveries:
  │     Screen coords → Camera3D.project_position() → world_pos
  │     HexGrid.world_to_axial(world_pos) → coords
  │     Emit tap_world(coords: Vector2i)
  │     → feature-009 (building): place structure on tapped tile
  │     → future: inspect object, select target
  │
  └─ No movement. Player stays where they are.
```

#### Input Pipeline — Floating Joystick (Outcome 3)

```
Drag ≥ 20px (any time) OR scan_rejected fallback
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
  │     # Continuous movement
  │     velocity = direction * move_speed * magnitude
  │     new_position = position + velocity * delta
  │
  │     # Boundary check — derive candidate tile
  │     candidate_tile = HexMath.world_to_axial(new_position)
  │     if candidate_tile != current_tile:
  │       var traversal = HexGrid.get_traversal(current_tile, candidate_tile)
  │       match traversal:
  │         WALK:
  │           position = new_position  # cross boundary
  │           _on_tile_changed(old_tile, candidate_tile)
  │         JUMP, DROP:
  │           _start_jump(candidate_tile, traversal)  # enter JUMPING state
  │           # Arc tween from current pos to candidate tile center
  │           # JUMP: arc up (~0.3s), DROP: arc down (~0.2s)
  │           # On completion → _on_tile_changed + resume WALKING
  │         BLOCKED:
  │           # Slide along boundary — project velocity parallel to hex edge
  │           position = _slide_along_boundary(position, velocity, delta)
  │     else:
  │       position = new_position  # still same tile, always OK
  │
  │     Update elevation Y (WALK: interpolate between tile elevations)
  │     Update facing_direction
  │
  └─ Touch UP:
       Hide joystick visual
       Tween snap to current_tile center (~0.1s)
       Set move_state = IDLE
```

**Tile boundary crossing:** The player moves in continuous world space. When `HexMath.world_to_axial(position)` returns a different tile than `current_tile`, a boundary crossing occurs. The system queries `HexGrid.get_traversal()` to determine the crossing type:
- **WALK (diff 0-1):** Seamless crossing. Tile transition signals fire. Smooth Y interpolation.
- **JUMP (diff 2-3 up):** Enter JUMPING state. Tween arc from current position to destination tile center, Y arcs up then down (~0.3s). On land: tile transition signals fire, resume WALKING.
- **DROP (diff 2-3 down):** Same as JUMP but faster (~0.2s), Y arcs down with gravity feel.
- **BLOCKED (diff 4+, water, wall):** Slide along boundary edge (no hard stop — smooth rejection).

**During JUMPING:** Joystick input is buffered (direction and magnitude stored). Player cannot change direction mid-air. On landing, buffered input immediately resumes movement — no perceptible pause.

**Elevation interpolation (WALK only):** During movement between same-elevation or diff-1 tiles, Y position interpolates between the source and destination tile elevations based on distance to each tile center. This prevents jarring Y jumps at boundaries.

**Jump/Drop arc:** Uses a simple parabolic arc. Jump: Y rises by `gap_height * 0.5 + 0.3` above the higher tile, where `gap_height = elevation_diff × ELEVATION_STEP` (e.g., diff-2 gap at ELEVATION_STEP=0.5 → 1.0 world units → peak 0.8 units above tile). Drop: Y follows a gravity-like curve to the lower tile. Both use Tween with EASE_IN_OUT. Arc peak and timing are `@export` tunable. **[TUNING_REQUIRED]** — timing (0.3s jump / 0.2s drop) calibrated for HEX_SIZE=1.0; may need adjustment at HEX_SIZE=3.0.

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

Movement does NOT call fog updates directly. DayNightCycle (feature-008) listens to
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
       │    └─ MeshInstance3D [single ArrayMesh — entire hex grid]
       ├─ Player (Node3D)
       │    ├─ PlayerVisual (Node3D)              ← mesh/sprite placeholder
       │    └─ PlayerInput (Node)                 ← two-outcome input classifier
       └─ Camera3D
  └─ JoystickOverlay (CanvasLayer)                ← screen-space joystick
```

**Autoloads:** `HexGrid` only (feature-001). No new singletons for movement.

#### File Structure

```
scripts/
  player/
    player.gd              # Node3D — state machine (IDLE/WALKING/JUMPING), continuous movement
    player_input.gd        # Node (child of Player) — _unhandled_input, two-outcome classifier
    player_camera.gd       # Camera3D script — lerp follow, map bounds clamping

scenes/
  player/
    player.tscn            # Player + PlayerVisual + PlayerInput as children

ui/
  joystick_overlay.gd      # CanvasLayer — floating joystick visual
  joystick_overlay.tscn    # Scene — joystick circle + drag indicator
```

**[PIVOT] Removed:** `player_pathfinder.gd` — player no longer uses A* pathfinding.
Feature-010 (fauna) will implement its own pathfinder in delivery-005.

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `player.gd` | Owns `MoveState` machine (IDLE/WALKING/JUMPING), `current_tile` (derived), continuous movement. Queries `HexGrid.get_traversal()` at tile boundaries. Orchestrates tile transitions (exit → enter). Emits `player_moved`. Receives joystick signals from player_input. Does NOT receive scan signals. | `HexGrid` (API), `player_input.gd` (joystick signals only) |
| `player_input.gd` | Child Node of Player. `_unhandled_input`. Two-outcome classification: tap (no-op on world in delivery-001, future interactions), joystick (→ player.gd), potential scan hold (→ feature-003 decides). Converts screen pos to coords at hold threshold — does NOT query catalog, fauna, or tile contents. Falls back to joystick on `scan_rejected`. | `joystick_overlay.gd` (drag signals), `HexGrid` (world_to_axial only), feature-003 (`scan_rejected` signal) |
| `player_camera.gd` | Script on Camera3D (sibling of Player, not child). Lerp follow with exported `follow_speed` (8.0) and `offset`. Map AABB clamping computed on `map_generated`. | `Player.position`, `HexGrid` (map bounds) |
| `joystick_overlay.gd` | CanvasLayer. Shows/hides joystick at touch origin. Emits drag vector + magnitude each frame. Disappears on release. | Touch input only |

#### Signal Wiring — Complete

```
joystick_overlay.gd                     player_input.gd
  signal joystick_started(origin)   ──►
  signal joystick_moved(dir, mag)   ──►
  signal joystick_released()        ──►

player_input.gd                         player.gd (movement)
  signal tap_world(coords: Vector2i)         ──►  no-op in delivery-001 (future: building, inspect)
  signal joystick_start(dir: Vector2)        ──►  begin walking
  signal joystick_move(dir: Vector2, m: float) ──►  continue walking
  signal joystick_stop()                     ──►  snap to tile center, IDLE

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
2. `player.gd` connects to `player_input` movement signals: `joystick_start`,
   `joystick_move`, `joystick_stop`
3. `player.gd` does NOT connect to scan signals — feature-003 connects to those
   directly on `player_input`

**Why player_input is a child Node:** `_unhandled_input()` is a Node callback.
RefCounted can't receive it.

#### Camera Follow

```gdscript
# player_camera.gd — on Camera3D, sibling of Player
@export var follow_speed: float = 8.0
@export var offset: Vector3 = Vector3(0, 12, 8)  # Calibrated for HEX_SIZE=3.0

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
| Joystick | Input poll (~16ms) + drag vector read + `get_traversal` check + position update | ~21ms worst case |
| Scan hold | Input poll (~16ms) + world_to_axial O(1) + emit signal (~0ms) + feature-003 response (~1ms, within 1 frame) | ~17ms to coords, +16ms for response = ~33ms total |

All within 100ms. Scan hold classification at 300ms is intentional — the 300ms wait
is the design threshold, not latency. Once classified, the signal fires in <2ms.

#### Two-Outcome Touch Discrimination — Thresholds

| Parameter | Value | Exported | Rationale |
|-----------|-------|----------|-----------|
| `tap_max_duration` | 300ms | Yes | Standard mobile tap threshold |
| `tap_max_drag` | 20px | Yes | Prevents drag-taps from triggering interactions |
| `hold_threshold` | 300ms | Yes | Same as tap max — classification happens at this moment |
| `drag_threshold` | 20px | Yes | Drag triggers joystick immediately (even over ❓) |

**Classification timeline:**

```
t=0ms     Touch DOWN. Start tracking duration + drag.
t<300ms   If drag ≥ 20px → JOYSTICK immediately (drag = intent to move).
          If touch UP → TAP (duration < 300ms, drag < 20px) → no-op on world.
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

- Hex tiles: **[TUNING_REQUIRED for HEX_SIZE=3.0 + camera Vector3(0, 12, 8)]** — previous estimate (~54-72px) was for HEX_SIZE=1.0. Verify after camera calibration. Target: above 48dp minimum.
- ❓ elements: positioned on hex tiles, same touch target size.
- Joystick: no fixed zone — appears at touch point.

#### Platform Differences

None. `InputEventScreenTouch` / `InputEventScreenDrag` work identically on iOS and
Android in Godot. No platform-specific code.

#### Memory

Player node + Camera + JoystickOverlay = negligible.
Hit-test at hold threshold: one-time query, no ongoing memory.
