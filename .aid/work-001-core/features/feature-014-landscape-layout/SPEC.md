# Landscape Layout — Orientation + HUD + Player Model

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-06 | Feature created for delivery-004b — landscape orientation, HUD reposition, player model placeholder, input zone split | /aid-specify |

## Source

- delivery-004b (Camera + Landscape pivot)
- Modifies feature-012 (HUD), feature-002 (Player), project.godot settings

## Description

The game switches from portrait (1080x1920) to landscape (1920x1080). This feature covers four changes: (A) screen orientation flip in project.godot, (B) HUD repositioned for landscape layout, (C) visible player model placeholder (cyan capsule), and (D) input zone split into left 40% (joystick), center 20% (world interaction), right 40% (camera orbit). The input zone split is shared with feature-013 (camera system).

## User Stories

- As a player, I want the game in landscape so I see more of the world horizontally and the camera angle feels natural
- As a player, I want the HUD positioned so it doesn't block my view of the game world or overlap with input zones
- As a player, I want to see my character in the world so I know where I am and which direction I'm facing
- As a player, I want clear touch zones so movement, camera, and world interaction don't conflict

## Priority

Must (P0 — delivery-004b)

## Acceptance Criteria

- [ ] Game runs in landscape orientation (1920x1080)
- [ ] HUD elements repositioned: StatBars top-left, DayCounter top-right, buttons bottom-right
- [ ] HUD does not overlap joystick zone (left 40%) or camera zone (right 40%)
- [ ] Touch targets >= 48dp (Android guideline)
- [ ] Player has visible capsule mesh (cyan/teal emissive)
- [ ] Player model rotates to face movement direction
- [ ] Input zones: left 40% joystick, center 20% world tap, right 40% camera orbit
- [ ] Zone boundaries are percentage-based (resolution-independent)

## Save Integration

None. Orientation, HUD layout, and player model are runtime-only.

---

## Technical Specification

### Data Model

#### A. Screen Orientation

Project settings changes in `project.godot`:

| Setting | Old Value (Portrait) | New Value (Landscape) |
|---------|---------------------|----------------------|
| `display/window/handheld/orientation` | `1` (portrait) | `2` (landscape) |
| `display/window/size/viewport_width` | `1080` | `1920` |
| `display/window/size/viewport_height` | `1920` | `1080` |

Stretch mode and aspect settings remain unchanged.

#### B. HUD Layout Zones — Landscape

```
┌─────────────────────────────────────────────────────────────┐
│ ZONE A: Stats     │                         │ ZONE B: Day   │
│ (top-left)        │                         │ (top-right)   │
│ [HP ████░░]       │                         │ DAY 07 ☀      │
│ [HUN ███░░]       │                         │               │
│ [THI ██░░░]       │                         │               │
├───────────────────┤                         ├───────────────┤
│                   │                         │               │
│                   │      ZONE C: World      │               │
│   (joystick       │      (center)           │  (camera      │
│    zone)          │                         │   zone)       │
│                   │                         │               │
│                   │                         │               │
├───────────────────┤    ZONE E: Float Text   │  ZONE D:      │
│                   │    (bottom-center)       │  Buttons      │
│                   │                         │  (btm-right)  │
│                   │                         │ [I][B][C][S][J]│
├─────────────────────────────────────────────┴───────────────┤
│                    ZONE F: Panel drawer (when open)          │
│                    (right-side or bottom, narrower)           │
└─────────────────────────────────────────────────────────────┘
```

#### HUD Element Positioning — Landscape

| Element | Portrait Position | Landscape Position | Anchor |
|---------|------------------|-------------------|--------|
| StatBars | Top-left, horizontal | Top-left, vertical stack | TOP_LEFT |
| DayCounter | Top-right | Top-right | TOP_RIGHT |
| Action buttons | Bottom-center, horizontal row (128x128) | Bottom-right, horizontal row (96x96) | BOTTOM_RIGHT |
| Floating text | Bottom-center | Bottom-center | BOTTOM_CENTER |
| Notifications | Top-center | Top-center | TOP_CENTER |
| Panel drawer | Bottom ~45% height | Right-side drawer OR bottom ~35% height | RIGHT or BOTTOM |
| PlacementLabel | Center above player | Center above player (unchanged) | CENTER |

#### Action Button Sizes — Landscape

| Property | Portrait Value | Landscape Value |
|----------|---------------|----------------|
| Button size | 64x64px | 96x96px |
| Button spacing | 8px | 12px |
| Button count | 5 (Inventory, Build, Craft, Scanner, Journal) | 5 (unchanged) |
| Total row width | 5 * 64 + 4 * 8 = 352px | 5 * 96 + 4 * 12 = 528px |

96x96px exceeds Android's 48dp minimum touch target at all common DPIs.

#### Panel Drawer — Landscape Options

Two valid approaches (implementation decision):

**Option A — Right-side drawer:**
- Width: ~40% of screen (768px at 1920)
- Full height
- Slides in from right edge
- Does not overlap joystick zone

**Option B — Bottom drawer (narrower):**
- Height: ~35% of screen (378px at 1080)
- Full width
- Slides up from bottom
- Shallower than portrait (~45% → ~35%)

Both work. Option A preferred — uses horizontal space better in landscape.

#### C. Player Model Placeholder

| Property | Value |
|----------|-------|
| Mesh type | CapsuleMesh |
| Height | 1.2 units |
| Radius | 0.3 units |
| Material | StandardMaterial3D, emissive cyan/teal |
| Emissive color | Color(0.0, 0.8, 0.7) — bioluminescent theme |
| Emissive energy | 2.0 (visible but not overwhelming) |
| Parent node | PlayerVisual (child of Player, already exists in scene tree) |
| Rotation | Faces Player.facing_direction (updated in _process) |

```gdscript
# Player model material — placeholder
var material := StandardMaterial3D.new()
material.albedo_color = Color(0.0, 0.6, 0.5)
material.emission_enabled = true
material.emission = Color(0.0, 0.8, 0.7)
material.emission_energy_multiplier = 2.0
```

The PlayerVisual node already exists in the scene tree (feature-002) but is currently empty. This feature adds a MeshInstance3D child with the capsule mesh.

#### Player Model Rotation

```gdscript
# In player.gd or player_visual.gd — each frame while moving
if facing_direction != Vector2.ZERO:
    var angle = atan2(facing_direction.x, facing_direction.y)
    player_visual.rotation.y = angle
```

Rotation only updates while moving. When idle, the model retains its last facing direction.

#### D. Input Zone Split

Zone definitions (percentage-based):

```gdscript
# Constants — could live in player_input.gd or a shared input constants file
const ZONE_LEFT_END: float = 0.4      # 0% - 40% = joystick
const ZONE_CENTER_END: float = 0.6    # 40% - 60% = world interaction
# 60% - 100% = camera orbit

enum InputZone { LEFT, CENTER, RIGHT }

func _get_zone(screen_x: float) -> InputZone:
    var viewport_width = get_viewport().get_visible_rect().size.x
    var ratio = screen_x / viewport_width
    if ratio < ZONE_LEFT_END:
        return InputZone.LEFT
    elif ratio < ZONE_CENTER_END:
        return InputZone.CENTER
    else:
        return InputZone.RIGHT
```

#### Zone Behavior

| Zone | Touch Type | Behavior |
|------|-----------|----------|
| Left 40% | Touch + drag | Floating joystick appears at touch point, player moves continuously |
| Left 40% | Tap (< 300ms, < 20px drag) | No-op (joystick zone, not interaction) |
| Center 20% | Tap | tap_tile(coords) — building placement, object inspection |
| Center 20% | Drag | No-op (center is tap-only, no drag behavior) |
| Right 40% | Drag | Camera orbit (yaw/pitch, handled by feature-013) |
| Right 40% | Tap | No-op (camera zone, not interaction) |
| Anywhere | Two-finger pinch | Camera zoom (handled by feature-013) |

#### Cross-Feature Signal Map (this feature)

| Signal | Source | Consumer | What |
|--------|--------|----------|------|
| `stat_changed` | feature-007 | StatBars (repositioned) | Update stat bar values |
| `day_started` | feature-008 | DayCounter (repositioned) | Update day number |
| `phase_changed` | feature-008 | DayCounter (repositioned) | Update phase icon |
| All other HUD signals | various | HUD elements (repositioned) | Unchanged behavior, new positions |

No new signals. All existing HUD signal wiring remains unchanged — only element positions change.

---

### Feature Flow

#### A. Orientation Startup

```
project.godot loaded:
  │
  ├─ Viewport size = 1920x1080
  ├─ Orientation = landscape
  │
  └─ All Control nodes reflow to landscape anchors
```

No runtime code needed. Godot handles orientation from project settings.

#### B. HUD Initialization (landscape)

```
HUD._ready():
  │
  ├─ StatBars: anchor TOP_LEFT, vertical VBoxContainer
  │     ├─ HPBar (ProgressBar, ~200px wide)
  │     ├─ HungerBar
  │     └─ ThirstBar
  │
  ├─ DayCounter: anchor TOP_RIGHT
  │     ├─ DayLabel ("DAY 01")
  │     └─ PhaseIcon (32x32px)
  │
  ├─ ActionButtons: anchor BOTTOM_RIGHT, horizontal HBoxContainer
  │     ├─ InventoryButton (96x96px)
  │     ├─ BuildButton (96x96px)
  │     ├─ CraftButton (96x96px, hidden until first recipe_discovered)
  │     ├─ ScannerButton (96x96px)
  │     └─ JournalButton (96x96px)
  │
  ├─ FloatingTextContainer: anchor BOTTOM_CENTER
  ├─ NotificationContainer: anchor TOP_CENTER
  ├─ PlacementLabel: anchor CENTER (tracked to player)
  │
  ├─ Connect to all source signals (unchanged from feature-012)
  │
  └─ Done — same behavior, landscape positions
```

All signal connections and behavior identical to feature-012 portrait spec. Only anchors and sizes change.

#### C. Player Model Setup

```
Player._ready() (or PlayerVisual._ready()):
  │
  ├─ Create MeshInstance3D as child of PlayerVisual
  │     mesh = CapsuleMesh.new()
  │     mesh.height = 1.2
  │     mesh.radius = 0.3
  │     material = StandardMaterial3D (emissive cyan/teal)
  │
  └─ Done — capsule visible at player position
```

#### Player Model Rotation (per frame)

```
player.gd._process(delta) — after movement update:
  │
  ├─ if facing_direction != Vector2.ZERO:
  │     var angle = atan2(facing_direction.x, facing_direction.y)
  │     player_visual.rotation.y = angle
  │
  └─ Done — model faces movement direction
```

#### D. Input Zone Routing

```
player_input.gd._unhandled_input(event):
  │
  ├─ if event is InputEventScreenTouch or InputEventScreenDrag:
  │     var zone = _get_zone(event.position.x)
  │
  │     match zone:
  │       InputZone.LEFT:
  │         _handle_joystick(event)  # existing joystick logic, unchanged
  │
  │       InputZone.CENTER:
  │         if _is_tap(event):       # tap only, no drag
  │           _handle_world_tap(event)
  │
  │       InputZone.RIGHT:
  │         pass  # Camera handles its own input (feature-013)
  │               # OR forward via signal — implementation choice
  │
  ├─ if event is InputEventScreenTouch and event.double:
  │     # Two-finger: pinch detection (any zone → camera zoom)
  │     _handle_pinch(event)  # feature-013 handles
  │
  └─ Done
```

**Refactoring needed:** Current `player_input.gd` treats the entire screen as joystick zone. Must add zone detection before joystick activation. Joystick only activates for touches originating in the left 40%.

---

### Layers & Components

#### Scene Tree Changes

```
Main (Node)
  └─ World (Node3D)
       ├─ (all world renderers from features 001-012)
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)            [feature-002]
       │    │    └─ CapsuleMesh (MeshInstance3D) ← NEW (this feature)
       │    ├─ PlayerInput (Node)               [feature-002, MODIFIED — zone routing]
       │    ├─ (all player child systems)
       │    └─ ...
       └─ Camera3D                              [feature-013]

  └─ JoystickOverlay (CanvasLayer, layer 10)    [feature-002, LEFT 40% ONLY]

  └─ HUD (CanvasLayer, layer 20)                ← MODIFIED LAYOUT (this feature)
       ├─ TopBar (HBoxContainer)                ← LANDSCAPE: full width
       │    ├─ StatBars (VBoxContainer)          ← top-left (unchanged anchor)
       │    │    ├─ HPBar (ProgressBar)
       │    │    ├─ HungerBar (ProgressBar)
       │    │    └─ ThirstBar (ProgressBar)
       │    ├─ Spacer (Control, expand)
       │    └─ DayCounter (HBoxContainer)        ← top-right (unchanged anchor)
       │         ├─ DayLabel (Label)
       │         └─ PhaseIcon (TextureRect)
       ├─ BottomBar (HBoxContainer)              ← LANDSCAPE: bottom-right
       │    ├─ Spacer (Control, expand)
       │    ├─ InventoryButton (TextureButton)   96x96px ← RESIZED
       │    ├─ BuildButton (TextureButton)       96x96px
       │    ├─ CraftButton (TextureButton)       96x96px
       │    ├─ ScannerButton (TextureButton)     96x96px
       │    └─ JournalButton (TextureButton)     96x96px
       ├─ FloatingTextContainer (Control)        ← bottom-center
       ├─ NotificationContainer (Control)        ← top-center
       ├─ PlacementLabel (Label)                 ← center
       │
       │  Panel Zone:
       ├─ InventoryPanel (PanelContainer)        ← right-side drawer OR narrower bottom
       ├─ CraftingPanel (PanelContainer)
       ├─ BuildPanel (PanelContainer)
       ├─ CatalogPanel (PanelContainer)
       └─ JournalPanel (PanelContainer)

  └─ ScreenFade (CanvasLayer, layer 30)          [feature-007]
  └─ CutsceneViewer (CanvasLayer, layer 40)      [feature-011]
```

#### File Structure

```
# Modified files (not new):
project.godot                     # orientation + viewport size
scripts/player/player_input.gd   # zone routing added
scripts/player/player.gd         # player_visual rotation
scenes/player/player.tscn        # CapsuleMesh added to PlayerVisual
scenes/ui/hud.tscn               # landscape anchors + button sizes
scripts/hud/hud.gd               # button sizes adjusted (64 → 96)

# No new files. This feature modifies existing components.
```

#### Component Responsibilities

| Component | Responsibility | Change |
|-----------|---------------|--------|
| `project.godot` | Screen orientation + viewport | Portrait → landscape values |
| `player_input.gd` | Touch input classification | ADD: zone detection before joystick/tap routing |
| `player.gd` | Movement + model rotation | ADD: rotate PlayerVisual to face facing_direction |
| `player.tscn` | Player scene | ADD: CapsuleMesh MeshInstance3D under PlayerVisual |
| `hud.tscn` | HUD scene | UPDATE: anchors for landscape, button size 64→96 |
| `hud.gd` | HUD logic | UPDATE: button size references if hardcoded |
| All panel scenes | Bottom drawer panels | UPDATE: layout for landscape (right-side or narrower bottom) |

#### HUD Zone Avoidance

The HUD must not place interactive elements in the joystick zone (left 40%) or camera zone (right 40%):

| HUD Element | Position | Overlaps Zone? | Notes |
|-------------|----------|----------------|-------|
| StatBars | Top-left | Left zone overlap OK | `mouse_filter = IGNORE` — non-interactive, passes touch through |
| DayCounter | Top-right | Right zone overlap OK | `mouse_filter = IGNORE` — non-interactive |
| Action buttons | Bottom-right | Right zone | Buttons consume touch via `_gui_input` BEFORE `_unhandled_input` — no conflict |
| Floating text | Bottom-center | Center zone | Non-interactive — passes through |
| Notifications | Top-center | Center zone | Non-interactive — passes through |
| Panel drawer | Right-side or bottom | Covers zones when open | Panel is temporary — open=interaction mode, closed=game mode |

**No conflict.** Godot's input propagation handles priority: `_gui_input` on Control nodes (HUD buttons) consumes touch before `_unhandled_input` (game input zones).

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Zone detection | 1 division + 2 comparisons | Per touch event |
| Player model rotation | 1 atan2 | Per frame (while moving) |
| HUD reflow | 0 (anchors handle it) | Layout only |
| Capsule mesh render | 1 draw call | Every frame |

Zero additional per-frame cost beyond the capsule mesh draw call.

#### Draw Calls

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| Player CapsuleMesh | 1 | Single MeshInstance3D with StandardMaterial3D |
| HUD (CanvasLayer) | 0 | UI only — not 3D draw calls |
| **Total added** | **1** | Running total: ~23 (was ~22) |

Still well within the <100 draw call budget.

#### Touch Interaction

| Element | Size | Notes |
|---------|------|-------|
| Action buttons | 96x96px | Above 48dp at all common DPIs |
| Close (X) buttons | 48x48px | Minimum (unchanged) |
| Panel entries | ~90-100px height | Comfortable tap (unchanged) |
| Stat bars | Display only | `mouse_filter = IGNORE` |
| Day counter | Display only | `mouse_filter = IGNORE` |
| Joystick zone | Left 40% of screen | ~768px wide at 1920 — generous |
| Camera zone | Right 40% of screen | ~768px wide at 1920 — generous |
| World tap zone | Center 20% of screen | ~384px wide at 1920 — adequate |

#### Platform Differences

None. Landscape orientation works identically on iOS and Android in Godot.
`project.godot` orientation setting applies to both platforms.

#### Memory

- CapsuleMesh: ~500 bytes (simple primitive)
- StandardMaterial3D: ~200 bytes
- Zone constants: ~24 bytes
- HUD layout changes: 0 additional (same Control nodes, different anchors)
- Total additional: negligible
