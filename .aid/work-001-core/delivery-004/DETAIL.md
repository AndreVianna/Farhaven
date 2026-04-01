# delivery-004: Time and Consequence — Day/Night + Survival

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-008-day-night-cycle, feature-007-survival-stats
**Depends on:** delivery-001 (001-008), delivery-002 (009-015), delivery-003 (016-023)
**Cumulative state:** Day/night rhythm, hunger/thirst/HP, death/respawn, auto-save

## Execution Graph

```
task-024 (DayNightCycle — phase timer + signals)
  │
  ├──────────────────────────────┐
  ▼                              ▼
task-025 (DayNightCycle          task-028 (SurvivalSystem —
  lighting + visibility +          stat tick, consume,
  day counter wiring)              take_damage)
  │                              │
  ▼                              ▼
task-026 (SaveManager            task-029 (SurvivalSystem —
  autoload)                       death, respawn, ground
  │                               items, ScreenFade)
  │                              │
  ▼                              ▼
task-027 (DayNight +             task-030 (GroundItemRenderer
  Save integration test)          + stat bars wiring)
  │                              │
  └──────────────┬───────────────┘
                 ▼
           task-031 (Survival integration test)
```

**Parallel groups:**
- task-025 ∥ task-028: lighting/visibility and survival tick both depend only on task-024
- task-027 ∥ task-029, task-030: day/night tests run while survival death/render are built

**Scope overlap prevention:** Delivery-001 task-005 already creates `stat_bars.gd` and
`day_counter.gd` as shell components. This delivery wires signal sources to those
existing shells — does NOT recreate them.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 024 | DayNightCycle — phase timer + signals | IMPLEMENT | delivery-003 | -- |
| 025 | DayNightCycle — lighting, visibility, day counter wiring | IMPLEMENT | 024 | 028 |
| 026 | SaveManager autoload | IMPLEMENT | 024 | 028, 029 |
| 027 | DayNight + Save integration test | TEST | 025, 026 | 029, 030 |
| 028 | SurvivalSystem — stat tick, consume, take_damage | IMPLEMENT | 024 | 025 |
| 029 | SurvivalSystem — death, respawn, ground items, ScreenFade | IMPLEMENT | 028 | 027 |
| 030 | GroundItemRenderer + stat bars wiring | IMPLEMENT | 029 | 027 |
| 031 | Survival integration test | TEST | all above | -- |

## Task Details

### task-024: DayNightCycle — Phase Timer + Signals [IMPLEMENT]

**Source:** feature-008 → Data Model + Feature Flow (phase timer)

**Scope:**
- `scripts/day_night/day_night_cycle.gd` — autoload Node:
  - `TimePhase` enum: DAY, DUSK, NIGHT, DAWN
  - Properties: `current_phase`, `phase_elapsed`, `day_count`, `is_daytime`
  - `PHASE_DURATIONS`: DAY 180s, DUSK 30s, NIGHT 90s, DAWN 10s (total ~310s)
  - `VISIBILITY_RADIUS`: DAY=2, DUSK=2, NIGHT=1, DAWN=2
  - `TORCH_VISIBILITY_RADIUS = 2`
  - Phase timer in `_process`: increment elapsed, transition on exceeded
  - 4 transitions: DAY→DUSK (is_daytime=false), DUSK→NIGHT, NIGHT→DAWN (day_count++,
    is_daytime=true), DAWN→DAY
  - 5 signals: `phase_changed`, `dawn`, `dusk`, `night`, `day_started`
  - `get_save_data()` / `load_save_data()` (day_count, phase, phase_elapsed, chapter_id)
  - Register as autoload in Project Settings
  - No lighting, no visibility refresh, no torch tracking yet

**Criteria:**
- [ ] Phase timer cycles through all 4 phases in correct order
- [ ] Signals emit at correct transitions (dusk on DAY→DUSK, night on DUSK→NIGHT, etc.)
- [ ] `is_daytime` true during DAY/DAWN, false during DUSK/NIGHT
- [ ] `day_count` increments on NIGHT→DAWN
- [ ] Full cycle ~310s (within ±1s tolerance in unit test)
- [ ] Save/load round-trip: day_count, phase, phase_elapsed preserved
- [ ] Unit tests for all transition paths
- [ ] Build passes with zero warnings

---

### task-025: DayNightCycle — Lighting, Visibility, Day Counter Wiring [IMPLEMENT]

**Source:** feature-008 → Data Model (lighting) + Feature Flow (visibility refresh)

**Scope:**
- Add to `day_night_cycle.gd`:
  - `register_lighting(env, sun)` API + null-safe tween guard
  - Lighting values per phase (warm palette from SPEC: warm white, orange, warm purple, peach)
  - Tween-based transitions over phase duration
  - `_torch_tiles: Array[Vector2i]` — updated on `structure_placed`/`destroyed` for torches
  - Centralized `refresh_visibility` calls on 3 triggers:
    1. `tile_entered` → build sources (player + torches if NIGHT)
    2. Phase transition (DUSK→NIGHT, NIGHT→DAWN) → radius change
    3. Torch placed/destroyed during NIGHT → rebuild sources
  - Torch sources added only during NIGHT (other phases radius already 2)
- Create `world.gd` on World Node3D: calls `DayNightCycle.register_lighting()` in `_ready()`
- Add WorldEnvironment + DirectionalLight3D to World scene
- **Wire DayNightCycle signals to existing `day_counter.gd` from delivery-001:**
  Connect `day_started` → update day number label.
  Connect `phase_changed` → update phase icon color/shape.
  (day_counter.gd already exists — just connect the signals, don't recreate)

**Criteria:**
- [ ] Lighting tweens to correct warm values per phase (SPEC table)
- [ ] No errors when lighting not registered (headless/test safe)
- [ ] Visibility radius: 2 during DAY/DUSK/DAWN, 1 during NIGHT
- [ ] Torch tiles extend NIGHT visibility to radius 2
- [ ] `refresh_visibility` called on tile_entered, phase change, torch change
- [ ] Torch sources only added during NIGHT phase
- [ ] DayCounter label updates on `day_started`
- [ ] DayCounter phase icon updates on `phase_changed`
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-026: SaveManager Autoload [IMPLEMENT]

**Source:** feature-008 → Feature Flow (save/load)

**Scope:**
- `scripts/save/save_manager.gd` — autoload Node:
  - Listens to `DayNightCycle.day_started` → auto-save
  - Collects `get_save_data()` from all available systems:
    HexGrid, Player, Inventory, CraftingSystem, Catalog/ScannerSystem, DayNightCycle,
    SurvivalSystem (this delivery), JournalSystem (future — graceful skip)
  - Writes `user://save.json` via FileAccess
  - Load flow: detect file → parse JSON → distribute via `load_save_data()`
  - Corrupt/missing save → delete, start fresh (no crash)
  - Single save slot
  - Missing systems handled gracefully (skip with no error)
- Register as autoload in Project Settings

**Criteria:**
- [ ] Auto-save triggers on `day_started` signal
- [ ] Save file: valid JSON with all available system data
- [ ] Load restores all system state correctly
- [ ] Missing save → new game (no crash)
- [ ] Corrupt save → deleted, new game (no crash)
- [ ] Missing systems in save data → defaults (no crash)
- [ ] Missing systems at runtime → skipped (no crash)
- [ ] Unit tests: save/load round-trip, corrupt handling, missing system handling
- [ ] Build passes with zero warnings

---

### task-027: DayNight + Save Integration Test [TEST]

**Source:** AC7 + AC10

**Scope:**
- Full phase cycle timing (5 min ±15s)
- Visibility changes across phase transitions
- Torch visibility during NIGHT
- Save at dawn, load mid-phase, resume correctly
- Corrupt save → fresh start
- All AC7 criteria
- AC10 criteria for DayNightCycle + available system data

**Criteria:**
- [ ] Full cycle: ~310s (within AC7 5 min ±15s tolerance)
- [ ] Dusk warning: phase change + lighting tween at correct time
- [ ] Night visibility: radius 1 confirmed
- [ ] Torch: extends to radius 2 during NIGHT
- [ ] Save/load round-trip preserves all state
- [ ] Corrupt save handled gracefully
- [ ] AC7 fully covered
- [ ] AC10 covered for available systems
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass

---

### task-028: SurvivalSystem — Stat Tick, Consume, Take Damage [IMPLEMENT]

**Source:** feature-007 → Data Model + Feature Flow (stat tick, consume)

**Scope:**
- `scripts/survival/survival_system.gd` — Node (child of Player):
  - Properties: hp, hunger, thirst (floats, 100.0 max), hp_max, hunger_max, thirst_max, is_dead
  - `STAT_CONFIG`: hunger_rate 1.0, thirst_rate 1.5, hp_drain_no_hunger 2.0,
    hp_drain_no_thirst 3.0, hp_regen_day 0.5
  - `CONSUMABLE_CONFIG`: berries (hunger 15, thirst 5, toxic 0),
    toxic_berries (hunger 10, thirst 0, toxic 25), meat (hunger 25, thirst 0, toxic 0)
  - `_process` tick: deplete hunger/thirst, HP drain stacking, HP regen (daytime + fed),
    clamp, emit `stat_changed`, death check
  - Consume flow: on `Inventory.item_used` → lookup CONSUMABLE_CONFIG → apply restore →
    apply toxic_damage via `take_damage` if > 0
  - `take_damage(amount: float)`: reduce HP, emit stat_changed, trigger death check
  - `stat_changed(stat_name, current, max_val)` signal every frame
  - `is_dead` gates tick (no processing while dead)
  - Read `DayNightCycle.is_daytime` for regen condition

**Criteria:**
- [ ] Hunger depletes at 1.0/sec, thirst at 1.5/sec
- [ ] HP drains: 2.0/sec hunger=0, 3.0/sec thirst=0, 5.0/sec both
- [ ] HP regens 0.5/sec during daytime when hunger>0 AND thirst>0
- [ ] No regen at night or when starving
- [ ] Berries: hunger +15, thirst +5
- [ ] Toxic berries: hunger +10, toxic 25 HP damage
- [ ] Meat: hunger +25
- [ ] `take_damage` reduces HP, emits stat_changed
- [ ] `stat_changed` emits every frame (3 stats)
- [ ] No processing when `is_dead`
- [ ] Unit tests for all depletion/drain/regen/consume paths
- [ ] Build passes with zero warnings

---

### task-029: SurvivalSystem — Death, Respawn, Ground Items, ScreenFade [IMPLEMENT]

**Source:** feature-007 → Feature Flow (death, respawn, ground items) + Layers & Components (ScreenFade)

**Scope:**
- Extend `survival_system.gd`:
  - Death: hp≤0 → is_dead=true, emit `player_died`, drop 50% each stack (floor, tools safe),
    items pile on passable neighbors
  - Respawn: teleport to `_respawn_tile`, HP=100, hunger=50, thirst=50, is_dead=false,
    emit `player_respawned`
  - `_respawn_tile`: default (0,0), updates on shelter `structure_placed`/`destroyed`
  - Night death: connect to `DayNightCycle.dawn` → deferred respawn
  - `_ground_items: Array[Dictionary]` + public API:
    `get_ground_items_at`, `remove_ground_item`, `add_ground_item`
  - Fauna meat: connect to `fauna_killed` signal (stub — activates when F-010 arrives)
  - Signals: `player_died`, `player_respawned`, `ground_item_dropped`, `ground_item_picked_up`
  - `get_save_data()` / `load_save_data()` for stats + ground items (is_dead not saved)
- `ui/screen_fade.gd` — CanvasLayer (layer 30) with ColorRect:
  - `fade_out(duration: float = 1.5)` → alpha 0→1
  - `fade_in(duration: float = 1.5)` → alpha 1→0
  - `flash(color: Color, duration: float = 0.2)` → brief pulse
  - Signals: `fade_out_completed`, `fade_in_completed`
- Wire death: fade_out → teleport+reset while black → fade_in (day) or wait dawn (night)

**Criteria:**
- [ ] Death at hp≤0: is_dead, 50% each stack dropped (floor), tools safe
- [ ] Items pile on passable neighbors (multiple entries same tile OK)
- [ ] Respawn: teleport to _respawn_tile, stats 100/50/50
- [ ] _respawn_tile updates on shelter placed/destroyed
- [ ] Night death: deferred to dawn
- [ ] ScreenFade: fade_out, fade_in, flash all work with correct alpha tweens
- [ ] Death sequence: fade_out → teleport → fade_in (day) or wait dawn → fade_in (night)
- [ ] Ground items CRUD API works
- [ ] Fauna meat: stub connection (no crash when F-010 absent)
- [ ] Save/load round-trip: stats + ground items preserved, is_dead always false on load
- [ ] Unit tests: drop calc, respawn stats, ground item CRUD, fade signals
- [ ] Build passes with zero warnings

---

### task-030: GroundItemRenderer + Stat Bars Wiring [IMPLEMENT]

**Source:** feature-007 → Layers & Components (GroundItemRenderer, stat bars signal source)

**Scope:**
- `scripts/survival/ground_item_renderer.gd` — Node3D:
  - Single MultiMeshInstance3D, ~10 max instances, 1 draw call
  - Placeholder loot marker mesh (glowing circle or icon)
  - On `ground_item_dropped`: add instance at tile world position
  - On `ground_item_picked_up`: remove/update instance
  - Fog-aware: hidden if tile HIDDEN
- `scenes/world/ground_item_renderer.tscn`
- **Wire SurvivalSystem.stat_changed to existing `stat_bars.gd` from delivery-001:**
  Connect signal → stat bars update values + colors.
  (stat_bars.gd already exists with ProgressBars + gradients — just connect the signal
  source, don't recreate)

**Criteria:**
- [ ] Ground item markers appear on drop, disappear on full pickup
- [ ] Partial pickup: marker stays until all items collected
- [ ] Fog-aware (HIDDEN tiles: markers not visible)
- [ ] Draw calls: 1 (single MultiMesh)
- [ ] Stat bars update on `stat_changed` signal (HP, Hunger, Thirst)
- [ ] Stat bar colors change at correct thresholds (>50% green, 25-50% yellow, <25% red)
- [ ] Stat bar values tween smoothly
- [ ] Build passes with zero warnings

---

### task-031: Survival Integration Test [TEST]

**Source:** AC8

**Scope:**
- Full survival lifecycle:
  - Stat depletion over time
  - HP drain when starving/dehydrated
  - HP regen during daytime when fed
  - Consume berries → hunger restore
  - Consume toxic berries → hunger restore + HP damage
  - Death at hp≤0 → fade → respawn with 50% drop
  - Night death deferred to dawn
  - Ground item lifecycle (drop → persist → auto-pickup via F-004 stub)
  - Save/load round-trip for survival data
- All AC8 criteria
- ScreenFade verified (fade_out, fade_in, flash)
- Stat bars reflect live values

**Criteria:**
- [ ] AC8 fully covered: 3 bars visible, hunger 0→HP drain, eat berries→restore,
      all stats 0→death→respawn with 50% drop
- [ ] Depletion rates match STAT_CONFIG
- [ ] Toxic berries: hunger +10, HP -25
- [ ] Night death deferred to dawn verified
- [ ] Ground items: created on death, persist, auto-pickup (F-004 stub)
- [ ] Save/load round-trip for stats + ground items
- [ ] ScreenFade: fade_out/fade_in/flash all verified
- [ ] Stat bars update in real-time
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-003):
- World
  - WorldEnvironment (Node3D) — lighting palette (existing, now wired)
  - DirectionalLight3D — warm tones (existing, now wired to phase)
  - GroundItemRenderer (Node3D) — NEW, 1 MultiMesh for death drops
- DayNightCycle (autoload) — NEW
- SaveManager (autoload) — NEW
- Player
  - SurvivalSystem (Node) — NEW

### Bootstrap Changes
- DayNightCycle autoload starts phase timer on _ready() (DAY first, 180s)
- DayNightCycle takes ownership of ALL refresh_visibility calls — **remove Player's direct call from delivery-001**
- DayNightCycle.register_lighting() called by Main to wire WorldEnvironment + DirectionalLight3D
- SurvivalSystem._ready() → connects to DayNightCycle phase signals for HP regen rules
- SaveManager._ready() → connects to DayNightCycle.day_started for auto-save
- StatBars (delivery-001 shell) wired to SurvivalSystem signals
- DayCounter (delivery-001 shell) wired to DayNightCycle signals

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-003 still works
- [ ] Day/night cycle visible: lighting changes color over ~5 minutes (warm day → purple/plum night)
- [ ] Day counter increments
- [ ] Stat bars animate: hunger/thirst slowly decrease
- [ ] Night: visibility radius shrinks to 1 hex
- [ ] Dawn: visibility expands back to 2 hexes
- [ ] Eat berries → hunger bar increases
- [ ] Die (let stats drain) → fade to black → respawn at crash site → 50% items dropped on ground
- [ ] Close and reopen → save loaded, state preserved

### Dev Environment
No additional requirements beyond delivery-001.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (024-031). DayCounter and StatBars wired to existing shells from delivery-001. | /aid-detail |
