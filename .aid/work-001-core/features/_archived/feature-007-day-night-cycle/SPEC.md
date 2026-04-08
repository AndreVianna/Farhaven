# Day/Night Cycle

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F7/F12, §9 AC7 | /aid-interview |
| 2026-03-31 | Data Model written — phases, visibility sources, refresh_visibility API | /aid-specify |
| 2026-03-31 | Feature Flow written — SaveManager split out, torch sources NIGHT only | /aid-specify |
| 2026-03-31 | Layers & Components written — lighting registration pattern, SaveManager autoload | /aid-specify |
| 2026-03-31 | UI Specs written — DAY 07 mil-spec style, design system palette, no drop shadows | /aid-specify |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |

## Source

- REQUIREMENTS.md §5 F7 (Day/Night Cycle)
- REQUIREMENTS.md §5 F12 (HUD Layout — day counter, time-of-day icon)
- REQUIREMENTS.md §9 AC7 (Day/Night acceptance criteria)
- REQUIREMENTS.md §10 P0 — Persistence

## Description

The game runs on a continuous day/night cycle: Day (~3 min real time) → Dusk (30s warning with screen tint) → Night (~1.5 min) → Dawn. Full cycle is ~5 minutes. During the day, all revealed tiles are visible. At night, visibility is reduced to 1 hex around the player; Torches extend visibility to 2 hexes around the torch. The HUD shows a day counter ("Day 7") and time-of-day icon in the top-right.

The day/night cycle drives the game's pacing: day is for exploration and gathering, night is for survival. Auto-save triggers at each dawn.

## User Stories

- As a player, I want to feel the rhythm of day and night so sessions have natural structure
- As a player, I want the dusk warning so I have time to get to safety
- As a player, I want reduced visibility at night so darkness feels dangerous

## Priority

Must (P0 — Persistence)

## Acceptance Criteria

- [ ] Full cycle completes in 5 min ±15s (measurable)
- [ ] Dusk warning visible 30s before night
- [ ] Night: only tiles within 1 hex of player visible
- [ ] Torch placed: extends visibility to 2 hexes around torch

## Save Integration

Adds current day count, time-of-day phase, and phase elapsed time to save data. Auto-save triggers at dawn.

---

## Technical Specification

### Data Model

#### Phase Enum

```gdscript
enum TimePhase { DAY, DUSK, NIGHT, DAWN }
```

#### DayNightCycle Properties (autoload singleton)

```gdscript
var current_phase: TimePhase = TimePhase.DAY
var phase_elapsed: float = 0.0         # seconds elapsed in current phase
var day_count: int = 1                 # starts at Day 1
var is_daytime: bool = true            # true during DAY and DAWN, false during DUSK and NIGHT
```

`is_daytime` is derived from `current_phase`. Updated on phase transitions, not
computed per frame. Safe to read in `_process`.

#### Phase Durations — Config

```gdscript
const PHASE_DURATIONS: Dictionary = {
    TimePhase.DAY:   180.0,  # 3 minutes
    TimePhase.DUSK:   30.0,  # 30 seconds warning
    TimePhase.NIGHT:  90.0,  # 1.5 minutes
    TimePhase.DAWN:   10.0,  # brief transition, new day starts
}
# Total: ~310 seconds ≈ 5 min 10s (within AC7's 5 min ±15s — tight margin, 5s to spare)
```

DAWN is a brief 10s transition — screen brightens, day counter increments. Gives the
player a visual "morning" moment and lets respawn fade-in feel natural.

#### Visibility Radius — Per Phase

```gdscript
const VISIBILITY_RADIUS: Dictionary = {
    TimePhase.DAY:   2,  # current tile + 2 rings
    TimePhase.DUSK:  2,  # same as day (warning, not visibility change)
    TimePhase.NIGHT: 1,  # reduced — only adjacent tiles
    TimePhase.DAWN:  2,  # back to full
}

const TORCH_VISIBILITY_RADIUS: int = 2  # torch extends night visibility
```

Daytime baseline: radius 2. Night: radius 1. Torch at night: radius 2 around
the torch tile. Night visibility is meaningful without being claustrophobic.

#### Feature-001 API Amendment: refresh_visibility()

**Replaces `update_fog()`.** The old `update_fog(player_coords, radius)` can't handle
multiple visibility sources (player + torches) without overwriting each other. New API:

```gdscript
# Replaces update_fog(). Single pass, multiple sources, no race conditions.
# sources: Array of { "coords": Vector2i, "radius": int }
# Player is always sources[0]. Torches append.
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]
```

**Algorithm (single pass):**
1. Mark all currently VISIBLE tiles as REVEALED (demote)
2. For each source, mark tiles within source.radius as VISIBLE (promote)
3. Any tile going HIDDEN → VISIBLE emits `tile_revealed`
4. Any tile changing fog state emits `tile_visibility_changed`
5. Return array of newly revealed tiles

One function, one pass. No additive/overwrite conflicts. Called by DayNightCycle
(not by movement directly) — DayNightCycle builds the sources list and calls
`HexGrid.refresh_visibility()`.

**Who calls it:**
- On player movement: DayNightCycle builds sources (player + all torches) and calls
  `refresh_visibility`
- On phase transition: DayNightCycle rebuilds sources with new radius and calls
  `refresh_visibility`
- On torch placed/destroyed: DayNightCycle updates torch list and calls
  `refresh_visibility`

Movement (feature-002) no longer calls fog updates directly — it emits
`tile_entered`/`tile_exited`, and DayNightCycle reacts by refreshing visibility.

#### Signals

```gdscript
signal phase_changed(new_phase: TimePhase)
signal dawn()                              # NIGHT → DAWN
signal dusk()                              # DAY → DUSK
signal night()                             # DUSK → NIGHT
signal day_started(day_number: int)        # DAWN → DAY, after counter increments
```

Convenience signals so downstream systems don't need to check `phase_changed` args:
- Feature-006: `dawn` → deferred respawn
- Feature-008: `night` → fauna spawn
- Save system: `day_started` → auto-save

#### Save Data

```json
{
  "day_night": {
    "day_count": 7,
    "phase": 0,
    "phase_elapsed": 45.2
  }
}
```

Phase saved as int (enum ordinal). On load, resume from saved phase and elapsed time.

#### Cross-Feature Impacts

| Feature | Effect |
|---------|--------|
| feature-001 (hex grid) | `update_fog()` replaced by `refresh_visibility(sources)` |
| feature-002 (movement) | No longer calls fog directly — emits `tile_entered`, DayNightCycle handles visibility |
| feature-003 (gathering) | No direct effect |
| feature-006 (survival) | `is_daytime` gates HP regen. `dawn` triggers deferred respawn. |
| feature-008 (building/threats) | `night` triggers fauna spawn. Torch is a visibility source. |
| Save/load | SaveManager (within this feature) listens to `day_started`, orchestrates save. Each feature defines its own save data shape. |

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
  → Renderer: start screen tint (amber/orange, gradual)
  → No visibility change (radius stays 2)

DUSK → NIGHT:
  current_phase = NIGHT, phase_elapsed = 0.0
  Emit phase_changed(NIGHT), night()
  → Visibility shrinks to 1 hex (+ torch zones)
  → Call refresh_visibility() with night radius + torch sources
  → Renderer: darken scene, reduce ambient light

NIGHT → DAWN:
  current_phase = DAWN, phase_elapsed = 0.0, is_daytime = true
  day_count += 1
  Emit phase_changed(DAWN), dawn()
  → Visibility expands back to 2 hexes (no torch sources needed)
  → Call refresh_visibility() with day radius
  → Renderer: brighten scene
  → Feature-006: deferred respawn triggers here

DAWN → DAY:
  current_phase = DAY, phase_elapsed = 0.0
  Emit phase_changed(DAY), day_started(day_count)
  → SaveManager triggers auto-save (listens to day_started)
  → Renderer: full brightness, tint removed
```

#### Visibility Refresh — Centralized

DayNightCycle owns all calls to `HexGrid.refresh_visibility()`. Three triggers:

**1. Player movement (`tile_entered` signal):**

```
HexGrid emits tile_entered(coords)
  │
  ├─ DayNightCycle receives signal
  ├─ Build sources:
  │     sources = [{ "coords": coords, "radius": VISIBILITY_RADIUS[current_phase] }]
  │     if current_phase == TimePhase.NIGHT:
  │       For each torch in _torch_tiles:
  │         sources.append({ "coords": torch, "radius": TORCH_VISIBILITY_RADIUS })
  │
  └─ HexGrid.refresh_visibility(sources)
```

Torch sources added only during NIGHT. During DAY/DUSK/DAWN, radius is already 2 —
torches (also radius 2) would have zero effect. Less iteration, clearer intent.

**2. Phase transition (radius changes):**

```
On DUSK → NIGHT or NIGHT → DAWN:
  │
  ├─ Build sources with new radius (player.current_tile + torches if NIGHT)
  └─ HexGrid.refresh_visibility(sources)
```

Only these two transitions change the visibility radius. DAY→DUSK and DAWN→DAY
don't need a refresh (radius stays 2).

**3. Torch placed/destroyed:**

```
HexGrid emits structure_placed(coords, &"torch") or structure_destroyed(coords, &"torch")
  │
  ├─ Update _torch_tiles (add/remove coords)
  ├─ if current_phase == TimePhase.NIGHT:
  │     Rebuild sources and call refresh_visibility()
  └─ else: no-op (torches have no visibility effect outside NIGHT)
```

**`_torch_tiles: Array[Vector2i]`** — maintained by DayNightCycle, updated on
structure signals. Only queried during NIGHT phase.

#### Save/Load — SaveManager

**SaveManager is a separate script** within feature-007's scope. DayNightCycle emits
`day_started` — SaveManager listens and orchestrates. DayNightCycle has zero knowledge
of other systems' save data.

**Auto-save flow (at dawn):**

```
DayNightCycle emits day_started(day_count)
  │
  ├─ SaveManager receives signal
  │
  ├─ Collect save data from all systems:
  │     Each system implements get_save_data() -> Dictionary
  │     save = {
  │       "hex_grid":  HexGrid.get_save_data(),
  │       "player":    Player.get_save_data(),
  │       "inventory": Inventory.get_save_data(),
  │       "survival":  SurvivalSystem.get_save_data(),
  │       "crafting":  CraftingSystem.get_save_data(),
  │       "day_night": DayNightCycle.get_save_data(),
  │     }
  │
  ├─ Write to user://save.json via FileAccess:
  │     var file = FileAccess.open("user://save.json", FileAccess.WRITE)
  │     file.store_string(JSON.stringify(save))
  │     file.close()
  │
  └─ Done
```

**Load flow (game start):**

```
SaveManager._ready() or Main scene init:
  │
  ├─ FileAccess.file_exists("user://save.json")?
  │     ✗ No → new game (worldgen, defaults)
  │
  ├─ Read + JSON.parse_string()
  │     ✗ Parse fails → delete corrupt file, new game (AC: no crash)
  │
  ├─ Distribute to systems:
  │     HexGrid.load_save_data(data.hex_grid)
  │     Player.load_save_data(data.player)
  │     Inventory.load_save_data(data.inventory)
  │     SurvivalSystem.load_save_data(data.survival)
  │     CraftingSystem.load_save_data(data.crafting)
  │     DayNightCycle.load_save_data(data.day_night)
  │
  └─ Resume gameplay
```

Each system implements `get_save_data() -> Dictionary` and
`load_save_data(data: Dictionary)`. Save data shapes defined in each
feature's Data Model. **Single save slot:** `user://save.json`.

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment (WorldEnvironment)   ← NEW
       ├─ DirectionalLight3D                    ← NEW (sun)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)             [feature-003]
       ├─ GroundItemRenderer (Node3D)           [feature-006]
       ├─ Player (Node3D)                       [feature-002]
       │    └─ (children as before)
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               [feature-003]
  └─ HUD (CanvasLayer)                          [feature-004]
       ├─ StatBars (HBoxContainer)              [feature-006]
       ├─ DayCounter (HBoxContainer)            ← NEW (top-right)
       ├─ InventoryButton                       [feature-004]
       ├─ CraftButton                           [feature-005]
       ├─ InventoryPanel                        [feature-004]
       └─ CraftingPanel                         [feature-005]
  └─ ScreenFade (CanvasLayer)                   [feature-006]
```

#### Autoloads

```
HexGrid (Node)        — existing (feature-001)
DayNightCycle (Node)  ← NEW — phase timer, visibility refresh, torch tracking
SaveManager (Node)    ← NEW — save/load orchestration
```

DayNightCycle as autoload: every feature needs `is_daytime`, phase signals, or
`day_count`. Same rationale as HexGrid.

SaveManager as autoload: needs references to all systems for save/load. Autoload
`_ready()` runs after other autoloads, so HexGrid and DayNightCycle are available.

#### File Structure

```
scripts/
  day_night/
    day_night_cycle.gd    # Autoload — phase timer, visibility, torch tracking
  save/
    save_manager.gd       # Autoload — save/load orchestration

ui/
  day_counter.gd          # Control — "Day 7" + phase icon
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `day_night_cycle.gd` | Autoload. Phase timer, transitions + signals, visibility refresh, `_torch_tiles`, `is_daytime`. Tweens registered lighting nodes on transitions. | `HexGrid` (refresh_visibility, structure signals), `Player` (current_tile via tile_entered) |
| `save_manager.gd` | Autoload. Listens to `day_started` → collects save data → writes JSON. Loads on game start → distributes to systems. | All systems (get_save_data/load_save_data) |
| `day_counter.gd` | HUD top-right. Updates day number on `day_started`, phase icon on `phase_changed`. | `DayNightCycle` (signals) |

#### Signal Wiring

```
HexGrid signals                          day_night_cycle.gd
  tile_entered(coords)               ──►  refresh visibility
  structure_placed(coords, type)     ──►  update _torch_tiles if torch
  structure_destroyed(coords, type)  ──►  update _torch_tiles if torch

day_night_cycle.gd                       save_manager.gd
  day_started(day_count)             ──►  auto-save

day_night_cycle.gd                       day_counter.gd
  day_started(day_count)             ──►  update "Day N" label
  phase_changed(phase)               ──►  update phase icon

day_night_cycle.gd                       WorldEnvironment + DirectionalLight3D
  phase transitions                  ──►  tween light intensity, color, sky tint
                                          (via registered references)
```

#### Lighting — Registration Pattern

DayNightCycle is an autoload — its `_ready()` runs before the World scene tree
exists. It cannot use `get_node()` to find WorldEnvironment or DirectionalLight3D.

**Solution:** World scene script registers lighting nodes on its own `_ready()`:

```gdscript
# In world.gd (attached to World Node3D):
func _ready():
    DayNightCycle.register_lighting($WorldEnvironment, $DirectionalLight3D)
```

DayNightCycle stores the references:

```gdscript
# In day_night_cycle.gd:
var _world_env: WorldEnvironment
var _sun_light: DirectionalLight3D

func register_lighting(env: WorldEnvironment, sun: DirectionalLight3D) -> void:
    _world_env = env
    _sun_light = sun
```

Phase transitions check if lighting is registered before tweening:

```gdscript
if _world_env and _sun_light:
    # tween properties
```

**If lighting isn't registered** (e.g., unit tests, headless), phase transitions still
fire all signals — just no visual changes. Clean, testable, no fragile path lookups.

#### Lighting Values Per Phase

DayNightCycle tweens `WorldEnvironment` and `DirectionalLight3D` properties on
transitions. Tween duration = phase duration for smooth interpolation.

| Phase | Ambient Energy | Sun Intensity | Sun Color | Environment Tint |
|-------|---------------|---------------|-----------|-----------------|
| DAY | 1.0 | 1.0 | Warm white | None |
| DUSK | 0.7 | 0.6 | Orange | Amber overlay |
| NIGHT | 0.2 | 0.05 | Cool blue | Dark blue |
| DAWN | 0.7 → 1.0 | 0.5 → 1.0 | Orange → white | Amber → none |

Values are tunable. Each transition creates a Tween that interpolates from current
to target over the phase duration. No per-frame manual lerp.

**Draw call impact:** Zero. WorldEnvironment and DirectionalLight3D are scene-wide
settings, not renderable objects.

### UI Specs

#### Layout — Top-right of HUD

```
┌──────────────────────────┐
│ [♥ ████████░░]           │  ← stat bars (top-left, feature-006)
│ [🍖 █████░░░░]           │
│ [💧 ████░░░░░]  DAY 07 ☀ │  ← day counter + phase icon (top-right)
│                          │
│      (game world)        │
│                          │
│              [Inv][Build]│
└──────────────────────────┘
```

#### DayCounter Design

- **Position:** Top-right, anchored to right edge
- **Layout:** HBoxContainer — "DAY 07" label + phase icon, right-aligned
- **Day label:** "DAY 07" — zero-padded, uppercase, mil-spec style.
  Font: Space Grotesk, label style, uppercase, tracking-widest.
  ~24px. White text with 1px dark outline stroke for readability over varying
  backgrounds (no drop shadows — Tactical Brutalism rule).
  Updates on `day_started(day_count)`: `"DAY %02d" % day_count`
- **Background:** Thin semi-transparent panel behind text — same approach as stat bars.

#### Phase Icon

Small icon (32×32px) next to day label. Updates on `phase_changed`. Colors from
the design system palette:

| Phase | Icon | Color |
|-------|------|-------|
| DAY | Sun | Primary (#a8e8ff) |
| DUSK | Setting sun | Warning/amber |
| NIGHT | Moon | Outline-variant (dimmed) |
| DAWN | Rising sun | Primary at 60% opacity |

Placeholder art: colored circles with simple shapes (circle = sun, crescent = moon).

#### Touch & Performance

- Display only. `mouse_filter = IGNORE`. No interaction.
- Zero draw calls (UI elements, not 3D objects).
- Day transition: optional brief pulse animation on counter (text scales up
  slightly, then back) on `day_started`. Not critical.
