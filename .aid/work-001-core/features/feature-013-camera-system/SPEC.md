# Camera System — Third-Person Orbital

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-06 | Feature created for delivery-004b — third-person orbital camera replacing static offset | /aid-specify |

## Source

- delivery-004b (Camera + Landscape pivot)
- Replaces static offset camera from feature-002 (player_camera.gd)

## Description

The camera switches from a static top-down offset (Vector3(0,12,8)) to a third-person orbital camera. The player can orbit manually by dragging on the right 40% of the screen, and the camera auto-returns behind the player after 2 seconds of idle. Pinch-to-zoom adjusts distance. A raycast prevents terrain from occluding the player — the camera snaps closer when blocked. The camera remains a sibling of Player in the World node (not a child) to avoid jitter.

## User Stories

- As a player, I want to orbit the camera around my character so I can see the world from different angles
- As a player, I want the camera to auto-follow behind me when I'm moving so I don't have to manually adjust it constantly
- As a player, I want to pinch-to-zoom so I can see more of the world or focus on my character
- As a player, I want the camera to never clip through terrain so I always have a clear view

## Priority

Must (P0 — delivery-004b)

## Acceptance Criteria

- [ ] Camera orbits around player via drag on right 40% of screen
- [ ] Camera auto-returns behind player after 2s of no manual orbit input
- [ ] Default distance 7 units, pitch 40 degrees
- [ ] Pinch-to-zoom: distance range 5-12 units
- [ ] Pitch clamped between 20 and 70 degrees
- [ ] Terrain occlusion: camera snaps closer if raycast to player is blocked
- [ ] Camera remains clamped to map bounds (hex grid AABB)
- [ ] Camera is sibling of Player (not child) — no jitter
- [ ] Input zones: right 40% orbit, left 40% joystick (unchanged), center 20% world interaction

## Save Integration

Camera state (yaw, pitch, distance) IS saved and restored on load. This is intentional — the player's chosen viewpoint is part of their session context.

---

## Technical Specification

### Data Model

#### Camera Constants

```gdscript
# player_camera.gd — exported constants for tuning
const CAMERA_DISTANCE_DEFAULT: float = 7.0
const CAMERA_DISTANCE_MIN: float = 5.0
const CAMERA_DISTANCE_MAX: float = 12.0
const CAMERA_PITCH_DEFAULT: float = 40.0   # degrees
const CAMERA_PITCH_MIN: float = 20.0       # degrees
const CAMERA_PITCH_MAX: float = 70.0       # degrees
const CAMERA_ORBIT_SENSITIVITY: float = 0.3
const CAMERA_ZOOM_SENSITIVITY: float = 0.01
const CAMERA_AUTO_FOLLOW_DELAY: float = 2.0   # seconds before auto-return
const CAMERA_AUTO_FOLLOW_SPEED: float = 2.0   # rad/s
const CAMERA_FOV: float = 60.0                # degrees (mobile optimal)
```

All constants are `@export` tunable in the inspector.

#### Camera Properties (on Camera3D node)

| Property | Type | Description |
|----------|------|-------------|
| `_distance` | `float` | Current distance from player (default 7.0) |
| `_yaw` | `float` | Horizontal orbit angle in radians |
| `_pitch` | `float` | Vertical orbit angle in radians (converted from degrees) |
| `_target` | `Node3D` | Reference to Player node |
| `_idle_timer` | `float` | Time since last manual orbit input (seconds) |
| `_is_orbiting` | `bool` | True while player is actively dragging to orbit |
| `_map_bounds` | `Rect2` | AABB of hex grid for clamping (computed on map_generated) |

#### Input Zones

Screen is divided into 3 vertical zones (percentage-based, resolution-independent):

```
┌──────────┬────────┬──────────┐
│          │        │          │
│  LEFT    │ CENTER │  RIGHT   │
│  40%     │  20%   │  40%     │
│          │        │          │
│ Movement │ World  │ Camera   │
│ Joystick │ Tap    │ Orbit    │
│          │        │          │
└──────────┴────────┴──────────┘
```

| Zone | Screen X Range | Purpose | Handler |
|------|---------------|---------|---------|
| Left 40% | 0% - 40% | Movement joystick (unchanged) | player_input.gd → joystick_overlay.gd |
| Center 20% | 40% - 60% | World interaction (tap-to-select tiles) | player_input.gd → tap_tile signal |
| Right 40% | 60% - 100% | Camera orbit (drag to rotate) | player_camera.gd |

Pinch gesture: detected anywhere on screen (two-finger gesture), always routes to camera zoom.

#### Orbital Camera Geometry

```
        Camera3D
           \
            \  distance
             \
              \  pitch angle
               \___________
               |           |
               |  Player   |
               |___________|

Top-down view (yaw):
          N (yaw=0)
          |
    W ----+---- E
          |
          S

Camera position = Player.position + spherical_offset(yaw, pitch, distance)
```

```gdscript
# Spherical to cartesian offset
func _compute_offset() -> Vector3:
    var pitch_rad = deg_to_rad(_pitch)
    var x = _distance * sin(_yaw) * cos(pitch_rad)
    var y = _distance * sin(pitch_rad)
    var z = _distance * cos(_yaw) * cos(pitch_rad)
    return Vector3(x, y, z)
```

#### Occlusion Raycast

| Property | Value |
|----------|-------|
| Ray origin | Player.position + Vector3(0, 0.5, 0) (slightly above ground) |
| Ray target | Computed camera position |
| Collision mask | Terrain only (layer 1) |
| On hit | Camera distance = hit_point distance - 0.5 (snap closer) |
| On clear | Camera distance = _distance (user-set or default) |

Raycast runs every frame in `_process`. Uses `PhysicsDirectSpaceState3D.intersect_ray()` — no persistent RayCast3D node needed.

#### Save Data

None. Camera always resets to defaults on game load:
- `_distance = CAMERA_DISTANCE_DEFAULT`
- `_pitch = CAMERA_PITCH_DEFAULT`
- `_yaw` = behind player (derived from `Player.facing_direction`)

---

### Feature Flow

#### Startup Flow

```
player_camera.gd._ready():
  │
  ├─ Set FOV = CAMERA_FOV (60)
  ├─ _distance = CAMERA_DISTANCE_DEFAULT (7.0)
  ├─ _pitch = CAMERA_PITCH_DEFAULT (40.0)
  ├─ _yaw = derived from Player.facing_direction (behind player)
  ├─ _idle_timer = 0.0
  ├─ _is_orbiting = false
  │
  ├─ Connect to HexGrid.map_generated → _compute_bounds()
  │
  └─ Done — camera positioned behind player at default distance/pitch
```

#### Per-Frame Update (`_process`)

```
player_camera.gd._process(delta):
  │
  ├─ AUTO-FOLLOW CHECK:
  │     if NOT _is_orbiting:
  │       _idle_timer += delta
  │       if _idle_timer >= CAMERA_AUTO_FOLLOW_DELAY:
  │         # Compute target yaw (behind player)
  │         target_yaw = atan2(-Player.facing_direction.x, -Player.facing_direction.y)
  │         # Smooth rotation toward target
  │         _yaw = lerp_angle(_yaw, target_yaw, CAMERA_AUTO_FOLLOW_SPEED * delta)
  │
  ├─ COMPUTE POSITION:
  │     offset = _compute_offset()  # spherical → cartesian
  │     desired_pos = Player.position + offset
  │
  ├─ OCCLUSION CHECK:
  │     ray_origin = Player.position + Vector3(0, 0.5, 0)
  │     ray_target = desired_pos
  │     result = space_state.intersect_ray(ray_origin → ray_target, terrain mask)
  │     if result:
  │       # Snap camera closer — distance to hit point minus margin
  │       actual_distance = (result.position - ray_origin).length() - 0.5
  │       actual_distance = max(actual_distance, CAMERA_DISTANCE_MIN)
  │       offset = _compute_offset_at_distance(actual_distance)
  │       desired_pos = Player.position + offset
  │
  ├─ MAP BOUNDS CLAMP:
  │     desired_pos.x = clampf(desired_pos.x, _map_bounds.position.x, _map_bounds.end.x)
  │     desired_pos.z = clampf(desired_pos.z, _map_bounds.position.y, _map_bounds.end.y)
  │
  ├─ APPLY:
  │     position = desired_pos
  │     look_at(Player.position + Vector3(0, 0.5, 0))  # look at player center
  │
  └─ Done
```

#### Manual Orbit Flow (right 40% drag)

```
Touch DOWN in right 40% of screen
  │
  ├─ _is_orbiting = true
  ├─ _idle_timer = 0.0
  │
  ├─ Each frame while dragging:
  │     drag_delta = current_touch_pos - previous_touch_pos
  │     _yaw += drag_delta.x * CAMERA_ORBIT_SENSITIVITY * delta
  │     _pitch -= drag_delta.y * CAMERA_ORBIT_SENSITIVITY * delta
  │     _pitch = clampf(_pitch, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
  │
  └─ Touch UP:
       _is_orbiting = false
       _idle_timer = 0.0  # start countdown to auto-follow
```

#### Pinch-to-Zoom Flow

```
Two-finger pinch detected (anywhere on screen)
  │
  ├─ Compute pinch_delta = current finger distance - previous finger distance
  │
  ├─ _distance -= pinch_delta * CAMERA_ZOOM_SENSITIVITY
  ├─ _distance = clampf(_distance, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
  │
  └─ Done (takes effect next _process frame)
```

#### Auto-Follow Return Flow

```
No manual orbit input for CAMERA_AUTO_FOLLOW_DELAY seconds
  │
  ├─ Compute target_yaw = behind Player.facing_direction
  │     target_yaw = atan2(-facing_direction.x, -facing_direction.y)
  │
  ├─ Each frame:
  │     _yaw = lerp_angle(_yaw, target_yaw, CAMERA_AUTO_FOLLOW_SPEED * delta)
  │
  ├─ Continue until _yaw ~= target_yaw (within 0.01 rad)
  │     OR manual orbit input received → cancel auto-follow
  │
  └─ Done (camera is behind player)
```

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ (all world renderers from features 001-012)
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)            [feature-002]
       │    ├─ PlayerInput (Node)               [feature-002, MODIFIED — zone routing]
       │    ├─ (all player child systems from features 003-011)
       │    └─ ...
       └─ Camera3D                              ← THIS FEATURE (replaces static offset)

  └─ JoystickOverlay (CanvasLayer, layer 10)    [feature-002, LEFT 40% ONLY]
  └─ HUD (CanvasLayer, layer 20)                [feature-012]
  └─ ScreenFade (CanvasLayer, layer 30)         [feature-007]
  └─ CutsceneViewer (CanvasLayer, layer 40)     [feature-011]
```

**Camera3D remains a sibling of Player** — same as before. The only change is the script behavior: static offset → orbital.

#### File Structure

```
scripts/
  player/
    player_camera.gd       # Camera3D script — REWRITTEN: orbital, auto-follow,
                            #   occlusion raycast, pinch zoom, map bounds clamp
    player_input.gd        # Node — MODIFIED: input zone routing (left/center/right)
```

No new scenes. Camera3D node already exists in the scene tree.

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `player_camera.gd` | Orbital camera: yaw/pitch/distance control, auto-follow rotation, occlusion raycast, pinch zoom, map bounds clamping. Receives orbit input directly via `_unhandled_input` (right 40% zone). | `Player.position`, `Player.facing_direction`, `HexGrid` (map bounds), Physics space state (raycast) |
| `player_input.gd` | MODIFIED: routes touch input to correct handler based on screen zone. Left 40% → joystick. Center 20% → tap_tile. Right 40% → forwarded to camera (or camera handles its own input via zone check). | `joystick_overlay.gd` (left zone), `player_camera.gd` (right zone) |

#### Input Zone Routing

Two approaches (implementation choice):

**Option A — PlayerInput routes all input:**
```gdscript
# player_input.gd
func _unhandled_input(event):
    var zone = _get_zone(event.position.x)
    match zone:
        Zone.LEFT:   _handle_joystick(event)
        Zone.CENTER: _handle_world_tap(event)
        Zone.RIGHT:  _forward_to_camera(event)
```

**Option B — Each system checks its own zone:**
```gdscript
# player_input.gd handles LEFT + CENTER only
# player_camera.gd handles RIGHT zone independently via _unhandled_input
```

Option B preferred — keeps camera self-contained. Each system rejects input outside its zone.

#### Signal Wiring

```
HexGrid                              player_camera.gd
  map_generated()                ──►  _compute_bounds()

Player                               player_camera.gd
  (reads position + facing_direction each frame — no signal, direct access)
```

No new signals. Camera reads player state directly (same node tree).

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Orbital position compute | 2 trig calls + vector math | Every frame |
| Occlusion raycast | 1 physics raycast | Every frame |
| Auto-follow lerp | 1 lerp_angle | Every frame (when idle > 2s) |
| Pinch detection | 2-finger distance calc | On pinch input only |
| Map bounds clamp | 2 clampf calls | Every frame |

Total per-frame cost: ~1 raycast + basic math. Well within budget.

#### Draw Calls

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| Camera3D | 0 | Camera is not rendered — it defines the viewport |
| **Total** | **0** | Running total unchanged |

#### Touch Interaction

| Zone | Input | Size |
|------|-------|------|
| Left 40% | Joystick (unchanged) | 40% of screen width |
| Center 20% | World tap (tap-to-select) | 20% of screen width |
| Right 40% | Camera orbit (drag) | 40% of screen width |
| Anywhere | Pinch-to-zoom (two fingers) | Full screen |

Zone boundaries are percentage-based — work at any resolution.

#### Platform Differences

None. `InputEventScreenTouch` / `InputEventScreenDrag` / multi-touch pinch work identically on iOS and Android in Godot.

#### Memory

- Camera properties: ~100 bytes (floats + vectors)
- Raycast: per-frame query, no persistent allocation
- Total: negligible
