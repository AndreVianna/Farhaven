# delivery-005b: Night Falls — Building + Threats

**Status:** Approved
**Created:** 2026-03-31
**Rewritten:** 2026-04-08 (aligned with delivery-005a engine)
**Features:** feature-009-building, feature-010-night-threats
**Depends on:** delivery-001 (001-008), delivery-002 (009-015), delivery-003 (016-023), delivery-004 (024-031), delivery-005a
**Cumulative state:** Place structures, fauna at night, auto-defend + auto-pickup activate

> **Authoritative engine spec:** `.aid/work-001-core/delivery-005a/DESIGN.md`
> If this file and DESIGN.md disagree, DESIGN.md wins.

---

## Rewrite Summary (2026-04-08)

This DETAIL.md was rewritten after delivery-005a landed. Key changes:

1. **Building = Assemble Recipes.** Structures are built via `kind: assemble` recipes in `data/recipes/`. BuildingSystem is a thin UX wrapper for placement mode — it no longer owns structure config, material validation, or inventory consumption. RecipeRuntime handles all of that.
2. **Inventory is weight-based.** All references to "24 slots" or `Inventory.expand(12)` are replaced with weight capacity. Storage Chest increases `capacity_weight` by +50.0.
3. **Fog removed → LightingManager.** All fog-based visibility criteria are replaced with distance-based + lighting checks via `LightingManager.get_active_lights()`.
4. **Fauna drops = Breakdown Recipe.** Fauna death triggers a breakdown recipe that produces drops, not hardcoded item spawning.
5. **task-034 (StructureRenderer) retained** as a signal-driven renderer for player-placed structures. PropRenderer only renders natural-origin props via `tile.get_props()`, so structures need their own renderer.

---

## Execution Graph

```
      CHAIN A (Building)                    CHAIN B (Night Threats)
         (parallel)                            (parallel)

task-032 (Build recipes +                 task-037 (FaunaManager —
  BuildingSystem placement                  spawn, AI, contact,
  wrapper)                                  despawn, death recipes)
  │                                         │
  ├──────────────┐                          ▼
  ▼              ▼                        task-038 (Fauna renderer
task-033       task-034                    + signal wiring)
(Placement     (Structure
 mode +         renderer)
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
DayNightCycle from delivery-004, RecipeRuntime + LightingManager from delivery-005a),
not on each other.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 032 | Build recipes + BuildingSystem placement wrapper | IMPLEMENT | delivery-005a | 037, 039b |
| 033 | Placement mode + input + highlights | IMPLEMENT | 032 | 034, 037, 039b |
| 034 | Structure renderer (signal-driven) | IMPLEMENT | 032 | 033, 037, 039b |
| 035 | Build panel UI | IMPLEMENT | 033 | 037, 038, 039b |
| 036 | Building cross-feature integration test | TEST | 032, 034, 035 | 038, 039b |
| 037 | FaunaManager — spawn, AI, contact, despawn | IMPLEMENT | delivery-005a | 032, 033, 034, 039b |
| 038 | Fauna renderer + signal wiring | IMPLEMENT | 037 | 035, 036, 039b |
| 039b | Recipe editor page (level editor) | IMPLEMENT | delivery-005a | All other 005b tasks |

## Task Details

### task-032: Build Recipes + BuildingSystem Placement Wrapper [IMPLEMENT]

**Source:** feature-009 → Data Model

**Scope:**

**A) Build Recipes (data/recipes/)**

Create 6 Assemble recipes for structures, one `.tres` per structure. Each recipe follows the pattern from DESIGN.md §4 (kind: assemble) and §7 (worked examples). Recipe costs from the original feature-009 spec:

| Recipe ID | Kind | Inputs (source: player_inventory) | Conditions | Actions | Time | Outputs | unlock_when |
|-----------|------|----------------------------------|------------|---------|------|---------|-------------|
| `build_workbench` | assemble | wood ×5, stone ×3 | `at_tile_type: buildable` (gate) | [build] | 3.0 | workbench ×1 | [] (known from start) |
| `build_storage_chest` | assemble | wood ×8, stone ×4 | `at_tile_type: buildable` (gate) | [build] | 3.0 | storage_chest ×1 | [] (known from start) |
| `build_shelter` | assemble | wood ×10, stone ×5, fiber ×3 | `at_tile_type: buildable` (gate) | [build] | 5.0 | shelter ×1 | [] (known from start) |
| `build_campfire` | assemble | wood ×3, fiber ×2 | `at_tile_type: buildable` (gate) | [build] | 2.0 | campfire ×1 | [] (known from start) |
| `build_wall` | assemble | wood ×3 | `at_tile_type: buildable` (gate) | [build] | 2.0 | wall ×1 | [] (known from start) |
| `build_torch` | assemble | wood ×2, fiber ×1 | `at_tile_type: buildable` (gate) | [build] | 1.0 | torch ×1 | [] (known from start) |

The `at_tile_type: buildable` condition means the target tile is passable and not water/cliff. The `must_sustain` flag is false (gate-only — checked at start, not sustained during build time).

All build recipes use `actions: [build]` — this means the recipe is NOT passive. The player must trigger it explicitly via the Build panel → placement mode. BuildingSystem acts as the bridge between the UI action and `RecipeRuntime.try_start_recipe()`.

**PropDef for Wall:** If `data/props/00106.tres` (Wall) does not yet exist, create it:
```yaml
id: "00106"
display_name: "Wall"
tags: [STRUCTURE]
capabilities:
  PLACEABLE: { footprint: [Vector2i(0,0)], blocks_movement: true }
  CATALOGABLE: { scan_time: 1.0, display_tag: "survival" }
origin: CRAFTED
placeholder_mesh_type: "box"
placeholder_params: { size_x: 0.8, size_y: 0.6, size_z: 0.2 }
placeholder_color: Color(0.5, 0.4, 0.3, 1.0)
```

Wall is the ONLY structure with `blocks_movement: true` that is purely structural (no STATION, no CONTAINER, no EMITS_LIGHT).

**B) BuildingSystem (scripts/building/building_system.gd)**

BuildingSystem is now a **thin UX wrapper** — it manages placement mode and delegates to RecipeRuntime for material consumption and structure creation. It does NOT own structure config, ingredient lists, or inventory manipulation.

- Node (child of Player)
- Holds reference to the currently selected build recipe (from Build panel)
- On player tap during placement mode:
  1. Validate placement: adjacent tile, passable, sub-hex footprint available (no overlapping props), tile is not water
  2. Build a `WorldContext` with the target tile, player reference, etc.
  3. Call `RecipeRuntime.try_start_recipe(selected_recipe, ctx)`
  4. If recipe returns a `PendingRecipe` (or resolves instantly for time=0): the recipe handles material consumption and output production
  5. When recipe resolves: the output prop (structure) needs to be placed on the tile. Wire `RecipeRuntime.recipe_resolved` to place the output prop dict into `HexGrid.get_tile(coords).props`, then emit `HexGrid.structure_placed`
- **Storage Chest effect:** On `structure_placed` for storage_chest → increase `Inventory.capacity_weight` by 50.0. (Inventory is RefCounted and cannot listen to signals directly, so BuildingSystem or main.gd wiring handles this.)
- `structure_build_failed(reason)` signal for UI feedback
- `get_save_data()` / `load_save_data()` — structures are saved as props in tile data (HexGrid is source of truth)

**Criteria:**
- [ ] All 6 build recipes created as `.tres` files in `data/recipes/`
- [ ] Recipes load correctly via RecipeRegistry at startup
- [ ] Wall PropDef (00106) exists with PLACEABLE(blocks_movement: true)
- [ ] Placement rejects: footprint overlap with existing props, non-adjacent, water tile, insufficient materials (handled by RecipeRuntime input validation)
- [ ] Materials consumed by RecipeRuntime on successful build (not by custom logic)
- [ ] Output structure prop placed on tile with correct sub-hex position
- [ ] `HexGrid.structure_placed` emitted with correct coords + type
- [ ] `structure_build_failed` emitted with reason on rejection
- [ ] Storage Chest placement increases `Inventory.capacity_weight` by 50.0
- [ ] Only Wall has `blocks_movement: true` via its PLACEABLE capability
- [ ] All other structures (workbench, storage_chest, shelter, campfire, torch) are walkable
- [ ] Unit tests for all validation paths
- [ ] Build passes with zero warnings

---

### task-033: Placement Mode + Input + Highlights [IMPLEMENT]

**Source:** feature-009 → Feature Flow (placement mode, input priority, highlights)

**Scope:**
- `_is_placing` / `_placing_recipe` state in `building_system.gd`
- `enter_placement_mode(recipe: Recipe)` / `exit_placement_mode()`
- During placement: lowest `process_priority` value in `_unhandled_input`,
  claims ALL taps via `set_input_as_handled()`
- Show sub-hex grid overlay on adjacent tiles during placement mode
- Tap tile with available sub-hexes for footprint → create WorldContext → call `RecipeRuntime.try_start_recipe()` → place structure → exit
- Tap non-valid → cancel → exit (no materials consumed — RecipeRuntime never called)
- Call `HexGridRenderer.highlight_tiles(valid_tiles, Color.CYAN)` on enter
  (API already exists from delivery-001 task-004)
- Call `HexGridRenderer.clear_highlights()` on exit
- Highlight recalculation on `tile_entered` during placement (joystick walk)
- Sub-hex footprint overlay shows which sub-hexes are available vs occupied
- `placement_mode_entered(recipe_id)` / `placement_mode_exited()` signals
- Show/hide placement label via HUD (`show_placement_label` / `hide_placement_label`)

**Criteria:**
- [ ] Placement mode claims all taps (no fall-through to scanner/movement)
- [ ] Tap highlighted tile → structure placed via RecipeRuntime → highlights cleared → mode exits
- [ ] Tap non-highlighted → cancel, no materials consumed (RecipeRuntime not invoked), highlights cleared
- [ ] Highlights update on player movement during placement
- [ ] Placement label visible during mode, hidden after
- [ ] `placement_mode_entered` / `exited` signals emitted
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-034: Structure Renderer [IMPLEMENT]

**Source:** feature-009 → Layers & Components (StructureRenderer)

**Context:** PropRenderer (`scripts/rendering/prop_renderer.gd`) renders natural-origin props only — its `_populate_all_visible_tiles()` calls `tile.get_props()` which filters for `origin == NATURAL`. Player-placed structures (origin = CRAFTED) are not rendered by PropRenderer. Therefore a separate StructureRenderer is needed for structures placed during gameplay.

PropRenderer uses MultiMesh pools (one pool per PropDef, up to 128 instances). Structures are low-count (typically <20 total across the map) and may need specialized rendering (multi-hex footprints, sub-hex positioning with rotation). A signal-driven approach with individual Node3D children is appropriate.

**Scope:**
- `scripts/building/structure_renderer.gd` — Node3D
- `scenes/world/structure_renderer.tscn` — renders structure props as individual Node3D children
  (workbench, storage_chest, shelter, campfire, wall, torch)
- On `HexGrid.structure_placed(coords, structure_type)`: add instance at sub-hex world position (tile world pos + sub-hex offset) + elevation Y
- Placeholder meshes: colored boxes/shapes per structure type (<500 tris). Use PropDef placeholder config (`placeholder_mesh_type`, `placeholder_params`, `placeholder_color`) for visual consistency with PropRenderer.
- On `HexGrid.structure_destroyed(coords, structure_type)`: remove the corresponding Node3D child
- Signal-driven (no per-frame queries)
- Structure position derived from footprint's anchor sub-hex coordinate within the parent hex

**Criteria:**
- [ ] Structures render at correct sub-hex positions within tiles
- [ ] Each type visually distinct (different color/shape based on PropDef placeholder config)
- [ ] Draw calls: ~5-6 (one Node3D per structure)
- [ ] Signal-driven updates only (on structure_placed / structure_destroyed)
- [ ] Multi-hex structures (workbench, shelter) render correctly across their footprint
- [ ] Build passes with zero warnings

**Parallel with:** task-033

---

### task-035: Build Panel UI [IMPLEMENT]

**Source:** feature-009 → Layers & Components + UI Specs

**Scope:**
- `ui/build_panel.gd` — bottom drawer (~45% height)
- `ui/structure_entry_ui.gd` — single row: icon + name + ingredients + BUILD button
- BuildButton (64×64px) in HUD — always visible
- 6 structure entries. Each entry reads its recipe from RecipeRegistry (query by `actions: [build]` or by a fixed list of build recipe IDs). Display ingredient costs from `recipe.inputs` with owned/needed counts (green/red). Check player inventory for affordability.
- Affordable = bright + active BUILD; unaffordable = greyed
- BUILD tap → `building_system.enter_placement_mode(recipe)`, close panel
- `panel_opened` signal for mutual exclusion (5-panel list: inventory, catalog, crafting, build, future)
- Refresh on `inventory_changed` (ingredient counts may change)

**Criteria:**
- [ ] BuildButton always visible in HUD
- [ ] Panel opens/closes on BuildButton tap
- [ ] 6 structures with correct recipes displayed (costs from recipe inputs)
- [ ] Affordable = bright/active, unaffordable = dimmed/greyed
- [ ] BUILD tap enters placement mode with the selected recipe and closes panel
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
  - Storage Chest → `Inventory.capacity_weight` increases by 50.0 (weight-based, not slot-based)
  - Shelter → respawn point updates. Shelter prop has STATION([respawn]) — SurvivalSystem (when it exists) should query for STATION(respawn) on the player's tile
  - Torch → `LightingManager` registers the light source (via `HexGrid.structure_placed` → `LightingManager._on_structure_placed`). Verify `LightingManager.get_active_lights()` includes the torch during NIGHT/DUSK phases.
  - Workbench → CraftButton visible (crafting proximity check via STATION([craft]) capability)
  - Wall (only blocking structure) → blocks movement (PlaceableCap.blocks_movement = true, checked via `HexGrid.get_traversal`)
  - Walkable structures (Workbench, Storage Chest, Shelter, Campfire, Torch) → player can stand on them
  - Multiple structures per hex: footprints don't overlap at sub-hex level
- AC6 full coverage: place on empty hex, reject occupied footprint, shelter protection, wall redirects
- Panel mutual exclusion with all other panels
- Placement mode cancel verified (no materials consumed)
- Build recipes correctly consumed by RecipeRuntime (not custom logic)

**Criteria:**
- [ ] AC6 fully covered
- [ ] Storage Chest → inventory capacity_weight increases by 50.0
- [ ] Shelter → respawn point updates (STATION(respawn) prop query)
- [ ] Torch → LightingManager registers light, get_active_lights() returns it at night
- [ ] Workbench → CraftButton visible (STATION(craft) proximity)
- [ ] Blocking structure (Wall) → pathfinding routes around
- [ ] Walkable structures → player can stand on
- [ ] Placement cancel → no material loss (RecipeRuntime not invoked)
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
    spawn 1-3, first_spawn_day 4, spawn_min_distance 3
  - `CHAPTER1_SPECIES = [&"thornback"]`
  - **Spawn:** on `DayNightCycle.night`, Day 4+ only. Tile validation:
    - Passable tile
    - No structure props on tile (check `tile.get_props_with_tag(&"STRUCTURE")`)
    - Distance ≥ 3 hexes from player (`HexGrid.distance(tile, player_tile) >= 3`)
    - NOT within any active light radius: for each light in `LightingManager.get_active_lights()`, the tile's world position must be outside `light.radius` from `light.position`. This replaces the old "not VISIBLE" + "not within torch radius 2" criteria.
  - **Movement:** `_process` NIGHT only, cooldown-gated. Move toward player within
    detection_range. Wall avoidance via `_is_fauna_passable(from, to, max_jump)` —
    NOT `HexGrid.is_passable()` (which allows JUMP/DROP). Thornback (`max_jump: 1`)
    treats elevation diff 2+ as BLOCKED. No stacking (only one fauna per tile).
    Fauna also avoids tiles within active light radii (query LightingManager).
  - **Contact damage:** after fauna move, if adjacent to player: shelter check
    (0 damage if player is on a tile with STATION([respawn]) prop — the shelter), else 10 HP.
    Emit `fauna_attacked_player(id, damage, species_type)`
  - **Surprise encounter:** Fauna that enters the player's detection range from darkness (from outside any active light radius) triggers a surprise encounter on first contact. The signal includes `species_type` for ScannerSystem to auto-register as ENCOUNTERED. This replaces the old "stepping out of fog" mechanic — same gameplay effect (unknown threat emerging from darkness), different trigger (light-based, not fog-based).
  - **`apply_damage(fauna_id, damage)`:** called by F-004 auto-defend. Reduce HP.
    On death (hp ≤ 0):
    - Emit `fauna_killed(id, coords, species_type)`
    - **Death drops via breakdown recipe:** Place a `thornback_corpse` prop on the tile → a passive breakdown recipe auto-fires → drops appear. Create the recipe:
      ```
      fauna_death_thornback:
        kind: breakdown
        inputs: [{thornback_corpse, 1, source: world_tile}]
        actions: []  # passive
        time: 0
        outputs: [{meat, 1, prob: 1.0}, {bone, 1, prob: 0.5}]
        unlock_when: []
      ```
    - Also create PropDef for `thornback_corpse` if needed (tags: [FAUNA_CORPSE], PLACEABLE, no PORTABLE — corpse stays on ground)
  - **Despawn:** on `DayNightCycle.dawn` → clear all, emit `fauna_despawned` per fauna
  - **Public API:** `get_fauna_at`, `get_fauna_adjacent_to`, `get_all_fauna`
  - 5 signals with species_type on all
  - Fauna NOT saved (transient per-night)
  - **Known emergent:** shelter farming — intentional for MVP (1-3 meat/night)

**Criteria:**
- [ ] No fauna spawn Days 1-3
- [ ] 1-3 fauna spawn Day 4+ at night
- [ ] Spawn tiles: passable, no structure, ≥3 hexes from player, NOT within any active light radius (via `LightingManager.get_active_lights()`)
- [ ] AI movement: toward player within 2 hexes, walls block, no stacking, avoids lit tiles
- [ ] Contact damage: 10 HP normal, 0 on shelter tile (check STATION(respawn)), signal still fires
- [ ] `apply_damage`: HP reduction, `fauna_killed` on hp ≤ 0
- [ ] Death triggers breakdown recipe: `thornback_corpse` placed → `fauna_death_thornback` recipe fires → meat + bone drops
- [ ] All fauna despawn at dawn
- [ ] Public query API returns correct fauna data
- [ ] Contact damage is fauna-move-only (free first strike for player)
- [ ] Surprise encounter: fauna approaching from darkness (outside light radius) triggers surprise
- [ ] Unit tests: spawn validation (including light radius exclusion), AI movement, contact, shelter, apply_damage, despawn, death recipe
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
  - `fauna_attacked_player` → ScannerSystem surprise encounter (UNKNOWN → ENCOUNTERED) (feature-003)
  - `fauna_attacked_player` → HUD `ScreenFade.flash(red)` (feature-012/007)
  - `fauna_killed` → Triggers breakdown recipe flow (FaunaManager places corpse prop → RecipeRuntime auto-resolves `fauna_death_thornback` → drops produced). Downstream: auto-pickup picks up drops via `SurvivalSystem.get_ground_items_at` or directly from tile props.
  - `fauna_spawned` → PropRenderer (prop mesh, feature-003) + PropLabelRenderer (question-mark/warning/name label based on knowledge state, feature-003)
  - `fauna_moved` → AutoInteractionSystem auto-defend adjacency check (feature-004)
- **F-004 stubs activate:** FaunaManager now exists → `get_fauna_adjacent_to` returns
  real data → auto-defend fires for ENCOUNTERED or CATALOGED hostile fauna
- **F-004 auto-pickup activates:** ground items from breakdown recipe drops now exist →
  `SurvivalSystem.get_ground_items_at` returns real data (or items exist as props on tile for direct pickup)

**Criteria:**
- [ ] Fauna render at correct positions, move between tiles, disappear on kill/despawn
- [ ] Draw calls: 1 (single MultiMesh)
- [ ] Surprise attack: UNKNOWN fauna from darkness → `fauna_attacked_player` → F-003 auto-registers as ENCOUNTERED
- [ ] Contact damage: `fauna_attacked_player` → F-007 `take_damage`
- [ ] Damage feedback: `fauna_attacked_player` → ScreenFade.flash(red)
- [ ] Death drops: `fauna_killed` → corpse prop placed → breakdown recipe → drops appear on tile
- [ ] Auto-defend activates: F-004 now gets real fauna data from query API (fires on ENCOUNTERED or CATALOGED hostile)
- [ ] Auto-pickup activates: ground items from breakdown recipe drops picked up on tile_entered
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

### task-039b: Recipe Editor Page (Level Editor) [IMPLEMENT]

**Source:** delivery-005a DESIGN.md (Recipe system), delivery-005b needs recipes editable

**Scope:**
- New page in `tools/level-editor/` alongside the existing Prop and Biome editor pages
- **List view:** shows all recipes from `data/recipes/*.tres` with id, display_name, kind
- **Create/Edit form:**
  - id (numeric, auto-increment)
  - display_name (text)
  - kind (dropdown: Assemble, Transform, Breakdown, Combine)
  - inputs (list editor: each entry has ref_or_tag picker + count + source dropdown + is_tag checkbox)
  - outputs (list editor: each entry has prop_ref picker + count + prob slider 0-1)
  - effects (list editor: kind dropdown + params key-value)
  - conditions (list editor: predicate kind dropdown + params + must_sustain checkbox)
  - actions (tag list: craft, build, eat, chop, use, gather, etc.)
  - time (float input)
  - unlock_when (list editor: predicate kind + params)
- **Prop ref picker:** dropdown/search that lists PropDef ids + display_names from `data/props/`
- **Validation:** inputs reference valid prop IDs or known tags, outputs reference valid prop IDs, prob in [0,1]
- **Round-trip:** load .tres → edit → save → reload without data loss
- **Delete:** with confirmation
- Follow same patterns as prop-editor.js (tres-parser, file-discovery, validation, unknown-field passthrough)

**Criteria:**
- [ ] Recipe list page shows all recipes with id, display_name, kind
- [ ] Create new recipe from the editor
- [ ] Edit existing recipe — all fields editable
- [ ] Delete recipe with confirmation
- [ ] Prop ref picker shows PropDef ids + names
- [ ] Validation catches: missing inputs, invalid prop refs, prob out of range
- [ ] Round-trip: every existing recipe .tres survives load → edit → save → reload
- [ ] All JS tests pass (existing + new recipe editor tests)
- [ ] Build passes with zero warnings

**Parallel with:** all other 005b tasks (independent JS work, doesn't touch game code)

---

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-004 + delivery-005a):
- Player
  - BuildingSystem (Node) — NEW
  - FaunaManager (Node) — NEW
- World
  - StructureRenderer (Node3D) — NEW, renders player-placed structure props (individual Node3D per structure)
  - FaunaRenderer (Node3D) — NEW, 1 MultiMesh for fauna bodies

### Bootstrap Changes
- BuildingSystem._ready() → connects to HexGrid.tile_entered + structure_placed/destroyed. Placement validates sub-hex footprint availability in tile.props[]. On build action: creates WorldContext, calls RecipeRuntime.try_start_recipe() with the selected build recipe.
- FaunaManager._ready() → connects to DayNightCycle.night_started/day_started for spawn/despawn. Queries LightingManager.get_active_lights() for spawn validation and AI movement.
- FaunaManager.apply_damage() API available for AutoInteractionSystem auto-defend
- AutoInteractionSystem auto-defend stub activates (was stub since delivery-003)
- AutoInteractionSystem auto-pickup stub activates (ground items from delivery-004 + breakdown recipe drops)
- Torch placement → LightingManager auto-registers via structure_placed signal (already wired in 005a)
- Storage Chest placement → BuildingSystem (or main.gd wiring) increases Inventory.capacity_weight by 50.0

### New Recipe Files
| File | Kind | Notes |
|------|------|-------|
| `data/recipes/build_workbench.tres` | assemble | 5 wood + 3 stone → workbench |
| `data/recipes/build_storage_chest.tres` | assemble | 8 wood + 4 stone → storage_chest |
| `data/recipes/build_shelter.tres` | assemble | 10 wood + 5 stone + 3 fiber → shelter |
| `data/recipes/build_campfire.tres` | assemble | 3 wood + 2 fiber → campfire |
| `data/recipes/build_wall.tres` | assemble | 3 wood → wall |
| `data/recipes/build_torch.tres` | assemble | 2 wood + 1 fiber → torch |
| `data/recipes/fauna_death_thornback.tres` | breakdown | thornback_corpse → meat + bone(50%) |

### New PropDef Files (if not already existing)
| File | Notes |
|------|-------|
| `data/props/00106.tres` | Wall — PLACEABLE(blocks_movement: true) |
| `data/props/fauna_corpse_thornback.tres` | Thornback corpse — PLACEABLE, transient |

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-004 and delivery-005a still works
- [ ] Tap Build button → panel shows 6 structures with costs (read from recipe inputs)
- [ ] Select structure → adjacent valid tiles highlight cyan, sub-hex grid overlay shown
- [ ] Tap highlighted tile → RecipeRuntime consumes materials → structure prop placed at sub-hex position → footprint occupied
- [ ] Storage Chest placed → inventory capacity_weight increases by 50.0
- [ ] Torch placed → LightingManager.get_active_lights() includes the torch at night
- [ ] Night (day 4+): fauna appear outside lit areas, approach player
- [ ] UNKNOWN fauna shows question-mark, attacks player → surprise damage → auto-registered as ENCOUNTERED → warning label shown
- [ ] After ENCOUNTERED: player auto-attacks approaching fauna (auto-defend activates at ENCOUNTERED)
- [ ] Fauna killed → corpse prop placed → breakdown recipe fires → meat/bone drops appear
- [ ] Shelter: standing on shelter tile (STATION(respawn)) → 0 damage from fauna contact
- [ ] Dawn: all fauna despawn
- [ ] Walls: fauna routes around placed walls (blocks_movement = true)

### Dev Environment
No additional requirements beyond delivery-001 + delivery-005a.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 7 tasks created (032-038). Two parallel chains. Highlight API redundancy eliminated. | /aid-detail |
| 2026-04-02 | task-038: fauna_spawned signal wiring updated — ElementIconRenderer → PropRenderer + PropLabelRenderer. | /spec-update |
| 2026-04-02 | Scan redesign: task-037 "surprise auto-catalog" → "auto-register as ENCOUNTERED". task-038 auto-defend activates on ENCOUNTERED, not CATALOGED. | /scan-redesign-apply |
| 2026-04-04 | Unified props + sub-hex architecture: structures are props in tile.props[] with footprints. Placement validates sub-hex availability. StructureRenderer uses individual Node3D (not MultiMesh). Task descriptions updated for tasks 032-036. | /arch-update |
| 2026-04-09 | Added task-039b (Recipe editor page). Moved from tech-debt to explicit delivery task. Runs parallel with all other 005b tasks (independent JS work). |
| 2026-04-08 | **Full rewrite for delivery-005a alignment.** Building now uses Assemble recipes via RecipeRuntime (not custom BuildingSystem logic). Inventory references updated to weight-based (capacity_weight, not slots). All fog references replaced with LightingManager light-radius checks. Fauna death drops use breakdown recipes. task-034 retained (PropRenderer only renders natural-origin props). Storage Chest effect: +50.0 capacity_weight. Surprise encounter redesigned: light-based trigger replaces fog-based. | delivery-005a alignment |
