# Survival Stats, Death & Respawn

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F8, F11, §9 AC8 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-03-31 | Fix: toxic_berries concrete values (hunger 10, toxic_damage 25) | /aid-specify |
| 2026-04-02 | Scene tree: ElementIconRenderer → PropRenderer + PropLabelRenderer (feature-003 architecture change). | /spec-update |
| 2026-04-04 | Unified props: ground items remain main-hex addressed (no sub-hex). Death drops unchanged. Save/load note for resource props with sub-hex data. | /arch-update |

## Source

- REQUIREMENTS.md §5 F8 (Survival Stats)
- REQUIREMENTS.md §5 F11 (Death & Respawn)
- REQUIREMENTS.md §9 AC8 (Survival Stats acceptance criteria)

## Description

Three survival stats (HP, Hunger, Thirst) deplete over time. When Hunger or Thirst reaches zero, HP drains. The player eats/drinks to restore stats -- but unknown flora requires scanning first. HP regenerates slowly during daytime. Death triggers a fade-to-black transition and respawn at Shelter or Crash Site with 50% inventory drop. Day counter continues. Death at night defers respawn to dawn.

## User Stories

- As a player, I want survival stats to create gentle urgency without being punishing
- As a player, I want death to have consequences but not end my run
- As a player, I want eating to require knowledge -- scanning adds real food risk

## Priority

Must (P0 -- Core Loop)

## Acceptance Criteria

- [ ] HUD shows 3 bars at all times
- [ ] Hunger reaches 0 -> HP decreases at defined rate
- [ ] Eat scanned-safe Berries -> Hunger increases by defined amount
- [ ] All three stats at 0 -> player dies -> fade to black -> respawn with 50% inventory drop

## Save Integration

HP, Hunger, Thirst values. Respawn tile coordinates. Ground items array.

---

## Technical Specification

### Data Model

#### Stat Properties (on SurvivalSystem node, child of Player)

```gdscript
var hp: float = 100.0
var hp_max: float = 100.0
var hunger: float = 100.0
var hunger_max: float = 100.0
var thirst: float = 100.0
var thirst_max: float = 100.0

var is_dead: bool = false
```

All floats (0.0 to max). Smooth depletion + smooth HUD bar rendering.

#### Public API — External Damage

```gdscript
func take_damage(amount: float) -> void
```

Reduces `hp` by `amount`, clamped to 0. Emits `stat_changed`. Triggers death
check. Consumed via `fauna_attacked_player` from feature-010 (FaunaManager) and
via `auto_defend_triggered` from feature-004 (surprise attack damage to player).

#### Depletion/Regen Rates — Config

```gdscript
const STAT_CONFIG: Dictionary = {
    "hunger_rate": 1.0,         # points/sec depletion
    "thirst_rate": 1.5,         # points/sec (faster than hunger, per F8)
    "hp_drain_no_hunger": 2.0,  # HP/sec when hunger == 0
    "hp_drain_no_thirst": 3.0,  # HP/sec when thirst == 0 (faster, per F8)
    "hp_regen_day": 0.5,        # HP/sec during daytime
}
```

All values tunable — exported or in a config resource.

**HP drain stacking:** Both hunger AND thirst at zero → both drains apply:
`2.0 + 3.0 = 5.0 HP/sec`.

**HP regen conditions:** Daytime only (feature-008 `DayNightCycle.is_daytime`).
Only when hunger > 0 AND thirst > 0. No regen at night or while starving.

#### Consumable Effects — Config

```gdscript
const CONSUMABLE_CONFIG: Dictionary = {
    &"berries":       { "hunger": 15.0, "thirst": 5.0, "toxic_damage": 0.0 },
    &"toxic_berries": { "hunger": 10.0, "thirst": 0.0, "toxic_damage": 25.0 },
    &"meat":          { "hunger": 25.0, "thirst": 0.0, "toxic_damage": 0.0 },
}
```

**[NEW] `toxic_damage` field:** For toxic flora, this value is > 0. When the player
consumes a toxic item (via feature-005's inventory panel with warning), SurvivalSystem
applies the stat restore AND the toxic damage.

**Chapter 1 toxic flora:** 1 type — toxic berries. Looks similar to safe berries
but cataloged as toxic on scan. Values: restores 10 hunger, deals 25 HP damage
(25% of max HP). Serious but not instantly lethal — 4 toxic berries = death.
Scanning once prevents all future risk for that species forever.

Toxic damage applied as HP loss via `take_damage()` immediately after stat restore.

**Note:** The `toxic_damage` field on non-toxic items is 0.0 (no damage). Feature-005's
inventory panel shows a warning dialog for toxic flora (queries Catalog), but
SurvivalSystem doesn't know about the Catalog — it just reads `toxic_damage` from
the config. Clean separation: Catalog decides if warning shows, Config decides the effect.

#### Death — Inventory Drop Rules

**50% of each resource/consumable stack, rounded down.** Predictable, no RNG.

Example: 50 wood, 10 stone, 5 berries → drops 25 wood, 5 stone, 2 berries.

**Tool slots NOT affected.** Only resource/consumable inventory slots lose items.

**Drop algorithm:**
```
For each occupied slot in Inventory._slots:
    drop_amount = floor(slot.quantity / 2)
    if drop_amount > 0:
        Inventory.remove_item(slot.type, drop_amount)
        Place as ground item on passable neighbor of death tile
```

**Scatter placement:** Items pile on same tile if few passable neighbors. Multiple
entries with same coords supported. Items on non-visible tiles recoverable when revealed.

#### Ground Items — Transient Pickups

Separate from tile props (map data). Ground items are death drops + fauna meat drops
that persist until picked up.

**Ground items use main-hex coords only (no sub-hex).** Unlike resource props which
have sub-hex positions, ground items are addressed at the tile level. This is an MVP
simplification — sub-hex placement for drops is not needed since auto-pickup triggers
on tile entry.

```gdscript
var _ground_items: Array[Dictionary] = []
# Each entry: { "type": StringName, "amount": int, "coords": Vector2i }
# Note: no sub_hex field — ground items are main-hex addressed
```

**[CHANGED] Auto-pickup ownership:** Feature-004 (AutoInteractionSystem) handles the
pickup on `tile_entered`. SurvivalSystem owns the `_ground_items` data and provides:

```gdscript
func get_ground_items_at(coords: Vector2i) -> Array[Dictionary]
func remove_ground_item(coords: Vector2i, type: StringName, amount: int) -> void
func add_ground_item(coords: Vector2i, type: StringName, amount: int) -> void
```

Feature-004 calls `get_ground_items_at` + `Inventory.add_item` + `remove_ground_item`.
SurvivalSystem doesn't call `Inventory.add_item` for pickups — it just manages the data.

**Fauna meat drops:** Feature-010 emits `fauna_killed(id, coords, species_type)` →
SurvivalSystem listens → `add_ground_item(coords, &"meat", 1)`.

#### Respawn Point

```gdscript
var _respawn_tile: Vector2i  # Shelter coords if built, else Crash Site (0,0)
```

Updates on:
- `structure_placed` with `&"shelter"` → `_respawn_tile = coords` (signal operates on props with category="structure")
- `structure_destroyed` with `&"shelter"` → revert to Crash Site or another Shelter

#### Signals

```gdscript
signal stat_changed(stat_name: StringName, current: float, max_val: float)
signal player_died()
signal player_respawned(coords: Vector2i)
signal ground_item_dropped(coords: Vector2i, type: StringName, amount: int)
signal ground_item_picked_up(coords: Vector2i, type: StringName, amount: int)
```

#### Save Data

```json
{
  "survival": {
    "hp": 85.5,
    "hunger": 42.0,
    "thirst": 60.0,
    "respawn_tile_col": 0,
    "respawn_tile_row": 0
  },
  "ground_items": [
    { "type": "wood", "amount": 25, "tile_col": 2, "tile_row": -1 },
    { "type": "stone", "amount": 5, "tile_col": 3, "tile_row": -1 }
  ]
}
```

`is_dead` not saved — player always loads alive (respawn completes before save).

**Note on props vs ground items:** Resource props (tile data from feature-001) include
`sub_hex` coordinates and are saved per-tile in the hex grid save. Ground items
(death drops, meat) do NOT have sub-hex data — they remain main-hex addressed.
The two systems are independent: props are map data, ground items are transient pickups.

#### Cross-Feature Dependencies

| What | Source |
|------|--------|
| `item_used(type)` signal — consumable consumed | feature-005 (inventory) |
| `is_daytime` property — HP regen condition | feature-008 (DayNightCycle) |
| `dawn` signal — deferred respawn trigger | feature-008 (DayNightCycle) |
| `structure_placed`/`destroyed` — shelter respawn | feature-009 via HexGrid |
| `fauna_attacked_player(id, damage, species)` — external HP damage | feature-010 (FaunaManager) |
| `fauna_killed(id, coords, species)` — meat ground item creation | feature-010 (FaunaManager) |
| `get_ground_items_at` / `remove_ground_item` — auto-pickup API | feature-004 (AutoInteractionSystem) queries this |

---

### Feature Flow

#### Stat Tick (_process)

```
Every frame (SurvivalSystem._process):
  │
  ├─ if is_dead: return
  │
  ├─ Deplete hunger:
  │     hunger = max(0.0, hunger - STAT_CONFIG.hunger_rate * delta)
  │     Emit stat_changed(&"hunger", hunger, hunger_max)
  │
  ├─ Deplete thirst:
  │     thirst = max(0.0, thirst - STAT_CONFIG.thirst_rate * delta)
  │     Emit stat_changed(&"thirst", thirst, thirst_max)
  │
  ├─ HP drain (starving/dehydrated):
  │     if hunger == 0.0:
  │       hp -= STAT_CONFIG.hp_drain_no_hunger * delta
  │     if thirst == 0.0:
  │       hp -= STAT_CONFIG.hp_drain_no_thirst * delta
  │     (both apply simultaneously if both zero → 5.0 HP/sec)
  │
  ├─ HP regen (daytime, not starving):
  │     if DayNightCycle.is_daytime AND hunger > 0 AND thirst > 0:
  │       hp = min(hp_max, hp + STAT_CONFIG.hp_regen_day * delta)
  │
  ├─ Clamp + emit:
  │     hp = clamp(hp, 0.0, hp_max)
  │     Emit stat_changed(&"hp", hp, hp_max)
  │
  ├─ Death check:
  │     if hp <= 0.0 AND NOT is_dead:
  │       → trigger death flow
  │
  └─ End
```

`stat_changed` emits every frame for smooth HUD bar updates. 3 listeners, negligible.

#### Consume Flow

```
Inventory (feature-005) emits item_used(type)
  │
  ├─ SurvivalSystem receives signal
  │
  ├─ Look up CONSUMABLE_CONFIG[type]
  │     ✗ Not found → ignore (not a stat consumable)
  │
  ├─ Apply stat effects:
  │     hunger = min(hunger_max, hunger + config.hunger)
  │     thirst = min(thirst_max, thirst + config.thirst)
  │     Emit stat_changed for each affected stat
  │
  ├─ [NEW] Apply toxic damage (if any):
  │     if config.toxic_damage > 0.0:
  │       take_damage(config.toxic_damage)
  │       → HUD (feature-012): ScreenFade.flash(red) for damage feedback
  │       → Stat bar HP updates immediately
  │
  └─ Done
```

**Ownership:** Inventory (feature-005) shows toxic warning dialog (queries Catalog).
If player confirms, `item_used` fires. SurvivalSystem applies effects blindly from
CONSUMABLE_CONFIG — doesn't know about Catalog or toxicity logic.

#### Death Flow

```
hp <= 0.0 triggers:
  │
  ├─ Set is_dead = true
  ├─ Emit player_died()
  │
  ├─ Drop 50% of each resource/consumable stack:
  │     For each occupied slot in Inventory._slots:
  │       drop_amount = floor(slot.quantity / 2)
  │       if drop_amount > 0:
  │         Inventory.remove_item(slot.type, drop_amount)
  │         Pick passable neighbor (round-robin, items pile on same tile)
  │         add_ground_item(coords, type, drop_amount)
  │         Emit ground_item_dropped(coords, type, drop_amount)
  │     Tool slots untouched.
  │
  ├─ Fade to black:
  │     ScreenFade.fade_out(1.5)
  │     On fade_out_completed:
  │       Teleport + reset (respawn flow)
  │       if DayNightCycle.is_daytime:
  │         ScreenFade.fade_in(1.5) → player "wakes up"
  │       else:
  │         Connect to DayNightCycle.dawn → then ScreenFade.fade_in(1.5)
  │
  └─ Continue to respawn flow
```

#### Respawn Flow

```
Respawn (immediate or deferred to dawn):
  │
  ├─ Teleport to _respawn_tile:
  │     Player.current_tile = _respawn_tile
  │     Player.position = HexGrid.axial_to_world(_respawn_tile) + elevation Y
  │     Emit HexGrid.tile_entered(_respawn_tile)
  │
  ├─ Reset stats:
  │     hp = hp_max               → full HP
  │     hunger = hunger_max * 0.5 → 50% (urgency remains)
  │     thirst = thirst_max * 0.5 → 50%
  │
  ├─ Set is_dead = false
  ├─ Emit player_respawned(_respawn_tile)
  └─ Done
```

Day counter unaffected. No permadeath.

#### Fauna Meat Drop (via signal)

```
FaunaManager (feature-010) emits fauna_killed(id, coords, species_type)
  │
  ├─ SurvivalSystem receives signal
  ├─ add_ground_item(coords, &"meat", 1)
  ├─ Emit ground_item_dropped(coords, &"meat", 1)
  └─ Done
```

FaunaManager does NOT access `_ground_items` — it emits, SurvivalSystem creates.

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)                  [feature-003]
       ├─ PropLabelRenderer (Node3D)              [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ ResourceRenderer (Node3D)             [feature-004]
       ├─ GroundItemRenderer (Node3D)           ← THIS FEATURE (MultiMesh loot markers)
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    ├─ CraftingSystem (Node)            [feature-006]
       │    └─ SurvivalSystem (Node)            ← THIS FEATURE
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ StatBars (HBoxContainer)              ← THIS FEATURE (top-left)
       │    ├─ HPBar (ProgressBar)
       │    ├─ HungerBar (ProgressBar)
       │    └─ ThirstBar (ProgressBar)
       ├─ (other HUD elements from other features)
  └─ ScreenFade (CanvasLayer)                   ← THIS FEATURE (above HUD)
       └─ FadeRect (ColorRect)
```

#### File Structure

```
scripts/
  survival/
    survival_system.gd         # Node (child of Player) — stat tick, consume, death/respawn,
                                #   ground items data + API, respawn point tracking
    ground_item_renderer.gd    # Node3D — MultiMesh for loot markers on tiles

scenes/
  world/
    ground_item_renderer.tscn  # Single MultiMeshInstance3D

ui/
  stat_bars.gd                 # Control — 3 ProgressBars, listens to stat_changed
  screen_fade.gd               # CanvasLayer — fade_out, fade_in, flash (reusable)
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `survival_system.gd` | Child Node of Player. Stat tick (_process), consume handler (item_used), take_damage API, death/respawn flow, `_ground_items` data + public query/mutation API, `_respawn_tile` tracking, fauna meat creation on `fauna_killed`. | `Inventory` feature-005 (remove_item for drops, item_used signal), `HexGrid` (tile queries, structure signals), `DayNightCycle` feature-008 (is_daytime, dawn signal), `ScreenFade` (fade_out/fade_in) |
| `stat_bars.gd` | HBoxContainer in HUD with 3 ProgressBars. Listens to `stat_changed`, updates values + colors (gradient thresholds). `mouse_filter = IGNORE`. | `SurvivalSystem` (stat_changed signal) |
| `screen_fade.gd` | CanvasLayer above HUD. ColorRect with alpha tween. `fade_out(duration)`, `fade_in(duration)`, `flash(color, duration)`. Signals: `fade_out_completed`, `fade_in_completed`. Reusable. | None (standalone utility) |
| `ground_item_renderer.gd` | Node3D under World. Single MultiMeshInstance3D (~10 max instances, 1 draw call). Updates on `ground_item_dropped`/`ground_item_picked_up`. Fog-aware visibility. | `SurvivalSystem` (ground item signals) |

#### Signal Wiring — Complete

```
Inventory (feature-005) signals              survival_system.gd
  item_used(type)                        ──►  apply consumable effect + toxic damage

HexGrid signals                              survival_system.gd
  structure_placed(coords, type)         ──►  update _respawn_tile if shelter
  structure_destroyed(coords, type)      ──►  revert _respawn_tile if shelter lost

DayNightCycle (feature-008)                  survival_system.gd
  is_daytime property                    ──►  HP regen condition (read per frame)
  dawn signal                            ──►  deferred respawn trigger

FaunaManager (feature-010)                   survival_system.gd
  fauna_attacked_player(id, dmg, species)──►  take_damage(dmg)
  fauna_killed(id, coords, species)      ──►  add_ground_item(coords, &"meat", 1)

survival_system.gd                           stat_bars.gd (feature-012 HUD)
  stat_changed(name, current, max)       ──►  update ProgressBar + color

survival_system.gd                           screen_fade.gd
  player_died()                          ──►  fade_out(1.5)
  (on fade_out_completed)                ──►  teleport + reset + fade_in or wait for dawn

survival_system.gd                           ground_item_renderer.gd
  ground_item_dropped(coords, type, amt) ──►  add loot marker
  ground_item_picked_up(coords, type, a) ──►  remove/update marker

feature-004 (AutoInteractionSystem)          survival_system.gd
  (queries get_ground_items_at)          ──►  reads ground item data for auto-pickup
  (calls remove_ground_item)             ──►  removes picked up items
```

#### ScreenFade API — Complete

```gdscript
# screen_fade.gd — CanvasLayer above HUD
func fade_out(duration: float = 1.5) -> void   # alpha 0 → 1 (to black)
func fade_in(duration: float = 1.5) -> void    # alpha 1 → 0 (from black)
func flash(color: Color, duration: float = 0.2) -> void  # brief color pulse

signal fade_out_completed()
signal fade_in_completed()  # available for future use
```

Three uses:
1. Death: `fade_out` → black → respawn → `fade_in`
2. Damage hit: `flash(Color(1,0,0,0.3), 0.2)` — red vignette (feature-010 combat)
3. Future: save/load transitions

### UI Specs

#### Stat Bars — Layout

```
┌──────────────────────────┐
│ [♥ ████████░░]           │  ← HP (top-left)
│ [🍖 █████░░░░]           │  ← Hunger
│ [💧 ████░░░░░]           │  ← Thirst
│                          │
│      (game world)        │
└──────────────────────────┘
```

#### Stat Bar Design

- **Position:** Top-left, stacked vertically
- **Size:** ~200px wide × 20px tall each
- **Color gradient per stat:**
  - HP: green (>50%) → yellow (25-50%) → red (<25%)
  - Hunger: green → yellow → red (same thresholds)
  - Thirst: blue (>50%) → yellow → red
- **Icon prefix** per bar. No numeric value.
- **Translucent background**
- **Smooth tween** on value change (not instant snap)
- **`mouse_filter = IGNORE`** — display only, touches pass through

#### Death Transition

No text, no "YOU DIED." Smooth cinematic fade:

```
HP hits 0 → fade to black (1.5s) → teleport + reset while black →
  daytime: fade in (1.5s) → "wakes up"
  nighttime: stay black → dawn signal → fade in (1.5s) → "wakes up at dawn"
```

#### Touch Targets

No interactive elements. Stat bars display-only. Fade blocks input while opaque.

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Stat tick | 3 float ops + 3 signal emits | Every frame |
| Consume | 2 float adds + optional take_damage | On item_used |
| Death drops | O(n): n = occupied slots (≤24) | On death |
| Ground item query | O(m): m = items at coords (0-3 typical) | On tile_entered (feature-004 calls) |

Stat tick is the only per-frame cost: 3 float operations + 3 signal emissions.
At 60fps, ~180 signal emissions/sec. Godot handles this without issue for 3 listeners.

#### Draw Calls

| Renderer | Draw Calls | Notes |
|----------|-----------|-------|
| GroundItemRenderer | 1 | Single MultiMesh, ~10 max instances |
| StatBars | 0 | CanvasLayer UI |
| ScreenFade | 0 | CanvasLayer UI (single ColorRect) |
| **Total** | **1** | Running total: terrain ~5, icons ~6, resources ~6, ground items ~1 = ~18 |

#### Platform Differences

None. Pure GDScript + Godot UI. iOS/Android identical.

#### Memory

- Stat properties: 6 floats = negligible
- CONSUMABLE_CONFIG: ~5 entries = negligible
- Ground items: ~20 entries max × ~32 bytes = <1KB
- GroundItemRenderer: 1 MultiMesh, 10 instances = negligible
- ScreenFade: 1 ColorRect = negligible
