# delivery-005a: Engine Refactor — Lighting, Yields, Refinement, Inventory Weight

**Status:** Planning
**Created:** 2026-04-08
**Features:** TBD (likely new feature-016-lighting, feature-017-yield-system, feature-018-refinement-chains, feature-019-inventory-weight)
**Depends on:** delivery-004 (024-031) + delivery-004b (032b-039b) + post-PR#10 cleanup
**Cumulative state:** Engine ready for full survival gameplay loop — local lighting, multi-tool yields, world refinement chains, weighted inventory, robust consumables.

## Motivation

PR #10 (resource→prop rename) consolidated everything as Props but kept the implementation simplified — single yield per prop, integer `max_stack`, no tool variation. Fog of war was removed in post-PR#10 cleanup, leaving torches and campfires without in-game function. The full design from `docs/design/game-mechanics-redesign-2026-04-06.md` requires several engine extensions before delivery-005b (Night Falls) can deliver the intended gameplay loop:

- **Lighting:** torches/campfires need a real local brightness system to replace the deleted fog-reveal mechanic.
- **Weight-based inventory:** different props occupy different slot amounts (berries 0.01, firewood 2.0, crystal lump 3.0), not a flat "1 stack per item".
- **Yield tables:** chopping a tree bare-handed gives a twig; with a knife, wood; with an axe, a fallen_tree (Source). Same prop, different yields based on equipped tool.
- **Refinement chains:** Tree → Fallen Tree → Log → Firewood should replace the prop in place, not delete it.
- **Movable Sources:** large Sources (Log, Pile of Stones) need to be transportable via a Cart structure.
- **Robust consumables:** extend `is_consumable` beyond single-shot stat changes into buffs, delayed effects, cooldowns, HUD status icons.

These are all engine-level refactors. Delivery-005b (Night Falls — Building + Threats) will build on them. Splitting the work lets us land the engine changes cleanly and test them in isolation before stacking gameplay on top.

## Execution Graph

```
task-039 (Local Lighting System)         task-040 (Slot-based weight)
  │                                          │
  │                                          │
  │         task-041 (Yield Tables with Tool Variation)
  │           │
  │           ├──────────────┐
  │           ▼              ▼
  │       task-042        task-043
  │      (Refinement      (Movable + Cart
  │       Chains in        foundations)
  │       World)              │
  │           │               │
  │           └───────┬───────┘
  │                   │
  │   task-044 (Robust Consumables)
  │                   │
  └─────┬─────────────┘
        ▼
task-045 (Documentation cascade)
```

**Parallel groups:**
- task-039 (Lighting) ∥ task-040 (Slot weight) ∥ task-041 (Yield tables) ∥ task-044 (Consumables) — all independent of each other
- task-042 (Refinement chains) depends on task-041
- task-043 (Movable + Cart) depends on task-041
- task-045 runs LAST, after everything else

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 039 | Local Lighting System | IMPLEMENT | delivery-004b | 040, 041, 044 |
| 040 | Slot-based inventory weight (slot_size: float) | IMPLEMENT | delivery-004b | 039, 041, 044 |
| 041 | Yield Tables with Tool Variation | IMPLEMENT | delivery-004b | 039, 040, 044 |
| 042 | Refinement Chains in World | IMPLEMENT | 041 | 043, 044 |
| 043 | Movable flag + Cart system foundations | IMPLEMENT | 041 | 042, 044 |
| 044 | Robust Consumables | IMPLEMENT | delivery-004b | 039, 040, 041, 042, 043 |
| 045 | Documentation cascade | DOCS | 039, 040, 041, 042, 043, 044 | -- |

## Task Details

### task-039: Local Lighting System [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (lighting design), post-PR#10 cleanup

**Scope:**
- Replace the no-op torch/campfire `emit_light` flag with a real local lighting system
- Track structures and held items that emit light (torch, campfire, lantern, crystal clusters?)
- Each light source has a position (world coords) + radius + intensity
- At night, pass active light positions/radii to a shader that renders local brightness on the terrain + props + player
- Replaces the deleted fog-of-war reveal mechanism — gives meaning back to torches/campfires
- Fauna spawn exclusion from lighting system (see task-037 redesign in delivery-005b)
- New scene tree node: `LightingManager` (Node) — location TBD (autoload vs. child of World)
- Signals: `light_source_registered(id, position, radius)`, `light_source_unregistered(id)`, `light_source_moved(id, position)`

**Criteria:**
- [ ] Light sources register/unregister on structure placement/destruction
- [ ] Player-carried torch (if equipped) emits light at player position and moves with them
- [ ] At night, tiles near light sources visibly brighter than tiles far from them
- [ ] Day-time: lighting system has no visible effect (overridden by sun)
- [ ] Draw call budget preserved (shader-based, not per-light Node3D)
- [ ] Unit tests: register, unregister, move, query-lights-in-radius
- [ ] Build passes with zero warnings

---

### task-040: Slot-based Inventory Weight (slot_size: float) [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (weighted inventory)

**Scope:**
- Add `slot_size: float` field to `PropDef` (replaces or augments integer `max_stack`)
- `Inventory.add_item`, `Inventory.is_full`, `Inventory.get_used_slot_count` become float-based
- UI shows fractional remaining slots (e.g. "8.3 / 12 slots")
- Slot sizes per item (initial values from design doc, confirm with Andre):
  - Berry: 0.01
  - Wood: 1.0
  - Firewood: 2.0
  - Crystal Lump: 3.0
  - Stone: 1.0 (Andre mentioned 6 in conversation — TBD)
  - Log: 50.0 (too large for inventory — always a Source, see task-043)
- Items with `slot_size > max_total_slots` cannot enter inventory — they stay as Sources in the world (overflow behavior)
- `max_total_slots` starts at 12 (current), expands to 24 after Storage Chest (delivery-005b task-032)

**Criteria:**
- [ ] `PropDef.slot_size: float` field exists and loaded from data
- [ ] `Inventory.add_item` respects slot_size (adds fractional weight)
- [ ] `Inventory.is_full` returns true when remaining < new item slot_size
- [ ] UI displays fractional slot count accurately
- [ ] Items with slot_size > max_total_slots rejected from inventory with explanatory reason
- [ ] Backwards-compat: existing props without explicit slot_size default to 1.0
- [ ] Unit tests: add, remove, is_full, overflow rejection, fractional display
- [ ] Build passes with zero warnings

---

### task-041: Yield Tables with Tool Variation [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (yield tables)

**Scope:**
- Replace single `yield_type: StringName` on `PropDef` with a yield table dictionary keyed by tool id:
  ```
  yields: Dictionary = {
      &"bare": {result: &"twig", amount: Vector2i(1, 1), is_source: false},
      &"knife": {result: &"wood", amount: Vector2i(1, 2), is_source: false},
      &"axe": {result: &"fallen_tree", amount: Vector2i(1, 1), is_source: true},
  }
  ```
- `amount: Vector2i` → min/max roll (was fixed int)
- `is_source: bool` → true if the yielded prop replaces the source in world (see task-042) instead of going to inventory
- `AutoInteractionSystem.auto_gather` reads the table based on the player's currently equipped tool
- Falls back to `&"bare"` key if tool key not found
- New design examples (confirm with Andre):
  - Tree + bare → twig (Item, goes to inventory)
  - Tree + knife → wood (Item, goes to inventory)
  - Tree + axe → fallen_tree (Source, replaces tree in world)
  - Fallen Tree + axe → log (Source, replaces fallen_tree)
  - Log + saw → firewood (Item, goes to inventory, 2-4 pieces per log)

**Criteria:**
- [ ] `PropDef.yields` dictionary exists and loads from data
- [ ] auto_gather reads equipped tool and picks correct yield entry
- [ ] `&"bare"` fallback works when tool not listed
- [ ] Amount Vector2i min/max random roll works
- [ ] `is_source: false` yields go to inventory via existing Inventory.add_item
- [ ] `is_source: true` yields trigger prop replacement (see task-042)
- [ ] Unit tests: bare, knife, axe, fallback, min/max roll
- [ ] Build passes with zero warnings

---

### task-042: Refinement Chains in World [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (refinement chains)

**Scope:**
- When a yield has `is_source: true`, the source prop is REPLACED in world by the new prop at the same hex/sub_hex
- Chain example: Tree → Fallen Tree → Log → Firewood (only the last step yields an Item)
- `AutoInteractionSystem` detects `is_source: true` yields and emits `prop_replaced(old_prop, new_prop, coords, sub_hex)` instead of `prop_removed`
- `HexGrid.get_tile(coords).props` entry is updated in place (same index, new prop def)
- `PropRenderer` listens to `prop_replaced` and swaps the mesh at that sub_hex position without a full re-render
- Preserves any sub-hex-specific state (orientation, variation)

**Criteria:**
- [ ] `is_source: true` yield replaces prop in HexGrid.get_tile().props in place
- [ ] `prop_replaced` signal emitted with old + new + coords + sub_hex
- [ ] PropRenderer swaps mesh without flickering
- [ ] Chain can fire multiple times (Tree → Fallen Tree → Log → Firewood) as player keeps interacting
- [ ] Last step (Item yield) removes prop from world normally
- [ ] Unit tests: single replacement, chained replacement, final Item step
- [ ] Build passes with zero warnings

**Parallel with:** task-043

---

### task-043: Movable Flag + Cart System Foundations [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (movable Sources, cart)

**Scope:**
- Add `movable: bool` to `PropDef` — true for large Sources that can be carried (Log, Pile of Stones)
- Non-movable Sources (Tree, Boulder) stay in place and must be processed where they are
- New structure type: `Cart` — inventory-like storage attached to a structure prop
- Cart has its own slot capacity (e.g. 100 slots) separate from player inventory
- Player can push a Cart (new interaction): movable Sources near the Cart load into it on walk-up or drag
- Cart movement reduces player speed proportionally to load (e.g. 50% speed at full capacity)
- Cart is a Structure placeable via delivery-005b task-032 (Building data model) — confirm recipe with Andre
- UX for loading items onto cart: drag from inventory? walk-up interaction? **TBD**

**Criteria:**
- [ ] `PropDef.movable: bool` field exists
- [ ] Cart structure can be built from build panel (delivery-005b integration)
- [ ] Movable Sources can be loaded onto Cart (mechanism TBD)
- [ ] Cart has its own inventory-like storage
- [ ] Player speed scales with Cart load when pushing
- [ ] Non-movable Sources rejected from Cart loading
- [ ] Cart can be unloaded at base (back into player inventory or ground)
- [ ] Unit tests: movable check, load, unload, speed scaling
- [ ] Build passes with zero warnings

**Parallel with:** task-042

---

### task-044: Robust Consumables [IMPLEMENT]

**Source:** `docs/design/game-mechanics-redesign-2026-04-06.md` (consumables redesign)

**Scope:**
- Extend `is_consumable` from a flag with single-shot stat changes into a richer system
- New resource type: `ConsumableEffect` (Resource file, one per effect type)
- Effect kinds:
  - **Immediate stat change** (Berry: +5 hunger immediately) — current behavior, preserved
  - **Temporary buff** (Spicy Pepper: +10% movement speed for 60s)
  - **Delayed effect** (Toxic Berries: -10 HP applied after 30s, not immediately)
  - **Duration-based status** (with icon in HUD + countdown timer)
- Eat animation + cooldown (prevents spam-eating)
- Status icons in HUD with remaining time visible
- Buffs save in game state (with remaining time) so reload doesn't clear them
- Storage: `ConsumableEffect` resource files in `data/consumables/` OR inline dictionary in PropDef (**TBD with Andre**)

**Criteria:**
- [ ] `ConsumableEffect` resource defined with kind, magnitude, duration, delay
- [ ] Immediate effects still work (no regression)
- [ ] Temporary buffs apply, tick down, and expire correctly
- [ ] Delayed effects fire at correct time after eating
- [ ] HUD shows active effects with countdown timers
- [ ] Eat cooldown prevents spam
- [ ] Effects persist across save/load with remaining time
- [ ] Unit tests: immediate, buff, delayed, expiration, save/load
- [ ] Build passes with zero warnings

---

### task-045: Documentation Cascade [DOCS]

**Source:** All preceding tasks in delivery-005a

**Scope:**
- Update `.aid/knowledge/data-model.md` with:
  - `PropDef.slot_size: float`
  - `PropDef.yields: Dictionary` (tool → yield entry)
  - `PropDef.movable: bool`
  - `ConsumableEffect` resource schema
  - `LightingManager` data contract
- Update `.aid/knowledge/architecture.md` with:
  - LightingManager node in scene tree
  - Cart structure as special Structure sub-type
  - Refinement chain flow through AutoInteractionSystem
- Update `.aid/knowledge/module-map.md` with new script paths and responsibilities
- Update `.aid/knowledge/domain-glossary.md` with: slot_size, yield table, Source (vs Item), movable, refinement chain, ConsumableEffect, LightingManager, Cart
- Update `.aid/work-001-core/features/feature-inventory.md` with new features 016-019:
  - feature-016-lighting
  - feature-017-yield-system
  - feature-018-refinement-chains
  - feature-019-inventory-weight
- Scaffold feature SPEC stubs in `.aid/work-001-core/features/feature-016-lighting/`, etc.

**Criteria:**
- [ ] data-model.md reflects all new PropDef fields
- [ ] architecture.md reflects new scene tree + new systems
- [ ] module-map.md includes all new script paths
- [ ] domain-glossary.md has new terms
- [ ] feature-inventory.md has features 016-019
- [ ] SPEC stubs exist for 016-019 (can be minimal, flesh out during implementation)
- [ ] No broken internal links
- [ ] Commit message includes full list of updated knowledge files

---

## Open Questions (for Andre)

- **Slot sizes:** Andre mentioned Stone=6 slots and Tree Log=50 slots in conversation, but the design doc says Stone=1, Wood=1, Firewood=2. Confirm exact `slot_size` values per item — a full table is needed before task-040 can land.
- **Lighting cone:** per-light radius from `PropDef.light_radius`? Or a more complex falloff curve (quadratic, exponential)?
- **Fauna spawn rules without fog:** distance-based exclusion? Behind cliffs? At edge of map? At any tile not lit by a light source? (Feeds into delivery-005b task-037 redesign.)
- **Cart UX:** how does the player load items onto the cart? Drag from inventory? Walk-up interaction? Auto-load nearby movable Sources on proximity?
- **Consumable effect duration storage:** `ConsumableEffect` as `.tres` resource files or inline dictionary in `PropDef`?
- **Feature numbering:** are 016-019 the right numbers, or should they follow a different convention?

## Integration Contract

(Draft skeleton — Andre will refine)

### Scene Tree Additions
- `LightingManager` (Node) — child of World? Or autoload singleton? **TBD**
- No other persistent nodes expected (Cart is a structure instance, not a manager)

### New Autoloads
- None initially (unless LightingManager becomes autoload)

### Save Data Additions
- Light source positions + radii (if not derivable from structures alone)
- Active consumable effects with remaining time
- Cart inventories (per cart instance)
- Inventory weights (already covered by existing inventory save)

### Bootstrap Changes
- `LightingManager._ready()` → connects to `HexGrid.structure_placed/destroyed` + day/night signals
- `AutoInteractionSystem` → reads equipped tool from Player, queries yield table
- `Inventory` → float-based math throughout
- `PropRenderer` → listens to new `prop_replaced` signal

## Visual Smoke Test

(Skeleton — to be filled in after task definitions are firm)

- [ ] Place a torch at night → the torch tile and surrounding tiles brighten visibly
- [ ] Walk near the torch at night → player model lit; walk away → goes dark
- [ ] Inventory UI shows fractional slot count (e.g. "8.3 / 12 slots") after picking up berries
- [ ] Chop a tree with bare hands → twig in inventory
- [ ] Chop a tree with a knife → wood in inventory
- [ ] Chop a tree with an axe → tree replaced by fallen_tree at same position, no item in inventory
- [ ] Chop the fallen_tree with an axe → replaced by log (Source, cannot pick up, too heavy)
- [ ] Build a cart, push it near a log → log loads onto cart
- [ ] Push cart with load → player speed visibly reduced
- [ ] Eat spicy pepper → speed buff visible in HUD with countdown timer
- [ ] Eat toxic berries → no immediate effect, damage applied 30s later
- [ ] Save/load with active buffs → buffs persist with remaining time

## Out of Scope (explicitly excluded)

- Actual Night Falls gameplay (building + fauna) — that's delivery-005b
- New biomes, new prop types beyond what's needed to test the engine changes — future deliveries
- Balance tuning of slot sizes, yield amounts, buff durations — happens during delivery-005b playtest
- Art assets for Cart, new consumable effects — placeholder meshes only
- Multiplayer considerations — single-player MVP only

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-08 | Initial scope created. Split from delivery-005 to separate engine refactor from Night Falls gameplay. | Lola post-PR#10 review |
