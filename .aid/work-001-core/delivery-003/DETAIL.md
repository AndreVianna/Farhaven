# delivery-003: Movement IS Interaction — Auto-Gather + Crafting

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-004-auto-interaction (auto-gather active), feature-006-crafting
**Depends on:** delivery-001 (001-008), delivery-002 (009-015)
**Cumulative state:** Walk near cataloged resources → auto-gather → craft tools. Core loop complete.

## Execution Graph

```
      CHAIN A                 CHAIN B              CHAIN C
   (Auto-Interaction)     (ResourceRenderer)      (Crafting)
      (parallel)             (parallel)           (parallel)

task-016 (data layer)    task-019 (MultiMesh     task-020 (data layer +
  │                       renderer)               craft action)
  ▼                        │                       │
task-017 (auto-gather      │                       ▼
  flow)                    │                     task-021 (crafting
  │                        │                       panel UI)
  ▼                        │                       │
task-018 (respawn +        │                       │
  stubs)                   │                       │
  │                        │                       │
  └────────────┬───────────┴───────────────────────┘
               ▼
         task-022 (feedback wiring — fly-to-player, floating text)
               │
               ▼
         task-023 (integration test — core loop end-to-end)
```

**3 parallel chains:**
- Chain A: task-016 → 017 → 018 (Auto-Interaction system)
- Chain B: task-019 (ResourceRenderer — standalone, needs only HexGrid from delivery-001)
- Chain C: task-020 → 021 (Crafting system + UI)

**Merge:** task-022 depends on Chains A + C (needs auto-gather + crafting signals).
task-023 depends on everything.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 016 | Auto-Interaction data layer + resource config | IMPLEMENT | delivery-002 | 019, 020 |
| 017 | Auto-gather flow — proximity, tween, chain | IMPLEMENT | 016 | 019, 020 |
| 018 | Respawn queue + auto-defend stub + auto-pickup stub | IMPLEMENT | 017 | 019, 020, 021 |
| 019 | ResourceRenderer — MultiMesh per type | IMPLEMENT | delivery-001 | 016, 017, 018, 020, 021 |
| 020 | Crafting data layer — recipes, discovery, craft action | IMPLEMENT | delivery-002 | 016, 017, 018, 019 |
| 021 | Crafting panel UI + HUD integration | IMPLEMENT | 020 | 016, 017, 018, 019 |
| 022 | Feedback wiring — floating text + fly-to-player | IMPLEMENT | 017, 020 | -- |
| 023 | Integration test — core loop end-to-end | TEST | all above | -- |

## Task Details

### task-016: Auto-Interaction Data Layer + Resource Config [IMPLEMENT]

**Source:** feature-004 → Data Model

**Scope:**
- `scripts/auto_interaction/auto_interaction_system.gd` — Node (child of Player):
  - Properties: `_is_gathering`, `_gather_target_coords`, `_gather_target_index`,
    `_gather_tween`, `_defend_cooldown`, `_respawn_queue`
  - Resource config table: gather_time + gather_amount per type (7 types + toxic_berries)
  - Tool speed multipliers: stone_axe halves wood, stone_pickaxe halves stone
  - Tool priority: `TOOL_PRIORITY = { stone_pickaxe: 2, stone_axe: 1, "": 0 }`
  - Weapon damage: `WEAPON_DAMAGE = { survival_knife: 10, "": 5 }`
  - Auto-defend config: attack_cooldown 1.0s, attack_range 1
  - `can_gather(node, inventory)`: tool_required match via Inventory.get_tool
  - 5 signals declared: `auto_gather_started`, `auto_gather_completed`,
    `auto_gather_failed`, `auto_defend_triggered`, `ground_item_picked_up`
  - `resource_depleted` / `resource_respawned` emitted via HexGrid (canonical owner),
    NOT duplicated on AutoInteractionSystem
  - No flow logic yet — data + config + utilities only

**Criteria:**
- [ ] `can_gather`: bare hands gathers wood, stone_pickaxe gathers ore,
      stone_axe does NOT mine ore, empty slot rejects gated resource
- [ ] Resource config: all 8 types (including toxic_berries) with correct values
- [ ] Tool speed: stone_axe halves wood time (1.0 * 0.5 = 0.5s)
- [ ] Weapon damage: survival_knife=10, bare hands=5
- [ ] 5 signals declared (auto_gather_started/completed/failed, auto_defend_triggered, ground_item_picked_up)
- [ ] resource_depleted/respawned emitted via HexGrid, NOT on AutoInteractionSystem
- [ ] Build passes with zero warnings

---

### task-017: Auto-Gather Flow — Proximity, Tween, Chain [IMPLEMENT]

**Source:** feature-004 → Feature Flow (auto-gather)

**Scope:**
- On `tile_entered`: check current tile + 6 neighbors (7 tiles total)
- Catalog gate: `Catalog.is_cataloged(RESOURCE_TO_ENTRY[node.type])`
- Tool gate: `can_gather(node, Inventory)`
- Candidate sorting: TOOL_PRIORITY desc, then nearest to player
- Begin gather: compute effective_time (base * tool_speed), create Tween
- **Gather always completes** — no cancel, no range check after start
- On tween complete: decrement remaining, `Inventory.add_item` (at arrival, not start),
  emit `auto_gather_completed`. If remaining==0: emit `HexGrid.resource_depleted`
  (HexGrid owns tile data and the canonical signal — ResourceRenderer listens there),
  add to respawn queue if respawn_time>0.
- **Chain:** re-check from player's CURRENT position after each completion.
  Player may have moved. Chain continues while resources available.
- Inventory full: emit `auto_gather_failed(&"inventory_full")`
- Tool-gated (cataloged but wrong tool): emit `auto_gather_failed(&"tool_gated")`

**Criteria:**
- [ ] 7-tile check: current tile + 6 neighbors all checked for resources
- [ ] Catalog gate: uncataloged resource skipped (no gather, no feedback)
- [ ] Tool gate: gated resource without tool → `auto_gather_failed(&"tool_gated")`
- [ ] Priority: highest TOOL_PRIORITY first, nearest wins ties
- [ ] Effective time: base * tool_speed multiplier
- [ ] Gather completes regardless of player distance (no range cancel)
- [ ] Chain re-check from CURRENT position after each completion
- [ ] `add_item` called at tween completion (arrival, not start)
- [ ] Inventory full → `auto_gather_failed(&"inventory_full")`
- [ ] Depleted → `resource_depleted` + respawn queue entry
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-018: Respawn Queue + Auto-Defend Stub + Auto-Pickup Stub [IMPLEMENT]

**Source:** feature-004 → Feature Flow (respawn, auto-defend, auto-pickup)

**Scope:**
- **Respawn queue** in `_process`:
  - Tick `time_remaining` only when tile `fog_state != VISIBLE`
  - Pause on VISIBLE, resume on REVEALED/HIDDEN
  - On expire: `node.remaining = max_amount`, emit `HexGrid.resource_respawned`
    (HexGrid owns the canonical signal — ResourceRenderer listens there)
  - `respawn_time == 0` → never enters queue
  - NOT saved (intentional — world heals on load)
- **Auto-defend stub:**
  - Connect to `fauna_moved` signal from FaunaManager — if FaunaManager absent,
    connection is no-op (graceful)
  - When connected: check adjacent cataloged hostile fauna, cooldown gate,
    weapon lookup, emit `auto_defend_triggered(fauna_id, damage)`
  - Cooldown tick in `_process`: `_defend_cooldown -= delta`
- **Auto-pickup stub:**
  - On `tile_entered`: query `SurvivalSystem.get_ground_items_at(coords)` — if
    SurvivalSystem absent, returns empty (graceful)
  - Pick up via `Inventory.add_item`, partial pickup, emit `ground_item_picked_up`

**Criteria:**
- [ ] Respawn timer ticks when REVEALED or HIDDEN
- [ ] Respawn pauses when VISIBLE
- [ ] Respawn triggers at time_remaining ≤ 0, resets to max_amount
- [ ] `respawn_time == 0` → never enters queue
- [ ] Auto-defend cooldown decrements, blocks when > 0
- [ ] Auto-defend fires on adjacent cataloged hostile (mock FaunaManager)
- [ ] Auto-defend ignores passive fauna, ignores uncataloged
- [ ] Auto-pickup picks up ground items (mock SurvivalSystem)
- [ ] No crash when FaunaManager / SurvivalSystem absent
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-019: ResourceRenderer — MultiMesh per Type [IMPLEMENT]

**Source:** feature-004 → Layers & Components (renderer)

**Scope:**
- `scripts/rendering/resource_renderer.gd` — Node3D
- `scenes/world/resource_renderer.tscn` — 6 MultiMeshInstance3D children:
  wood/tree, stone/rock, berries/bush, fiber/grass, ore/vein, crystal/cluster
- Placeholder meshes: colored primitives (<500 tris each)
- On `map_generated`: allocate instances for all tile resource_nodes
- On `tile_revealed`/`tile_visibility_changed`: show/hide per fog
  (HIDDEN=not instanced, REVEALED=dimmed via custom data, VISIBLE=full)
- On `resource_depleted`: swap mesh variant (tree→stump, rock→rubble)
- On `resource_respawned`: swap back (stump→tree)
- Per-node deterministic random offset within hex (seeded from coords+index)

**Criteria:**
- [ ] 6 MultiMeshInstance3D children, one per resource type
- [ ] Resources render at correct positions with per-node offset
- [ ] Offset deterministic (same across save/load)
- [ ] HIDDEN not visible, REVEALED dimmed, VISIBLE full
- [ ] Depleted → swap to depleted variant, respawned → swap back
- [ ] Signal-driven (no per-frame queries)
- [ ] Draw calls: ~6
- [ ] Build passes with zero warnings

---

### task-020: Crafting Data Layer — Recipes, Discovery, Craft Action [IMPLEMENT]

**Source:** feature-006 → Data Model + Feature Flow

**Scope:**
- `scripts/crafting/crafting_system.gd` — Node (child of Player):
  - Recipe config: stone_axe (2W+1S, discovery_material=stone, tool_slot=axe),
    stone_pickaxe (3W+2S, discovery_material=stone, tool_slot=pickaxe)
  - `_discovered_recipes: Array[StringName]`
  - Discovery: on `Inventory.item_added` → check discovery_material match → append,
    emit `recipe_discovered`
  - Craft action: validate workbench proximity → already-owned block → ingredient check →
    consume → produce (`Inventory.set_tool`) → emit `craft_completed`
  - `is_near_workbench(player_tile)`: read-only check on 6 neighbors' `tile.structure`
  - `workbench_proximity_changed(near)` signal on tile_entered/exited/structure signals
  - Signals: `recipe_discovered`, `craft_completed`, `craft_failed`,
    `workbench_proximity_changed`
  - `get_save_data()` / `load_save_data()`
- `data/recipe_config.tres`

**Criteria:**
- [ ] Discovery triggers on first stone gathered (both recipes appear)
- [ ] Discovery permanent (re-gathering doesn't re-discover)
- [ ] Validation order: workbench → already-owned → ingredients
- [ ] Consume: `remove_item` called per ingredient
- [ ] Produce: `set_tool` called with correct slot + name
- [ ] Already-owned blocks craft, no materials consumed
- [ ] Insufficient materials blocks craft
- [ ] No workbench nearby blocks craft
- [ ] `workbench_proximity_changed` emitted on state change
- [ ] Save/load round-trip preserves discovered_recipes
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-021: Crafting Panel UI + HUD Integration [IMPLEMENT]

**Source:** feature-006 → Layers & Components + UI Specs

**Scope:**
- `scenes/ui/crafting_panel.tscn` — bottom drawer (~45% height)
- `ui/crafting_panel.gd` — open/close, recipe rendering, craft trigger
- `ui/recipe_entry_ui.gd` — 3 states: affordable, unaffordable, already-owned
- Ingredient display: owned/needed, green/red color coding
- CraftButton (64×64px) in HUD — hidden by default, visible on
  `workbench_proximity_changed(true)`
- `panel_opened` for mutual exclusion (5-panel list)
- Refreshes on `inventory_changed`, `craft_completed`, `recipe_discovered`

**Criteria:**
- [ ] CraftingPanel opens/closes on CraftButton tap
- [ ] CraftButton visible only near Workbench, hidden by default
- [ ] Recipe entries: affordable (bright/green/active), unaffordable (dim/red/grey),
      already-owned (dim/"Owned")
- [ ] Ingredient owned/needed correct and color-coded
- [ ] Craft button tap calls `crafting_system.craft()`
- [ ] Panel refreshes on inventory_changed / craft_completed / recipe_discovered
- [ ] `panel_opened` signal; mutual exclusion with Inventory + Catalog
- [ ] Touch targets: entry ~100px, Craft ~80×48, close 48×48, CraftButton 64×64
- [ ] Game continues, ~55% visible
- [ ] Build passes with zero warnings

---

### task-022: Feedback Wiring — Floating Text + Fly-to-Player [IMPLEMENT]

**Source:** feature-004 + feature-006 → feedback contracts with feature-012 (HUD)

**Depends on:** task-017 (auto-gather signals), task-020 (crafting signals)

**Scope:**
- Wire `auto_gather_completed` → HUD FloatingTextManager: "+N Type" green at player
- Wire `auto_gather_failed(&"inventory_full")` → "INVENTORY FULL" red at player
- Wire `auto_gather_failed(&"tool_gated")` → "REQUIRES [TOOL]" red at player
- Wire `auto_defend_triggered` → "-N" red at fauna position (stub — no fauna yet)
- Wire `recipe_discovered` → HUD NotificationManager: "New recipe: Stone Axe!"
- Wire `craft_completed` → success feedback (flash, sound hook)
- **Fly-to-player visual:** on gather complete, temporary sprite/label tweens from
  resource world_pos to Player.position (CURRENT) over ~0.3s, then queue_free
- Sound hook: gather "ding" placeholder AudioStreamPlayer at player position

**Criteria:**
- [ ] "+1 Wood" green floating text at player on auto_gather_completed
- [ ] "INVENTORY FULL" red on auto_gather_failed (inventory_full)
- [ ] "REQUIRES [TOOL]" red on auto_gather_failed (tool_gated)
- [ ] Damage text at fauna position on auto_defend_triggered (verified with mock)
- [ ] Fly-to-player tweens to CURRENT player position (not gather-start position)
- [ ] Fly-to-player sprite queue_free after tween completes (no lingering nodes)
- [ ] "New recipe!" notification on recipe_discovered
- [ ] Success feedback on craft_completed
- [ ] All existing tests pass
- [ ] Build passes with zero warnings

---

### task-023: Integration Test — Core Loop End-to-End [TEST]

**Source:** AC3 + AC4

**Scope:**
Integration tests verifying the complete core loop:
- explore → scan (delivery-002) → catalog → auto-gather → craft → unlock gated resources
- AC3 full coverage: uncataloged inert, scan→catalog→auto-gather, tool-gated, depletion, respawn
- AC4 full coverage: workbench recipe visibility, greyed insufficient, discovery on gather,
  craft produces tool
- Chain gathering: walk through multiple resources, auto-gather fires sequentially
- Tool gating round-trip: craft pickaxe → ore now auto-gatherable
- Respawn: depleted off-screen → timer → resource restored
- Stubs: no crash when FaunaManager / SurvivalSystem absent
- CraftButton: hidden without workbench, visible with workbench (test fixture)
- Panel mutual exclusion: Crafting + Inventory + Catalog
- Fly-to-player visual fires and cleans up
- Resource depletion → visual change in ResourceRenderer

**Criteria:**
- [ ] AC3 fully covered (uncataloged inert, scan→catalog→auto-gather, tool gate, depletion, respawn)
- [ ] AC4 fully covered (recipe visibility, greyed, discovery, craft → tool in slot)
- [ ] Chain gathering verified (sequential auto-gathers while walking)
- [ ] Tool gating round-trip: craft pickaxe → ore auto-gatherable
- [ ] Respawn: off-screen depleted → timer → restored
- [ ] Stubs safe: no crash without FaunaManager / SurvivalSystem
- [ ] CraftButton hidden/visible based on workbench proximity
- [ ] Panel mutual exclusion: 3 panels tested
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (016-023) — 3 parallel chains documented | /aid-detail |
