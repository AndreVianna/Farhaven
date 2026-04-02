# HUD & UI Framework

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F12 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-03-31 | Fix: notification queue max depth 3, faster dismiss for queued items | /aid-specify |
| 2026-04-01 | [PIVOT] Scene tree updated for single-mesh renderer. Draw call budget updated. | /design-pivot |
| 2026-04-01 | M3: HexGridRenderer draw call note updated — cliff faces included in ArrayMesh (0 extra draw calls). | /pivot-cascade |
| 2026-04-02 | Draw call budget: ElementIconRenderer ~5 → PropRenderer ~5 + PropLabelRenderer ~1. Scene tree updated. | /spec-update |
| 2026-04-02 | Scan redesign: scan_completed feedback still works (proximity scan). Added entry_encountered feedback for ENCOUNTERED state. Catalog display updated for 3-state entries. | /scan-redesign-apply |

## Source

- REQUIREMENTS.md §5 F12 (HUD Layout)

## Description

The HUD provides the always-visible game interface: stat bars (top-left), day counter (top-right), action buttons (bottom-right: Inventory, Build, Craft-when-near-workbench, Scanner/Catalog). The HUD also owns the panel mutual exclusion system (only one bottom-drawer panel open at a time), floating text feedback system (gather amounts, damage numbers, scan results), and the screen fade system (death transition, damage flash). Design system TBD -- vibrant, warm, sci-fi. NOT Tactical Brutalism.

## User Stories

- As a player, I want minimal UI so the beautiful world is the focus
- As a player, I want clear feedback when things happen (gathering, damage, scanning)
- As a player, I want quick access to my inventory, build menu, and catalog

## Priority

Must (P0)

## Acceptance Criteria

- [ ] Stat bars visible at top-left at all times
- [ ] Day counter visible at top-right
- [ ] Inventory, Build, Scanner buttons always visible (bottom-right)
- [ ] Craft button appears only near Workbench
- [ ] Only one panel open at a time (mutual exclusion)
- [ ] Floating text feedback on gather, damage, scan
- [ ] Touch targets >= 48dp

## Save Integration

No direct save data. Reads state from other features.

---

## Technical Specification

### Data Model

Feature-012 owns no persistent data. It reads state from other features and provides
shared UI infrastructure. All data flows inward via signals.

#### HUD Layout Zones

```
┌──────────────────────────────────┐
│ ZONE A: Stats    │  ZONE B: Day  │  ← top bar
│ (top-left)       │  (top-right)  │
├──────────────────┴───────────────┤
│                                  │
│           ZONE C: World          │  ← game world (no HUD elements)
│           (center)               │
│                                  │
│                                  │
├──────────────────────────────────┤
│              ZONE D: Buttons     │  ← bottom-right
│              ZONE E: Notifications│  ← bottom-center (transient)
├──────────────────────────────────┤
│                                  │
│         ZONE F: Panel drawer     │  ← bottom ~45% (when open)
│                                  │
└──────────────────────────────────┘
```

| Zone | Content | Owner |
|------|---------|-------|
| A | StatBars (HP, Hunger, Thirst) | feature-007 data → this feature renders |
| B | DayCounter ("DAY 07" + phase icon) | feature-008 data → this feature renders |
| C | Game world (no HUD) | — |
| D | Action buttons (Inventory, Build, Craft*, Scanner, Journal) | This feature provides, other features control visibility |
| E | Floating text + notifications (transient) | This feature renders, other features trigger |
| F | Panel drawer (one at a time) | Each feature owns its panel content, this feature provides the container pattern |

*Craft button conditional — visible only near Workbench.

#### Action Buttons

| Button | Size | Visibility | Signal Source |
|--------|------|-----------|---------------|
| InventoryButton | 64×64px | Always visible | feature-005 (opens InventoryPanel) |
| BuildButton | 64×64px | Always visible | feature-009 (opens BuildPanel) |
| CraftButton | 64×64px | Near Workbench only | feature-006 `workbench_proximity_changed(near)` |
| ScannerButton | 64×64px | Always visible | feature-003 (opens CatalogPanel) |
| JournalButton | 64×64px | Always visible | feature-011 (opens JournalPanel) |

#### Panel Mutual Exclusion System

5 panels participate. Opening any one closes all others.

| Panel | Feature | Trigger |
|-------|---------|---------|
| InventoryPanel | feature-005 | InventoryButton tap |
| CraftingPanel | feature-006 | CraftButton tap (near Workbench) |
| BuildPanel | feature-009 | BuildButton tap |
| CatalogPanel | feature-003 | ScannerButton tap |
| JournalPanel | feature-011 | JournalButton tap |

**Implementation:** Each panel emits `panel_opened` signal. Each panel connects to
all others' `panel_opened` and calls `close()` on itself. Symmetric — no central
coordinator. HUD provides the container structure; panels self-organize.

**CutsceneViewer (feature-011) is NOT a panel.** It's a fullscreen overlay above HUD
that pauses the game. Does not participate in mutual exclusion.

#### Floating Text System

Shared system for all transient text feedback in the game.

```gdscript
# Public API on FloatingTextManager
func show_text(world_pos: Vector3, text: String, color: Color, duration: float = 1.0) -> void
```

| Caller | Text | Color | Position |
|--------|------|-------|----------|
| feature-004 (auto_gather_completed) | "+1 Wood" | Green | Player position |
| feature-004 (auto_gather_failed &"inventory_full") | "INVENTORY FULL" | Red | Player position |
| feature-004 (auto_gather_failed &"tool_gated") | "REQUIRES STONE AXE" | Red | Player position |
| feature-004 (auto_defend_triggered) | "-10" | Red | Fauna position |
| feature-003 (scan_completed) | "Cataloged!" | Cyan/white | Scan target position |
| feature-003 (entry_encountered) | "Encountered!" | Orange/yellow | Fauna position |
| feature-006 (recipe_discovered) | "New recipe!" | Gold | Player position |
| feature-009 (structure_build_failed) | Build error text | Red | Player position |
| feature-011 (journal_entry_unlocked) | "New journal entry!" | Gold | Screen center |

**Text lifecycle:** Spawn label at screen position (projected from world_pos via
Camera3D), tween upward + fade alpha over duration, then `queue_free`. Labels
stack vertically if multiple fire simultaneously.

#### Notification System

Brief banners for non-urgent events (recipe discovery, journal unlock). Different from
floating text — notifications appear at a fixed screen position (top-center or
bottom-center), not at a world position. Simpler and less intrusive.

```gdscript
func show_notification(text: String, duration: float = 2.0) -> void
```

Notifications queue — if multiple arrive, show sequentially (not simultaneously).
Auto-dismiss after duration. No tap interaction.

**Queue overflow rules:**
- Max queue depth: 3 notifications
- First notification: 2.0s duration
- Queued items (2nd, 3rd): 1.5s duration (faster dismiss)
- If queue > 3: oldest unshown notifications are dropped (not shown)
- Prevents notification fatigue during productive exploration runs

#### ScreenFade System

Owned by feature-007 (SurvivalSystem) for death transitions. Defined in feature-007
SPEC. HUD provides the CanvasLayer container in the scene tree but does not implement
the fade logic. ScreenFade sits ABOVE the HUD CanvasLayer.

```gdscript
# Defined in feature-007, used by features 007 + 010
func fade_out(duration: float = 1.5) -> void
func fade_in(duration: float = 1.5) -> void
func flash(color: Color, duration: float = 0.2) -> void
signal fade_out_completed()
signal fade_in_completed()
```

#### Placement Mode Label

When feature-009 (building) enters placement mode, a floating label appears:

```gdscript
# Triggered by BuildingSystem signals
func show_placement_label(structure_type: StringName) -> void  # "TAP TO PLACE WALL"
func hide_placement_label() -> void
```

Centered above player. Design system TBD (MVP: clean sans-serif, uppercase,
semi-transparent background).

#### Design System — TBD

**Tactical Brutalism is discarded.** The new direction is: vibrant colors, soft shapes,
sci-fi but warm. Astroneer meets MLU.

**MVP placeholder approach:**
- Font: Godot default or a clean sans-serif bundled font
- Colors: warm palette (see feature-008 lighting values for reference)
- Panels: semi-transparent dark background, rounded corners
- Buttons: simple colored rectangles with icon placeholders
- Stat bars: standard Godot ProgressBar with custom StyleBox

**Post-MVP:** Design system document with color tokens, typography, component styles.
This is a design task, not an engineering task. The spec defines layout and behavior;
visual styling is decoupled.

#### Cross-Feature Signal Consumption — Complete Map

| Signal | Source Feature | HUD Reaction |
|--------|---------------|-------------|
| `stat_changed(name, current, max)` | feature-007 | Update StatBars |
| `day_started(day_count)` | feature-008 | Update DayCounter label |
| `phase_changed(phase)` | feature-008 | Update DayCounter icon |
| `workbench_proximity_changed(near)` | feature-006 | Show/hide CraftButton |
| `auto_gather_completed(coords, type, amount)` | feature-004 | Floating "+N Type" green |
| `auto_gather_failed(coords, reason)` | feature-004 | Floating error text red |
| `auto_defend_triggered(fauna_id, damage)` | feature-004 | Floating "-N" red at fauna |
| `inventory_full(type, rejected)` | feature-005 | Floating "INVENTORY FULL" red |
| `scan_completed(entry_id)` | feature-003 | Floating "Cataloged!" |
| `entry_encountered(entry_id, label)` | feature-003 | Floating "Encountered!" |
| `recipe_discovered(name)` | feature-006 | Notification "New recipe!" |
| `structure_build_failed(reason)` | feature-009 | Floating error text |
| `placement_mode_entered(type)` | feature-009 | Show placement label |
| `placement_mode_exited()` | feature-009 | Hide placement label |
| `journal_entry_unlocked(entry_id)` | feature-011 | Notification "New journal entry!" |
| `fauna_attacked_player(id, dmg, species)` | feature-010 | ScreenFade.flash(red) |
| `player_died()` | feature-007 | ScreenFade.fade_out() |

---

### Feature Flow

#### Startup Flow

```
HUD._ready():
  │
  ├─ Create StatBars (3 ProgressBars, initial values 100/100)
  ├─ Create DayCounter ("DAY 01" + sun icon)
  ├─ Create action buttons (Inventory, Build, Scanner, Journal = visible; Craft = hidden)
  ├─ Create FloatingTextManager (empty, ready to spawn labels)
  ├─ Create NotificationManager (empty, ready to queue)
  │
  ├─ Connect to all source signals (see signal map above)
  │
  └─ Done — HUD is passive, reacts to signals only
```

**HUD has zero per-frame logic.** All updates are signal-driven. No `_process`.

#### Stat Bar Update Flow

```
feature-007 emits stat_changed(&"hp", 75.0, 100.0)
  │
  ├─ StatBars receives signal
  │
  ├─ Identify bar by stat_name → HPBar
  ├─ Tween bar value from current to 75.0/100.0 = 0.75 (smooth, ~0.2s)
  ├─ Update color based on ratio:
  │     > 0.5 → green (HP/Hunger) or blue (Thirst)
  │     0.25-0.5 → yellow
  │     < 0.25 → red
  │
  └─ Done
```

#### Floating Text Flow

```
feature-004 emits auto_gather_completed(coords, &"wood", 1)
  │
  ├─ FloatingTextManager receives signal (or HUD dispatcher routes it)
  │
  ├─ world_pos = HexGrid.axial_to_world(coords) + Vector3(0, 2, 0)  # above tile
  ├─ screen_pos = Camera3D.unproject_position(world_pos)
  │
  ├─ Create Label node:
  │     text = "+1 Wood"
  │     color = Color.GREEN
  │     position = screen_pos
  │     Add to HUD CanvasLayer
  │
  ├─ Tween: position.y -= 60px over 1.0s (float upward)
  ├─ Tween: modulate.a → 0.0 over 1.0s (fade out)
  │
  ├─ On tween complete: queue_free()
  │
  └─ If multiple active: stack vertically (offset each by ~30px)
```

#### Notification Flow

```
feature-006 emits recipe_discovered(&"stone_axe")
  │
  ├─ NotificationManager receives signal
  │
  ├─ Create notification:
  │     text = "New recipe: Stone Axe!"
  │     Queue if another notification is active
  │
  ├─ Show: slide in from top or fade in at bottom-center
  │     duration = 2.0s
  │     Auto-dismiss after duration
  │
  ├─ If queued: show next after current dismisses
  │
  └─ Done
```

#### Button Tap → Panel Open Flow

```
Player taps InventoryButton
  │
  ├─ InventoryButton._pressed()
  │
  ├─ InventoryPanel.toggle()
  │     if visible: close (hide, emit panel_closed)
  │     if hidden: open (show, emit panel_opened)
  │
  ├─ panel_opened emitted → all other panels receive → close themselves
  │     CraftingPanel.close()
  │     BuildPanel.close()
  │     CatalogPanel.close()
  │     JournalPanel.close()
  │
  └─ Done — only InventoryPanel is open
```

---

### Layers & Components

#### Scene Tree — Complete (all 12 features)

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment                      [feature-008]
       ├─ DirectionalLight3D                    [feature-008]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       │    └─ MeshInstance3D [single ArrayMesh — per-vertex color blending]
       ├─ PropRenderer (Node3D)                  [feature-003]
       ├─ PropLabelRenderer (Node3D)              [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ ResourceRenderer (Node3D)             [feature-004]
       ├─ StructureRenderer (Node3D)            [feature-009]
       ├─ FaunaRenderer (Node3D)                [feature-010]
       ├─ GroundItemRenderer (Node3D)           [feature-007]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)            [feature-002]
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    ├─ CraftingSystem (Node)            [feature-006]
       │    ├─ SurvivalSystem (Node)            [feature-007]
       │    ├─ BuildingSystem (Node)            [feature-009]
       │    ├─ FaunaManager (Node)              [feature-010]
       │    └─ JournalSystem (Node)             [feature-011]
       └─ Camera3D                              [feature-002]

  └─ JoystickOverlay (CanvasLayer, layer 10)    [feature-002]

  └─ HUD (CanvasLayer, layer 20)                ← THIS FEATURE
       ├─ TopBar (HBoxContainer)
       │    ├─ StatBars (VBoxContainer)          ← top-left
       │    │    ├─ HPBar (ProgressBar)
       │    │    ├─ HungerBar (ProgressBar)
       │    │    └─ ThirstBar (ProgressBar)
       │    ├─ Spacer (Control, expand)
       │    └─ DayCounter (HBoxContainer)        ← top-right
       │         ├─ DayLabel (Label)             ← "DAY 07"
       │         └─ PhaseIcon (TextureRect)      ← sun/moon/etc.
       ├─ BottomBar (HBoxContainer)              ← bottom-right
       │    ├─ Spacer (Control, expand)
       │    ├─ InventoryButton (TextureButton)   [feature-005]
       │    ├─ BuildButton (TextureButton)       [feature-009]
       │    ├─ CraftButton (TextureButton)       [feature-006, conditional]
       │    ├─ ScannerButton (TextureButton)     [feature-003]
       │    └─ JournalButton (TextureButton)     [feature-011]
       ├─ FloatingTextContainer (Control)        ← floating text labels spawn here
       ├─ NotificationContainer (Control)        ← notification banners here
       ├─ PlacementLabel (Label)                 ← "TAP TO PLACE WALL" (hidden default)
       │
       │  Panel Zone (bottom drawers, one at a time):
       ├─ InventoryPanel (PanelContainer)        [feature-005]
       ├─ CraftingPanel (PanelContainer)         [feature-006]
       ├─ BuildPanel (PanelContainer)            [feature-009]
       ├─ CatalogPanel (PanelContainer)          [feature-003]
       └─ JournalPanel (PanelContainer)          [feature-011]

  └─ ScreenFade (CanvasLayer, layer 30)          [feature-007]
       └─ FadeRect (ColorRect)

  └─ CutsceneViewer (CanvasLayer, layer 40)      [feature-011, process_mode ALWAYS]
       ├─ Background (ColorRect)
       ├─ PanelImage (TextureRect)
       ├─ CaptionLabel (Label)
       └─ TapPrompt (Label)
```

**CanvasLayer ordering:**
- Layer 10: JoystickOverlay (below HUD)
- Layer 20: HUD (main game UI)
- Layer 30: ScreenFade (above HUD for death/damage transitions)
- Layer 40: CutsceneViewer (above everything, pauses game)

#### Autoloads (complete list)

```
HexGrid (Node)        — feature-001
DayNightCycle (Node)  — feature-008
SaveManager (Node)    — feature-008
```

No autoloads from this feature. HUD is a scene tree node, not a singleton.

#### File Structure

```
scripts/
  hud/
    hud.gd                   # Root Control — signal connections, button management
    stat_bars.gd             # VBoxContainer — 3 ProgressBars, stat_changed listener
    day_counter.gd           # HBoxContainer — day label + phase icon
    floating_text_manager.gd # Control — spawns/manages floating labels
    notification_manager.gd  # Control — queued notification banners

scenes/
  ui/
    hud.tscn                 # Complete HUD scene (all zones + button slots)
```

**Panel scenes and scripts are owned by their respective features**, not by this
feature. HUD provides the container CanvasLayer and button slots; panels are added
as children by their owning features or placed directly in the scene tree.

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `hud.gd` | Root HUD Control. Creates button slots. Connects to all source signals (see signal map). Routes signals to appropriate sub-components. Manages CraftButton visibility via `workbench_proximity_changed`. | All features (signals only — never queries feature state directly) |
| `stat_bars.gd` | 3 ProgressBars with color gradients. Listens to `stat_changed`. Tween smooth updates. `mouse_filter = IGNORE`. | feature-007 (stat_changed signal) |
| `day_counter.gd` | Day label + phase icon. Listens to `day_started` + `phase_changed`. `mouse_filter = IGNORE`. | feature-008 (signals) |
| `floating_text_manager.gd` | Spawns Label nodes at projected screen positions. Tween upward + fade. Queue_free on complete. Stacks multiple labels. | Camera3D (for world-to-screen projection), calling features (via `show_text` API) |
| `notification_manager.gd` | Queued banner notifications. Show/dismiss sequentially. Fixed screen position. | Calling features (via `show_notification` API) |

#### Signal Wiring

HUD connects to all 16 source signals listed in the Data Model signal map.
No feature connects to HUD signals — HUD is a pure consumer/renderer.

---

### UI Specs

#### Full Layout — Portrait 1080×1920

```
┌──────────────────────────────────┐
│ [♥████░░] [🍖███░░] [💧██░░]    │  ← Zone A: StatBars (top-left)
│                       DAY 07 ☀  │  ← Zone B: DayCounter (top-right)
│                                  │
│                                  │
│         (game world)             │  ← Zone C: no HUD
│                                  │
│                                  │
│      [New recipe: Stone Axe!]    │  ← Zone E: notification (transient)
│                                  │
│    [Inv][Build][Craft][Scan][Jnl]│  ← Zone D: buttons (bottom-right)
├──────────────────────────────────┤
│  (panel drawer when open)        │  ← Zone F: ~45% height
│                                  │
│                                  │
└──────────────────────────────────┘
```

#### Stat Bars Design

- **Position:** Top-left, stacked vertically
- **Size:** ~200px wide × 20px tall each
- **Color gradient:**
  - HP: green (>50%) → yellow (25-50%) → red (<25%)
  - Hunger: green → yellow → red
  - Thirst: blue (>50%) → yellow → red
- **Icon prefix** per bar, no numeric value
- **Translucent background**
- **Smooth tween** (Godot ProgressBar + Tween, ~0.2s per update)
- **`mouse_filter = IGNORE`**

#### Day Counter Design

- **Position:** Top-right, anchored
- **Layout:** HBoxContainer — "DAY 07" label + 32×32px phase icon
- **Label:** Zero-padded, uppercase. `"DAY %02d" % day_count`
- **Font/style:** Design system TBD. MVP: clean sans-serif, ~24px, white,
  1px dark outline, semi-transparent background panel
- **Phase icon colors (warm palette):**

| Phase | Icon | Color |
|-------|------|-------|
| DAY | Sun circle | Warm yellow (#FFD93D) |
| DUSK | Half-sun | Warm orange (#FFB347) |
| NIGHT | Crescent | Soft purple (#9B7DC8) |
| DAWN | Rising circle | Peach (#FFAB91) |

- **`mouse_filter = IGNORE`**

#### Action Buttons Design

- **Position:** Bottom-right, horizontal row
- **Size:** 64×64px each. Spacing: 8px between buttons.
- **Style:** MVP placeholder — colored rectangles with icon text
- **Tap:** Opens associated panel (or toggles if already open)
- **CraftButton:** hidden by default. Shown when `workbench_proximity_changed(true)`

#### Panel Drawer Design (shared pattern)

All 5 panels follow the same layout:
- **Full-width bottom drawer**, ~45% screen height (~864px at 1920)
- **Semi-transparent background**
- **Header:** Title label + close (X) button (48×48px)
- **ScrollContainer** inside for content that may exceed visible area
- **Game continues running** — no pause (except cutscenes)
- **Close:** toggle button, X button, or tap game area above panel

#### Floating Text Design

- **Spawn:** At screen position projected from world coordinates
- **Animation:** Rise 60px over 1.0s, fade alpha to 0
- **Stacking:** Multiple labels offset vertically (~30px each)
- **Font:** ~18px, bold, with 1px dark outline for readability
- **Colors:** Green (positive: gather), Red (negative: damage, error),
  Cyan/White (neutral: cataloged), Gold (notifications)

#### Notification Design

- **Position:** Bottom-center, above button row
- **Style:** Rounded banner, semi-transparent dark background, light text
- **Animation:** Slide in from bottom or fade in, auto-dismiss after 2s
- **Queue:** Show one at a time, sequential

#### Placement Label Design

- **Position:** Centered above player (screen-space, tracked to player world pos)
- **Text:** "TAP TO PLACE [TYPE]" — uppercase
- **Style:** Design system TBD. MVP: semi-transparent background, light text
- **Visibility:** Only during placement mode (feature-009)

#### Touch Targets — Complete Summary

| Element | Size | Notes |
|---------|------|-------|
| Action buttons | 64×64px | Above 48dp minimum |
| Close (X) buttons | 48×48px | Minimum |
| Panel slot entries | ~90-100px height | Comfortable mobile tap |
| Build/Craft entry buttons | ~80×48px | Within entries |
| Stat bars | Display only | `mouse_filter = IGNORE` |
| Day counter | Display only | `mouse_filter = IGNORE` |
| Floating text | Non-interactive | No touch target |
| Notifications | Non-interactive | Auto-dismiss |
| Button spacing | 8px | Prevents mis-taps |

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Stat bar update | 1 tween per bar (~3 per frame when depleting) | On stat_changed signal |
| Day counter update | 1 label text set + 1 icon swap | On day_started / phase_changed |
| Floating text spawn | 1 Label node + 2 Tweens | Per gather/damage event (~1-3/sec while active) |
| Notification show | 1 Label node + 1 Tween | On recipe/journal unlock (rare) |
| Button visibility | 1 bool set | On workbench_proximity_changed |

**Zero per-frame cost.** All updates are signal-driven. No `_process` in any HUD
component. Tweens run independently via Godot's tween system.

#### Draw Calls

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| HUD CanvasLayer | 0 | CanvasLayer UI — not 3D draw calls |
| ScreenFade | 0 | CanvasLayer UI |
| CutsceneViewer | 0 | CanvasLayer UI |
| **Total** | **0** | All HUD is CanvasLayer. **Final running total: ~24 3D draw calls** |

#### Final 3D Draw Call Budget

| Renderer | Feature | Draw Calls |
|----------|---------|-----------|
| HexGridRenderer | 001 | ~1 (includes cliff face geometry — same ArrayMesh, 0 extra draw calls) |
| PropRenderer | 003 | ~5 |
| PropLabelRenderer | 003 | ~1 |
| ResourceRenderer | 004 | ~6 |
| GroundItemRenderer | 007 | ~1 |
| StructureRenderer | 009 | ~5 |
| FaunaRenderer | 010 | ~1 |
| ScanProgressRenderer | 003 | ~1 |
| Player mesh | 002 | ~1 |
| **Total 3D** | | **~22** |
| **Budget** | | **<100** |
| **Remaining** | | **~78** |

Well within budget. ~78 draw calls remaining for future chapters, effects, and polish.

#### Touch Interaction

- 5 action buttons: 64×64px each (HUD bottom-right)
- Panel interactions: per-feature panel specs
- All standard Godot `_gui_input` / `_pressed` handling
- `mouse_filter = STOP` on buttons and panels
- `mouse_filter = IGNORE` on stat bars, day counter, floating text

#### Platform Differences

None. Godot UI Controls identical on iOS/Android. CanvasLayer rendering identical.

#### Memory

- HUD scene: ~20 Control nodes = negligible
- Floating text: max ~5 simultaneous labels × ~1KB = negligible
- Notifications: 1 active + queue of ~3 = negligible
- Stat bar styles + button textures: <100KB total
