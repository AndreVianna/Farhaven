# delivery-004: Crafting + Survival Stats

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-005-crafting, feature-006-survival-stats
**Depends on:** delivery-001 (001-008), delivery-002 (009-016), delivery-003 (017-030)
**Cumulative state:** Complete MVP loop

## Execution Graph

Two fully independent tracks — crafting and survival have no cross-dependency.

```
CRAFTING TRACK                          SURVIVAL TRACK
                                        (parallel)

task-031 (Recipe config + discovery)    task-036 (Stat tick + consume)
  │                                       │
  ▼                                       ▼
task-032 (Craft action logic)           task-037 (Death, respawn, ground items)
  │                                       │
  ├────────────┐                          ├────────────┬────────────┐
  ▼            ▼                          ▼            ▼            ▼
task-033     task-034                   task-038     task-039     task-040
(Crafting    (Crafting                  (StatBars    (ScreenFade  (GroundItem
 Panel UI)    save)                      HUD)         + death)     Renderer)
  │            │                          │            │            │
  └─────┬──────┘                          └─────┬──────┴────────────┘
        ▼                                       ▼
task-035 (Crafting tests)               task-041 (Survival save)
                                          │
                                          ▼
                                        task-042 (Survival tests)
```

**Parallel groups:**
- Crafting track (031-035) ∥ Survival track (036-042) — fully independent
- task-033 ∥ task-034: both depend on task-032, not on each other
- task-038 ∥ task-039 ∥ task-040: three rendering components, all depend on task-037, independent of each other

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 031 | Recipe config + discovery + proximity | IMPLEMENT | delivery-003 | 036 (cross-track) |
| 032 | Craft action logic | IMPLEMENT | 031 | 037 (cross-track) |
| 033 | Crafting Panel UI | IMPLEMENT | 032 | 034 |
| 034 | Crafting save integration | IMPLEMENT | 032 | 033 |
| 035 | Crafting integration tests | TEST | 033, 034 | 042 (cross-track) |
| 036 | Survival system core — stat tick + consume | IMPLEMENT | delivery-003 | 031 (cross-track) |
| 037 | Death, respawn, ground items | IMPLEMENT | 036 | 032 (cross-track) |
| 038 | StatBars HUD | IMPLEMENT | 037 | 039, 040 |
| 039 | ScreenFade + death sequence | IMPLEMENT | 037 | 038, 040 |
| 040 | GroundItemRenderer | IMPLEMENT | 037 | 038, 039 |
| 041 | Survival save integration | IMPLEMENT | 038, 039, 040 | -- |
| 042 | Survival integration tests | TEST | 041 | 035 (cross-track) |

## Task Details — Crafting Track

### task-031: Recipe config + discovery + proximity [IMPLEMENT]

**Scope:** Create recipe data, discovery logic, and Workbench proximity check.

**Files:**
- `data/recipe_config.tres` (or static Dictionary)
- `scripts/crafting/crafting_system.gd` — Node, child of Player

**Implements:**
- Recipe config: Stone Axe (2 Wood + 1 Stone), Stone Pickaxe (3 Wood + 2 Stone)
  - Both: `output_type: &"tool"`, `discovery_material: &"stone"`
  - Stone Axe: `tool_slot: &"axe"`, Stone Pickaxe: `tool_slot: &"pickaxe"`
- `_discovered_recipes: Array[StringName]`
- Discovery: listen to `Inventory.item_added` → check `discovery_material` match
- `is_near_workbench(player_tile)` — read-only check on `HexTile.structure`
- `workbench_proximity_changed(near: bool)` signal — emitted on `tile_entered`,
  `tile_exited`, `structure_placed`, `structure_destroyed`
- All signals: `recipe_discovered`, `craft_completed`, `craft_failed`,
  `workbench_proximity_changed`

**Criteria:**
- [ ] Recipe config loads with both recipes, correct ingredients
- [ ] Discovery triggers when stone first gathered (both recipes appear)
- [ ] Proximity check reads `tile.structure == &"workbench"` from adjacent tiles
- [ ] `workbench_proximity_changed` fires on all four triggers
- [ ] Unit tests for discovery, proximity, recipe lookup
- [ ] Build passes with zero warnings

---

### task-032: Craft action logic [IMPLEMENT]

**Scope:** Implement the full craft action flow in `crafting_system.gd`.

**Implements:**
- Validation chain (order matters):
  1. Workbench proximity → `craft_failed(&"no_workbench")`
  2. Already-owned check (`Inventory.get_tool(slot) == recipe_name`) → `craft_failed(&"already_owned")`
  3. Ingredient check (`Inventory.has_item` per ingredient) → `craft_failed(&"insufficient_materials")`
- Consume: `Inventory.remove_item()` per ingredient
- Produce: `Inventory.set_tool(recipe.tool_slot, recipe_name)` → returns old tool (discarded)
- Emit `craft_completed(recipe_name)`
- Instant — no timer, no progress bar

**Criteria:**
- [ ] Validation in correct order: workbench → owned → ingredients
- [ ] Materials consumed only on successful craft
- [ ] Tool placed in correct slot via `set_tool`
- [ ] Already-owned blocks craft and does NOT consume materials
- [ ] `craft_completed` / `craft_failed` signals emit with correct args
- [ ] Unit tests for all validation paths + successful craft
- [ ] All existing tests still pass
- [ ] Build passes with zero warnings

---

### task-033: Crafting Panel UI [IMPLEMENT]

**Scope:** Bottom-drawer crafting panel.

**Files:**
- `scenes/ui/crafting_panel.tscn` — PanelContainer
- `ui/crafting_panel.gd` — open/close, recipe rendering
- `ui/recipe_entry_ui.gd` — single recipe row

**Implements:**
- CraftButton in HUD (bottom-right, 64×64px) — visible only when `workbench_proximity_changed(true)`
- Bottom drawer: full width, ~45% height, ScrollContainer wrapping VBoxContainer
- Recipe entry states: affordable (bright, green counts, active CRAFT button),
  unaffordable (dimmed, red counts, greyed), already-owned (dimmed, "Owned" badge)
- Ingredient display: `owned/needed` per material from `Inventory.get_count()`
- CRAFT button tap → `crafting_system.craft(recipe_name)`
- Mutual exclusion: `panel_opened` signal, connects to Inventory + Build panels
- Refresh on: `inventory_changed`, `craft_completed`, `recipe_discovered`
- Game continues running — no pause

**Criteria:**
- [ ] CraftButton visible only near Workbench, hidden otherwise
- [ ] Panel shows discovered recipes with correct states
- [ ] Ingredient owned/needed counts accurate and color-coded
- [ ] Already-owned recipes greyed with "Owned" badge
- [ ] Mutual exclusion with Inventory and Build panels
- [ ] Touch targets: entries ~100px, CRAFT ~80×48, close 48×48, CraftButton 64×64
- [ ] Build passes with zero warnings

**Parallel with:** task-034

---

### task-034: Crafting save integration [IMPLEMENT]

**Scope:** Extend SaveManager for crafting data.

**Implements:**
- `CraftingSystem.get_save_data()` → `{ "discovered_recipes": [...] }`
- `CraftingSystem.load_save_data(data)` → restore `_discovered_recipes`
- SaveManager includes crafting section in save file
- Missing crafting section on load → empty discovered list (fresh state)

**Criteria:**
- [ ] Save file includes `"crafting": { "discovered_recipes": [...] }`
- [ ] Load restores discovery state correctly
- [ ] Missing section handled gracefully (fresh state, no crash)
- [ ] Unit tests for save/load round-trip
- [ ] All existing tests still pass
- [ ] Build passes with zero warnings

**Parallel with:** task-033

---

### task-035: Crafting integration tests [TEST]

**Scope:** End-to-end tests for all AC4 acceptance criteria.

**Covers:**
- AC4: 5 Wood + 3 Stone → Workbench recipe visible (Note: Workbench is built via
  Build panel, but recipe visibility refers to crafting recipes becoming available)
- AC4: 2 Wood + 0 Stone → recipe greyed out
- AC4: First stone gathered → Stone Axe recipe appears
- AC4: Craft Stone Axe → materials consumed, tool in axe slot
- Additional: craft with no Workbench fails, craft already-owned fails,
  panel mutual exclusion, CraftButton visibility toggle

**Criteria:**
- [ ] All four AC4 criteria covered
- [ ] Craft without Workbench → failed
- [ ] Craft already-owned → failed, no materials consumed
- [ ] Panel mutual exclusion verified
- [ ] Tests deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

---

## Task Details — Survival Track

### task-036: Survival system core — stat tick + consume [IMPLEMENT]

**Scope:** Create `scripts/survival/survival_system.gd` as child Node of Player.
Core stat system — no death, no respawn, no ground items yet.

**Implements:**
- Stat properties: `hp`, `hunger`, `thirst` (floats, 0-100)
- `STAT_CONFIG`: hunger_rate 1.0/s, thirst_rate 1.5/s, hp_drain_no_hunger 2.0/s,
  hp_drain_no_thirst 3.0/s, hp_regen_day 0.5/s
- `CONSUMABLE_CONFIG`:
  - `&"berries": { "hunger": 15.0, "thirst": 5.0 }`
  - `&"meat": { "hunger": 25.0, "thirst": 0.0 }` — best hunger item, from fauna kills
- `_process` tick: deplete hunger/thirst, HP drain when starving/dehydrated (stacking),
  HP regen (daytime + fed + hydrated), clamp, death check
- Consume: listen to `Inventory.item_used` → apply `CONSUMABLE_CONFIG` effects
- `is_dead` flag gates tick
- Signals: `stat_changed(name, current, max)`, `player_died`, `player_respawned`,
  `ground_item_dropped`, `ground_item_picked_up`

**Criteria:**
- [ ] Stats deplete at configured rates
- [ ] HP drains when hunger == 0 (2.0/s) and/or thirst == 0 (3.0/s)
- [ ] Both drains stack: 5.0 HP/s when both zero
- [ ] HP regens only when: daytime AND hunger > 0 AND thirst > 0
- [ ] Berries restore: hunger +15, thirst +5
- [ ] **Meat restores: hunger +25, thirst +0** (meat in CONSUMABLE_CONFIG)
- [ ] `stat_changed` emits per frame for smooth HUD updates
- [ ] `is_dead` gates tick (no depletion while dead)
- [ ] Unit tests for depletion, drain, stacking, regen, consume
- [ ] Build passes with zero warnings

---

### task-037: Death, respawn, and ground items [IMPLEMENT]

**Scope:** Death flow, respawn flow, ground item management in `survival_system.gd`.

**Implements:**
- Death trigger: `hp <= 0 AND NOT is_dead`
- Drop 50% of each resource/consumable stack: `floor(quantity / 2)` per slot
  - **Tool slots NOT affected**
  - Scatter on passable neighbor tiles, **items pile on same tile** if few neighbors
- `_ground_items: Array[Dictionary]` — transient drop entries
- Respawn: teleport to `_respawn_tile`, reset stats (HP full, hunger 50%, thirst 50%)
- Night death: fade to black → stay black → dawn signal → fade in → respawn
- Day death: fade to black → respawn → fade in
- `_respawn_tile` tracking: listen to `structure_placed`/`structure_destroyed` for shelter
- Auto-pickup on `tile_entered`: iterate matching ground items, `Inventory.add_item()`,
  partial pickup (reduce amount, keep entry), full pickup (remove entry)
- Listen to `fauna_killed` signal → create meat ground item on fauna death tile

**Criteria:**
- [ ] Death triggers at HP ≤ 0
- [ ] Drops exactly `floor(quantity / 2)` per resource/consumable slot
- [ ] Tool slots untouched
- [ ] Items pile on tiles (multiple entries with same coords)
- [ ] Respawn: HP 100%, hunger 50%, thirst 50%
- [ ] `_respawn_tile` updates on shelter placed/destroyed
- [ ] Auto-pickup on tile_entered, partial pickup supported
- [ ] `fauna_killed` → meat ground item created
- [ ] Unit tests for drop calc, respawn stats, auto-pickup, meat drop
- [ ] Build passes with zero warnings

---

### task-038: StatBars HUD [IMPLEMENT]

**Scope:** Three survival stat bars at top-left of HUD.

**Files:** `ui/stat_bars.gd` — HBoxContainer with 3 ProgressBars

**Implements:**
- HP bar: green (>50%) → yellow (25-50%) → red (<25%)
- Hunger bar: green → yellow → red (same thresholds)
- Thirst bar: blue (>50%) → yellow → red
- ~200px wide × 20px tall each, stacked vertically
- Icon prefix per bar, no numeric display
- Smooth tween on value change (not instant snap)
- Translucent background
- `mouse_filter = IGNORE` — display only, touches pass through
- Listen to `SurvivalSystem.stat_changed(name, current, max)`

**Criteria:**
- [ ] 3 bars visible at top-left at all times
- [ ] Colors change at correct thresholds (>50%, 25-50%, <25%)
- [ ] Values tween smoothly
- [ ] `mouse_filter = IGNORE` — no touch interception
- [ ] Build passes with zero warnings

**Parallel with:** task-039, task-040

---

### task-039: ScreenFade + death sequence [IMPLEMENT]

**Scope:** Reusable fade transition and death-specific sequence.

**Files:** `ui/screen_fade.gd` — CanvasLayer above HUD, full-screen ColorRect

**Implements:**
- `fade_out(duration: float = 1.5)` — alpha 0→1
- `fade_in(duration: float = 1.5)` — alpha 1→0
- `flash(color: Color, duration: float = 0.2)` — brief vignette (used by combat feedback)
- Signals: `fade_out_completed`, `fade_in_completed`
- Death sequence wiring:
  - `player_died` → `fade_out(1.5)`
  - `fade_out_completed` → teleport + reset stats (while screen is black)
  - If daytime → `fade_in(1.5)` immediately
  - If nighttime → connect to `DayNightCycle.dawn` → then `fade_in(1.5)`
- No text, no "YOU DIED" — just black fade, player "wakes up"

**Criteria:**
- [ ] `fade_out` transitions alpha 0→1 over duration
- [ ] `fade_in` transitions alpha 1→0 over duration
- [ ] `flash` does quick color pulse (for combat hit feedback)
- [ ] Death: fade out → black → respawn while hidden → fade in
- [ ] Night death: stays black until dawn, then fades in
- [ ] Completion signals fire correctly
- [ ] Build passes with zero warnings

**Parallel with:** task-038, task-040

---

### task-040: GroundItemRenderer [IMPLEMENT]

**Scope:** Visual markers for dropped items on tiles.

**Files:**
- `scripts/survival/ground_item_renderer.gd`
- `scenes/world/ground_item_renderer.tscn` — single MultiMeshInstance3D

**Implements:**
- Single MultiMeshInstance3D with loot marker mesh (~10 max instances, 1 draw call)
- Listen to `ground_item_dropped` → add marker at tile world position
- Listen to `ground_item_picked_up` → remove/update marker
- Visibility follows tile fog state (hidden if tile HIDDEN)
- Placeholder mesh: glowing circle or simple icon

**Criteria:**
- [ ] Markers appear on drop, disappear on full pickup
- [ ] Partial pickup: marker stays until all items collected
- [ ] Visibility follows tile fog state
- [ ] Draw calls: 1 (single MultiMesh)
- [ ] Build passes with zero warnings

**Parallel with:** task-038, task-039

---

### task-041: Survival save integration [IMPLEMENT]

**Scope:** Extend SaveManager for survival data.

**Implements:**
- `SurvivalSystem.get_save_data()`:
  ```json
  {
    "survival": { "hp": 85.5, "hunger": 42.0, "thirst": 60.0,
                  "respawn_tile_col": 0, "respawn_tile_row": 0 },
    "ground_items": [ { "type": "wood", "amount": 25, "tile_col": 2, "tile_row": -1 } ]
  }
  ```
- `SurvivalSystem.load_save_data(data)` → restore stats, respawn tile, ground items
- `is_dead` NOT saved — player always loads alive
- Missing section → full stats, empty ground items

**Criteria:**
- [ ] Save includes survival section + ground_items array
- [ ] Load restores all values correctly
- [ ] `is_dead` always false on load
- [ ] Missing section → defaults (full HP, full hunger/thirst, Crash Site respawn)
- [ ] Ground items round-trip correctly
- [ ] Unit tests for save/load
- [ ] All existing tests still pass
- [ ] Build passes with zero warnings

---

### task-042: Survival stats integration tests [TEST]

**Scope:** End-to-end tests for all AC8 acceptance criteria.

**Covers:**
- AC8: HUD shows 3 bars at all times
- AC8: Hunger 0 → HP decreases at defined rate
- AC8: Eat berries → hunger increases by defined amount
- AC8: All stats 0 → die → respawn with 50% inventory drop
- Additional: death at night defers to dawn, respawn at Shelter vs Crash Site,
  ground item auto-pickup, partial pickup when inventory full, meat consumption
  restores hunger +25, fade sequence plays correctly

**Criteria:**
- [ ] All four AC8 criteria covered
- [ ] Death at night → respawn at dawn verified
- [ ] Respawn location: Shelter if built, Crash Site if not
- [ ] Ground item auto-pickup and partial pickup verified
- [ ] Meat consumption: hunger +25 verified
- [ ] Fade sequence: day death = immediate, night death = wait for dawn
- [ ] Tests deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 12 tasks created (031-042) — approved | /aid-detail |
