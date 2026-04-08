# delivery-004b: New Perspective — Camera + Landscape Layout

**Status:** In Progress (7/8 tasks done, 038b in progress)
**Created:** 2026-04-06
**Features:** feature-013-camera-system, feature-014-landscape-layout, feature-015-terrain-slopes
**Depends on:** delivery-004 (024-031)
**Cumulative state:** Third-person orbital camera, landscape orientation, visible player, camera-relative movement

## Motivation

The game pivots from top-down portrait (board game feel) to third-person orbital landscape (exploration feel). This must happen before delivery-005b (Building + Fauna) because:
- Structure placement feedback depends on camera perspective
- Fauna needs to be visible at player level for threat impact
- All future visual work builds on this foundation

## Execution Graph

```
task-032b (Project settings —
  landscape viewport + orientation)
  │
  ├──────────────────────────────────┐
  ▼                                  ▼
task-033b (Camera rewrite —         task-036b (Player model —
  orbital controller,                 capsule mesh, facing
  auto-follow, occlusion,            rotation, material)
  pinch zoom, bounds clamp)          │
  │                                  │
  ▼                                  │
task-034b (Input zone split —        │
  left=joystick, center=tap,         │
  right=orbit, pinch=zoom)           │
  │                                  │
  ├──────────────────────────────────┘
  ▼
task-035b (HUD landscape layout —
  stat bars, buttons, panels
  repositioned for 1920x1080)
  │
  ▼
task-037b (Camera-relative movement —
  joystick direction rotated by
  camera yaw)
  │
  ▼
task-039b (Terrain slopes —
  interpolate edge Y for diff 1-3,
  cliff faces only for diff 4+)
  │
  ▼
task-038b (Visual polish + test —
  floating text projection,
  integration test)
```

**Parallel groups:**
- task-033b ∥ task-036b: camera rewrite and player model are independent
- task-034b depends on task-033b: input zones route to camera
- task-035b depends on task-034b: HUD must respect input zones
- task-037b depends on task-033b + task-036b: movement needs camera yaw + visible model
- task-039b depends on task-037b: terrain slopes need orbital camera to evaluate visually
- task-038b depends on all above: final visual/test pass

## Tasks

| # | Name | Type | Depends On | Parallel With | Status |
|---|------|------|-----------|---------------|--------|
| 032b | Project settings — landscape viewport + orientation | IMPLEMENT | delivery-004 | -- | DONE |
| 033b | Camera orbital controller | IMPLEMENT | 032b | 036b | DONE |
| 034b | Input zone split — multi-touch routing | IMPLEMENT | 033b | 036b | DONE |
| 035b | HUD landscape layout | IMPLEMENT | 034b | -- | DONE |
| 036b | Player model placeholder | IMPLEMENT | 032b | 033b | DONE |
| 037b | Camera-relative movement | IMPLEMENT | 033b, 036b | 035b | DONE |
| 039b | Terrain slopes — elevation edge interpolation | IMPLEMENT | 037b | -- | DONE |
| 038b | Visual polish + integration test | TEST | all above | -- | IN PROGRESS |

## Task Details

### task-032b: Project Settings — Landscape Viewport + Orientation [IMPLEMENT]

**Source:** feature-014 → Screen Orientation

**Scope:**
- `project.godot`:
  - `window/size/viewport_width` = 1920
  - `window/size/viewport_height` = 1080
  - `window/handheld/orientation` = 2 (landscape)
  - Keep `window/stretch/mode = "viewport"`
  - Keep `renderer/rendering_method = "mobile"`

**Criteria:**
- [ ] Game launches in landscape orientation
- [ ] Viewport is 1920x1080
- [ ] Existing world renders correctly (hexes, props, labels)
- [ ] Touch input still works (may look wrong positionally — fixed in later tasks)

---

### task-033b: Camera Orbital Controller [IMPLEMENT]

**Source:** feature-013 → Full spec

**Scope:**
- Rewrite `scripts/player/player_camera.gd`:
  - Replace static `offset` with orbital: `_distance`, `_yaw`, `_pitch`
  - FOV = 60 degrees
  - Default: distance=7, pitch=40deg
  - Spherical-to-cartesian position computation
  - `look_at(Player.position + Vector3(0, 0.5, 0))`
  - Auto-follow: after 2s idle, smooth lerp_angle yaw back behind player facing_direction
  - Map bounds clamping (adjusted for lower camera angle)
  - Occlusion raycast: PhysicsDirectSpaceState3D.intersect_ray from player to camera, snap closer on hit
  - Pinch-to-zoom: distance range 5-12 units
- Constants (all @export for tuning):
  - CAMERA_DISTANCE_DEFAULT = 7.0, MIN = 5.0, MAX = 12.0
  - CAMERA_PITCH_DEFAULT = 40.0, MIN = 20.0, MAX = 70.0
  - CAMERA_ORBIT_SENSITIVITY = 0.3
  - CAMERA_ZOOM_SENSITIVITY = 0.01
  - CAMERA_AUTO_FOLLOW_DELAY = 2.0
  - CAMERA_AUTO_FOLLOW_SPEED = 2.0
  - CAMERA_FOV = 60.0
- Camera handles its own orbit input (right 40% of screen) via `_unhandled_input`
- Camera remains sibling of Player in World node (not child)

**Criteria:**
- [ ] Camera orbits around player at correct distance/pitch
- [ ] Manual orbit via drag on right 40% of screen
- [ ] Auto-follow returns camera behind player after 2s idle
- [ ] Pinch-to-zoom between 5 and 12 units
- [ ] Pitch clamped 20-70 degrees (no camera flip)
- [ ] Occlusion raycast: camera snaps closer when terrain blocks view
- [ ] Map bounds clamping prevents camera flying off world edge
- [ ] No jitter (camera is sibling, not child of player)

---

### task-034b: Input Zone Split — Multi-Touch Routing [IMPLEMENT]

**Source:** feature-013 → Input Zones, feature-014 → Input Zone Split

**Scope:**
- Modify `scripts/player/player_input.gd`:
  - Zone detection: left 40% = joystick, center 20% = world tap, right 40% = camera (handled by camera script)
  - `_unhandled_input` checks touch position.x against viewport width thresholds
  - Left zone: existing joystick behavior (unchanged logic, zone-gated)
  - Center zone: tap_tile ray cast (update ray cast for new camera angle)
  - Right zone: reject/ignore (camera handles its own input)
  - Track touch index per zone (prevent cross-zone finger conflicts)
  - Pinch detection: two-finger gesture anywhere → forward to camera
- Modify `ui/joystick_overlay.gd`:
  - Confine show_at() to left 40% of screen (reject right-side touches)

**Criteria:**
- [ ] Left 40% of screen activates joystick (unchanged behavior)
- [ ] Center 20% handles world tap (tile selection)
- [ ] Right 40% does NOT trigger joystick
- [ ] Two-finger pinch adjusts camera zoom from anywhere on screen
- [ ] No cross-zone conflicts (finger on left + finger on right work independently)
- [ ] Ray cast for tap_tile works correctly with new camera angle

---

### task-035b: HUD Landscape Layout [IMPLEMENT]

**Source:** feature-014 → HUD Repositioning

**Scope:**
- Redesign `scenes/ui/hud.tscn` for landscape 1920x1080:
  - TopBar → split: StatBars top-left, DayCounter top-right
  - BottomBar → Bottom-right: action buttons (96x96, horizontal row)
  - Panels (inventory, catalog, crafting): right-side drawer or narrower bottom drawer
  - FloatingTextContainer: centered in viewport
  - NotificationContainer: top-center
  - PlacementLabel: centered
- Update `scripts/hud/hud.gd` as needed for layout changes
- Ensure HUD does NOT overlap input zones:
  - Left 40%: no HUD elements (joystick zone)
  - Bottom-right buttons: within right 40% but above camera drag area
- All touch targets >= 48dp (Android minimum)
- Button size: 96x96 (down from 128x128 to fit landscape)

**Criteria:**
- [ ] Stat bars visible top-left at all times
- [ ] Day counter visible top-right
- [ ] Action buttons (5) visible bottom-right, 96x96 minimum
- [ ] Panels open without overlapping joystick zone
- [ ] No HUD elements in left 40% (movement zone)
- [ ] All touch targets >= 48dp
- [ ] Mutual exclusion still works (one panel at a time)

---

### task-036b: Player Model — Facing Rotation + Visual Review [IMPLEMENT]

**Source:** feature-014 → Player Model

**Scope:**
- Player model already exists in `scenes/player/player.tscn`:
  - `PlayerModel` (Node3D) with Head, Torso, LeftArm, RightArm (with cyan Bracelet), LeftLeg, RightLeg
  - Blocky humanoid style with suit_mat (grey-blue) + skin_mat (peach) + bracelet_mat (emissive cyan)
  - Total height ~1.8 units, positioned above ground
- Add facing rotation to `PlayerModel`:
  - In player.gd `_process` or when facing_direction changes
  - Rotation around Y axis: `$PlayerModel.rotation.y = atan2(facing_direction.x, facing_direction.y)`
  - Only rotate when facing_direction is non-zero
- Visual review from orbital camera:
  - Does the blocky model read well at 6-8 unit camera distance on mobile?
  - Is the emissive cyan bracelet visible as "the character's signature"?
  - Does the model need scaling for the new camera angle?
  - Material: consider switching to unshaded to match world style (currently standard shaded)

**Criteria:**
- [ ] Player model rotates to face movement direction
- [ ] Model visible and readable at all zoom levels (5-12 units)
- [ ] Emissive bracelet distinguishes player from terrain
- [ ] Model rises/falls with elevation correctly
- [ ] Does not interfere with camera occlusion raycast (exclude player collision layer)

---

### task-037b: Camera-Relative Movement [IMPLEMENT]

**Source:** feature-013 → affects feature-002 movement

**Scope:**
- Modify `scripts/player/player.gd`:
  - Joystick direction is currently world-space (up = -Z, right = +X)
  - With orbital camera, joystick "up" should mean "away from camera" (forward)
  - Rotate joystick direction by camera yaw before applying:
    ```
    var cam_yaw = camera.get_yaw()  # or read from camera node
    var rotated_dir = joystick_dir.rotated(-cam_yaw)
    ```
  - Camera reference: get_node("../Camera3D") or export reference
  - facing_direction updated from rotated direction (model faces movement direction)
- Jump/drop arcs: unchanged (world-space destination, not camera-relative)
- Slide-along-boundary: unchanged (world-space)

**Criteria:**
- [ ] Joystick "up" moves player away from camera (forward in camera view)
- [ ] Joystick "right" moves player right relative to camera view
- [ ] Movement direction changes when camera orbits
- [ ] Player model faces movement direction correctly
- [ ] Jump/drop arcs still work (world-space targets)
- [ ] Slide along boundary still works

---

### task-039b: Terrain Slopes — Elevation Edge Interpolation [IMPLEMENT]

**Source:** feature-015 → Terrain Slopes

**Scope:**
- Modify `scenes/world/hex_grid_renderer.gd` mesh generation:
  - **Current behavior:** All elevation differences produce hard cliff edges (vertical quads).
    Corner vertices use `Vector3i(x*1000, elevation, z*1000)` as key — different elevations
    never share corners → abrupt step.
  - **New behavior:** Three transition types based on elevation diff:
    - **Diff 0:** Same as now — shared corners, flat transition
    - **Diff 1-3 (WALK/JUMP/DROP):** Slope. Outer corner vertices on the shared edge
      interpolate Y between the two elevations. The higher tile's edge corners slope
      DOWN toward the neighbor. Inner ring (85% radius) stays at tile's own elevation.
      No cliff face quad generated.
    - **Diff 4+ (BLOCKED):** Cliff. Vertical quad as current. No interpolation.
  - Implementation approach:
    - Step 2 (corner map): For each corner, collect all neighboring tile elevations
    - New step: For each hex edge, check neighbor elevation diff:
      - If diff 1-3: corner Y = weighted average of own elevation and neighbor elevation
        (e.g., `lerp(own_y, neighbor_y, 0.5)` at the shared edge)
      - If diff 0 or diff 4+: corner Y = own elevation (as now)
    - Step 5 (cliff faces): Only generate when diff >= 4 (currently generates for any diff > 0)
  - Corner vertex may have different Y per adjacent edge → each hex needs per-edge corner
    vertices (not shared). This increases vertex count from 13 to up to 19 per hex
    (center + 6 inner + 6 outer_high + 6 outer_low in worst case). Acceptable for mobile
    (~250 tiles × 19 vertices = ~4750 vertices, well within budget).
- Modify player Y interpolation in `scripts/player/player.gd`:
  - `_update_elevation_y_interpolated()` already lerps between tile elevations during WALK.
  - For JUMP/DROP: Y arc animation handles elevation change — no change needed.
  - Player should walk smoothly on slopes. Current Y interpolation based on distance
    between tile centers should work naturally with sloped geometry.

**Criteria:**
- [ ] Diff 0: flat shared edges (unchanged)
- [ ] Diff 1: gentle slope visible from orbital camera
- [ ] Diff 2-3: steeper slope, visually distinct from gentle
- [ ] Diff 4+: vertical cliff face (unchanged)
- [ ] No gaps or z-fighting between sloped edges
- [ ] Player walks smoothly on slopes (no hovering or clipping)
- [ ] Single ArrayMesh draw call maintained (1 draw call for all hexes)
- [ ] Slopes look natural from orbital camera angle (35-45 deg pitch)

---

### task-038b: Visual Polish + Integration Test [TEST]

**Source:** Impact analysis — visual review items

**Scope:**
- Visual review:
  - Terrain slopes from orbital angle (smooth transitions, no gaps)
  - Floating text projection: verify text appears at correct screen positions
  - Prop labels: verify billboard Labels3D orient correctly to orbital camera
  - Ground item markers: verify colored discs visible from orbital angle
  - Day/night lighting: verify darkness uniform + lantern falloff look correct from new angle
- Test updates:
  - `test_player_input.gd`: multi-touch zone routing tests
  - `test_player.gd`: camera-relative movement direction
  - `test_player_camera.gd`: new test file for orbital camera behavior
  - Update any tests that assert portrait-specific HUD positions
- Integration test:
  - Full game loop: move → camera orbit → interact → menu → save/load
  - Verify no regressions in survival, scanning, crafting, day/night

**Criteria:**
- [ ] All hex tiles render correctly from orbital angle
- [ ] Slopes smooth from orbital angle, cliffs sharp for diff 4+
- [ ] Floating text appears near world objects, not offset
- [ ] Billboard labels face camera correctly
- [ ] Day/night lighting transitions look correct from new angle
- [ ] All existing tests pass (or updated for new layout)
- [ ] New camera tests cover: orbit, auto-follow, pinch zoom, occlusion, bounds
- [ ] New input tests cover: zone routing, multi-touch, cross-zone isolation
- [ ] Full game loop smoke test passes

---

## Out of Scope (explicitly excluded)

- Final art assets (props, structures, creatures) — separate art pipeline
- Master shader evolution (rim light, emission) — incremental, post-004b
- Bioluminescence effects — future delivery
- Biome-specific tile meshes (vegetation, terrain detail) — future delivery
- Fauna, building, journal features — delivery-005b, -006
- Inventory stack limit redesign — deferred discussion

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| Camera terrain clipping at low pitch near cliffs | HIGH | Occlusion raycast + pitch min 20deg + distance min 5.0 |
| Multi-touch input regressions | HIGH | Per-zone touch index tracking, thorough test coverage |
| HUD touch targets too small in landscape | MEDIUM | Enforce 48dp minimum, test on physical device |
| Camera-relative movement feels disorienting | MEDIUM | Auto-follow aligns camera behind player, reducing dissonance |
| Floating text/labels mispositioned | LOW | billboard + unproject_position adapts to any camera automatically |
| Slope geometry gaps at 3-way elevation junctions | MEDIUM | Average corner Y from both adjacent edges; visual smoke test |
| Existing tests break from layout changes | LOW | Update assertions in task-038b, batch fix |

## References

- Impact Analysis: `docs/design/delivery-004b-impact-analysis.md`
- Feature-013 SPEC: `.aid/work-001-core/features/feature-013-camera-system/SPEC.md`
- Feature-014 SPEC: `.aid/work-001-core/features/feature-014-landscape-layout/SPEC.md`
- Feature-015 SPEC: `.aid/work-001-core/features/feature-015-terrain-slopes/SPEC.md`
- Mobile Guidelines: `~/lola/projects/farhaven-research/mobile-game-design-guidelines.md`
- Art Direction: `~/lola/projects/farhaven-research/asset-direction-research.md`
