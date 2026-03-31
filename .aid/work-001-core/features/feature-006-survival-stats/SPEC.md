# Survival Stats, Death & Respawn

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F8/F11/F12, §9 AC8 | /aid-interview |
| 2026-03-30 | Data Model written — stats, drop rules, ground items, auto-pickup | /aid-specify |
| 2026-03-30 | Feature Flow written — stat tick, consume, death/respawn, item piling | /aid-specify |
| 2026-03-30 | Layers & Components written — ground_item_renderer under scripts/survival/ | /aid-specify |
| 2026-03-31 | UI Specs written — stat bars, fade-to-black death (no text overlay) | /aid-specify |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |
| 2026-03-31 | Round 2 fixes: take_damage() API, fauna signal dependencies | /audit |

## Source

- REQUIREMENTS.md §5 F8 (Survival Stats)
- REQUIREMENTS.md §5 F11 (Death & Respawn)
- REQUIREMENTS.md §5 F12 (HUD Layout — stat bars)
- REQUIREMENTS.md §9 AC8 (Survival acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

The player has three survival stats displayed as compact horizontal bars at the top of the HUD: HP, Hunger, and Thirst. Hunger and Thirst deplete over time; when either reaches zero, HP drains (Thirst drains HP faster). The player eats or drinks to restore stats. HP regenerates slowly during daytime. There is no stamina bar.

When HP reaches zero, the player dies and respawns at their Shelter (if built) or the Crash Site. 50% of inventory is dropped as random items scattered on nearby tiles (recoverable). The day counter continues — no reset. If death occurs at night, respawn happens at dawn. No permadeath.

## User Stories

- As a player, I want to see my survival stats at a glance so I know when I'm in danger
- As a player, I want hunger and thirst to create gentle urgency without being punishing
- As a player, I want death to have consequences (lose items) but not end my run (no permadeath)

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] HUD shows 3 bars at all times
- [ ] Hunger reaches 0 → HP decreases at defined rate
- [ ] Eat Berries → Hunger increases by defined amount
- [ ] All three stats at 0 → player dies → respawn with 50% inventory drop

## Save Integration

Adds HP, Hunger, Thirst values and respawn location to save data.

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

All stats are `float` (0.0 to max). Floats allow smooth depletion and smooth HUD
bar rendering without rounding artifacts.

#### Public API — External Damage

```gdscript
# Apply external HP damage (from fauna contact, environmental hazards, etc.)
func take_damage(amount: float) -> void
```

Consumed via `fauna_attacked_player` signal from feature-008's FaunaManager.
Reduces `hp` by `amount`, clamped to 0. Emits `stat_changed`. Triggers death
check if HP reaches 0.

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

All values tunable — exported or in a config resource for balancing.

**HP drain stacking:** Both hunger AND thirst at zero → both drains apply:
`2.0 + 3.0 = 5.0 HP/sec`. Ignoring both stats is very dangerous.

**HP regen conditions:** Daytime only (feature-007 provides `is_daytime`). Only when
hunger > 0 AND thirst > 0. No regen at night, no regen while starving/dehydrated.

#### Consumable Effects — Config

```gdscript
const CONSUMABLE_CONFIG: Dictionary = {
    &"berries": { "hunger": 15.0, "thirst": 5.0 },
    &"meat":    { "hunger": 25.0, "thirst": 0.0 },
}
```

Keyed by item type (matches `item_config` from feature-004). Berries restore mostly
hunger with a small thirst bonus. Meat is the best hunger item (25 vs berries' 15) — only source is fauna kills (feature-008). Future items (clean water, cooked food) add entries without code changes.

#### Death — Inventory Drop Rules

**What is dropped:** 50% of each resource/consumable stack, rounded down.

Example: player has 50 wood, 10 stone, 5 berries →
drops 25 wood, 5 stone, 2 berries. Predictable, no RNG frustration.

**Tool slots are NOT affected by death.** Only resource/consumable inventory slots
lose items. Losing a crafted tool would be too punishing for MVP.

**Drop algorithm:**
```
For each occupied slot in Inventory._slots:
    drop_amount = floor(slot.quantity / 2)
    if drop_amount > 0:
        Inventory.remove_item(slot.type, drop_amount)
        Place as ground item on a nearby passable tile
```

**Scatter placement:** Dropped items are placed on passable tiles adjacent to the
death location. **Multiple ground items can pile on the same tile** — no
one-item-per-tile limit. If few passable neighbors exist, items pile up. The
`_ground_items` array supports multiple entries with the same coords, and auto-pickup
iterates all matching entries for a tile. Items dropped on non-visible tiles are
still recoverable when revealed.

#### Ground Items — Transient Pickups

Separate from `ResourceNode` (which are tile properties from worldgen). Ground items
are transient drops from death that persist until picked up.

```gdscript
# Managed by SurvivalSystem or a shared GroundItems list
var _ground_items: Array[Dictionary] = []
# Each entry:
# { "type": StringName, "amount": int, "coords": Vector2i }
```

**Auto-pickup on `tile_entered`:** When player enters a tile with ground items,
automatically attempt to pick up each item via `Inventory.add_item()`. If inventory
fills mid-collection, remaining items stay on the ground. Player can return later
with space. No manual tap required — walking over items picks them up.

**Partial pickup:** `add_item` returns amount actually added. If less than the ground
item's amount, reduce the ground item entry by the added amount. Entry removed only
when fully picked up.

#### Respawn Point

```gdscript
var _respawn_tile: Vector2i  # Shelter coords if built, else Crash Site (0,0)
```

Updates on:
- `structure_placed` with type `&"shelter"` → `_respawn_tile = coords`
- `structure_destroyed` with type `&"shelter"` → revert to Crash Site (or another
  Shelter if multiple exist — scan HexGrid for remaining shelters)

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

`is_dead` is not saved — player always loads alive. If death occurred, respawn
completed before the next save (auto-save at dawn).

#### Cross-Feature Dependencies

| What | Source |
|------|--------|
| `item_used` signal (consumable consumed) | feature-004 (inventory) |
| `is_daytime` for HP regen condition | feature-007 (day/night) |
| `structure_placed`/`destroyed` for Shelter respawn | feature-008 via HexGrid |
| `tile_entered` for ground item auto-pickup | feature-002 via HexGrid |
| `fauna_attacked_player` for external HP damage (`take_damage`) | feature-008 (FaunaManager) |
| `fauna_killed` for meat ground item creation | feature-008 (FaunaManager) |

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

`stat_changed` emits every frame for smooth HUD bar updates. At 3 listeners this
is negligible.

#### Consume Flow

```
Inventory emits item_used(&"berries")
  │
  ├─ SurvivalSystem receives signal
  │
  ├─ Look up CONSUMABLE_CONFIG[&"berries"]
  │     ✗ Not found → ignore (not a stat consumable)
  │
  ├─ Apply effects:
  │     hunger = min(hunger_max, hunger + config.hunger)  → +15.0
  │     thirst = min(thirst_max, thirst + config.thirst)  → +5.0
  │
  ├─ Emit stat_changed for each affected stat
  └─ Done
```

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
  │         Pick a passable neighbor of death tile (round-robin through neighbors,
  │           items pile on same tile if few neighbors available)
  │         _ground_items.append({ coords, type, amount })
  │         Emit ground_item_dropped(coords, type, amount)
  │     Tool slots untouched.
  │
  ├─ Fade to black (~1-2s):
  │     ScreenFade.fade_out()
  │     On fade complete:
  │       Teleport player + reset stats (respawn flow below)
  │       if DayNightCycle.is_daytime:
  │         ScreenFade.fade_in() → player "wakes up" at respawn point
  │       else:
  │         Stay black until dawn signal → then ScreenFade.fade_in()
  │
  └─ Continue to respawn flow
```

#### Respawn Flow

```
Respawn triggers (immediate or at dawn):
  │
  ├─ Teleport player to _respawn_tile:
  │     Player.current_tile = _respawn_tile
  │     Player.position = HexGrid.axial_to_world(_respawn_tile) + elevation Y
  │     Emit HexGrid.tile_entered(_respawn_tile)
  │
  ├─ Reset stats:
  │     hp = hp_max             → full HP
  │     hunger = hunger_max * 0.5  → 50% (urgency remains)
  │     thirst = thirst_max * 0.5  → 50%
  │
  ├─ Set is_dead = false
  ├─ Emit player_respawned(_respawn_tile)
  └─ Done
```

**Day counter unaffected (F11).** Death does not reset the day count.

#### Ground Item Auto-Pickup

```
HexGrid emits tile_entered(coords)
  │
  ├─ SurvivalSystem checks _ground_items for entries matching coords
  │
  ├─ For each matching entry:
  │     added = Inventory.add_item(item.type, item.amount)
  │     if added == item.amount:
  │       Remove entry from _ground_items
  │       Emit ground_item_picked_up(coords, type, amount)
  │     elif added > 0:
  │       item.amount -= added (partial pickup, entry stays)
  │       Emit ground_item_picked_up(coords, type, added)
  │     else:
  │       Skip (inventory full, item stays on ground)
  │
  └─ Done
```

No tap required. All ground items on a tile are attempted together. Partial
pickup supported — remainder stays until player returns with space.

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)                             [existing]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ResourceRenderer (Node3D)             [feature-003]
       ├─ GroundItemRenderer (Node3D)           ← NEW (MultiMesh for dropped items)
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    ├─ GatherSystem (Node)              [feature-003]
       │    ├─ CraftingSystem (Node)            [feature-005]
       │    └─ SurvivalSystem (Node)            ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               [feature-003]
  └─ HUD (CanvasLayer)                          [feature-004]
       ├─ StatBars (HBoxContainer)              ← NEW (top of screen)
       │    ├─ HPBar (ProgressBar)
       │    ├─ HungerBar (ProgressBar)
       │    └─ ThirstBar (ProgressBar)
       ├─ InventoryButton (TextureButton)       [feature-004]
       ├─ CraftButton (TextureButton)           [feature-005]
       ├─ InventoryPanel (PanelContainer)       [feature-004]
       └─ CraftingPanel (PanelContainer)        [feature-005]
  └─ ScreenFade (CanvasLayer)                    ← NEW (above HUD, reusable fade transition)
       └─ FadeRect (ColorRect)                  ← full-screen black, alpha-tweened
```

#### File Structure

```
scripts/
  survival/
    survival_system.gd         # Node (child of Player) — stat tick, consume, death/respawn,
                                #   ground items, respawn point tracking
    ground_item_renderer.gd    # Node3D — MultiMesh for ground item visuals on tiles

scenes/
  world/
    ground_item_renderer.tscn  # Scene — single MultiMeshInstance3D for loot markers

ui/
  stat_bars.gd                 # Control — 3 ProgressBars, listens to stat_changed
  screen_fade.gd               # CanvasLayer — reusable fade-to-black transition
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `survival_system.gd` | Child Node of Player. Stat tick, consume handler, death/respawn flow, `_ground_items` management, auto-pickup on `tile_entered`, `_respawn_tile` tracking. | `Inventory` (add/remove_item, item_used), `HexGrid` (tile queries, signals), `DayNightCycle` (is_daytime, dawn) |
| `stat_bars.gd` | HBoxContainer with 3 ProgressBars at top of HUD. Listens to `stat_changed`, updates bar values + colors (green → yellow → red). | `SurvivalSystem` (stat_changed) |
| `screen_fade.gd` | CanvasLayer above HUD. Full-screen ColorRect with alpha tween. `fade_out()` → black, `fade_in()` → transparent. Reusable for death, save/load, scene transitions. | `SurvivalSystem` (death trigger), future features |
| `ground_item_renderer.gd` | Node3D under World. Single `MultiMeshInstance3D` with loot marker mesh (~10 max instances, 1 draw call). Updates on drop/pickup signals. | `SurvivalSystem` (ground_item_dropped, ground_item_picked_up) |

#### Signal Wiring

```
Inventory signals                        survival_system.gd
  item_used(type)                    ──►  apply consumable effect

HexGrid signals                          survival_system.gd
  tile_entered(coords)               ──►  auto-pickup ground items
  structure_placed(coords, type)     ──►  update _respawn_tile if shelter
  structure_destroyed(coords, type)  ──►  revert _respawn_tile if shelter lost

DayNightCycle (feature-007)              survival_system.gd
  is_daytime property                ──►  HP regen condition (read per frame)
  dawn signal                        ──►  deferred respawn trigger

FaunaManager (feature-008)               survival_system.gd
  fauna_attacked_player(id, damage)  ──►  take_damage(damage)
  fauna_killed(id, coords)           ──►  create meat ground item on fauna death tile

survival_system.gd                       stat_bars.gd
  stat_changed(name, current, max)   ──►  update ProgressBar value + color

survival_system.gd                       screen_fade.gd
  player_died()                      ──►  fade_out (1-2s to black)
  player_respawned(coords)           ──►  fade_in (if daytime; else wait for dawn)

survival_system.gd                       ground_item_renderer.gd
  ground_item_dropped(coords, ...)   ──►  add loot marker instance
  ground_item_picked_up(coords, ...) ──►  remove/update marker instance
```

#### Ground Item Rendering

Single `MultiMeshInstance3D` with a loot marker mesh (glowing circle or small icon).
Max ~10 instances (generous upper bound for death drops). One draw call — consistent
with the project's MultiMesh pattern.

Updated only on `ground_item_dropped` / `ground_item_picked_up` signals. No per-frame
work. Instance visibility follows tile fog state — marker hidden if tile is HIDDEN.

### UI Specs

#### Stat Bars — Layout (Portrait 1080×1920)

```
┌──────────────────────────┐
│ [♥ ████████░░]           │  ← HP bar (top-left)
│ [🍖 █████░░░░]           │  ← Hunger bar
│ [💧 ████░░░░░]           │  ← Thirst bar
│              Day 7 ☀     │  ← future (feature-007, top-right)
│                          │
│      (game world)        │
│                          │
│              [Inv][Build]│  ← HUD buttons (bottom-right)
└──────────────────────────┘
```

#### Stat Bar Design

- **Position:** Top-left, stacked vertically (HP top, Hunger middle, Thirst bottom)
- **Size:** ~200px wide × 20px tall each. Compact — doesn't dominate the screen.
- **Style:** Filled `ProgressBar` with color gradient per stat:
  - **HP:** green (>50%) → yellow (25–50%) → red (<25%)
  - **Hunger:** green (>50%) → yellow (25–50%) → red (<25%)
  - **Thirst:** blue (>50%) → yellow (25–50%) → red (<25%)
- **Label:** Small icon prefix per bar to identify stat. No numeric value — bar fill
  communicates urgency visually.
- **Background:** Translucent — bars don't obscure the game world.
- **Update:** Driven by `stat_changed` signal. Bar value tweens smoothly to new value
  (Godot ProgressBar `value` property + short tween, not instant snap).
- **Touch interaction:** None. `mouse_filter = IGNORE` — touches pass through to game.

#### Death Transition — Fade to Black

No text overlay, no "YOU DIED" screen. Death is a smooth cinematic fade:

```
HP hits 0
  │
  ├─ Screen fades to black (~1-2s, ColorRect alpha 0→1)
  │
  ├─ While black (player can't see):
  │     Teleport to respawn tile
  │     Reset stats
  │     Drop items on ground
  │
  ├─ If daytime: fade back in (~1-2s, alpha 1→0)
  │   Player "wakes up" at shelter/crash site
  │
  └─ If nighttime: screen stays black until dawn
      Dawn signal → fade in (~1-2s)
      Player "wakes up" at dawn
```

**screen_fade.gd** — reusable CanvasLayer with full-screen ColorRect:

```gdscript
# Public API
func fade_out(duration: float = 1.5) -> void   # alpha 0 → 1
func fade_in(duration: float = 1.5) -> void    # alpha 1 → 0
signal fade_out_completed()
signal fade_in_completed()  # available for future use (no current consumer)
```

Reusable for death, save/load transitions, scene changes. Not death-specific.

#### Touch Targets

No interactive elements in stat bars or death fade. No touch target concerns.
Stat bars use `mouse_filter = IGNORE`. Fade ColorRect blocks input while
fully opaque (prevents tapping during transition).
