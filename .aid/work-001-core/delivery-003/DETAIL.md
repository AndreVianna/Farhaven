# delivery-003: Day/Night + Building & Threats

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-007-day-night-cycle, feature-008-building-threats
**Depends on:** delivery-001 (tasks 001-008), delivery-002 (tasks 009-016)
**Cumulative state:** Survive the night

## Execution Graph

```
task-017 (DayNightCycle autoload — phase timer)
  │
  ├──────────────────┬──────────────────┐
  ▼                  ▼                  ▼
task-020           task-021           task-022
(Lighting)         (Day counter HUD)  (SaveManager)
  │                  │                  │
  └──────┬───────────┴──────────────────┘
         │
         ▼
task-018 (refresh_visibility multi-source)
  │
  ▼
task-019 (DayNightCycle visibility integration)
  │
  ▼
task-023 (DayNightCycle + SaveManager tests)
  │
  ▼
task-024 (BuildingSystem — placement + validation)
  │
  ▼
task-025 (StructureRenderer + highlight API)
  │
  ▼
task-026 (FaunaManager — spawn, AI, contact damage, despawn)
  │
  ▼
task-027 (Combat system — player attack, weapon, kill)
  │
  ├──────────────────┐
  ▼                  ▼
task-028           task-029
(FaunaRenderer +   (BuildPanel UI +
 combat feedback)   placement label)
  │                  │
  └──────┬───────────┘
         ▼
task-030 (Building & Threats integration tests)
```

**Parallel groups:**
- task-020 + task-021 + task-022: all depend only on task-017. Lighting, day counter HUD, and SaveManager are independent.
- task-028 + task-029: renderer/feedback (world-space) and UI panel (screen-space) are independent.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 017 | DayNightCycle autoload — phase timer | IMPLEMENT | delivery-001 | -- |
| 018 | refresh_visibility multi-source on HexGrid | IMPLEMENT | delivery-001 | -- |
| 019 | DayNightCycle visibility integration | IMPLEMENT | 017, 018 | -- |
| 020 | Lighting registration + phase tweens | IMPLEMENT | 017 | 021, 022 |
| 021 | DayCounter HUD element | IMPLEMENT | 017 | 020, 022 |
| 022 | SaveManager autoload | IMPLEMENT | 017 | 020, 021 |
| 023 | DayNightCycle + SaveManager tests | TEST | 017-022 | -- |
| 024 | BuildingSystem — placement + validation | IMPLEMENT | 018 | -- |
| 025 | StructureRenderer + highlight API | IMPLEMENT | 024 | -- |
| 026 | FaunaManager — spawn, AI, contact damage, despawn | IMPLEMENT | 017, 019, 024 | -- |
| 027 | Combat system — player attack, weapon, kill | IMPLEMENT | 026 | -- |
| 028 | FaunaRenderer + combat/damage feedback | IMPLEMENT | 027 | 029 |
| 029 | BuildPanel UI + placement mode label | IMPLEMENT | 024, 025 | 028 |
| 030 | Building & Threats integration tests | TEST | 024-029 | -- |

## Task Details

### task-017: DayNightCycle autoload — phase timer and transitions [IMPLEMENT]

**Scope:** Create `scripts/day_night/day_night_cycle.gd` as autoload Node. Phase clock
and signals only — no visibility, no lighting, no torch tracking.

**Implements:**
- `TimePhase` enum: `DAY, DUSK, NIGHT, DAWN`
- Phase timer in `_process`: `phase_elapsed += delta`, transition on duration exceeded
- `PHASE_DURATIONS` config: DAY 180s, DUSK 30s, NIGHT 90s, DAWN 10s (total ~310s)
- `is_daytime` derived: true during DAY/DAWN, false during DUSK/NIGHT
- `day_count` increments on NIGHT→DAWN
- All signals: `phase_changed(phase)`, `dawn()`, `dusk()`, `night()`, `day_started(day_count)`
- `get_save_data()` / `load_save_data()` for phase + elapsed + day_count
- Register as autoload in Project Settings

**Criteria:**
- [ ] All 4 phase transitions fire correct signals in correct order
- [ ] Full cycle completes in ~310s (±1s tolerance)
- [ ] `is_daytime` true during DAY/DAWN, false during DUSK/NIGHT
- [ ] `day_count` increments on NIGHT→DAWN transition
- [ ] Save/load preserves phase, elapsed time, day_count
- [ ] Unit tests for all transitions and timing
- [ ] Build passes with zero warnings

---

### task-018: refresh_visibility multi-source on HexGrid [IMPLEMENT]

**Scope:** Update `HexGrid.refresh_visibility()` to handle multiple visibility sources.
This was defined in feature-007 SPEC as a feature-001 API amendment.

**Implements:**
- `refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]`
- Algorithm: demote all VISIBLE→REVEALED, then promote per source within radius
- Each source: `{ "coords": Vector2i, "radius": int }`
- Emits `tile_revealed` for HIDDEN→VISIBLE, `tile_visibility_changed` for all transitions
- Returns newly revealed tiles

**Note:** If delivery-001 already implemented this (task-003 specified it), this task
verifies and adds multi-source test coverage. If not yet implemented, implement now.

**Criteria:**
- [ ] Single source works (player only, radius 2)
- [ ] Multiple sources work (player radius 1 + torch radius 2)
- [ ] Overlapping radii don't cause double-processing
- [ ] HIDDEN→VISIBLE emits `tile_revealed`
- [ ] VISIBLE→REVEALED and REVEALED→VISIBLE emit `tile_visibility_changed`
- [ ] Existing delivery-001 tests still pass
- [ ] Unit tests for single, multi, and overlapping sources
- [ ] Build passes with zero warnings

---

### task-019: DayNightCycle visibility integration [IMPLEMENT]

**Scope:** Wire DayNightCycle to own all `refresh_visibility` calls.

**Implements:**
- Connect to `HexGrid.tile_entered` — build sources and call `refresh_visibility`
- Visibility radius per phase: DAY=2, DUSK=2, NIGHT=1, DAWN=2
- `_torch_tiles: Array[Vector2i]` — updated on `structure_placed`/`structure_destroyed`
  for `&"torch"` type
- Torch sources included **only during NIGHT** (radius 2 already covers everything
  during DAY/DUSK/DAWN — adding torches would have zero effect)
- Phase transitions DUSK→NIGHT and NIGHT→DAWN trigger `refresh_visibility` (radius change)
- DAY→DUSK and DAWN→DAY do not trigger refresh (radius unchanged)
- Torch placed/destroyed during NIGHT triggers refresh; during other phases, no-op
- Movement (feature-002) no longer calls fog directly — DayNightCycle reacts to `tile_entered`

**Criteria:**
- [ ] Player movement triggers visibility refresh with phase-appropriate radius
- [ ] DUSK→NIGHT shrinks visibility to radius 1 + torch sources
- [ ] NIGHT→DAWN expands to radius 2 (no torch sources)
- [ ] Torch placed during NIGHT triggers refresh with torch as source
- [ ] Torch placed during DAY tracked but no refresh triggered
- [ ] Unit tests for radius per phase and torch inclusion rules
- [ ] Build passes with zero warnings

---

### task-020: Lighting registration + phase tweens [IMPLEMENT]

**Scope:** Visual lighting changes per phase.

**Implements:**
- `register_lighting(env: WorldEnvironment, sun: DirectionalLight3D)` on DayNightCycle
- World scene script (`world.gd`) calls `register_lighting()` in `_ready()`
- Add WorldEnvironment + DirectionalLight3D to World scene tree
- Tween-based transitions per SPEC lighting values table:
  DAY: ambient 1.0, sun 1.0, warm white, no tint
  DUSK: ambient 0.7, sun 0.6, orange, amber overlay
  NIGHT: ambient 0.2, sun 0.05, cool blue, dark blue tint
  DAWN: ambient 0.7→1.0, sun 0.5→1.0, orange→white, amber→none
- Null-check before tweening (headless/test safe)

**Criteria:**
- [ ] `register_lighting` stores references correctly
- [ ] Phase transitions tween lighting values per SPEC table
- [ ] If lighting not registered, transitions fire signals with no errors
- [ ] Tweens interpolate smoothly over phase duration
- [ ] Zero draw call impact (WorldEnvironment + DirectionalLight3D are scene-wide)
- [ ] Build passes with zero warnings

**Parallel with:** task-021, task-022

---

### task-021: DayCounter HUD element [IMPLEMENT]

**Scope:** Create day counter + phase icon in HUD top-right.

**Files:** `ui/day_counter.gd` — HBoxContainer in HUD CanvasLayer

**Implements:**
- "DAY 01" label: zero-padded, uppercase, `"DAY %02d" % day_count`
- Font: Space Grotesk, uppercase, tracking-widest, ~24px
- White text with 1px dark outline (no drop shadow — Tactical Brutalism)
- Semi-transparent background panel
- Phase icon: 32×32px colored circle/crescent per phase
  - DAY: primary (#a8e8ff), DUSK: warning/amber, NIGHT: outline-variant (dimmed), DAWN: primary at 60%
- Updates on `day_started` (day number) and `phase_changed` (icon)
- `mouse_filter = IGNORE` — display only

**Criteria:**
- [ ] Displays "DAY 01" at game start
- [ ] Updates to "DAY 02" on first dawn
- [ ] Phase icon changes per transition using design system palette
- [ ] No touch interaction (`mouse_filter = IGNORE`)
- [ ] Anchored top-right of HUD
- [ ] Space Grotesk font, uppercase, 1px outline, no drop shadow
- [ ] Build passes with zero warnings

**Parallel with:** task-020, task-022

---

### task-022: SaveManager autoload [IMPLEMENT]

**Scope:** Create `scripts/save/save_manager.gd` as autoload Node.

**Implements:**
- Listens to `DayNightCycle.day_started` for auto-save trigger
- `_save()`: collects `get_save_data()` from all systems (HexGrid, Player, Inventory,
  DayNightCycle — SurvivalSystem + CraftingSystem stubs for future deliveries)
- Writes `user://save.json` via `FileAccess`
- `_load()`: on `_ready()` or Main init, detect file, parse JSON, distribute to systems
- Corrupt file → delete, start fresh (no crash)
- Missing file → new game (worldgen)
- Single save slot: `user://save.json`

**Criteria:**
- [ ] Auto-save triggers on `day_started` signal
- [ ] Save file contains valid JSON with all registered system data
- [ ] Load restores state correctly (round-trip test)
- [ ] Missing save → fresh game without crash
- [ ] Corrupt save → deleted, fresh game without crash
- [ ] DayNightCycle phase, elapsed, day_count survive save/load
- [ ] Unit tests for save/load round-trip, corrupt handling, missing handling
- [ ] Build passes with zero warnings

**Parallel with:** task-020, task-021

---

### task-023: DayNightCycle + SaveManager tests [TEST]

**Scope:** Integration tests for the full day/night + save system.

**Covers:**
- AC7: full cycle 5 min ±15s, dusk warning 30s before night, night visibility 1 hex,
  torch extends to 2 hexes
- AC10: auto-save at dawn, load restores world + player state, corrupt = fresh start
- Visibility changes across phase transitions with player + torch
- Save at dawn, load mid-phase, resume correctly
- Lighting tweens no error in headless mode

**Criteria:**
- [ ] Full cycle timing: ~310s (within AC7 tolerance)
- [ ] Night visibility = 1 hex confirmed
- [ ] Torch extends to 2 hexes confirmed
- [ ] Save/load round-trip preserves all state
- [ ] AC7 and AC10 criteria covered
- [ ] Tests deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

---

### task-024: BuildingSystem — placement validation and build action [IMPLEMENT]

**Scope:** Create `scripts/building/building_system.gd` as child Node of Player.

**Implements:**
- `structure_config` data: 5 structures (Workbench, Storage Chest, Shelter, Wall, Torch)
  with recipes, `blocks_movement`, effect
- **Shelter has `blocks_movement: false`** — player stands on shelter for night protection
- Placement mode: `is_placing` flag, `enter_placement_mode(type)`, `exit_placement_mode()`
- Validation: adjacent, passable, no existing structure, not water/cliff, sufficient materials
- Consume materials: `Inventory.remove_item()` per recipe ingredient
- Place: `HexGrid.get_tile(coords).structure = type`, emit `HexGrid.structure_placed`
- Input priority: lowest `process_priority` (runs first), claims input only when `is_placing`
- Calls `HexGridRenderer.highlight_tiles()` / `clear_highlights()` during placement
- Cancel: tap non-valid area or Build button → exit, no materials consumed
- `blocks_movement` structures disconnect AStar2D edges (Shelter excluded — walkable)

**Criteria:**
- [ ] All 5 structure types placeable on valid tiles
- [ ] Placement rejected: occupied, non-adjacent, water, cliff
- [ ] Materials consumed on successful placement
- [ ] `structure_placed` signal emitted with correct type
- [ ] `blocks_movement: true` structures disconnect AStar2D edges
- [ ] **Shelter has `blocks_movement: false` — player can stand on shelter tile**
- [ ] `is_placing` flag gates input correctly (highest priority when placing)
- [ ] Highlight API called on enter/exit placement mode
- [ ] Cancel exits cleanly — no materials consumed
- [ ] Unit tests for validation logic, material consumption
- [ ] Build passes with zero warnings

---

### task-025: StructureRenderer + HexGridRenderer highlight API [IMPLEMENT]

**Scope:** Visual rendering for structures and tile highlights.

**Files:**
- `scripts/building/structure_renderer.gd` + `scenes/world/structure_renderer.tscn`
  — Node3D with 5 MultiMeshInstance3D children
- Extend `hex_grid_renderer.gd` with highlight API

**Implements:**
- One MultiMeshInstance3D per structure type (5 total, ~5 draw calls)
- On `structure_placed`: add instance at tile world position + elevation Y
- Fog-aware: structure hidden if tile is HIDDEN
- Placeholder meshes: colored boxes/shapes per structure type
- `HexGridRenderer.highlight_tiles(coords: Array[Vector2i], color: Color)` — uses
  instance custom data highlight channel, shader blends color over base
- `HexGridRenderer.clear_highlights()` — resets highlight channel
- Zero additional draw calls for highlights (same MultiMesh instances)

**Criteria:**
- [ ] Structures render at correct tile positions
- [ ] Structures follow tile fog visibility
- [ ] Highlight API highlights specified tiles with given color
- [ ] `clear_highlights()` removes all highlights
- [ ] Draw calls: ~5 for structures (one per type)
- [ ] Build passes with zero warnings

---

### task-026: FaunaManager — spawn, AI movement, contact damage, despawn [IMPLEMENT]

**Scope:** Create `scripts/fauna/fauna_manager.gd` as child Node of Player. Fauna
lifecycle — everything except player-initiated combat.

**Implements:**
- Spawn on `DayNightCycle.night` signal (only if `day_count >= 4`)
- Spawn rules: not VISIBLE, no structure, passable, ≥3 hexes from player
- `randi_range(1, 3)` fauna per night
- `_fauna: Array[Dictionary]` — id, coords, hp, move_cooldown, cooldown_remaining
- AI movement in `_process` (NIGHT only): cooldown tick, detection range 2 hexes,
  move toward player (pick neighbor closest to player), wall avoidance (passability check),
  no fauna stacking on same tile
- Contact damage: after fauna moves, if adjacent to player →
  shelter check (`tile.structure == &"shelter"` → 0 damage), else 10 HP
- Emit `fauna_attacked_player(id, damage)` → SurvivalSystem applies HP loss
- Despawn all on `dawn` signal
- Signals: `fauna_spawned`, `fauna_moved`, `fauna_attacked_player`, `fauna_despawned`

**Contact damage is fauna-move-only (intentional design).** Player approaching fauna
gets a free first strike.

**Criteria:**
- [ ] No fauna spawn before day 4
- [ ] 1-3 fauna spawn at night on day 4+
- [ ] Spawn tiles: not VISIBLE, no structure, passable, ≥3 hexes from player
- [ ] Fauna move toward player within 2 hexes
- [ ] Fauna route around walls (passability check)
- [ ] Contact damage: 10 HP per move cycle when adjacent
- [ ] Shelter protection: 0 damage if player on shelter tile
- [ ] All fauna despawn at dawn
- [ ] Unit tests for spawn rules, movement AI, shelter protection
- [ ] Build passes with zero warnings

---

### task-027: Combat system — player attack, weapon damage, kill [IMPLEMENT]

**Scope:** Player-initiated combat against fauna. Extends FaunaManager or separate
combat handler on Player.

**Implements:**
- Attack trigger: tap adjacent fauna tile (same input pattern as gathering)
- Input priority: fauna attack > gather > movement
- `is_attacking` flag (same pattern as `is_gathering`)
- Weapon lookup: `Inventory.get_tool(&"weapon")` → `WEAPON_DAMAGE` table
  - Survival Knife: 10 damage, bare hands: 5 damage
- Attack cooldown: 1.0s between hits
- Apply damage: `fauna.hp -= damage`
- On kill (`hp <= 0`): remove fauna, emit `fauna_killed(id, coords)`
  → SurvivalSystem listens, creates `&"meat"` ground item on death tile
  (FaunaManager does NOT write to SurvivalSystem._ground_items)

**Criteria:**
- [ ] Tap adjacent fauna tile triggers attack
- [ ] Survival Knife: 10 damage per hit (2 hits to kill)
- [ ] Bare hands: 5 damage per hit (4 hits to kill)
- [ ] Attack cooldown: 1.0s (no rapid tapping)
- [ ] `is_attacking` locks other input during cooldown
- [ ] `fauna_killed` signal emitted on death (meat drop is SurvivalSystem's concern)
- [ ] Input priority: fauna > gather > movement
- [ ] Unit tests for damage calc, kill threshold, cooldown
- [ ] Build passes with zero warnings

---

### task-028: FaunaRenderer + combat/damage feedback [IMPLEMENT]

**Scope:** Fauna visuals and floating damage/hit feedback.

**Files:**
- `scripts/fauna/fauna_renderer.gd` + `scenes/world/fauna_renderer.tscn` — single MultiMesh
- Extend `ui/gather_feedback.gd` with shared `show_floating_text(world_pos, text, color)` API
- Extend `ui/screen_fade.gd` with `flash(color, duration)` for hit vignette

**Implements:**
- Single MultiMeshInstance3D for all fauna (~3 max instances, 1 draw call)
- Update on: `fauna_spawned` (add), `fauna_moved` (transform), `fauna_killed` (remove),
  `fauna_despawned` (remove)
- Placeholder mesh: colored sphere or simple creature shape
- GatherFeedback extended API:
  - Gather: `show_floating_text(pos, "+1 WOOD", Color.GREEN)`
  - Attack: `show_floating_text(pos, "-10", Color.RED)`
- ScreenFade extended API:
  - `flash(Color(1, 0, 0, 0.3), 0.2)` — red vignette on player hit (~0.2s)
- ScreenFade now has 3 uses: death fade, damage flash, future transitions

**Criteria:**
- [ ] Fauna render at correct positions, update on move
- [ ] Fauna disappear on kill and despawn
- [ ] Floating damage numbers: "-10" red on attack, rises and fades
- [ ] Red vignette flash on player damage (~0.2s)
- [ ] GatherFeedback `show_floating_text` works for both gather and combat
- [ ] Draw calls: 1 for fauna
- [ ] Build passes with zero warnings

**Parallel with:** task-029

---

### task-029: BuildPanel UI + placement mode label [IMPLEMENT]

**Scope:** Build menu UI and placement mode overlay.

**Files:**
- `ui/build_panel.gd` + `ui/structure_entry_ui.gd`
- Placement mode floating label

**Implements:**
- Bottom drawer: full width, ~45% height (same pattern as Inventory/Crafting)
- 5 structure entries with recipe costs (owned/needed, green/red)
- Affordable = bright + active BUILD button; unaffordable = greyed
- BUILD tap → `building_system.enter_placement_mode(type)`, close panel
- Mutual exclusion: `panel_opened` signal, connect to Inventory + Crafting panels
- Open/close: BuildButton toggle, X, tap above panel
- Game continues running — no pause
- ScrollContainer wrapping StructureList
- Placement mode label: centered above player, "TAP TO PLACE WALL" / "TAP TO CANCEL"
  - Space Grotesk, uppercase, tracking-widest
  - Primary (#a8e8ff) at 60% opacity, 1px dark outline
  - Tactical Brutalism style — no drop shadow, no generic tooltip

**Criteria:**
- [ ] Build panel shows 5 structures with correct recipes
- [ ] Affordable = bright + BUILD active; unaffordable = greyed
- [ ] BUILD tap enters placement mode and closes panel
- [ ] Mutual exclusion with Inventory and Crafting panels
- [ ] Placement label visible during placement mode (Tactical Brutalism style)
- [ ] Touch targets ≥ 48dp (entries ~100px, BUILD ~80×48, close 48×48)
- [ ] BuildButton (HUD): 64×64px, always visible
- [ ] Build passes with zero warnings

**Parallel with:** task-028

---

### task-030: Building & Threats integration tests [TEST]

**Scope:** End-to-end integration tests for the full building + threats system.

**Covers:**
- AC6: place on empty hex = occupied/blocks, occupied hex rejected, shelter = 0 damage,
  wall redirects fauna, structure HP (N/A — indestructible in MVP)
- AC9: day 3 = zero spawn, day 4 = 1-3 spawn, fauna move within 2 hexes,
  contact damage, dawn despawn
- Place each structure → verify downstream effects:
  - Workbench → blocks movement, crafting proximity (future delivery)
  - Storage Chest → inventory expands +12
  - Shelter → respawn point update, night protection
  - Torch → visibility source at night
  - Wall → blocks movement, redirects fauna pathing
- Combat: approach → attack → kill → `fauna_killed` signal
- Build panel affordability updates after material changes
- Placement mode cancel → no materials consumed
- Input priority: placement > fauna > gather > movement

**Criteria:**
- [ ] All AC6 criteria verified
- [ ] All AC9 criteria verified
- [ ] Each structure's downstream effect verified
- [ ] Combat flow: attack → damage → kill → signal
- [ ] Placement cancel: clean exit, no material loss
- [ ] Input priority stack verified
- [ ] Tests deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 14 tasks created (017-030) — approved | /aid-detail |
