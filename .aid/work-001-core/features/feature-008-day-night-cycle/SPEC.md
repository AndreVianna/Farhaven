# Day/Night Cycle & Save System

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F7, F10, §9 AC7, AC10 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-04-02 | Scene tree: ElementIconRenderer → PropRenderer + PropLabelRenderer (feature-003 architecture change). | /spec-update |
| 2026-04-04 | Sub-hex + unified props: torch tracking queries `tile.props` for torches instead of `tile.structure`. Torch visibility sources use sub-hex position as origin. `structure_placed`/`structure_destroyed` signals replaced by `prop_placed`/`prop_removed`. | /spec-update |

## Source

- REQUIREMENTS.md §5 F7 (Day/Night Cycle)
- REQUIREMENTS.md §5 F10 (Save System)
- REQUIREMENTS.md §9 AC7 (Day/Night acceptance criteria)
- REQUIREMENTS.md §9 AC10 (Save System acceptance criteria)

## Description

The game runs a continuous day/night cycle: Day (~3 min) -> Dusk (30s warning) -> Night (~1.5 min) -> Dawn. During day, visibility radius is 2 hexes. At night, visibility shrinks to 1 hex (torches extend to 2). Lighting transitions use warm colors -- charming, not dark/oppressive. Auto-save triggers at each dawn. Save/load orchestrates all systems via a SaveManager.

## User Stories

- As a player, I want the day/night rhythm to structure my sessions
- As a player, I want the dusk warning so I have time to prepare
- As a player, I want my progress saved automatically

## Priority

Must (P0 -- Persistence)

## Acceptance Criteria

- [ ] Full cycle completes in 5 min +/-15s (measurable)
- [ ] Dusk warning visible 30s before night
- [ ] Night: only tiles within 1 hex of player visible
- [ ] Torch placed: extends visibility to 2 hexes around torch
- [ ] Dawn triggers -> save file exists on disk
- [ ] Kill app -> reopen -> world state matches (tiles, structures, resources, catalog, journal)
- [ ] Kill app -> reopen -> player state matches (inventory, stats, position, day count)
- [ ] Corrupt/delete save -> game starts fresh without crash

## Save Integration

Day count, current phase, phase elapsed time. SaveManager orchestrates all other features' save data.

---

## Technical Specification

### Data Model

#### TimePhase Enum

```gdscript
enum TimePhase { DAY, DUSK, NIGHT, DAWN }
```

#### DayNightCycle Properties (autoload singleton)

```gdscript
var current_phase: TimePhase = TimePhase.DAY
var phase_elapsed: float = 0.0         # seconds elapsed in current phase
var day_count: int = 1                 # starts at Day 1
var is_daytime: bool = true            # true during DAY/DAWN, false during DUSK/NIGHT
```

`is_daytime` derived from `current_phase`. Updated on phase transitions only.
Safe to read in `_process` (feature-007 survival HP regen condition).

#### Phase Durations — Config

```gdscript
const PHASE_DURATIONS: Dictionary = {
    TimePhase.DAY:   180.0,  # 3 minutes
    TimePhase.DUSK:   30.0,  # 30 seconds warning
    TimePhase.NIGHT:  90.0,  # 1.5 minutes
    TimePhase.DAWN:   10.0,  # brief transition
}
# Total: ~310 seconds ≈ 5 min 10s (within AC7's 5 min ±15s — tight margin, 5s to spare)
```

DAWN is 10s — screen brightens, day counter increments. Brief "morning" moment.

#### Visibility Radius — Per Phase

```gdscript
const VISIBILITY_RADIUS: Dictionary = {
    TimePhase.DAY:   2,  # current tile + 2 rings
    TimePhase.DUSK:  2,  # same as day (warning phase, not visibility change)
    TimePhase.NIGHT: 1,  # reduced — adjacent tiles only
    TimePhase.DAWN:  2,  # back to full
}

const TORCH_VISIBILITY_RADIUS: int = 2  # torch extends night visibility
```

Daytime: radius 2. Night: radius 1. Torch at night: radius 2 around torch.

#### Torch Tracking

```gdscript
var _torch_positions: Array[Dictionary] = []
# Each entry: { "coords": Vector2i, "sub_hex": Vector2i }
```

Maintained by DayNightCycle. Updated on `HexGrid.structure_placed`/`structure_destroyed`
signals with `structure_type == &"torch"`. Only used as visibility sources
during NIGHT.

#### refresh_visibility API (feature-001)

DayNightCycle owns all calls to `HexGrid.refresh_visibility(sources)`:

```gdscript
# sources: Array of { "coords": Vector2i, "radius": int }
# Player is always sources[0]. Torches append during NIGHT only.
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]
```

**Algorithm (simplified — no REVEALED state):**
1. Promote HIDDEN tiles within source radius → VISIBLE
2. HIDDEN → VISIBLE emits `tile_revealed`
3. Any fog change emits `tile_visibility_changed`
4. Return newly revealed tiles

**Note:** Night/day darkness is handled by the hex shader's `darkness` uniform,
not by fog state. All tiles start VISIBLE. The shader applies distance-based
lantern falloff at night (full brightness at player, dimming with distance).

#### Signals

```gdscript
signal phase_changed(new_phase: TimePhase)
signal dawn()                              # NIGHT → DAWN
signal dusk()                              # DAY → DUSK
signal night()                             # DUSK → NIGHT
signal day_started(day_number: int)        # DAWN → DAY, after counter increments
```

**Downstream consumers:**
- `dawn` → feature-007 (deferred respawn)
- `night` → feature-010 (fauna spawn)
- `day_started` → SaveManager (auto-save)
- `is_daytime` → feature-007 (HP regen condition, read per frame)

#### Lighting Registration API

```gdscript
var _world_env: WorldEnvironment
var _sun_light: DirectionalLight3D

func register_lighting(env: WorldEnvironment, sun: DirectionalLight3D) -> void:
    _world_env = env
    _sun_light = sun
```

World scene script calls `DayNightCycle.register_lighting()` in its `_ready()`.
If not registered (tests, headless), transitions still fire signals — no visual
changes, no errors.

#### [CHANGED] Lighting Values Per Phase

**Redesign note:** Tone is "warm, charming, not dark/oppressive." Night uses warm
deep tones, not cold blue. The planet is alien but beautiful.

| Phase | Ambient Energy | Sun Intensity | Sun Color | Environment Tint |
|-------|---------------|---------------|-----------|-----------------|
| DAY | 1.0 | 1.0 | Warm white (#FFF5E0) | None |
| DUSK | 0.7 | 0.6 | Warm orange (#FFB347) | Amber overlay |
| NIGHT | 0.25 | 0.08 | Warm purple (#9B7DC8) | Deep plum (#2D1B4E) |
| DAWN | 0.7 → 1.0 | 0.5 → 1.0 | Peach → warm white | Peach → none |

**[CHANGED from pre-redesign]:** Night is warm purple/plum, not cold blue.
Charming alien night, not oppressive darkness. Values tunable.

#### Save Data — DayNightCycle

```json
{
  "day_night": {
    "day_count": 7,
    "phase": 0,
    "phase_elapsed": 45.2,
    "chapter_id": "ch1"
  }
}
```

Phase saved as int (enum ordinal). `chapter_id` for future extensibility.

#### Cross-Feature Dependencies

| What | Source |
|------|--------|
| `tile_entered(coords)` — trigger visibility refresh | feature-002 via HexGrid |
| `prop_placed`/`prop_removed` — torch tracking (filter category=structure, type=torch) | feature-009 via HexGrid |
| `refresh_visibility(sources)` — fog API | feature-001 (HexGrid) |

| What | Consumer |
|------|----------|
| `is_daytime` — HP regen condition | feature-007 (survival) |
| `dawn` — deferred respawn | feature-007 (survival) |
| `night` — fauna spawn | feature-010 (night threats) |
| `day_started` — auto-save | SaveManager (this feature) |
| `phase_changed` — lighting, day counter UI | feature-012 (HUD) |

---

### Feature Flow

#### Phase Timer Tick (_process)

```
Every frame (DayNightCycle._process):
  │
  ├─ phase_elapsed += delta
  │
  ├─ if phase_elapsed >= PHASE_DURATIONS[current_phase]:
  │     → transition to next phase
  │
  └─ End (most frames: just increment)
```

#### Phase Transitions

```
DAY → DUSK:
  current_phase = DUSK, phase_elapsed = 0.0, is_daytime = false
  Emit phase_changed(DUSK), dusk()
  → Lighting: tween to DUSK values (amber, warm orange)
  → No visibility change (radius stays 2)

DUSK → NIGHT:
  current_phase = NIGHT, phase_elapsed = 0.0
  Emit phase_changed(NIGHT), night()
  → Visibility shrinks to 1 hex + torch zones
  → Call refresh_visibility() with night radius + torch sources
  → Lighting: tween to NIGHT values (warm purple, deep plum)
  → Feature-010 (FaunaManager) spawns fauna if day_count >= 4

NIGHT → DAWN:
  current_phase = DAWN, phase_elapsed = 0.0, is_daytime = true
  day_count += 1
  Emit phase_changed(DAWN), dawn()
  → Visibility expands to 2 hexes (no torch sources)
  → Call refresh_visibility() with day radius
  → Lighting: tween to DAWN values (peach → warm white)
  → Feature-007 (SurvivalSystem): deferred respawn triggers here
  → Feature-010 (FaunaManager): all fauna despawn

DAWN → DAY:
  current_phase = DAY, phase_elapsed = 0.0
  Emit phase_changed(DAY), day_started(day_count)
  → SaveManager: auto-save triggered
  → Lighting: full brightness, tint removed
```

#### Visibility Refresh — Centralized

DayNightCycle owns all calls to `HexGrid.refresh_visibility()`. Three triggers:

**1. Player movement (`tile_entered`):**

```
HexGrid emits tile_entered(coords)
  │
  ├─ DayNightCycle receives signal
  ├─ Build sources:
  │     sources = [{ "coords": coords, "radius": VISIBILITY_RADIUS[current_phase] }]
  │     if current_phase == TimePhase.NIGHT:
  │       For each torch in _torch_positions:
  │         sources.append({ "coords": torch.coords, "sub_hex": torch.sub_hex, "radius": TORCH_VISIBILITY_RADIUS })
  │
  └─ HexGrid.refresh_visibility(sources)
```

Torch sources added only during NIGHT (DAY/DUSK/DAWN radius already 2).

**2. Phase transition (radius changes):**

Only DUSK→NIGHT and NIGHT→DAWN trigger refresh (radius changes). DAY→DUSK and
DAWN→DAY don't (radius unchanged).

**3. Torch placed/destroyed:**

```
HexGrid emits prop_placed(coords, sub_hex, category, type)
  │  (where category == &"structure" and type == &"torch")
  │
  ├─ _torch_positions.append({ "coords": coords, "sub_hex": sub_hex })
  ├─ if current_phase == TimePhase.NIGHT:
  │     Rebuild sources, call refresh_visibility()
  └─ else: no-op
```

Same for `prop_removed` (remove matching entry from `_torch_positions`).

#### Save/Load — SaveManager (separate autoload)

DayNightCycle emits `day_started` — SaveManager listens. DayNightCycle has zero
knowledge of other systems' save data.

**Auto-save flow (at dawn):**

```
DayNightCycle emits day_started(day_count)
  │
  ├─ SaveManager receives signal
  │
  ├─ Collect save data from all systems:
  │     save = {
  │       "hex_grid":    HexGrid.get_save_data(),
  │       "player":      Player.get_save_data(),
  │       "inventory":   Inventory.get_save_data(),
  │       "survival":    SurvivalSystem.get_save_data(),
  │       "crafting":    CraftingSystem.get_save_data(),
  │       "catalog":     ScannerSystem.get_save_data(),
  │       "journal":     JournalSystem.get_save_data(),
  │       "day_night":   DayNightCycle.get_save_data(),
  │     }
  │
  ├─ Write to user://save.json via FileAccess:
  │     var file = FileAccess.open("user://save.json", FileAccess.WRITE)
  │     file.store_string(JSON.stringify(save))
  │     file.close()
  │
  └─ Done
```

**[CHANGED from pre-redesign]:** Save now includes `catalog` (feature-003) and
`journal` (feature-011) sections for the new systems.

**Load flow (game start):**

```
SaveManager on game start:
  │
  ├─ FileAccess.file_exists("user://save.json")?
  │     ✗ No → new game (MapLoader, defaults)
  │
  ├─ Read + JSON.parse_string()
  │     ✗ Parse fails → delete corrupt file, new game (no crash)
  │
  ├─ Distribute to systems:
  │     HexGrid.load_save_data(data.hex_grid)
  │     Player.load_save_data(data.player)
  │     Inventory.load_save_data(data.inventory)
  │     SurvivalSystem.load_save_data(data.survival)
  │     CraftingSystem.load_save_data(data.crafting)
  │     ScannerSystem.load_save_data(data.catalog)
  │     JournalSystem.load_save_data(data.journal)
  │     DayNightCycle.load_save_data(data.day_night)
  │
  └─ Resume gameplay from saved state
```

Each system implements `get_save_data() -> Dictionary` and
`load_save_data(data: Dictionary)`. Missing sections on load → defaults (graceful).
**Single save slot:** `user://save.json`.

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment (WorldEnvironment)   ← THIS FEATURE
       ├─ DirectionalLight3D                    ← THIS FEATURE (sun)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)                  [feature-003]
       ├─ PropLabelRenderer (Node3D)              [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ PropRenderer (Node3D)             [feature-004]
       ├─ GroundItemRenderer (Node3D)           [feature-007]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    ├─ CraftingSystem (Node)            [feature-006]
       │    └─ SurvivalSystem (Node)            [feature-007]
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ StatBars (HBoxContainer)              [feature-007]
       ├─ DayCounter (HBoxContainer)            ← THIS FEATURE (top-right)
       ├─ (other HUD elements)
  └─ ScreenFade (CanvasLayer)                   [feature-007]
```

#### Autoloads

```
HexGrid (Node)        — feature-001
DayNightCycle (Node)  ← THIS FEATURE — phase timer, visibility, torch tracking
SaveManager (Node)    ← THIS FEATURE — save/load orchestration
```

DayNightCycle as autoload: every feature reads `is_daytime` or connects to phase signals.
SaveManager as autoload: needs references to all systems for save/load.

#### File Structure

```
scripts/
  day_night/
    day_night_cycle.gd    # Autoload — phase timer, visibility, torch tracking,
                           #   lighting registration + tweens
  save/
    save_manager.gd       # Autoload — save/load orchestration, file I/O

ui/
  day_counter.gd          # Control — day number + phase icon in HUD
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `day_night_cycle.gd` | Autoload. Phase timer in `_process`, transitions + signals, centralized `refresh_visibility` calls, `_torch_positions` tracking (queries `tile.props` for torches via `prop_placed`/`prop_removed` signals), lighting registration + tweens, `get_save_data`/`load_save_data`. | `HexGrid` (refresh_visibility, prop signals), `Player` (current_tile via tile_entered) |
| `save_manager.gd` | Autoload. Listens to `day_started` for auto-save. Collects `get_save_data()` from all registered systems. Writes JSON. Loads on startup, distributes to systems. Handles corrupt/missing gracefully. | All systems (get_save_data / load_save_data contract) |
| `day_counter.gd` | HBoxContainer in HUD top-right. "DAY 07" label + phase icon. Updates on `day_started` and `phase_changed`. `mouse_filter = IGNORE`. | `DayNightCycle` (signals) |

#### Signal Wiring — Complete

```
HexGrid signals                          day_night_cycle.gd
  tile_entered(coords)               ──►  refresh visibility (build sources per phase)
  prop_placed(coords, sub_hex, cat, type) ──► update _torch_positions if torch
  prop_removed(coords, sub_hex, cat, type)──► update _torch_positions if torch

day_night_cycle.gd                       save_manager.gd
  day_started(day_count)             ──►  auto-save

day_night_cycle.gd                       day_counter.gd (feature-012 HUD)
  day_started(day_count)             ──►  update "DAY NN" label
  phase_changed(phase)               ──►  update phase icon color/shape

day_night_cycle.gd                       WorldEnvironment + DirectionalLight3D
  phase transitions                  ──►  tween lighting values (via registered refs)
```

#### Lighting — Registration Pattern

World scene script registers on `_ready()`:

```gdscript
# world.gd
func _ready():
    DayNightCycle.register_lighting($WorldEnvironment, $DirectionalLight3D)
```

Null-check before tweening. Headless/test safe.

**Draw call impact:** Zero. WorldEnvironment + DirectionalLight3D are scene-wide settings.

### UI Specs

#### DayCounter — Layout

```
┌──────────────────────────┐
│ [♥ ████████░░]           │
│ [🍖 █████░░░░]           │
│ [💧 ████░░░░░]  DAY 07 ☀ │  ← top-right
│                          │
│      (game world)        │
└──────────────────────────┘
```

#### DayCounter Design

- **Position:** Top-right, anchored to right edge
- **Layout:** HBoxContainer — "DAY 07" label + phase icon
- **Day label:** "DAY 07" — zero-padded, uppercase. `"DAY %02d" % day_count`
- **[CHANGED] Font/style:** Design system TBD (Tactical Brutalism discarded).
  MVP placeholder: clean sans-serif, ~24px, white with 1px dark outline.
  Semi-transparent background panel. No drop shadows.
- **Phase icon:** 32×32px, placeholder colored circles:

| Phase | Icon | Color |
|-------|------|-------|
| DAY | Sun circle | Warm yellow (#FFD93D) |
| DUSK | Half-sun | Warm orange (#FFB347) |
| NIGHT | Crescent | Soft purple (#9B7DC8) |
| DAWN | Rising circle | Peach (#FFAB91) |

**[CHANGED from pre-redesign]:** Colors are warm palette, not Tactical Brutalism
cyan/primary. Matches "charming, warm, sci-fi" redesign tone.

- **Touch:** `mouse_filter = IGNORE`. Display only.

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Phase tick | 1 float add + comparison | Every frame |
| Phase transition | Signal emits + tween creation | ~Every 30-180s |
| Visibility refresh | `refresh_visibility` call (see feature-001) | On tile_entered + phase change + torch change |
| Save (auto) | JSON stringify + file write | Once per dawn (~5 min) |
| Load | File read + JSON parse + distribute | Once at startup |

Phase tick is negligible. Save at dawn: JSON stringify of ~100KB data + file write
is <50ms on mobile — imperceptible.

#### Draw Calls

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| WorldEnvironment | 0 | Scene-wide setting |
| DirectionalLight3D | 0 | Scene-wide setting |
| DayCounter (HUD) | 0 | CanvasLayer UI |
| **Total** | **0** | Running total unchanged: ~18 |

#### Touch Interaction

None. DayCounter is display-only (`mouse_filter = IGNORE`).
ScreenFade blocks input while opaque (feature-007 owns ScreenFade).

#### Platform Differences

None. Phase timer, FileAccess, and Godot lighting work identically on iOS/Android.
`user://` path resolves to platform-appropriate sandbox automatically.

#### Memory

- DayNightCycle state: 4 properties = negligible
- `_torch_positions`: ~10 entries max = negligible
- Lighting references: 2 node refs = negligible
- Save file: ~100KB JSON (all systems combined) = negligible
