# delivery-005a: Engine Refactor — Props, Recipes, Lighting, Inventory Weight

**Status:** Approved (design phase complete, implementation pending)
**Created:** 2026-04-08
**Last revised:** 2026-04-08 (full task list rewritten after Props/Recipes design conversation)
**Features:** TBD (see §Open Questions for feature numbering)
**Depends on:** delivery-004 (024-031) + delivery-004b (032b-039b) + post-PR#10 cleanup
**Cumulative state:** Engine ready for full survival gameplay loop — composable Props, unified Recipe system, weight-based Inventory, local lighting. Crafting/cooking/refining/gathering/consuming/burning/decaying/growing all run through the same Recipe machinery.

> **Authoritative design doc:** `DESIGN.md` in this directory. The decisions, capability set, Recipe shape, predicate vocabulary, discovery model, worked examples, runtime semantics, and migration plan are all specified there. This file is the *task plan* for executing that design. **If `DESIGN.md` and `DETAIL.md` ever disagree, `DESIGN.md` is authoritative** — bring `DETAIL.md` back into alignment, not the other way around.

## Motivation

PR #10 (resource→prop rename) consolidated everything as Props but kept the implementation simplified — single yield per prop, integer `max_stack`, no tool variation. Fog of war was removed in post-PR#10 cleanup, leaving torches and campfires without in-game function.

The original delivery-005a scope (tasks 039–045) listed several engine extensions individually: slot weight, yield tables, refinement chains, movable+cart, robust consumables. During the 2026-04-08 design conversation, we recognized that **all five of those features collapse into a unified Recipe system** sitting alongside a leaner capability-based PropDef. The collapse simplifies the model substantially while making it more flexible:

- Crafting, gathering, refining, cooking, eating, drinking, burning, decaying, growing, and trap-firing all become **Recipes** — first-class objects with the same shape, varying only in which fields are populated.
- The previous `Category` enum (mixing biological taxonomy with functional role) is replaced by composable **capabilities** + free-form **tags** + a UI-only **`category_tag`** label.
- The old "yield tables with tool variation" is just a Recipe with a `has_tool` condition predicate.
- The old "refinement chains" is just a sequence of Recipes whose outputs feed each other's inputs.
- The old "movable + cart" is two orthogonal capabilities (`MOVABLE` + `CONTAINER`).
- The old "robust consumables" is just per-prop Recipes (`eat_berry`, `drink_water`, `burn_log`) with `outputs: []` and `effects` for stat deltas.

The local lighting system survives as its own task (it's independent of the Recipe refactor — it's a renderer + day/night integration, not a Prop concern).

The full design rationale, decisions, and worked examples are in `DESIGN.md`.

## Execution Graph

```
task-039 (Local Lighting System)        task-046 (PropDef refactor)
   │                                       │
   │                                       ▼
   │                                    task-047 (Recipe schema + parser)
   │                                       │
   │                                       ├──────────────┐
   │                                       ▼              ▼
   │                                    task-048      task-049
   │                                    (Predicate    (Inventory
   │                                     Evaluator)    weight refactor)
   │                                       │              │
   │                                       └──────┬───────┘
   │                                              ▼
   │                                       task-050 (Recipe Runtime
   │                                                + Discovery Watcher)
   │                                              │
   │                                              ▼
   │                                       task-051 (Migrate
   │                                                AutoInteraction +
   │                                                Catalog hooks)
   │                                              │
   └──────────────────────┬──────────────────────┘
                          ▼
                  task-052 (Documentation cascade)
```

**Parallel groups:**
- task-039 (Lighting) runs entirely in parallel with the whole Recipe stack (independent subsystem)
- task-048 (Predicate Evaluator) and task-049 (Inventory weight) can be developed in parallel after task-047 (Recipe schema) lands
- task-050 (Recipe Runtime) depends on 047 + 048 + 049
- task-051 (AutoInteraction migration) depends on 050
- task-052 (Doc cascade) runs LAST, after everything else

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 039 | Local Lighting System | IMPLEMENT | delivery-004b | All other 005a tasks |
| 046 | PropDef refactor — capabilities + tags + category_tag | IMPLEMENT | delivery-004b + post-PR#10 | 039 |
| 047 | Recipe schema + parser (Resource type, .tres loader, RecipeRegistry) | IMPLEMENT | 046 | 039 |
| 048 | Predicate Evaluator (query item) | IMPLEMENT | 047 | 049, 039 |
| 049 | Inventory weight refactor | IMPLEMENT | 046 | 048, 039 |
| 050 | Recipe Runtime + Discovery Watcher | IMPLEMENT | 047, 048, 049 | 039 |
| 051 | Migrate AutoInteractionSystem + Catalog hooks | IMPLEMENT | 050 | 039 |
| 052 | Documentation cascade | DOCS | 039, 046, 047, 048, 049, 050, 051 | -- |

## Task Details

### task-039: Local Lighting System [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (lighting design), post-PR#10 cleanup

**Status note:** Unchanged from the previous delivery-005a draft. This task is independent of the Recipe refactor.

**Scope:**
- Replace the no-op torch/campfire `emit_light` flag with a real local lighting system
- Track props with the `EMITS_LIGHT` capability that are currently active (per their instance state, e.g. `is_lit: bool` on the fireplace prop)
- Each light source has a position (world coords) + radius + intensity (from capability fields)
- At night, pass active light positions/radii to a shader that renders local brightness on the terrain + props + player
- Replaces the deleted fog-of-war reveal mechanism — gives meaning back to torches/campfires
- Player-carried torch (if equipped/PORTABLE + EMITS_LIGHT) emits light at player position and moves with them
- New scene tree node: `LightingManager` (autoload candidate) — owns the active light source registry
- Signals: `light_source_registered(prop, position, radius)`, `light_source_unregistered(prop)`, `light_source_moved(prop, position)`

**Criteria:**
- [ ] Light sources register/unregister when EMITS_LIGHT props are placed/destroyed/state-toggled
- [ ] Player-carried torch emits light at player position and moves with them
- [ ] At night, tiles near light sources visibly brighter than tiles far from them
- [ ] Day-time: lighting system has no visible effect (overridden by sun)
- [ ] Draw call budget preserved (shader-based, not per-light Node3D)
- [ ] Unit tests: register, unregister, move, query-lights-in-radius
- [ ] Build passes with zero warnings

---

### task-046: PropDef refactor — capabilities + tags + `category_tag` [IMPLEMENT]

**Source:** `DESIGN.md` §3 (PropDef)

**Scope:**
- Replace `Category` enum's behavioral role. The enum may be retained as a typedef for `category_tag` values, or removed in favor of free-form `StringName` (decision: see Open Questions §1).
- Add the following fields to `PropDef`:
  - `tags: Array[StringName]` — free-form tag list (e.g. `BURNABLE.log`, `CONSUMABLE.edible`, `WOOD`, `METAL.iron`)
  - `category_tag: StringName` — purely for Catalog UI grouping (replaces behavioral use of `Category`)
  - **Capability fields** (each is a small inner Resource or Dictionary, `null`/empty when not present):
    - `portable: PortableCap` — `{ weight: float }`
    - `placeable: PlaceableCap` — `{ footprint: Vector2i, blocks_movement: bool, rotation_snap: int }`
    - `container: ContainerCap` — `{ capacity_weight: float, accepts_filter: Array[StringName] }`
    - `emits_light: LightCap` — `{ radius: float, color: Color, flicker: bool }`
    - `movable: MovableCap` — `{ push_cost: float }`
    - `station: StationCap` — `{ station_tags: Array[StringName] }`
    - `catalogable: CatalogableCap` — `{ scan_time: float, display_tag: StringName }`
- Migrate existing `data/props/*.tres` to fill in the new fields. Most props will need PORTABLE + PLACEABLE + CATALOGABLE entries derived from their old fields. Cross-check every existing prop.
- Update the editor (`tools/level-editor/js/prop-editor.js`) to read/write the new fields. Unknown-field passthrough (added in Fase 1 audit) protects against data loss during the transition; the editor will ignore the new fields until updated.
- Remove old fields that are now superseded (`yield_type`, `is_consumable`, `light_radius` if loose, `gather_time`, etc.) **only after** task-051 has migrated their consumers.

**Criteria:**
- [ ] All capability fields exist on `PropDef` and load from `.tres`
- [ ] `tags` and `category_tag` exist and load
- [ ] All existing prop `.tres` files migrated; `957/957` Godot tests still pass
- [ ] Editor reads/writes capability fields without losing data on round-trip
- [ ] Old `Category` enum behavioral references in code identified and tagged with `# REMOVE in task-051` comments (don't remove yet — that's task-051's job)
- [ ] Unit tests: capability presence/absence, tag membership, category_tag round-trip
- [ ] Build passes with zero warnings

---

### task-047: Recipe schema + parser (RecipeRegistry) [IMPLEMENT]

**Source:** `DESIGN.md` §4 (Recipe shape) + §8.1 (Recipe matching indexes)

**Scope:**
- New Resource: `scripts/recipes/recipe.gd` (extends Resource) with the fields specified in `DESIGN.md` §4.1:
  - `id: StringName`
  - `kind: int` (Assemble/Transform/Breakdown/Combine enum)
  - `inputs: Array[RecipeInput]`
  - `outputs: Array[RecipeOutput]`
  - `effects: Array[RecipeEffect]`
  - `conditions: Array[RecipeCondition]`
  - `actions: Array[StringName]`
  - `time: float`
  - `unlock_when: Array[Predicate]`
- Inner resource types: `RecipeInput { ref_or_tag: StringName, count: int, source: StringName }`, `RecipeOutput { prop_ref: StringName, count: int, prob: float }`, `RecipeEffect { kind: StringName, params: Dictionary }`, `RecipeCondition { predicate: Predicate, must_sustain: bool }`, `Predicate { kind: StringName, params: Dictionary }`.
- New autoload: `RecipeRegistry` — scans `data/recipes/*.tres` at startup, builds the indexes from `DESIGN.md` §8.1:
  - by input ref → recipes consuming it
  - by input tag → recipes consuming it
  - by station tag → recipes using it
  - by player action → recipes triggered by it
  - by watched predicate kind → recipes whose conditions reference it
- Provide query API: `find_recipes_for_input(prop_ref) -> Array[Recipe]`, `find_recipes_for_action(action) -> Array[Recipe]`, etc.
- Add `data/recipes/` directory and seed it with the **6 canonical examples** from `DESIGN.md` §7 (`eat_berry`, `chop_small_tree`, `cook_meat`, `craft_trap`, `trap_fires`, `meat_rots`, `burn_log_in_fireplace`) — these double as test fixtures.

**Criteria:**
- [ ] `Recipe` resource type loads from `.tres`
- [ ] `RecipeRegistry` autoload registered in `project.godot` after `PropRegistry`
- [ ] All 6 canonical example recipes load without errors
- [ ] Query API returns expected matches for each example
- [ ] Indexes built correctly (verify by inspecting `find_recipes_for_input(berry)` returns `[eat_berry]`)
- [ ] Unit tests: load, parse, index build, query by input/action/station
- [ ] Build passes with zero warnings

---

### task-048: Predicate Evaluator (query item) [IMPLEMENT]

**Source:** `DESIGN.md` §5 (Condition predicate vocabulary) + §8.4 (Predicate evaluator)

**Scope:**
- New RefCounted: `scripts/recipes/predicate_evaluator.gd`
- Single static method: `evaluate(predicate: Dictionary, ctx: WorldContext) -> bool`
- `WorldContext` is a small RefCounted that exposes the data the evaluator needs: player ref, current tile, current station, current containers, current world state. Constructed by callers with whatever subset they have available.
- Implement each predicate kind from `DESIGN.md` §5:
  - `has_tool`, `at_station`, `at_tile_type`, `player_stat`, `player_skill` (stub for now if skills don't exist), `player_knows_recipe`, `time_of_day`, `weather` (stub if no weather system), `biome`, `adjacent_to`, `prop_state`, `world_flag`, `animal_nearby`, `container_has`, `cataloged`
- Each predicate kind has its own handler function. Dispatch on `predicate.kind`.
- Predicates not yet implementable (skills, weather) return `false` and emit a warning so they don't silently pass.
- Unit tests for every predicate kind, both true and false branches.

**Criteria:**
- [ ] Every predicate kind from `DESIGN.md` §5 has a handler
- [ ] Stub predicates (skills, weather) emit warnings, return false
- [ ] Unit tests cover every predicate kind, both branches
- [ ] Performance: single predicate eval < 0.01 ms (measured in test)
- [ ] Build passes with zero warnings

---

### task-049: Inventory weight refactor [IMPLEMENT]

**Source:** `DESIGN.md` §9.2 (Inventory changes)

**Scope:**
- Refactor `scripts/inventory/inventory.gd` from slot-count-based to weight-based.
- Add `capacity_weight: float` (initial value 50.0; expandable later by storage props or skills).
- Add `current_weight: float` — computed each query OR cached and updated incrementally (decision: see Open Questions §2).
- `add_item(prop, count)` checks `current_weight + (prop.portable.weight * count) <= capacity_weight`. Returns success/fail + actual count added.
- `remove_item(prop, count)` decrements normally; updates weight.
- Items grouped by `prop_id` for stack display (UI shows N stacks, not N slots).
- UI shows weight bar (`current / capacity`) instead of slot count, plus per-stack counts.
- Items with `PORTABLE.weight > capacity_weight` cannot be picked up at all and remain in the world (must be transported via MOVABLE + CONTAINER props like Cart).
- Backwards compat: existing props without explicit `PORTABLE.weight` default to `1.0`.
- Update HUD/inventory UI to show weight + stacks.

**Criteria:**
- [ ] Inventory holds props with weight-based math, not slot count
- [ ] `current_weight` updated correctly on add/remove
- [ ] `is_full(prop, count)` returns true when adding would exceed capacity
- [ ] Items grouped by prop_id for display
- [ ] HUD shows weight bar + stack counts
- [ ] Items with weight > capacity rejected with reason
- [ ] Backwards-compat: existing props without weight default to 1.0
- [ ] Unit tests: add, remove, full check, overflow rejection, stack grouping
- [ ] Save/load preserves weight state correctly
- [ ] Build passes with zero warnings

---

### task-050: Recipe Runtime + Discovery Watcher [IMPLEMENT]

**Source:** `DESIGN.md` §8 (Runtime model) + §8.5 (Discovery watcher)

**Scope:**
- New autoload: `RecipeRuntime` (Node) — owns the pending recipe queue, tick loop, matching logic, sustain checks, resolution.
- Public API:
  - `try_start_recipe(recipe: Recipe, ctx: WorldContext) -> PendingRecipe | null` — match conditions, bind inputs, enqueue if conditions pass.
  - `cancel_recipe(pending: PendingRecipe, reason: StringName)` — return inputs, emit cancel signal.
  - `tick(delta: float)` — advance pending recipes, re-check sustains, resolve at deadline.
- `PendingRecipe` is a small Resource:
  ```
  PendingRecipe {
    recipe: Recipe
    start_time: float
    bound_inputs: Array[PropInstance]
    bound_station: PropInstance | null
    triggering_actor: Node | null   # usually Player
  }
  ```
- Pending recipes stored in two locations:
  - **On the relevant station/prop instance** for "this station is currently cooking" (queryable for HUD)
  - **In a global queue** for world-level passive recipes (`trap_fires`, `meat_rots`, `regrow_*`)
- On resolve:
  1. Remove inputs from their source (player inventory, container, world tile)
  2. Spawn outputs (each independent prob roll)
  3. Apply effects (delegate to effect handlers in §8.4 of DESIGN.md)
  4. Remove from pending queue
  5. Emit `recipe_resolved(recipe_id, outputs, effects)` signal
- On cancel: return inputs (default policy), remove from queue, emit `recipe_cancelled(recipe_id, reason)`.
- New autoload: `DiscoveryWatcher` (Node) — owns the player's known-recipes list (saved to game state), listens to global signals that might cause an `unlock_when` predicate to flip true:
  - `Catalog.entry_cataloged(prop_id)` → check recipes referencing `cataloged(prop_id)`
  - `Inventory.tool_equipped(tool_id)` → check `has_tool` unlocks
  - `WorldFlags.flag_changed(name, value)` → check `world_flag` unlocks
  - Recipe `grant_recipe` effects → directly add to known list
- Emit `recipe_unlocked(recipe_id)` for HUD feedback.
- **Cancellation policy for delivery-005a:** `cancel_return` only (return inputs to source). Pause-resume and cancel-destroy are deferred to a future delivery.

**Criteria:**
- [ ] `RecipeRuntime` autoload registered after `RecipeRegistry`
- [ ] `try_start_recipe` correctly matches and enqueues
- [ ] Pending recipes tick down correctly
- [ ] Sustain failure cancels and returns inputs
- [ ] Resolve produces outputs (with prob rolls) and applies effects
- [ ] `DiscoveryWatcher` autoload registered after `RecipeRegistry`
- [ ] Player starts with known list = recipes whose `unlock_when` is empty
- [ ] Catalog event triggers correct unlocks
- [ ] Tool equip triggers correct unlocks
- [ ] Save/load preserves known list AND pending recipes
- [ ] Unit tests: every example recipe (eat_berry, chop_small_tree, cook_meat, craft_trap, trap_fires, meat_rots, burn_log) — start, tick, resolve, cancel
- [ ] Integration test: `cook_meat` cancels mid-cook when fire goes out (sustain failure)
- [ ] Build passes with zero warnings

---

### task-051: Migrate AutoInteractionSystem + Catalog hooks [IMPLEMENT]

**Source:** `DESIGN.md` §9.4 (AutoInteractionSystem changes) + §9.5 (Catalog interaction)

**Scope:**
- Refactor `scripts/auto_interaction/auto_interaction_system.gd`:
  - Remove direct knowledge of "yield tables," "tool gates," "respawn queues," and other concepts now handled by `RecipeRuntime`.
  - On player approach to a prop: query `RecipeRegistry.find_recipes_for_input(prop_id)`. Filter by player's known list. Filter by which recipes' conditions currently pass (`PredicateEvaluator`). Present matching recipes to player (HUD prompt or auto-start, per UX policy).
  - On player action: emit player action event into `RecipeRuntime` (which will look up recipes triggered by that action).
  - The current "respawn queue" becomes a passive recipe: `regrow_berry_bush` with `inputs: [depleted_berry_bush]`, `time: <regrow_seconds>`, `outputs: [berry_bush]`. Move existing respawn data into `data/recipes/regrow_*.tres` files.
  - Remove old `_find_gather_candidates`, `auto_gather` flow, etc. — replaced by recipe matching.
- Add `Catalog.entry_cataloged(prop_id)` signal emission (if not already present) and wire it to `DiscoveryWatcher`.
- Update existing tests to use the new flow. Some tests will need to be rewritten to set up Recipe fixtures instead of directly calling `auto_gather`.
- **Now** remove the old `Category` enum behavioral references that were tagged in task-046.

**Criteria:**
- [ ] AutoInteractionSystem no longer has its own gather logic; delegates to RecipeRuntime
- [ ] Player approach to a known prop offers matching recipes
- [ ] Player action triggers correct recipe via RecipeRuntime
- [ ] Respawn queue migrated to passive `regrow_*` recipes
- [ ] Catalog entry signal wired to DiscoveryWatcher
- [ ] Old `Category` enum behavioral refs removed (only `category_tag` remains, and only for Catalog UI)
- [ ] All 957/957 existing Godot tests still pass (some rewritten as needed)
- [ ] Visual smoke test (see below) passes manually
- [ ] Build passes with zero warnings

---

### task-052: Documentation Cascade [DOCS]

**Source:** All preceding tasks in delivery-005a + `DESIGN.md`

**Scope:**
- Update `.aid/knowledge/data-model.md`:
  - PropDef capability fields (PORTABLE, PLACEABLE, CONTAINER, EMITS_LIGHT, MOVABLE, STATION, CATALOGABLE)
  - PropDef `tags`, `category_tag`
  - `Recipe` resource schema + entry types (RecipeInput, RecipeOutput, RecipeEffect, RecipeCondition, Predicate)
  - `PendingRecipe` resource schema
  - Inventory weight-based model
  - Player known-recipes list
- Update `.aid/knowledge/architecture.md`:
  - `RecipeRegistry`, `RecipeRuntime`, `DiscoveryWatcher`, `LightingManager`, `PredicateEvaluator` in scene tree / autoload section
  - New flow diagrams: recipe matching, recipe execution lifecycle, discovery watcher
  - Note that AutoInteractionSystem now delegates to RecipeRuntime
- Update `.aid/knowledge/api-contracts.md`:
  - `Recipe.kind`, `RecipeInput`, `RecipeOutput`, `RecipeEffect`, `RecipeCondition`, `Predicate` schemas
  - `RecipeRegistry` query API
  - `RecipeRuntime` public API + signals (`recipe_resolved`, `recipe_cancelled`)
  - `DiscoveryWatcher` signals (`recipe_unlocked`)
  - Predicate vocabulary table
- Update `.aid/knowledge/coding-standards.md`:
  - Convention for naming Recipe `.tres` files
  - Convention for naming Predicate kinds
- Update `.aid/knowledge/known-issues.md`:
  - Move resolved items
  - Add any new known issues uncovered during implementation
- Update `.aid/knowledge/feature-inventory.md` if features are added (see Open Questions §3)
- Add a brief section to `.aid/knowledge/architecture.md` pointing to `DESIGN.md` as the load-bearing spec
- Update `.aid/work-001-core/PLAN.md` build order section for delivery-005a to match the new task list

**Criteria:**
- [ ] All knowledge docs reflect new model
- [ ] No lingering references to `Category` enum as a behavioral switch (only as `category_tag` for UI)
- [ ] No lingering references to `is_consumable`, `yield_type`, `gather_time`, etc., that were absorbed by Recipes
- [ ] PLAN.md build order matches DETAIL.md task list
- [ ] DESIGN.md cross-linked from at least one knowledge doc
- [ ] No broken internal links
- [ ] Commit message lists all updated knowledge files

---

## Open Questions (for Andre)

These are unresolved items deliberately surfaced for Andre's call before or during implementation. Some are in DESIGN.md §11; the rest are task-specific.

1. **`category_tag` enum or StringName?** DESIGN.md §11 question 7. Lean: StringName for now, switch to enum later only if needed. Affects task-046.
2. **`current_weight` cached or computed?** DESIGN.md §11 question 2. Lean: cached, updated incrementally. Affects task-049.
3. **Feature numbering for the new systems.** Should we add features 016 (Lighting), 017 (Recipe System), 018 (Inventory Weight) — or treat them as engine refactors not warranting feature numbers? Affects task-052.
4. **Cancellation policy.** DESIGN.md §11 question 1 — pause-resume vs reset-on-cancel for `meat_rots`. Lean: ship with `cancel_return` only in delivery-005a; pause-resume is a follow-up. Affects task-050.
5. **Sub-recipe input sourcing.** DESIGN.md §11 question 3. The `source: container` field on inputs needs formalization. Affects task-047.
6. **Recipe collision resolution.** DESIGN.md §11 question 4. How does the UI present multiple eligible recipes? Quick-pick menu? Affects task-051.
7. **Save/load of pending recipes.** DESIGN.md §11 question 6. Stable IDs for bound inputs/stations across save/load. Affects task-050.
8. **Migration order.** Should task-046 (PropDef refactor) land in a single commit, or should each capability be migrated incrementally? Single commit is cleaner; incremental is safer. Lean: single commit with thorough test coverage.
9. **Catalog UI for un-discovered recipes.** DESIGN.md §11 question 5. "?? recipe" placeholders or no entry? Lean: no entry. Affects task-051.

## Integration Contract

(Refined skeleton — Andre will provide final values)

### Scene Tree / Autoload Additions

- `RecipeRegistry` (autoload, after `PropRegistry`) — scans `data/recipes/` at startup
- `RecipeRuntime` (autoload, after `RecipeRegistry`) — owns pending queue + tick loop
- `DiscoveryWatcher` (autoload, after `RecipeRegistry`) — owns known-recipes list, listens for unlocks
- `LightingManager` (autoload candidate, or child of World) — task-039 only

### Save Data Additions

- Player's known-recipes list (Array[StringName])
- Pending recipes queue (Array[PendingRecipe], with stable IDs for bound props)
- Inventory `current_weight` (or rebuilt from contained props on load)
- Light source instance state (e.g. `is_lit: bool` per fireplace) — likely already covered by per-prop instance state

### Bootstrap Changes

- Autoload order: PropRegistry → HexGrid → DayNightCycle → SaveManager → **RecipeRegistry → RecipeRuntime → DiscoveryWatcher → LightingManager**
- `AutoInteractionSystem._ready()` connects to `RecipeRuntime`
- `Catalog._ready()` emits `entry_cataloged` signal when an entry is discovered (if not already wired)
- `Inventory._ready()` emits `tool_equipped` signal when a tool slot is filled

## Visual Smoke Test

After delivery-005a is fully landed:

- [ ] Pick up first berry → `eat_berry` recipe unlocks (HUD notification) → eating gives +5 hunger
- [ ] Equip axe + walk to a cataloged small_tree → `chop_small_tree` recipe unlocks → chopping yields wood + branches
- [ ] Build a fireplace → light it (separate recipe) → place raw_meat near fire → `cook_meat` starts → after 15s, cooked_meat appears
- [ ] During cook_meat, walk away from fire (lose `at_station` sustain) → recipe cancels → raw_meat returned to player
- [ ] During cook_meat, fire goes out (sustain on `prop_state(fireplace, is_lit)`) → recipe cancels → raw_meat returned
- [ ] Craft a trap (`craft_trap` recipe) → place it → small fauna walks within range → trap fires → trapped_animal + branch + fiber dropped, trap consumed
- [ ] Leave cooked_meat at ambient temperature for an in-game day → `meat_rots` resolves → rotten_meat
- [ ] Place log inside fireplace's container → `burn_log_in_fireplace` runs passively → fire stays lit + light radius active for 60s → ash produced
- [ ] Inventory shows weight bar (e.g. "32.5 / 50.0") and grouped stacks
- [ ] Try to pick up a Log (50 weight) when inventory is at 10/50 → fails with "too heavy" feedback
- [ ] Save game mid-cook → load game → cooking continues from where it was
- [ ] Save game with active fire → load game → fire still lit, light still emitting
- [ ] At night, walk near a lit fireplace → terrain visibly brighter; walk away → goes dark

## Out of Scope (explicitly excluded)

- Actual Night Falls gameplay (building + fauna AI) — that's delivery-005b
- Cart UX details (drag-drop loading, push-mechanics tuning) — delivery-005b after CONTAINER + MOVABLE foundations are in place
- Recipe difficulty tiers, skill-based prerequisites, partial discovery hints — future scope
- NPC-taught recipes / scroll unlock content — supported by the model (via `world_flag` and `grant_recipe` effect) but no content ships
- Pause-resume sustain failure (only `cancel_return` ships in 005a)
- Loot table grouping (only independent prob rolls ship in 005a)
- Output count ranges (3..5 berries) — use multiple outputs with prob, or fixed counts
- Battery usage counters / charge state on instances
- Balance tuning of weights, recipe times, drop rates — happens during delivery-005b playtest
- Multiplayer considerations — single-player MVP only

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-08 | Initial scope created. Split from delivery-005 to separate engine refactor from Night Falls gameplay. Tasks 039-045. | Lola post-PR#10 review |
| 2026-04-08 | **Full task list rewritten** after Props/Recipes design conversation. Tasks 040-044 collapsed into a unified Recipe system (tasks 046-051). Task 039 (Lighting) preserved. Task 045 → 052 (Doc cascade). Authoritative spec moved to `DESIGN.md`. | Andre + Lola design conversation |
