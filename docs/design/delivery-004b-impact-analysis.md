# Delivery 004b: Camera & Layout Overhaul -- Impact Analysis

**Date:** 2026-04-06
**Summary:** Convert from top-down portrait (1080x1920) to third-person orbital landscape (1920x1080). Add visible player model, camera orbit via second finger, and landscape HUD layout.

---

## Impact Summary

| System | Impact | Key Change |
|--------|--------|------------|
| Camera (`player_camera.gd`) | **HIGH** | Rewrite: static offset to orbital controller |
| Player Input (`player_input.gd`) | **HIGH** | Multi-touch split: left = joystick, right = camera orbit |
| HUD Layout (`hud.tscn`, `hud.gd`) | **HIGH** | Full redesign for landscape aspect ratio |
| Project Settings (`project.godot`) | **HIGH** | Viewport 1920x1080, orientation landscape |
| Joystick Overlay (`joystick_overlay.gd`) | **MEDIUM** | Confine to left half of screen |
| Player (`player.gd`) | **MEDIUM** | Movement relative to camera yaw; add child model node |
| Hex Grid Renderer (`hex_grid_renderer.gd`) | **MEDIUM** | Cliff faces need side-angle visual pass; normals review |
| FloatingText (`floating_text_manager.gd`) | **MEDIUM** | `_world_to_screen` affected by new camera projection |
| Day/Night Shader (`hex_tile.gdshader`) | **LOW** | `player_world_pos` uniform unchanged; lantern falloff unaffected |
| Resource Renderer (`resource_renderer.gd`) | **LOW** | Unshaded MultiMesh; may want shaded materials later |
| Prop Label Renderer (`prop_label_renderer.gd`) | **LOW** | Billboard labels already camera-independent |
| Scan Progress Renderer (`scan_progress_renderer.gd`) | **LOW** | Billboard bar already camera-independent |
| Ground Item Renderer (`ground_item_renderer.gd`) | **LOW** | Flat disc markers; no visual change needed |
| FlyToPlayer (`fly_to_player.gd`) | **LOW** | 3D tween arc; works regardless of camera |
| Main Scene (`main.tscn`) | **LOW** | Camera3D node setup changes; player model sub-scene |
| Main Wiring (`main.gd`) | **LOW** | No logic changes; may wire camera rotation input |
| World (`world.gd`) | **NONE** | Lighting registration unchanged |
| Day/Night Cycle (`day_night_cycle.gd`) | **NONE** | Phase timer, visibility radius, lighting -- all camera-independent |
| Scanner System (`scanner_system.gd`) | **NONE** | Proximity scan logic uses hex distance, not screen space |
| Auto-Interaction (`auto_interaction_system.gd`) | **NONE** | World-space proximity gather; no camera dependency |
| Survival System (`survival_system.gd`) | **NONE** | Stat decay/death; no rendering dependency |
| Crafting System (`crafting_system.gd`) | **NONE** | Recipe/workbench logic; no rendering dependency |
| Save Manager (`save_manager.gd`) | **NONE** | Serialization paths unchanged |
| Shaders (`scan_progress.gdshader`) | **NONE** | Billboard shader; camera-agnostic |
| Test Suite (29 test files) | **MEDIUM** | Camera mock updates; HUD layout assertions; input tests |

---

## HIGH Impact Systems

### 1. Camera System

**File:** `scripts/player/player_camera.gd`

**Current state:**
- Extends Camera3D, sibling of Player under World
- Static `offset = Vector3(0, 12, 8)` -- 12 up, 8 back
- Smooth lerp follow (`follow_speed = 8.0`)
- Map bounds clamping from `HexGrid._tiles`
- Finds Player via `get_parent().get_node_or_null("Player")`

**What changes:**
- Replace static offset with orbital parameters: `distance` (6-8 units), `pitch` (35-45 deg), `yaw` (player-controlled)
- FOV export (~60 degrees, currently Godot default 75)
- Add `rotate_orbit(yaw_delta, pitch_delta)` public method for input to call
- Keep lerp follow for position, add slerp/lerp for rotation
- Keep map bounds clamping (adjust for lower camera = tighter bounds)
- Auto-follow: camera yaw auto-aligns behind player facing direction when no manual orbit input (with configurable delay)
- Consider making camera a child of a pivot Node3D at Player position for cleaner orbital math

**Specific modifications:**
```
- offset: Vector3        --> distance: float, pitch: float, yaw: float
- _process lerp          --> position lerp + rotation from spherical coords
- _compute_bounds        --> adjust padding for lower, tighter camera
+ rotate_orbit()         --> called by input system
+ _auto_follow_yaw()    --> smooth return behind player
```

**Risk:**
- Camera clipping through terrain at low pitch angles near cliffs (ELEVATION_STEP = 0.5, distance 6-8)
- Bounds clamping math changes from additive offset to spherical projection
- `look_at` or basis math errors causing camera flip at pitch extremes

**Dependencies:**
- `player_input.gd` sends orbit deltas to this
- `floating_text_manager.gd` uses `camera.unproject_position()` -- still works, different projection
- `player.gd` movement direction must now account for camera yaw
- `day_night_cycle.gd` sets `player_world_pos` shader uniform via `_on_tile_entered` -- no dependency on camera, safe

---

### 2. Player Input System

**File:** `scripts/player/player_input.gd`

**Current state:**
- Single-touch state machine: IDLE -> TRACKING -> JOYSTICK
- All touches go through one finger path
- `_unhandled_input` handles `InputEventScreenTouch` + `InputEventScreenDrag`
- Ray cast `_screen_to_axial` uses Camera3D for tap-to-tile on Y=0 plane
- References camera as sibling: `get_parent().get_parent().get_node_or_null("Camera3D")`

**What changes:**
- Multi-touch tracking: left half = movement (finger 0), right half = camera orbit (finger 1)
- Track touch `index` from `InputEventScreenTouch.index` / `InputEventScreenDrag.index`
- Left touch: existing joystick behavior (IDLE -> TRACKING -> JOYSTICK)
- Right touch: new camera orbit behavior -- drag delta maps to `camera.rotate_orbit(yaw, pitch)`
- Tap detection remains on left touch only (or either side, design decision)
- `_screen_to_axial` ray cast: ground plane intersection still works but camera angle changes ray geometry

**Specific modifications:**
```
- _state: single enum     --> _left_state + _right_state (or per-finger dict)
- _touch_origin: Vector2  --> _left_origin, _right_origin
- _touch_current: Vector2 --> _left_current, _right_current
+ _camera_ref: for calling rotate_orbit()
+ SCREEN_SPLIT_X: float   = viewport_width * 0.5 (or dynamic)
+ New signals: camera_orbit_started, camera_orbit_moved
```

**Risk:**
- Touch index tracking across press/release -- Godot touch events use `index` field, must map correctly
- `_unhandled_input` may receive touches consumed by HUD on left side; existing `mouse_filter=STOP` on HUD buttons already handles this, but landscape layout changes button positions
- `_screen_to_axial` ray cast intersecting Y=0 plane at steeper angles may hit further from the player, making tap targets less intuitive

**Dependencies:**
- `joystick_overlay.gd` receives `show_at` / `update_knob` / `hide_visual` from this -- left finger only
- `player_camera.gd` receives orbit input from this
- `player.gd` receives joystick signals from this (unchanged signal signatures)

---

### 3. HUD Layout

**Files:** `scenes/ui/hud.tscn`, `scripts/hud/hud.gd`, `scripts/hud/stat_bars.gd`, `scripts/hud/floating_text_manager.gd`

**Current state (portrait 1080x1920):**
- TopBar: HBoxContainer anchored to top, 8px margins. StatBars left (3x ProgressBar, 200x24 each), DayCounter right (48px font, 64x64 phase icon)
- BottomBar: HBoxContainer anchored to bottom, 128x128 buttons (INV, BLD, CRF, SCN, JNL), 144px height
- Panels (Inventory, Catalog, Crafting): full-screen anchors, bottom drawer pattern
- NotificationContainer: positioned above BottomBar (offset_top=-260, offset_bottom=-96)
- PlacementLabel: centered at 35% height
- FloatingTextContainer: full-screen overlay

**What changes:**
- Viewport flips from 1080x1920 to 1920x1080 (or 2160x1080)
- TopBar: wider, shorter. Stat bars can go horizontal or stay stacked. Day counter stays right.
- BottomBar: 5 buttons spread across wider bottom. May reduce button size from 128 to 96 or use icon-only.
- Panels: bottom drawer stays but wider -- content layout changes (grid columns, scroll direction)
- NotificationContainer: adjust vertical offsets for shorter screen
- PlacementLabel: re-anchor for landscape proportions
- All hardcoded pixel offsets in `.tscn` need landscape values

**Specific modifications:**
```
hud.tscn:
  - TopBar offsets: wider (1920 vs 1080 horizontal)
  - BottomBar: more horizontal space, possibly smaller buttons
  - InventoryPanel/CatalogPanel/CraftingPanel: anchor + offset adjustments
  - NotificationContainer: offset_top, offset_bottom adjusted
  - PlacementLabel: re-anchor

stat_bars.gd:
  - ProgressBar min size may shrink (less vertical space available)

floating_text_manager.gd:
  - _world_to_screen uses camera.unproject_position -- projection changes
  - RISE_PIXELS / STACK_OFFSET may need tuning for shorter viewport
```

**Risk:**
- Panel sizes may not fit well in landscape without layout rethink (portrait had tall drawers, landscape is wide but short)
- Button touch targets shrinking below 48dp minimum for mobile usability
- Floating text appearing off-screen with new camera angle/projection
- Safe area / notch considerations on landscape mobile

**Dependencies:**
- `hud.gd` functional logic (panel toggling, signal wiring) is layout-independent -- safe
- `floating_text_manager.gd` depends on camera projection for `_world_to_screen`
- All panel sub-scenes (`inventory_panel.tscn`, `catalog_panel.tscn`, `crafting_panel.tscn`) need layout review

---

### 4. Project Settings

**File:** `project.godot`

**Current state:**
```
window/size/viewport_width=1080
window/size/viewport_height=1920
window/stretch/mode="viewport"
window/handheld/orientation=1  (portrait)
```

**What changes:**
```
window/size/viewport_width=1920   (or 2160)
window/size/viewport_height=1080
window/handheld/orientation=0     (landscape)
```

**Risk:**
- Any code that assumes portrait dimensions (height > width) will break
- Aspect ratio change affects all anchored UI nodes
- Mobile device safe areas differ between portrait and landscape
- Touch emulation from mouse may behave differently

**Dependencies:**
- Every UI scene in the project is affected by viewport size change
- `_screen_to_axial` ray cast geometry changes
- Joystick overlay draw coordinates affected

---

## MEDIUM Impact Systems

### 5. Joystick Overlay

**File:** `ui/joystick_overlay.gd`

**Current state:**
- Full-screen Control with `mouse_filter = IGNORE`
- Floating joystick appears at any touch origin
- `max_radius=80`, `base_radius=80`, `knob_radius=30`
- Custom `_draw()` renders base circle + knob at touch position

**What changes:**
- Constrain joystick activation to left half of screen (right half is camera orbit)
- Either: `show_at()` rejects origins with `x > viewport_width / 2`, or PlayerInput pre-filters
- Radii may need scaling for landscape proportions (wider screen = feels smaller)
- Consider fixed-position joystick (left thumb zone) vs floating

**Risk:**
- If joystick appears near screen center, it may conflict with camera orbit zone
- `_draw()` coordinates are relative to Control origin -- if Control is resized to left-half, coordinates shift

---

### 6. Player Movement

**File:** `scripts/player/player.gd`

**Current state:**
- Movement uses raw joystick direction: `Vector3(velocity_2d.x, 0.0, velocity_2d.y)`
- Joystick X maps directly to world X, joystick Y maps to world Z
- `facing_direction` stores normalized 2D movement vector
- No camera-relative movement

**What changes:**
- Joystick direction must be rotated by camera yaw before applying to world space
- Formula: `world_dir = joystick_dir.rotated(-camera_yaw)`
- Need reference to camera (or receive pre-rotated direction from input)
- Add visible player model as child node (capsule/placeholder MeshInstance3D)
- Model rotates to face `facing_direction`

**Specific modifications:**
```
+ _camera: Node reference (or signal-based yaw injection)
+ _process_walking: rotate joystick_dir by camera yaw before computing velocity
+ Child MeshInstance3D or PackedScene for player model
+ Model rotation: look_at or basis rotation to face movement direction
```

**Risk:**
- Camera yaw rotation applied incorrectly causes player to move in wrong direction
- Jump/drop tweens use absolute world positions -- unaffected by camera rotation, safe
- `_slide_along_boundary` uses world-space velocity -- must receive camera-rotated velocity, not raw joystick

**Dependencies:**
- `player_input.gd` joystick signals (direction, magnitude) -- unchanged signatures but semantics change
- `auto_interaction_system.gd` uses `player.position` and `player.current_tile` -- world space, unaffected
- `scanner_system.gd` uses `player.current_tile` -- unaffected

---

### 7. Hex Grid Renderer

**File:** `scenes/world/hex_grid_renderer.gd`

**Current state:**
- Single ArrayMesh: 13 vertices per hex (center + inner ring + outer corners)
- All face normals set to `Vector3.UP`
- Cliff faces as quads between elevation transitions, normal = outward from edge midpoint
- `render_mode unshaded` in shader -- no lighting response
- `ELEVATION_STEP = 0.5`

**What changes:**
- From top-down, cliff faces were barely visible (viewed edge-on). At 35-45 degree pitch, they become prominent visual elements.
- Cliff face quality: currently 1 quad per edge (2 triangles). May need subdivision for taller cliffs or texture.
- Cliff color: currently `tile_colors[coords] * 0.6` (60% darkened). At side angle, this flat darkening may look harsh.
- Top face normals are all `Vector3.UP` -- fine for unshaded, but if moving to shaded rendering later, this matters.
- No immediate geometry changes required, but visual quality assessment needed at new camera angle.

**Risk:**
- Z-fighting between cliff faces and adjacent hex top surfaces at glancing camera angles
- Cliff geometry gaps at corners where 3+ tiles meet at different elevations
- Performance: geometry count unchanged, but more fragments rendered (side surfaces visible)

---

### 8. Floating Text Manager

**File:** `scripts/hud/floating_text_manager.gd`

**Current state:**
- `_world_to_screen` calls `camera.unproject_position(world_pos)` to place 2D labels at 3D positions
- `RISE_PIXELS = 60.0`, `STACK_OFFSET = 30.0`
- Fallback: viewport center if no camera

**What changes:**
- New camera angle changes where world positions project to screen
- Labels may appear at unexpected screen positions (e.g., behind player instead of above)
- Rise/stack pixel values may need tuning for landscape viewport height (1080 vs 1920)

**Risk:**
- World positions behind the camera project to invalid screen coordinates
- Labels clustering near screen center due to perspective compression at lower angle

---

### 9. Test Suite

**Files:** 29 test files under `tests/`

**Affected tests:**

| Test File | Impact | Reason |
|-----------|--------|--------|
| `test_player_input.gd` | HIGH | Tests single-touch state machine; multi-touch changes everything |
| `test_player.gd` | MEDIUM | Tests movement; camera-relative direction changes expected values |
| `test_hex_grid_renderer.gd` | LOW | Tests mesh generation; geometry unchanged |
| `test_resource_renderer.gd` | NONE | Tests MultiMesh instance management; no camera dependency |
| `test_prop_renderers.gd` | NONE | Tests label creation; billboard labels are camera-independent |
| `test_scan_progress_renderer.gd` | NONE | Tests progress bar show/hide; no camera dependency |
| `test_ground_item_renderer.gd` | NONE | Tests marker instance management; no camera dependency |
| `test_feedback_wiring.gd` | LOW | Tests signal connections; may touch HUD assertions |
| `test_scanner_system.gd` | NONE | Tests proximity scan; hex distance only |
| `test_auto_interaction_system.gd` | NONE | Tests gather/pickup; world space only |
| `test_auto_gather.gd` | NONE | Tests gather flow; world space only |
| `test_crafting_system.gd` | NONE | Tests recipe logic; no rendering |
| `test_crafting_panel.gd` | LOW | Tests UI panel; layout may change |
| `test_catalog_panel_ui.gd` | LOW | Tests UI panel; layout may change |
| `test_save_manager.gd` | NONE | Tests serialization; no camera dependency |
| `test_day_night_*.gd` | NONE | Tests phase timer and lighting; no camera dependency |
| `test_survival_*.gd` | NONE | Tests stat decay; no rendering dependency |

**Key changes:**
- `test_player_input.gd`: currently tests single-finger IDLE->TRACKING->JOYSTICK. Must add multi-touch tests (left/right finger, screen-half split, camera orbit signals).
- `test_player.gd`: if movement becomes camera-relative, mock camera yaw must be injected.
- Camera mock: tests that reference `Camera3D` as sibling need updated tree structure if camera becomes child of pivot.

---

## LOW Impact Systems

### 10. Day/Night Shader

**File:** `shaders/hex_tile.gdshader`

The shader reads `player_world_pos` uniform and computes distance-based lantern falloff. This is entirely world-space math, independent of camera. The `render_mode unshaded` means no lighting response -- the shader handles its own brightness. **No changes needed.**

Minor consideration: at lower camera angles, the visual effect of lantern falloff will be more dramatic (seeing further along the ground). This is a visual quality observation, not a code change.

### 11. Resource Renderer

**File:** `scripts/rendering/resource_renderer.gd`

MultiMesh pools with `StandardMaterial3D` + `shading_mode = SHADING_MODE_UNSHADED`. Instance transforms are world-space. **No changes needed for the delivery.** At side angles, unshaded flat-color meshes may look less convincing -- future improvement to consider shaded materials.

### 12. Prop Label Renderer

**File:** `scripts/rendering/prop_label_renderer.gd`

Uses `Label3D` with `billboard = BILLBOARD_ENABLED` and `no_depth_test = true`. Billboards automatically face the camera regardless of angle. **No changes needed.**

### 13. Scan Progress Renderer

**File:** `scripts/rendering/scan_progress_renderer.gd`

Uses a billboard shader on a QuadMesh. Camera-independent. **No changes needed.**

### 14. Ground Item Renderer

**File:** `scripts/survival/ground_item_renderer.gd`

Flat cylinder discs (`height = 0.05`) lying on the ground. From a side angle these become nearly invisible (viewed edge-on). May want to replace with small spheres or add a slight billboard marker above them in a future pass. **No immediate code change required**, but visual assessment at new camera angle recommended.

### 15. FlyToPlayer

**File:** `scripts/rendering/fly_to_player.gd`

3D tween from resource position to player position with parabolic arc. Entirely world-space. **No changes needed.**

### 16. Main Scene

**File:** `scenes/main.tscn`

Camera3D node may change from direct child of World to child of a CameraPivot node. Player scene may gain a child MeshInstance3D for the visible model. Node references in `player_input.gd` camera lookup path change.

### 17. Main Wiring

**File:** `scripts/main.gd`

No functional logic depends on camera orientation. May need to wire camera rotation input if not handled within PlayerInput's `_ready()`. **Minimal change.**

---

## NONE Impact Systems

These systems are entirely camera-independent and require zero changes:

- **Day/Night Cycle** (`day_night_cycle.gd`): Phase timer, visibility radius, lighting -- all world-space
- **Scanner System** (`scanner_system.gd`): Proximity auto-scan uses hex distance
- **Auto-Interaction** (`auto_interaction_system.gd`): World-space proximity gather
- **Survival System** (`survival_system.gd`): Stat decay, death, respawn -- pure game logic
- **Crafting System** (`crafting_system.gd`): Recipe discovery, workbench proximity
- **Save Manager** (`save_manager.gd`): Serialization via NodePaths unchanged

---

## Implementation Order (Suggested)

| Phase | Task | Rationale |
|-------|------|-----------|
| 1 | `project.godot` viewport + orientation | Foundation -- everything else depends on this |
| 2 | Camera rewrite (`player_camera.gd`) | New orbital controller with pitch/yaw/distance |
| 3 | Input split (`player_input.gd`) | Multi-touch: left = joystick, right = orbit |
| 4 | Joystick confinement (`joystick_overlay.gd`) | Left-half only activation |
| 5 | Camera-relative movement (`player.gd`) | Rotate joystick direction by camera yaw |
| 6 | Player model (`player.gd` + scene) | Visible capsule/placeholder as child of Player |
| 7 | HUD landscape layout (`hud.tscn` + panels) | Full layout redesign for 1920x1080 |
| 8 | Floating text tuning (`floating_text_manager.gd`) | Verify projection at new angle |
| 9 | Visual assessment pass | Cliff faces, ground items, resource meshes at side angle |
| 10 | Test suite updates | Multi-touch tests, camera mock, HUD assertions |

---

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| Camera clip through terrain at low pitch near cliffs | HIGH | Clamp minimum distance, add collision raycast |
| Touch input regression (multi-touch tracking) | HIGH | Comprehensive test matrix: 1 finger, 2 fingers, rapid tap+orbit |
| HUD elements too small on landscape mobile | MEDIUM | Enforce 48dp minimum touch targets; test on real devices |
| Player moves wrong direction with camera rotation | MEDIUM | Unit test: joystick (0,1) at camera yaw 90 deg = world (-1,0) |
| Floating text off-screen or behind camera | MEDIUM | Cull labels where `unproject_position` returns behind-camera coords |
| Ground item discs invisible at side angle | LOW | Defer to future pass; switch to sphere markers if needed |
| Save compatibility | LOW | No save format changes; camera state not persisted |
| Performance from more visible cliff geometry | LOW | Geometry count unchanged; fragment count slightly higher |
