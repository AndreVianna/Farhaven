# delivery-005: Night Falls — Building + Threats

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-009-building, feature-010-night-threats
**Depends on:** delivery-001 (001-008), delivery-002 (009-015), delivery-003 (016-023), delivery-004 (024-031)
**Cumulative state:** Place structures, fauna at night, auto-defend + auto-pickup activate

## Execution Graph

```
      CHAIN A (Building)                    CHAIN B (Night Threats)
         (parallel)                            (parallel)

task-032 (Building data model)            task-037 (FaunaManager —
  │                                         spawn, AI, contact,
  ├──────────────┐                          despawn)
  ▼              ▼                          │
task-033       task-034                     ▼
(Placement     (Structure                 task-038 (Fauna renderer
 mode +         renderer)                  + signal wiring)
 highlights)     │
  │              │
  ▼              │
task-035         │
(Build panel     │
 UI)             │
  │              │
  └──────┬───────┘
         ▼
task-036 (Building cross-feature
  integration test)
```

**Two fully parallel chains:**
- Chain A: task-032 → (033 ∥ 034) → 035 → 036 (Building)
- Chain B: task-037 → 038 (Night Threats — no dependency on Building tasks)

Both chains depend on delivery-level prerequisites (HexGrid from delivery-001,
DayNightCycle from delivery-004), not on each other.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 032 | Building data model + structure config | IMPLEMENT | delivery-004 | 037 |
| 033 | Placement mode + input + highlights | IMPLEMENT | 032 | 034, 037 |
| 034 | Structure renderer (MultiMesh) | IMPLEMENT | 032 | 033, 037 |
| 035 | Build panel UI | IMPLEMENT | 033 | 037, 038 |
| 036 | Building cross-feature integration test | TEST | 032, 034, 035 | 038 |
| 037 | FaunaManager — spawn, AI, contact, despawn | IMPLEMENT | delivery-004 | 032, 033, 034 |
| 038 | Fauna renderer + signal wiring | IMPLEMENT | 037 | 035, 036 |

## Task Details

### task-032: Building Data Model + Structure Config [IMPLEMENT]

**Source:** feature-009 → Data Model

**Scope:**
- `scripts/building/building_system.gd` — Node (child of Player):
  - `structure_config` data: 5 structures with recipes, `blocks_movement`, effects
    (workbench 5W+3S blocking, storage_chest 8W+4S blocking, shelter 10W+5S+3F walkable,
    wall 3W blocking, torch 2W+1F walkable)
  - Placement validation: adjacent, passable, no existing structure, sufficient materials
  - On valid placement: `Inventory.remove_item` per ingredient,
    `HexGrid.get_tile(coords).structure = type`, emit `HexGrid.structure_placed`
  - **Storage Chest effect:** after placement, call `Inventory.expand(12)` directly
    (Inventory is RefCounted — cannot listen to signals itself)
  - `structure_build_failed(reason)` signal
  - `get_save_data()` / `load_save_data()` — no separate save (F-001 tile data is source of truth)
- `data/structure_config.tres` (or static Dictionary)

**Criteria:**
- [ ] All 5 structure recipes correct (values from SPEC)
- [ ] Placement rejects: occupied, non-adjacent, water/cliff, insufficient materials
- [ ] Materials consumed on successful placement
- [ ] `structure_placed` emitted with correct coords + type
- [ ] `structure_build_failed` emitted with reason on rejection
- [ ] Storage Chest placement calls `Inventory.expand(12)` — inventory grows to 24 slots
- [ ] Shelter `blocks_movement: false`, Torch `blocks_movement: false`
- [ ] Workbench, Storage Chest, Wall `blocks_movement: true`
- [ ] Unit tests for all validation paths
- [ ] Build passes with zero warnings

---

### task-033: Placement Mode + Input + Highlights [IMPLEMENT]

**Source:** feature-009 → Feature Flow (placement mode, input priority, highlights)

**Scope:**
- `_is_placing` / `_placing_type` state in `building_system.gd`
- `enter_placement_mode(type)` / `exit_placement_mode()`
- During placement: lowest `process_priority` value in `_unhandled_input`,
  claims ALL taps via `set_input_as_handled()`
- Tap highlighted tile → place structure → exit
- Tap non-highlighted → cancel → exit (no materials consumed)
- Call `HexGridRenderer.highlight_tiles(valid_tiles, Color.CYAN)` on enter
  (API already exists from delivery-001 task-004)
- Call `HexGridRenderer.clear_highlights()` on exit
- Highlight recalculation on `tile_entered` during placement (joystick walk)
- `placement_mode_entered(type)` / `placement_mode_exited()` signals
- Show/hide placement label via HUD (`show_placement_label` / `hide_placement_label`)

**Criteria:**
- [ ] Placement mode claims all taps (no fall-through to scanner/movement)
- [ ] Tap highlighted tile → structure placed → highlights cleared → mode exits
- [ ] Tap non-highlighted → cancel, no materials consumed, highlights cleared
- [ ] Highlights update on player movement during placement
- [ ] Placement label visible during mode, hidden after
- [ ] `placement_mode_entered` / `exited` signals emitted
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-034: Structure Renderer (MultiMesh) [IMPLEMENT]

**Source:** feature-009 → Layers & Components (StructureRenderer)

**Scope:**
- `scripts/building/structure_renderer.gd` — Node3D
- `scenes/world/structure_renderer.tscn` — 5 MultiMeshInstance3D children
  (workbench, storage_chest, shelter, wall, torch)
- On `structure_placed`: add instance at tile world position + elevation Y
- Placeholder meshes: colored boxes/shapes per structure type (<500 tris)
- Fog-aware: structures on HIDDEN tiles not visible
- Signal-driven (no per-frame queries)

**Criteria:**
- [ ] 5 MultiMeshInstance3D children (one per structure type)
- [ ] Structures render at correct tile positions
- [ ] Each type visually distinct (different color/shape)
- [ ] Fog-aware (HIDDEN = not visible)
- [ ] Draw calls: ~5
- [ ] Signal-driven updates only
- [ ] Build passes with zero warnings

**Parallel with:** task-033

---

### task-035: Build Panel UI [IMPLEMENT]

**Source:** feature-009 → Layers & Components + UI Specs

**Scope:**
- `ui/build_panel.gd` — bottom drawer (~45% height)
- `ui/structure_entry_ui.gd` — single row: icon + name + ingredients + BUILD button
- BuildButton (64×64px) in HUD — always visible
- 5 structure entries with recipe costs (owned/needed, green/red)
- Affordable = bright + active BUILD; unaffordable = greyed
- BUILD tap → `building_system.enter_placement_mode(type)`, close panel
- `panel_opened` signal for mutual exclusion (5-panel list)
- Refresh on `inventory_changed`

**Criteria:**
- [ ] BuildButton always visible in HUD
- [ ] Panel opens/closes on BuildButton tap
- [ ] 5 structures with correct recipes displayed
- [ ] Affordable = bright/active, unaffordable = dimmed/greyed
- [ ] BUILD tap enters placement mode and closes panel
- [ ] `panel_opened` signal; mutual exclusion with other panels
- [ ] Refresh on `inventory_changed`
- [ ] Touch targets: entry ~100px, BUILD ~80×48, close 48×48, BuildButton 64×64
- [ ] Game continues, ~55% visible
- [ ] Build passes with zero warnings

---

### task-036: Building Cross-Feature Integration Test [TEST]

**Source:** AC6

**Scope:**
- All cross-feature structure effects verified:
  - Storage Chest → `Inventory.expand(12)` (24 slots after)
  - Shelter → `_respawn_tile` updates in SurvivalSystem
  - Torch → `_torch_tiles` in DayNightCycle (NIGHT visibility extension)
  - Workbench → CraftButton visible (crafting proximity)
  - Blocking structures (Workbench, Storage Chest, Wall) → AStar2D edges disconnected
  - Walkable structures (Shelter, Torch) → player can stand on them
- AC6 full coverage: place on empty hex, reject occupied, shelter protection, wall redirects
- Panel mutual exclusion with all 4 other panels
- Placement mode cancel verified

**Criteria:**
- [ ] AC6 fully covered
- [ ] Storage Chest → inventory expands to 24
- [ ] Shelter → respawn point updates
- [ ] Torch → night visibility extends
- [ ] Workbench → CraftButton visible
- [ ] Blocking structures → pathfinding routes around
- [ ] Shelter/Torch → player can walk on
- [ ] Placement cancel → no material loss
- [ ] Panel mutual exclusion verified
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass

---

### task-037: FaunaManager — Spawn, AI, Contact, Despawn [IMPLEMENT]

**Source:** feature-010 → Data Model + Feature Flow

**Scope:**
- `scripts/fauna/fauna_manager.gd` — Node (child of Player):
  - `_fauna: Array[Dictionary]` — entities with id, species_type, coords, hp,
    move_cooldown, cooldown_remaining
  - `_next_id: int = 0`
  - `FAUNA_CONFIG`: hp 20, contact_damage 10, move_cooldown 1.0s, detection_range 2,
    spawn 1-3, first_spawn_day 4, meat_drop 1, spawn_min_distance 3
  - `CHAPTER1_SPECIES = [&"thornback"]`
  - **Spawn:** on `DayNightCycle.night`, Day 4+ only. Tile validation: not VISIBLE,
    no structure, passable, ≥3 hexes from player, not within torch radius 2.
  - **Movement:** `_process` NIGHT only, cooldown-gated. Move toward player within
    detection_range. Wall avoidance (is_passable). No stacking.
  - **Contact damage:** after fauna move, if adjacent to player: shelter check
    (0 damage if on shelter, signal still fires), else 10 HP.
    Emit `fauna_attacked_player(id, damage, species_type)`
  - **Surprise auto-catalog:** signal includes species_type for F-003 to auto-catalog
  - **`apply_damage(fauna_id, damage)`:** called by F-004 auto-defend. Reduce HP,
    emit `fauna_killed(id, coords, species_type)` on death.
  - **Despawn:** on `DayNightCycle.dawn` → clear all, emit `fauna_despawned` per fauna
  - **Public API:** `get_fauna_at`, `get_fauna_adjacent_to`, `get_all_fauna`
  - 5 signals with species_type on all
  - Fauna NOT saved (transient per-night)
  - **Known emergent:** shelter farming — intentional for MVP (1-3 meat/night)

**Criteria:**
- [ ] No fauna spawn Days 1-3
- [ ] 1-3 fauna spawn Day 4+ at night
- [ ] Spawn tiles: not VISIBLE, no structure, passable, ≥3 hexes, not in torch radius
- [ ] AI movement: toward player within 2 hexes, walls block, no stacking
- [ ] Contact damage: 10 HP normal, 0 on shelter (signal still fires)
- [ ] `apply_damage`: HP reduction, `fauna_killed` on hp ≤ 0
- [ ] All fauna despawn at dawn
- [ ] Public query API returns correct fauna data
- [ ] Contact damage is fauna-move-only (free first strike for player)
- [ ] Unit tests: spawn validation, AI movement, contact, shelter, apply_damage, despawn
- [ ] Build passes with zero warnings

**Parallel with:** entire Chain A (tasks 032-036)

---

### task-038: Fauna Renderer + Signal Wiring [IMPLEMENT]

**Source:** feature-010 → Layers & Components (renderer, signal wiring)

**Scope:**
- `scripts/fauna/fauna_renderer.gd` — Node3D
- `scenes/world/fauna_renderer.tscn` — single MultiMeshInstance3D (~3 max)
- On `fauna_spawned`: add instance at tile world position
- On `fauna_moved`: update instance transform
- On `fauna_killed`/`fauna_despawned`: remove instance
- Placeholder mesh: colored sphere (<500 tris)
- **Signal wiring to downstream features:**
  - `fauna_attacked_player` → SurvivalSystem `take_damage(damage)` (feature-007)
  - `fauna_attacked_player` → ScannerSystem surprise auto-catalog (feature-003)
  - `fauna_attacked_player` → HUD `ScreenFade.flash(red)` (feature-012/007)
  - `fauna_killed` → SurvivalSystem `add_ground_item(&"meat", 1)` (feature-007)
  - `fauna_spawned` → ElementIconRenderer (❓ or identified icon, feature-003)
  - `fauna_moved` → AutoInteractionSystem auto-defend adjacency check (feature-004)
- **F-004 stubs activate:** FaunaManager now exists → `get_fauna_adjacent_to` returns
  real data → auto-defend fires for cataloged hostile fauna
- **F-004 auto-pickup activates:** ground items from meat drops now exist →
  `SurvivalSystem.get_ground_items_at` returns real data

**Criteria:**
- [ ] Fauna render at correct positions, move between tiles, disappear on kill/despawn
- [ ] Draw calls: 1 (single MultiMesh)
- [ ] Surprise attack: uncataloged fauna → `fauna_attacked_player` → F-003 auto-catalogs
- [ ] Contact damage: `fauna_attacked_player` → F-007 `take_damage`
- [ ] Damage feedback: `fauna_attacked_player` → ScreenFade.flash(red)
- [ ] Meat drop: `fauna_killed` → F-007 `add_ground_item(&"meat", 1)`
- [ ] Auto-defend activates: F-004 now gets real fauna data from query API
- [ ] Auto-pickup activates: ground items from meat drops picked up on tile_entered
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-004):
- Player
  - BuildingSystem (Node) — NEW
  - FaunaManager (Node) — NEW
- World
  - StructureRenderer (Node3D) — NEW, ~5 MultiMesh for structure types
  - FaunaRenderer (Node3D) — NEW, 1 MultiMesh for fauna bodies

### Bootstrap Changes
- BuildingSystem._ready() → connects to HexGrid.tile_entered + structure_placed/destroyed
- FaunaManager._ready() → connects to DayNightCycle.night_started/day_started for spawn/despawn
- FaunaManager.apply_damage() API available for AutoInteractionSystem auto-defend
- AutoInteractionSystem auto-defend stub activates (was stub since delivery-003)
- AutoInteractionSystem auto-pickup stub activates (ground items from delivery-004)
- Torch placement → DayNightCycle.register_visibility_source() for extended night visibility

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-004 still works
- [ ] Tap Build button → panel shows 5 structures with costs
- [ ] Select structure → adjacent valid tiles highlight cyan
- [ ] Tap highlighted tile → structure appears → tile occupied
- [ ] Storage Chest placed → inventory expands to 24 slots
- [ ] Night (day 4+): fauna appear outside visible area, approach player
- [ ] Uncataloged fauna shows ❓, attacks player → surprise damage → auto-cataloged
- [ ] After cataloging: player auto-attacks approaching fauna
- [ ] Shelter: standing on shelter tile → 0 damage from fauna contact
- [ ] Dawn: all fauna despawn
- [ ] Walls: fauna routes around placed walls

### Dev Environment
No additional requirements beyond delivery-001.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 7 tasks created (032-038). Two parallel chains. Highlight API redundancy eliminated. | /aid-detail |
