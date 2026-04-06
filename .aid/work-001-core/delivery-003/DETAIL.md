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
- On `tile_entered`: check current tile + 6 neighbors (7 tiles total).
  **Implementation note:** Actual implementation uses world-space radius (`GATHER_RADIUS = 0.75`) with `_process` throttle (`PROXIMITY_CHECK_INTERVAL = 0.1s`) instead of pure tile-based checks. The 7-tile conceptual model is the same but the proximity geometry is circular, not hexagonal.
- Catalog gate: `Catalog.is_cataloged(RESOURCE_TO_ENTRY[node.type])` (CATALOGED state required for auto-gather; flora/mineral go UNKNOWN→CATALOGED directly so this works)
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
  - Tick `time_remaining` always (fog-based pausing removed in implementation — world heals steadily regardless of player position)
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
- [ ] Respawn timer always ticks (fog-based pausing removed)
- [ ] Respawn triggers at time_remaining ≤ 0, resets to max_amount
- [ ] `respawn_time == 0` → never enters queue
- [ ] Auto-defend cooldown decrements, blocks when > 0
- [ ] Auto-defend fires on adjacent ENCOUNTERED or CATALOGED hostile (mock FaunaManager)
- [ ] Auto-defend ignores passive fauna, ignores UNKNOWN fauna
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
- **Replaces PropRenderer** (delivery-002 placeholder): Delete `scripts/rendering/prop_renderer.gd`,
  `scenes/world/prop_renderer.tscn`, and remove from `main.tscn`. PropRenderer's generic category
  cubes are superseded by ResourceRenderer's per-type meshes.
- **PropLabelRenderer stays** — labels (❓/⚠️/name) serve resources AND future fauna.
  Signal source changes: labels now driven by ResourceRenderer signals instead of PropRenderer.
- **PropUtils stays** — shared offset/type-lookup utilities still used by PropLabelRenderer.

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
  - Recipe config: stone_axe (2W+1S, discovery_material=stone, tool_slot=axe, pre_discovered=true, requires_workbench=false),
    stone_pickaxe (3W+2S, discovery_material=stone, tool_slot=pickaxe, pre_discovered=true, requires_workbench=false)
  - `_discovered_recipes: Array[StringName]`
  - **MVP simplification:** Both recipes are `pre_discovered: true` (loaded at `_ready()`) and `requires_workbench: false` (craftable anywhere). Workbench gate and item-triggered discovery exist in code but are inactive for current recipes — they activate when post-MVP recipes are added.
  - Discovery: `_load_pre_discovered()` at startup. For future recipes: `Inventory.item_added` → check discovery_material match → append, emit `recipe_discovered`
  - Craft action: check `requires_workbench` flag → workbench proximity (if required) → already-owned block → ingredient check →
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
- CraftButton (64×64px) in HUD — hidden by default, visible permanently after first
  `recipe_discovered` signal (MVP: both recipes pre-discovered, so CraftButton shows at startup)
- `panel_opened` for mutual exclusion (5-panel list)
- Refreshes on `inventory_changed`, `craft_completed`, `recipe_discovered`

**Criteria:**
- [ ] CraftingPanel opens/closes on CraftButton tap
- [ ] CraftButton visible after first recipe discovered (permanently), hidden by default
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
- CraftButton: hidden by default, visible after recipe_discovered (MVP: pre-discovered at startup)
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
- [ ] CraftButton hidden/visible based on recipe_discovered signal
- [ ] Panel mutual exclusion: 3 panels tested
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-002):
- Player
  - AutoInteractionSystem (Node) — NEW
  - CraftingSystem (Node) — NEW
- World
  - ResourceRenderer (Node3D) — NEW, ~6 MultiMesh pools for resource visuals (replaces PropRenderer from delivery-002)
  - ~~PropRenderer~~ — REMOVED (superseded by ResourceRenderer)

### Bootstrap Changes
- AutoInteractionSystem._ready() → connects to HexGrid.tile_entered for proximity checks
- AutoInteractionSystem queries Catalog.is_cataloged() before any auto-gather
- CraftingSystem._ready() → connects to Inventory.item_added for recipe discovery
- CraftButton becomes visible on first `recipe_discovered` signal (permanently). MVP: both recipes pre-discovered at startup.

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-002 still works
- [ ] Walk near a cataloged resource → gather animation starts → resource flies to player → inventory updates
- [ ] Walk near uncataloged resource → nothing happens (must scan first)
- [ ] Resources deplete visually after gathering
- [ ] Place workbench (if building exists, otherwise skip) → Craft button appears
- [ ] Open Craft panel → recipes show with ingredient counts (green=have, red=need)
- [ ] Craft Stone Axe → materials consumed, tool appears in tool slot

### Dev Environment
No additional requirements beyond delivery-001.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (016-023) — 3 parallel chains documented | /aid-detail |
| 2026-04-02 | Scan redesign: task-017 catalog gate uses `is_cataloged` (CATALOGED only for auto-gather). task-018 auto-defend fires on ENCOUNTERED or CATALOGED hostile. | /scan-redesign-apply |
| 2026-04-04 | [NOTE] Architecture update: tile data model now uses unified `tile.props[]` array and sub-hex grid. Resources are props with `category="resource"`. Auto-interaction queries props instead of `tile.resource_nodes`. Tasks already implemented — this note is for future reference. | /arch-update |
