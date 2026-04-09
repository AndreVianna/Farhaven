# delivery-005a: Props & Recipes — Design

**Status:** Approved (design phase complete, implementation pending)
**Created:** 2026-04-08
**Authors:** Andre Vianna + Lola (design conversation, 2026-04-08)
**Supersedes:** the original task-040..044 scope in `DETAIL.md` (slot weight, yield tables, refinement chains, robust consumables — all collapse into the unified Recipe system described here)

> This document is the load-bearing spec for delivery-005a. The implementation tasks in `DETAIL.md` were rewritten to match this design. If `DETAIL.md` and `DESIGN.md` ever disagree, **`DESIGN.md` is authoritative** and `DETAIL.md` should be brought back into alignment.

---

## TL;DR

Farhaven's Prop model is reorganized along two clean axes:

1. **PropDef** carries a set of small, orthogonal **capabilities** (PORTABLE, PLACEABLE, CONTAINER, EMITS_LIGHT, MOVABLE, STATION, CATALOGABLE) plus free-form **tags** and a UI-only **category_tag**. The previous `Category` enum (PLANT/MINERAL/.../STORAGE) was mixing "what the thing is" with "what role it plays" — that tension is resolved by splitting category-as-data (tags + label) from behavior-as-composition (capabilities).

2. **Recipe** becomes a first-class entity, completely separate from Prop. A Recipe is "an algorithm that transforms props" — it has typed inputs, outputs (with probability), non-prop effects (stat deltas, light, sound), conditions (gate + sustain predicates), player actions, time-to-cook, and unlock conditions. Crafting, gathering, refining, cooking, eating, burning, decaying, and growing all run through the same Recipe machinery — they only differ in which fields are populated. Recipes index themselves onto props by querying inputs, so a Prop never needs to know what recipes use it.

The result is a small, composable engine in which adding new gameplay almost never requires touching code — just adding a new `.tres` for a Prop or a Recipe.

---

## 1. Why this redesign

### 1.1 The tension in the current model

After PR#10, `Prop.Category` is an enum with values like `PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE, STRUCTURE, VEHICLE, EQUIPMENT, STORAGE`. This enum is **mixing two different axes**:

- **Eixo A — what the thing is** (biological/material taxonomy): `PLANT`, `MINERAL`, `ANIMAL`, `FUNGI`, `LIQUID`, `OOZE`
- **Eixo B — what the thing does** (functional role in gameplay): `STRUCTURE`, `VEHICLE`, `EQUIPMENT`, `STORAGE`

A Berry Bush is a `PLANT` *and* a `STRUCTURE` (blocks movement, occupies tile space). A Cart is a `VEHICLE` *and* a `STORAGE` *and* a `STRUCTURE`. A Torch is `EQUIPMENT` (held) *and* a `STRUCTURE` (placed) *and* effectively `CONSUMABLE` (burns out). Every time we want a prop that "mixes categories," the enum forces a false single-choice.

### 1.2 The redesign in one sentence

> What a Prop **is** lives in tags + a UI label; what a Prop **can do** lives in a composable capability set; what *happens* with Props lives entirely in Recipes — first-class objects that the engine matches against the world.

---

## 2. Naming

- **`Prop`** — kept (not renamed to `Asset`). Reason: "Asset" is overloaded in Godot ("asset pipeline", `.tres`/`.mesh`/`.png` files), and the cost of a second massive rename two weeks after `resource→prop` (PR#10) is not worth the marginal clarity gain.
  - We use "Prop" expansively in this project: **a Prop is any first-class entity in the game world** — placeable, holdable, consumable, crafted, natural, structural, or anomalous. The "stage prop" connotation is intentionally broadened.
- **`PropDef`** — schema/template. One per prop type. Lives in `data/props/*.tres`.
- **`Prop`** (instance) — runtime data attached to a tile or held in a container. May carry per-instance state (rotation, sub-hex position, remaining charges if applicable).
- **`Recipe`** — new first-class entity. One per transformation. Lives in `data/recipes/*.tres`.

---

## 3. PropDef

### 3.1 Capability set

A `PropDef` carries any subset of the following capabilities. Capabilities are **orthogonal** and **composable** — a single PropDef can have any combination.

```
PORTABLE(weight: float)
    The prop can be carried in inventory. `weight` determines how much
    inventory capacity it occupies. Berries: 0.01. Stones: 6. Logs: 50
    (effectively non-portable for normal players).

PLACEABLE(footprint: Vector2i, blocks_movement: bool, rotation_snap: int)
    The prop can be placed in the world at a sub-hex position. `footprint`
    is the size in sub-hex cells. `blocks_movement` controls pathing.
    `rotation_snap` is the angle increment (e.g. 60° for hex-aligned, 0
    for free).

CONTAINER(capacity_weight: float, accepts_filter: tag_or_ref_list)
    The prop can hold other props inside it. `capacity_weight` is the max
    total `PORTABLE.weight` of contained props. `accepts_filter` optionally
    restricts what can go in (e.g. fireplace accepts only BURNABLE tags).

EMITS_LIGHT(radius: float, color: Color, flicker: bool)
    The prop emits light into the world while active. The lighting system
    queries props with this capability. Active state is governed by the
    prop's instance state (e.g. `is_lit: bool`) — not by EMITS_LIGHT itself.

MOVABLE(push_cost: float)
    The prop can be pushed across tiles by the player without being
    picked up. `push_cost` modifies player speed when pushing. Combines
    naturally with PORTABLE(high_weight) for "carts and crates."

STATION(station_tags: [StringName])
    The prop is a crafting/cooking/refining station. `station_tags` lists
    the station roles it fulfills (e.g. ["cook", "fire", "light"] for a
    fireplace, ["craft", "saw"] for a workbench). Recipes filter onto the
    station by querying these tags.

CATALOGABLE(scan_time: float, display_tag: StringName)
    The prop can be cataloged by the ScannerSystem. `scan_time` is the
    duration the player must hold scan. `display_tag` is the catalog
    section/icon (Flora, Fauna, Mineral, Anomaly, etc.).
```

**That's the entire capability set.** Every previous capability draft (CRAFTABLE, REFINABLE, BURNABLE, GATHERABLE, EDIBLE, DRINKABLE, GROWS, DECAYS, USABLE) was absorbed into the Recipe system.

### 3.2 Tags

A `PropDef` also carries a free-form list of `tags: [StringName]`. Tags are used by Recipe inputs that want to accept "any prop satisfying this label" rather than a specific ref. Examples:

- `BURNABLE.log` — log-shaped fuel
- `BURNABLE.kindling` — small fire-starting material
- `CONSUMABLE.edible` — food
- `CONSUMABLE.drinkable` — drink
- `METAL.iron`, `METAL.copper`
- `ORE.iron`, `ORE.copper`

Tags are namespaced for readability but are just StringNames at runtime. Adding a new tag = adding it to a PropDef and to any Recipe that wants to filter by it.

### 3.3 `category_tag` (implemented as the existing `catalog_category` field)

A single StringName per PropDef that the Catalog UI uses to group props for display ("flora", "fauna", "minerals", "anomalies", "survival", "crafting", "storage", etc.). **This field is purely for UI grouping and never controls behavior.**

> **Implementation note (from foundation audit, §13):** PropDef already has a field `catalog_category: StringName` in `scripts/data/prop_def.gd:28` with exactly this role. **The new model uses the existing field name `catalog_category` rather than introducing a new `category_tag` field.** Throughout this document, "category_tag" and "catalog_category" refer to the same thing — `catalog_category` is the canonical name in code.

### 3.4 Example PropDefs

```yaml
# data/props/berry.tres
id: berry
display_name: "Berry"
tags: [CONSUMABLE.edible]
category_tag: "flora"
capabilities:
  PORTABLE:   { weight: 0.01 }
  PLACEABLE:  { footprint: (1,1), blocks_movement: false, rotation_snap: 0 }
  CATALOGABLE:{ scan_time: 0.5, display_tag: "flora" }
```

```yaml
# data/props/log.tres
id: log
display_name: "Log"
tags: [BURNABLE.log, WOOD]
category_tag: "wood"
capabilities:
  PORTABLE:   { weight: 50.0 }
  PLACEABLE:  { footprint: (1,1), blocks_movement: true, rotation_snap: 60 }
```

```yaml
# data/props/fireplace.tres
id: fireplace
display_name: "Fireplace"
tags: [STRUCTURE]
category_tag: "structure"
capabilities:
  PLACEABLE:   { footprint: (1,1), blocks_movement: true, rotation_snap: 0 }
  CONTAINER:   { capacity_weight: 200.0, accepts_filter: [BURNABLE] }
  EMITS_LIGHT: { radius: 5.0, color: warm_orange, flicker: true }
  STATION:     { station_tags: [cook, fire, light] }
  CATALOGABLE: { scan_time: 1.0, display_tag: "structure" }
# instance state: is_lit: bool
```

```yaml
# data/props/cart.tres
id: cart
display_name: "Cart"
tags: [STRUCTURE, VEHICLE]
category_tag: "structure"
capabilities:
  PORTABLE:    { weight: 200.0 }   # technically pocketable, effectively no
  PLACEABLE:   { footprint: (2,1), blocks_movement: true, rotation_snap: 60 }
  MOVABLE:     { push_cost: 1.0 }
  CONTAINER:   { capacity_weight: 500.0 }
  CATALOGABLE: { scan_time: 2.0, display_tag: "structure" }
```

```yaml
# data/props/trap.tres
id: trap
display_name: "Snare Trap"
tags: [STRUCTURE]
category_tag: "structure"
capabilities:
  PLACEABLE:   { footprint: (1,1), blocks_movement: false, rotation_snap: 0 }
  CATALOGABLE: { scan_time: 1.0, display_tag: "structure" }
```

---

## 4. Recipe

### 4.1 Recipe shape

```
Recipe {
  id:          StringName
  kind:        Assemble | Transform | Breakdown | Combine
  inputs:      [{ ref_or_tag, count, source }]
  outputs:     [{ prop_ref, count, prob }]
  effects:     [effect]
  conditions:  [{ predicate, must_sustain: bool }]
  actions:     [action_id]
  time:        float
  unlock_when: [predicate]
}
```

### 4.2 Field semantics

- **`id`** — unique StringName, e.g. `eat_berry`, `cook_meat`, `craft_trap`, `chop_small_tree`.
- **`kind`** — declarative classification, used for UI grouping and runtime filtering. Allowed values:
  - `Assemble` — many inputs → 1 output (crafting, building)
  - `Transform` — 1 input → 1 output of a different type (cooking, refining, growing, decaying)
  - `Breakdown` — 1 input → many outputs (butchering, harvesting, dismantling)
  - `Combine` — many inputs → many outputs (the most general; use sparingly)
- **`inputs`** — list of `{ref_or_tag, count, source}`. Each entry specifies:
  - `ref_or_tag` — either a specific PropDef ref (e.g. `branch`) **or** a tag (e.g. `BURNABLE.log`). Tag inputs are fungible — any prop with the tag matching satisfies the input.
  - `count` — how many of the prop are consumed (integer).
  - `source` — **where the input is drawn from**. Allowed values:
    - `&"player_inventory"` (default) — the input is taken from the triggering player's inventory.
    - `&"container"` — the input is taken from a CONTAINER capability of a prop in scope (typically the station resolved by the `at_station` condition). Used by passive station recipes (`burn_log_in_fireplace` pulls fuel from the fireplace's CONTAINER).
    - `&"world_tile"` — the input is taken from the props on the current tile (used by gather recipes: `chop_small_tree` consumes the small_tree on the player's tile).
    - `&"world_anywhere"` — the input is taken from any matching prop in the world. Rarely used; reserved for future global-effect recipes.
  Inputs are **consumed** when the recipe resolves (unless an output declares the same prop ref as a passthrough — see Trap example, where the trap is destroyed but its construction materials are returned via outputs).
- **`outputs`** — list of `{prop_ref, count, prob}`. Each output rolls **independently** against `prob` (default 1.0 = always). Outputs are produced when the recipe resolves.
- **`effects`** — list of non-prop consequences applied when the recipe resolves. Vocabulary (extensible):
  ```
  stat_delta(stat, value)               # hunger+5, health-10, sanity-2
  emit_light(radius, color, duration)
  spawn_heat(radius, duration)
  sound(sound_id)
  fx(particle_id, position)
  world_change(field, value)            # world flag, biome state
  grant_recipe(recipe_id)               # used by scroll-style unlocks
  ```
- **`conditions`** — list of `{predicate, must_sustain}`. Predicates must all be true for the recipe to be eligible. If `must_sustain: true`, the predicate is **re-checked every tick during execution**, and the recipe **cancels** if it becomes false (inputs are returned to source by default — see §8). If `must_sustain: false`, the predicate is only checked at the start (gate-only). The full predicate vocabulary is in §5.
- **`actions`** — list of player verbs that trigger the recipe to start. If empty, the recipe is **passive**: it starts automatically the moment all conditions become true, without requiring player input. Examples: `[eat]`, `[chop]`, `[place_on_fire]`, `[craft]`, `[]` (passive).
- **`time`** — duration in seconds the recipe takes to "cook" between trigger and resolution. `0` = instant resolve. During this time, sustain conditions are checked.
- **`unlock_when`** — list of predicates. The recipe enters the player's known list when all of them become true. If the list is empty, the recipe is **known from start**. Discovery is permanent — once known, always known. (See §6 for details.)

### 4.3 Decisions locked during the design conversation

| # | Question | Decision |
|---|---|---|
| Q1 | Recipe inputs accept refs or tags? | **Hybrid** — both refs and tags |
| Q2 | Direct-use (eat/drink/burn) is a Capability or a Recipe? | **Recipe**, with `outputs: []` allowed and `effects` for non-prop consequences |
| Q3 | Where does the effect of "eat berry" live? | **Per-prop recipe** — `eat_berry` is its own Recipe with its own effects |
| Q4 | Are conditions gates only, or also sustains? | **Per-condition `must_sustain` flag** — mix of gates and sustains in the same recipe |
| Q5 | Do outputs have probability? | **Yes** — `prob` field on each output, default 1.0, independent rolls |
| Q6 | Collapse `tools`/`place`/`actions` into `conditions`? | **Partial** — `tools` and `place` collapse into conditions; `actions` stays separate as an active trigger |

---

## 5. Condition predicate vocabulary

Initial vocabulary. The list is extensible — adding a new predicate kind requires touching the predicate evaluator and adding parsing, but no schema migration.

```
has_tool(tool_ref | tag)
    Player has the given prop equipped or in a tool slot.
    Replaces the previous standalone `tools` field on Recipe.

at_station(station_tag)
    The prop driving the recipe is at (or contained in) a STATION
    that has the given tag. Replaces the previous standalone `place`
    field on Recipe for stations.

at_tile_type(tile_tag)
    The recipe is happening on a tile of the given biome/type.
    Replaces the previous standalone `place` field on Recipe for tiles.

player_stat(stat, op, value)
    Player's stat satisfies the comparison. e.g. `player_stat(health, ge, 20)`.

player_skill(skill, op, value)
    Player's skill satisfies the comparison. (Skills are future scope.)

player_knows_recipe(recipe_id)
    Player has the given recipe in their known list.

time_of_day(phase)
    Current DayNightCycle phase matches. e.g. `time_of_day(night)`.

weather(type)
    Current weather matches. (Weather is future scope.)

biome(tile_tag)
    The relevant tile is in the given biome.

adjacent_to(prop_tag | tile_tag, count_ge)
    There are at least `count_ge` adjacent tiles or props matching.

prop_state(prop_ref, field, op, value)
    A specific prop instance's state field satisfies the comparison.
    e.g. `prop_state(fireplace, is_lit, eq, true)`.

world_flag(name, value)
    A named world flag has the given value. Used for quest/event gates.

animal_nearby(radius, filter)
    There is fauna within radius matching the filter. Used by traps,
    detection mechanics.

container_has(prop_ref | tag, count_ge)
    The container the recipe is operating on has at least N matching
    props inside. e.g. `container_has(BURNABLE, 1)` for a fireplace
    that needs fuel.

cataloged(prop_ref)
    Player has cataloged the given prop. Used primarily by `unlock_when`
    for catalog-driven recipe discovery.
```

The same vocabulary is used by both `conditions` and `unlock_when`. The runtime distinguishes them by *what triggers re-evaluation*:
- `conditions` are checked when matching a recipe to a candidate situation, and sustained-conditions are re-checked while the recipe runs.
- `unlock_when` is watched continuously for false→true transitions; the moment all of a recipe's `unlock_when` predicates are true, the recipe is added to the player's known list (permanently).

---

## 6. Discovery model

### 6.1 Rules

- Each player has a **known recipes** list. A recipe is either known or not known. Once known, **always known** — knowledge is permanent. There is exactly one copy per recipe.
- A recipe with `unlock_when: []` is **known from start** (basic verbs like drop, place, pick up).
- A recipe with `unlock_when: [...predicates...]` is **unlocked** when all its predicates first become true. The runtime watches for that transition.
- A recipe is only matched against the world for execution if it is in the player's known list.

### 6.2 Three typical unlock paths

1. **Catalog-driven** — finding/cataloging a prop unlocks recipes that use it.
   ```
   eat_berry:
     unlock_when: [{ kind: cataloged, prop: berry }]
   ```
   Picking up the first berry catalogs it → `cataloged(berry)` becomes true → `eat_berry` is granted.

2. **Combination-driven** — having the right tool plus having cataloged the right prop unlocks a gathering/crafting recipe.
   ```
   chop_small_tree:
     unlock_when: [
       { kind: has_tool, tool: axe },
       { kind: cataloged, prop: small_tree }
     ]
   ```
   The first time both conditions are true, `chop_small_tree` is granted.

3. **Event-driven** — special game events grant recipes via either `world_flag` predicates or via another recipe's `effects`:
   ```
   advanced_smelting:
     unlock_when: [{ kind: world_flag, name: completed_quest_alpha }]
   ```
   Or via a scroll/book item:
   ```
   read_alchemy_scroll:
     inputs: [{ ancient_alchemy_scroll, 1 }]
     actions: [read]
     time: 2
     outputs: []
     effects: [grant_recipe(advanced_alchemy)]
   ```

### 6.3 Why this is enough

The model intentionally does not include narrative discovery metadata, recipe difficulty tiers, partial progress, or hint systems. These are out of scope for delivery-005a. Recipes are flat data with predicate-driven unlocks. Anything richer (skill trees, prerequisite chains beyond predicates, recipe slots) is future scope.

---

## 7. Worked examples

These are the canonical examples from the design conversation. Each shows how a different gameplay verb fits naturally into the unified Recipe model.

### 7.1 Eating a berry

```yaml
id: eat_berry
kind: transform
inputs: [{ ref: berry, count: 1 }]
outputs: []
effects:
  - { kind: stat_delta, stat: hunger, value: 5 }
  - { kind: sound, sound_id: crunch }
conditions: []
actions: [eat]
time: 0
unlock_when:
  - { kind: cataloged, prop: berry }
```

The berry is consumed; nothing is produced; hunger goes up. Triggered by player `eat` action. Unlocked the first time the player catalogs a berry.

### 7.2 Chopping a small tree (with axe)

```yaml
id: chop_small_tree
kind: breakdown
inputs: [{ ref: small_tree, count: 1 }]
outputs:
  - { ref: wood, count: 3, prob: 1.0 }
  - { ref: branch, count: 2, prob: 0.8 }
effects:
  - { kind: sound, sound_id: chop }
conditions:
  - { predicate: { kind: has_tool, tool: axe }, must_sustain: true }
actions: [chop]
time: 4
unlock_when:
  - { kind: has_tool, tool: axe }
  - { kind: cataloged, prop: small_tree }
```

Player holds axe and triggers `chop`; for 4 seconds, tool must remain equipped (sustain); on resolve, the tree is consumed and produces 3 wood (always) plus 2 branches (80% chance).

### 7.3 Cooking meat over a fireplace

```yaml
id: cook_meat
kind: transform
inputs: [{ ref: raw_meat, count: 1 }]
outputs: [{ ref: cooked_meat, count: 1, prob: 1.0 }]
effects: [{ kind: sound, sound_id: sizzle }]
conditions:
  - { predicate: { kind: at_station, tag: cook }, must_sustain: true }
  - { predicate: { kind: prop_state, prop: fireplace, field: is_lit, op: eq, value: true }, must_sustain: true }
actions: [place_on_fire]
time: 15
unlock_when:
  - { kind: cataloged, prop: raw_meat }
  - { kind: cataloged, prop: fireplace }
```

If the player removes the meat from the fire (station predicate fails) or the fire goes out (prop_state predicate fails), the recipe **cancels mid-cook** — the raw meat is returned and the player must restart. Both predicates are sustains.

### 7.4 Crafting a trap

```yaml
id: craft_trap
kind: assemble
inputs:
  - { ref: branch, count: 1 }
  - { ref: fiber, count: 1 }
outputs: [{ ref: trap, count: 1, prob: 1.0 }]
effects: []
conditions: []
actions: [assemble]
time: 3
unlock_when: []           # known from start
```

### 7.5 Trap firing (passive, world-driven)

```yaml
id: trap_fires
kind: breakdown
inputs: [{ ref: trap, count: 1 }]
outputs:
  - { ref: trapped_animal, count: 1, prob: 1.0 }
  - { ref: branch, count: 1, prob: 1.0 }
  - { ref: fiber, count: 1, prob: 0.9 }
effects: [{ kind: sound, sound_id: snap }]
conditions:
  - { predicate: { kind: animal_nearby, radius: 1, filter: small_fauna }, must_sustain: false }
actions: []
time: 0
unlock_when: []
```

`actions: []` makes this a **passive recipe** — no player input. The condition is a gate (`must_sustain: false`), so it fires the moment a small fauna comes within range. The trap is consumed; the player gets a trapped animal back, plus the materials (with fiber breaking 10% of the time). To re-arm, the player runs `craft_trap` again.

### 7.6 Meat rotting (passive, time-only)

```yaml
id: meat_rots
kind: transform
inputs: [{ ref: cooked_meat, count: 1, source: world_anywhere }]
outputs: [{ ref: rotten_meat, count: 1, prob: 1.0 }]
effects: []
conditions: []
actions: []
time: 86400      # 24 in-game hours
unlock_when: []
```

Pure passive time-based decay. No conditions, no sustains — just `time`. After 24 in-game hours of existing in the world (or in inventory, or in any container), `cooked_meat` transforms to `rotten_meat`. Cold-storage preservation is **deferred** to a future delivery (it would require either pause-resume sustain semantics or a separate `prop_state(temperature)` condition; both add runtime complexity). For delivery-005a, meat just rots.

> **Decision (Andre, 2026-04-08):** meat_rots is `time` only — no temperature condition, no sustain. Removes pressure for pause-resume from the runtime model.

### 7.7 Burning a log in a fireplace

```yaml
id: burn_log_in_fireplace
kind: breakdown
inputs: [{ tag: BURNABLE.log, count: 1, source: container }]
outputs: [{ ref: ash, count: 1, prob: 1.0 }]
effects:
  - { kind: emit_light, radius: 5, duration: 60 }
  - { kind: spawn_heat, radius: 2, duration: 60 }
conditions:
  - { predicate: { kind: at_station, tag: fire }, must_sustain: true }
  - { predicate: { kind: prop_state, prop: fireplace, field: is_lit, op: eq, value: true }, must_sustain: true }
actions: []
time: 60
unlock_when: []
```

Passive. Pulls fuel from the fireplace's CONTAINER (note `source: container` on the input — distinct from the player's inventory). Each cycle consumes one log, produces ash, and the effects sustain the fire's light + heat for 60 seconds.

### 7.8 Battery state transitions

Per the design conversation, **usage mechanics are deferred**. Battery cycling is modeled as two trivial state-transition recipes that ping-pong the prop between two PropDefs:

```yaml
id: use_battery
kind: transform
inputs: [{ ref: charged_battery, count: 1 }]
outputs: [{ ref: depleted_battery, count: 1, prob: 1.0 }]
effects: []
conditions: []
actions: [use]
time: 0
unlock_when: [{ kind: cataloged, prop: charged_battery }]
```

```yaml
id: recharge_battery
kind: transform
inputs: [{ ref: depleted_battery, count: 1 }]
outputs: [{ ref: charged_battery, count: 1, prob: 1.0 }]
effects: []
conditions: [{ predicate: { kind: at_station, tag: charger }, must_sustain: true }]
actions: [recharge]
time: 30
unlock_when: [{ kind: cataloged, prop: depleted_battery }]
```

No usage counters, no per-instance charge state, no special code path. Two recipes, two PropDefs. If we later need partial-charge mechanics, they enter the model as instance state on the prop and a `prop_state` condition on the recipes.

---

## 8. Runtime model

### 8.1 Recipe matching

The runtime maintains an index over **known recipes** keyed by:
- For each input ref/tag → list of recipes that consume it
- For each station tag → list of recipes that use that station
- For each player action → list of recipes triggered by that action
- For each watched predicate → list of recipes whose conditions reference it

When the world state changes (player picks up/drops a prop, equips a tool, performs an action, enters a station, a tile state changes, fauna moves), the runtime queries the relevant indexes for **candidate recipes** and checks their full condition set. If conditions pass and a trigger is present (action or empty-actions passive), the recipe **starts** (enters the pending queue or resolves instantly if `time: 0`).

### 8.2 Pending recipes

A pending recipe has:
```
PendingRecipe {
  recipe_ref: Recipe
  start_time: float
  bound_inputs: [PropInstance]    # consumed inputs, locked
  bound_station: PropInstance | null
  triggering_actor: Player | null
  sustain_predicates: [Predicate]
}
```

Pending recipes are stored on the relevant station/prop instance (for "this station is currently cooking") or in a global queue (for world-level passive recipes like `trap_fires` and `meat_rots`).

Each tick, the runtime:
1. Re-evaluates each pending recipe's `sustain_predicates`. If any fails → cancel.
2. Checks if `start_time + recipe.time <= now` → resolve.

On resolve:
- Inputs are removed from their source.
- Outputs are spawned (each rolling against its `prob` independently).
- Effects are applied (stat deltas to player, lighting/sound/fx into the world).
- The recipe is removed from the pending queue.

On cancel:
- Inputs are returned to their source by default. (A future "spoil on cancel" flag can be added if needed.)
- The pending recipe is removed from the queue.
- An optional `recipe_cancelled(recipe_id, reason)` signal is emitted for HUD feedback.

### 8.3 Sustain failure policy

When a sustain condition fails mid-execution, the default behavior is **cancel + return inputs**. We may later want to introduce an `on_sustain_fail` field per recipe with options like:
- `cancel_return` (default) — return inputs, abort
- `cancel_destroy` — destroy inputs, abort (e.g. burnt food)
- `pause_resume` — freeze the timer; resume when sustain becomes true again (e.g. wheat growth pausing during drought)

For delivery-005a, we ship with **cancel_return only**. The pause-resume case is needed for `meat_rots` if we want preservation to actually pause rather than reset; mark this as an open implementation question (§11).

### 8.4 Predicate evaluator (the "query item")

A `PredicateEvaluator` (RefCounted) takes a `Predicate` (Dictionary) and a `WorldContext` (Player + relevant Prop + Tile + global state) and returns `bool`. It is the single source of truth for predicate semantics. Used by:
- Recipe matching (gate evaluation)
- Pending recipe ticking (sustain evaluation)
- Discovery watcher (unlock evaluation)

The evaluator dispatches on `predicate.kind` to one of the vocabulary handlers in §5. Adding a new predicate kind = adding a handler + updating parsing.

### 8.5 Discovery watcher

A `DiscoveryWatcher` (Node, possibly autoload) listens to global signals that might cause an unlock condition to flip from false to true:
- `Catalog.entry_cataloged(prop_id)` → check all recipes with `unlock_when` referencing `cataloged(prop_id)`
- `Inventory.tool_equipped(tool_id)` → check recipes with `has_tool` unlocks
- `WorldFlags.flag_changed(name, value)` → check recipes with `world_flag` unlocks
- Recipe `grant_recipe` effects → directly add to known list

For each candidate recipe, evaluate **all** of its `unlock_when` predicates (not just the one that flipped). If all are true and the recipe is not already in the known list, add it. Optionally emit `recipe_unlocked(recipe_id)` for HUD feedback.

---

## 9. Migration from current state

### 9.1 PropDef changes

(Specifics confirmed by foundation audit — see §13 for the full Category-related field inventory.)

- **Delete `PropDef.prop_category: int`** — this field stored an index into `Prop.Category` enum and is the source of "behavioral category." Capabilities replace its job entirely.
- **Delete `PropDef.category: StringName`** — this field has values "prop"/"resource"/"consumable"/"structure"/"tool" and is a vague typology that capabilities + `is_*` flags supersede.
- **Keep `PropDef.catalog_category: StringName`** — already exists, already correct. It's the UI-only catalog grouping label (this is what §3.3 calls `category_tag`). No rename needed.
- **Delete `PropDef.is_consumable: bool`, `hunger_restore`, `thirst_restore`, `health_restore`** — these are absorbed into per-prop `eat_*` / `drink_*` recipes' `effects` field.
- **Delete `PropDef.is_respawn_point: bool`** — becomes a tag `RESPAWN_POINT` or absorbed into a STATION station_tag (TBD in task-046).
- **Delete `PropDef.is_crafting_station: bool`** — replaced by STATION capability with `station_tags: [&"craft"]`.
- **Delete `PropDef.tool_slot: StringName`** — replaced by a `TOOL` tag plus a STATION-like capability or kept as a slot hint on PORTABLE (TBD; lean: keep as `tool_slot` because it maps directly to inventory tool slots and there's no clean capability for it).
- **Delete `PropDef.emits_light: bool` and `light_radius: int`** — replaced by EMITS_LIGHT capability with `radius`, `color`, `flicker` fields.
- **Delete `PropDef.gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed`** — all gather/yield/respawn behavior is absorbed into per-prop gather recipes (e.g. `chop_small_tree`) and respawn recipes (e.g. `regrow_berry_bush`).
- **Keep `PropDef.max_stack: int`** temporarily during transition; the new weight model uses `PORTABLE.weight` instead, but `max_stack` may be retained as a per-prop UI grouping limit (lean: delete after task-049 is stable).
- **Add `tags: Array[StringName]`** — free-form labels (BURNABLE.log, CONSUMABLE.edible, METAL.iron, etc.).
- **Add capability fields:** each is a small inner Resource or Dictionary, `null`/empty when not present:
  - `portable: PortableCap` — `{ weight: float }`
  - `placeable: PlaceableCap` — `{ footprint: Array[Vector2i], blocks_movement: bool, rotation_snap: int }` (note: `footprint` is already a field on PropDef — this capability formalizes it)
  - `container: ContainerCap` — `{ capacity_weight: float, accepts_filter: Array[StringName] }`
  - `emits_light: LightCap` — `{ radius: float, color: Color, flicker: bool }`
  - `movable: MovableCap` — `{ push_cost: float }`
  - `station: StationCap` — `{ station_tags: Array[StringName] }`
  - `catalogable: CatalogableCap` — `{ scan_time: float, display_tag: StringName }` (note: existing `gather_time` on sources may double as `catalogable.scan_time` initially, then split when CATALOGABLE is the only consumer)
- **Migrate existing `.tres` files** following the inventory in §14.
- **Behavioral cleanup in code** (task-051, after task-046 lands):
  - `Prop.Category` enum → can be deleted from `prop.gd`. References in `hex_tile.gd::get_props_by_category()`, `hex_tile.gd::get_structures()`, `hex_grid.gd` save/load, `map_loader.gd` load all need to migrate to capability or tag queries.
  - `Prop.is_natural_category()` → can be replaced by `prop.origin == NATURAL` (Origin enum already exists and is sufficient).
  - `Catalog.CatalogCategory` enum (in `catalog.gd`) is **out of scope** for delivery-005a — it's a separate enum in the catalog domain (4 values: FLORA, FAUNA, MINERAL, ANOMALY) and migrating it touches ScannerSystem, PropLabelRenderer, and the Catalog .tres files. Task-046 leaves it untouched.

### 9.2 Inventory changes

- Refactor from slot-count-based to **weight-based**.
- `Inventory` has a `capacity_weight: float` (initially 50, expandable later by storage props).
- Adding an item checks `current_weight + new_item.weight <= capacity_weight`.
- UI displays stacks (grouped by prop_id) with the total weight bar shown alongside.
- Items with `PORTABLE.weight > capacity_weight` cannot be picked up at all and remain in the world (must be transported via MOVABLE props like Cart).

### 9.3 New systems

- **`Recipe` resource type** — `scripts/recipes/recipe.gd` (Resource) defining the schema in §4. Plus `recipe_input.gd`, `recipe_output.gd`, `recipe_effect.gd` for the entry types.
- **`RecipeRegistry`** (autoload) — scans `data/recipes/*.tres` at startup, builds the indexes described in §8.1.
- **`RecipeRuntime`** (autoload or child of World) — owns the pending recipe queue, tick loop, matching logic, sustain checks, resolution.
- **`PredicateEvaluator`** (RefCounted) — pure function evaluator described in §8.4.
- **`DiscoveryWatcher`** (autoload) — described in §8.5. Owns the player's known-recipes list (saved to game state).

### 9.4 AutoInteractionSystem changes

The current `AutoInteractionSystem` directly knows about gathering, tool gates, yields, and respawn queues. After this refactor, most of that logic becomes:

> "Player approaches prop → query RecipeRuntime for matching passive/triggered recipes → if a recipe matches and is unlocked, present the action prompt or auto-start (depending on UX policy)."

The auto-gather flow becomes a thin wrapper that emits player-action events into the recipe runtime. The respawn queue becomes a passive recipe (`regrow_berry_bush` with `time: <regrow_seconds>` and the depleted state as input).

### 9.5 Catalog interaction

ScannerSystem and Catalog are mostly unchanged. The one new wire: when an entry is cataloged, emit a signal that DiscoveryWatcher listens to for catalog-driven unlocks.

---

## 10. Out of scope (deferred)

These items came up during design but are explicitly **not** in delivery-005a:

- **Battery usage counters** — handled later if needed via instance state + state-transition recipes. Current cycle is just two recipes.
- **Output count ranges** (e.g. "3 to 5 berries") — for now, use multiple outputs with prob, or fixed counts. Range support can be added later by extending `count` to `Vector2i` or `[min, max]`.
- **Loot table grouping** (one-of-N exclusive rolls) — current outputs are independent rolls. If grouping is needed, add a `group_id` field to outputs.
- **Pause-resume sustain failure** — current cancel policy is cancel-and-return-inputs only. Andre confirmed (2026-04-08) that `meat_rots` ships as time-only, removing the main pressure for pause-resume. If a future recipe needs it, the runtime can be extended then.
- **`on_sustain_fail` recipe field** — fixed default in delivery-005a; configurable later.
- **Cold-storage food preservation** — would require either pause-resume sustain or a `prop_state(temperature)` condition system. Decided 2026-04-08 to ship `meat_rots` without preservation. Spoilage is uniform.
- **NPC-taught recipes / scroll recipes as a system** — supported by the model (via `world_flag` unlocks or `grant_recipe` effects), but no NPC or scroll content ships in this delivery.
- **Recipe difficulty tiers, skill prerequisites, partial discovery hints** — out of scope.
- **Local Lighting System** — was task-039 in the original delivery-005a scope. This survives as its own task in the new task list (it's independent of the Recipe refactor).
- **`Catalog.CatalogCategory` enum migration** — the catalog domain enum (4 values, in `scripts/scanner/catalog.gd`) stays untouched. It's separate from `Prop.Category` and migrating it would touch ScannerSystem, PropLabelRenderer, and catalog .tres files. Out of scope.
- **Save/load migration of old saves** — Decided 2026-04-08 (Andre, PO call): existing save files break. Farhaven is in alpha, no important player saves exist. Loading a pre-005a save will fail loudly with a clear error. New save format is a clean break, not a backwards-compatible migration.

---

## 11. Open implementation questions

These are unresolved details that will need a call before or during implementation. The current document does **not** decide them; the implementation tasks should flag them when they hit them.

> **Resolved between draft v1 and v2 (2026-04-08):**
> - ~~Pause-resume vs reset-on-cancel for `meat_rots`~~ → Andre: meat_rots is time-only, no condition. Pause-resume not needed for delivery-005a.
> - ~~Sub-recipe input sourcing~~ → Formalized as `source` field on RecipeInput in §4.1/§4.2 (allowed values: `player_inventory`, `container`, `world_tile`, `world_anywhere`).
> - ~~Save/load of pre-005a saves~~ → Andre: accept break in alpha (see §10).
> - ~~`category_tag` naming~~ → Use existing `catalog_category` field name (foundation audit revealed it already exists; see §3.3 and §13).

Remaining open questions:

1. **Where does `current_weight` live on Inventory?** Computed each query from contained props, or cached and updated incrementally? Performance vs simplicity tradeoff. *Lean: cached, updated on add/remove.*
2. **Recipe collisions.** What if multiple recipes match the same situation (e.g. player can either `chop_tree` or `inspect_tree` while holding an axe near a tree)? UI must present a choice. Default policy: present all eligible recipes as a quick-pick menu; let the player choose. Sort by `kind` and `time`. *Lean: quick-pick, defer fancy UX.*
3. **Catalog of un-discovered recipes.** Should the player see "?? recipe" placeholders for recipes they haven't unlocked yet, or no entry at all? *Lean: no entry for delivery-005a (less UI work).*
4. **Save/load of pending recipes.** When the player saves mid-cook, the pending queue must persist. Bound inputs and bound stations need stable IDs across save/load. *Lean: stable IDs derived from tile coords + sub_hex + prop_def_id.*
5. **Recipe ordering inside DiscoveryWatcher.** When several recipes unlock simultaneously (e.g. picking up a prop unlocks 3 recipes), in what order are they granted? Probably doesn't matter, but worth confirming. *Lean: alphabetical by recipe id for determinism.*
6. **`tool_slot` field on PropDef** — keep, fold into a tag, or move into a TOOL capability? Tools (Axe, Pickaxe, Shovel, Knife, Scanner) currently use `tool_slot: StringName` to map to inventory tool slots. The new model could express this as `tags: [TOOL.axe]` or as a TOOL capability, but the simplest path is to keep `tool_slot` as-is. *Lean: keep `tool_slot`, no change.*
7. **`PlaceableCap.footprint` vs existing `footprint` field** — PropDef already has `footprint: Array[Vector2i]`. The PLACEABLE capability formalizes it. Should the existing field move into the capability, or stay top-level with PLACEABLE referencing it? *Lean: move into capability, single source of truth.*
8. **Predicate vocabulary stubs (skills, weather)** — the predicate evaluator needs `player_skill` and `weather` handlers but those subsystems don't exist yet. Should they return `false` with a warning, or be deferred entirely (parser rejects them)? *Lean: return false + warning, parseable but inert.*

---

## 12. Decision log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-08 | Replace `Category` enum with capability composition + tags + `category_tag` label | The enum was mixing "what something is" with "what it does"; composition lets a single prop be both a Plant and a Structure without a false choice. |
| 2026-04-08 | Recipe is a first-class entity, not a capability | Recipes can be discovered, indexed, and queried independently from the props they consume/produce. A prop never needs to know what recipes use it. |
| 2026-04-08 | Direct-use (eat, drink, burn, drain) is modeled as a Recipe with optional `outputs: []` | Different consumables consume differently (eat vs drink vs burn vs spend); a recipe with `effects` accommodates all of them uniformly. |
| 2026-04-08 | Per-prop recipes for consumables (`eat_berry`, `eat_bread`) rather than one generic `eat_any_edible` | Effects are tied conceptually to the specific transformation; verbose but easy to read and debug. |
| 2026-04-08 | Conditions are gate or sustain via per-condition `must_sustain` flag | Different conditions in the same recipe naturally split between "checked once at start" (gate) and "must remain true throughout" (sustain). |
| 2026-04-08 | Outputs have independent probability (no grouping) | Simplest starting point; loot-table grouping can be added later via `group_id` if needed. |
| 2026-04-08 | Partial collapse: `tools` and `place` become condition predicates; `actions` stays as a separate field | Tools and place are passive gates (predicates). Actions are active triggers initiated by the player — semantically distinct, runtime-distinct (event-driven vs evaluated). |
| 2026-04-08 | `Prop` name kept (not renamed to `Asset`) | "Asset" is overloaded in Godot ecosystem; second massive rename in two weeks not justified by marginal clarity gain. |
| 2026-04-08 | Discovery is permanent + flat — `unlock_when` predicate list, watched continuously, granted once forever | Simplest possible model; no progress tracking, no skill trees, no narrative metadata. Reuses condition vocabulary. |
| 2026-04-08 | Battery usage counter deferred — model as two state-transition recipes between charged/depleted | No need for instance counters yet; if richer behavior is required later, prop instance state + prop_state predicates handle it. |
| 2026-04-08 | `meat_rots` recipe is time-only (no temperature condition, no sustain) | Removes the architectural pressure for pause-resume sustain semantics in delivery-005a. Cold-storage food preservation is deferred. Andre's call. |
| 2026-04-08 | Existing save files break with delivery-005a — no migration path | Farhaven is alpha, no important player saves exist. Clean break is simpler than backwards-compat shims. Andre's call. |
| 2026-04-08 | Use existing `PropDef.catalog_category: StringName` field instead of inventing `category_tag` | Foundation audit revealed `catalog_category` already exists with exactly the right role. Using a new name would be gratuitous churn. |
| 2026-04-08 | RecipeInput formalized with `source` field (`player_inventory` / `container` / `world_tile` / `world_anywhere`) | Resolves the ambiguity from §7.7 (`burn_log_in_fireplace` pulled from container) by making the source explicit on every input. |
| 2026-04-08 | `Catalog.CatalogCategory` enum stays untouched in delivery-005a | It's a separate enum in the catalog domain (4 values, only used by ScannerSystem/PropLabelRenderer). Migrating it is out of scope. |
| 2026-04-08 | `Prop.is_natural_category()` replaced by `Origin == NATURAL` | Origin enum already exists and is sufficient. The behavioral category check is redundant. |
| 2026-04-08 | Crafting vs Building: same Recipe engine, different output destination | **Crafting** = output goes to player inventory (tools, items, consumables). **Building** = output requires world placement (structures with PLACEABLE capability). The UI panel is determined by whether the output PropDef has PLACEABLE: yes → Build panel (with tile highlight + sub-hex selection); no → Crafting panel. Same Recipe shape, same RecipeRuntime, different UX flow. Andre's call. |
| 2026-04-09 | Output delivery is 3-way: inventory → world placement → overflow to ground | RecipeRuntime._resolve() decides: (1) if output has STATION/structure tags → world placement UI; (2) else try inventory.add_item(); (3) if inventory rejects (weight exceeded or full) → spawn remainder as world prop near player tile. Covers: Wood Trunk always overflows (weight > capacity), Stone conditionally overflows (fits if space, ground if not). Future polish: falling direction for trunks, auto-pile for stacking ground items. Andre's call. |
| 2026-04-09 | Milestones/Events = Recipe kind=EVENT with count/count_max | Milestones, world flags, chapter gates, tutorials, and cycles ALL collapse into EVENT recipes. Recipe gains `count: int` (runtime, persisted) and `count_max: int` (schema). count_max=0 → unlimited (cycles/passive), count_max=1 → one-shot (milestone/flag), count_max=N → limited (tutorial hints). RecipeRuntime checks `count < count_max` before executing (0=always). World flags = EVENT recipes where count>=1 means "flag is set." Predicate `world_flag(name)` → looks up EVENT recipe count. No separate WorldFlags dictionary, no set_world_flag effect, no world_flag_changed signal needed — recipe_resolved IS the flag being set. New effect kinds needed: `play_cutscene`, `journal_entry`. Chapters = cascading EVENTs gated by other EVENT counts. Andre's design — collapses ~30h+ of planned systems into ~4h of Recipe extensions. |

---

## 13. Foundation Audit (existing Category-related code)

> Performed 2026-04-08 by Lola during the design refinement pass. Goal: prove the migration scope before implementation.

### 13.1 Three different "category" fields on PropDef

PropDef in `scripts/data/prop_def.gd` currently has **three distinct fields with overlapping semantics**, each playing a different role:

| Field | Type | Values seen in data | Role | Decision |
|---|---|---|---|---|
| `category` | `StringName` | `"prop"`, `"resource"`, `"consumable"`, `"structure"`, `"tool"` | Loose typology — what kind of thing is this in inventory/world terms | **DELETE.** Capabilities + tags supersede this. |
| `prop_category` | `int` | 0..9 — index into `Prop.Category` enum (PLANT/MINERAL/ANIMAL/FUNGI/LIQUID/OOZE/STRUCTURE/VEHICLE/EQUIPMENT/STORAGE) | Behavioral classification — drives `get_props_by_category()`, structure detection, etc. | **DELETE.** Capabilities replace its role. |
| `catalog_category` | `StringName` | `"flora"`, `"minerals"`, `"fauna"`, `"anomalies"`, `"survival"`, `"crafting"`, `"storage"`, `""` | UI grouping label for the Catalog screen | **KEEP.** This is what §3.3 calls `category_tag`. Already exists with the right role. |

This is the first surprise: **the field §3.3 specifies (`category_tag`) already exists** under the name `catalog_category`. The DESIGN.md was updated to use the existing name throughout.

### 13.2 `Prop.Category` enum behavioral call sites

The 10-value enum in `scripts/hex/prop.gd:7-10`:

```gdscript
enum Category {
    PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE,
    STRUCTURE, VEHICLE, EQUIPMENT, STORAGE,
}
```

| Location | Use | Migration target |
|---|---|---|
| `prop.gd:18` | `@export var category: Category = Category.PLANT` (instance default) | Delete; instance no longer carries this field |
| `prop.gd:40` `is_natural_category()` | range check `category in [PLANT..OOZE]` | Replace with `origin == Origin.NATURAL`. Origin enum already exists. |
| `prop.gd:48,63,73` (factory methods `create_prop`, `create_structure`, `create_anomaly`) | Set category on new instances | Factory methods can be deleted entirely; instances are reconstructed from PropDef + capabilities |
| `hex_tile.gd:20-25` `get_props_by_category(int)` | Filter props by category enum value | Replace with capability/tag query, e.g. `get_props_with_capability(STATION)` or `get_props_with_tag(&"STRUCTURE")` |
| `hex_tile.gd:36-37` `get_structures()` | `get_props_by_category(STRUCTURE)` | Replace with `get_props_with_capability(STATION)` OR `get_props_with_tag(&"STRUCTURE")` (decide in task-051) |
| `hex_tile.gd:28-33` `get_props()` | Filter via `is_natural_category()` | Replace with `prop.origin == NATURAL` filter |
| `hex_grid.gd:255` (save) | `"category": prop.category` | Delete; not in new save format |
| `hex_grid.gd:308` (load) | `prop.category = int(pd.get("category", _Prop.Category.PLANT))` | Delete; not in new load format |
| `map_loader.gd:108` | Same load pattern | Delete |
| `prop_def.gd:31-32` | `prop_category: int` field | Delete (see §13.1) |

**Total: ~10 behavioral call sites** across 4 files. Manageable. The migration is bounded.

### 13.3 `Catalog.CatalogCategory` enum (separate, out-of-scope)

A **different** enum lives in `scripts/scanner/catalog.gd:6`:

```gdscript
enum CatalogCategory { FLORA, FAUNA, MINERAL, ANOMALY }
```

This is the catalog domain enum, used by:

| Location | Use |
|---|---|
| `catalog_entry.gd:5` | Field on `CatalogEntry: int = 0  # Catalog.CatalogCategory value` |
| `catalog.gd` | `get_discovered_by_category()`, `entry_cataloged` signal payload, `encounter_entry` fauna gate, `get_scannable_at` skip logic |
| `scanner_system.gd:17-20` | Scan time per category lookup table |
| `scanner_system.gd:121,149,203,212` | Default category fallback when entry is null |
| `prop_label_renderer.gd:23-37` | Marker color and label per category |

**Decision: leave `CatalogCategory` untouched in delivery-005a.** Reasons:
- Different domain (catalog/scanner) from `Prop.Category` (world placement). Same word, different concept.
- Only 4 values, well-bounded, well-localized.
- Migrating it touches ScannerSystem, PropLabelRenderer, and 4 catalog `.tres` files (`flora.tres`, `fauna.tres`, `minerals.tres`, `anomalies.tres`).
- The new model could route this through `catalog_category: StringName` on PropDef instead of the enum, but that's a separate cleanup.

If a future delivery wants to unify all categorization through StringName tags, this enum is the next target. Not now.

### 13.4 Test impact

41 references to `Category` / `prop_category` / `catalog_category` across 6 test files:

| File | Refs |
|---|---|
| `tests/integration/test_delivery_002.gd` | 3 |
| `tests/unit/test_catalog.gd` | 5 |
| `tests/unit/test_scanner_system.gd` | 4 |
| `tests/unit/test_prop_renderers.gd` | 10 |
| `tests/unit/test_prop.gd` | 18 |
| `tests/unit/test_catalog_panel_ui.gd` | 1 |

Most of these are in `test_prop.gd` (testing the factory methods and `is_natural_category()`) and `test_prop_renderers.gd` (mock PropDefs setting categories). They will need updates in **task-046** (when PropDef changes) and **task-051** (when Category enum is removed). Test impact is real but bounded.

### 13.5 Other related fields that go away in delivery-005a

| Field | Currently | Replaced by |
|---|---|---|
| `is_consumable: bool` | Flag | Per-prop `eat_*`/`drink_*` recipes |
| `hunger_restore: float` | Effect on consume | `eat_*` recipe `effects: [stat_delta(hunger, +X)]` |
| `thirst_restore: float` | Effect on consume | `eat_*` recipe `effects: [stat_delta(thirst, +X)]` |
| `health_restore: float` | Effect on consume | `eat_*` recipe `effects: [stat_delta(health, +X)]` (negative for poison) |
| `is_respawn_point: bool` | Flag for shelter | Tag `RESPAWN_POINT` or absorbed into a `respawn` STATION tag |
| `is_crafting_station: bool` | Flag for workbench | STATION capability with `station_tags: [&"craft"]` |
| `emits_light: bool` + `light_radius: int` | Flag + radius | `EMITS_LIGHT` capability with `radius`, `color`, `flicker` |
| `gather_time: float` | Time to gather | `gather_*` recipe `time` field |
| `gather_amount: int` | Yield count | `gather_*` recipe `outputs[].count` |
| `tool_required: StringName` | Tool gate | `gather_*` recipe `conditions: [{has_tool: ...}]` |
| `respawn_time: float` | Source respawn delay | `regrow_*` recipe `time` field |
| `yield_type: StringName` | Single yield type | `gather_*` recipe `outputs[].prop_ref` |
| `tool_speed: Dictionary` | Per-tool speed multiplier | Multiple `gather_*` recipes with different `has_tool` conditions and different `time` |

This table is the migration cheat sheet for **task-046** + **task-047** + **task-051**. Every existing PropDef field that goes away has a clear destination.

### 13.6 Audit conclusions

- The migration scope is bounded and well-understood: ~10 behavioral call sites, 4 files, 6 test files, 28 PropDef `.tres` migrations.
- The biggest landmines:
  - The three-fields-named-category situation (resolved by §13.1's table)
  - The `Catalog.CatalogCategory` is a **separate** enum and must NOT be confused with `Prop.Category` (resolved by §13.3 — out of scope)
  - The 13 fields on PropDef that get deleted (see §13.5) — significant but each has a clear replacement
- No surprises that invalidate the design. The model holds.

---

## 14. Existing prop inventory — target capability mapping

> Performed 2026-04-08 by Lola. Each existing PropDef in `data/props/` mapped to its target capability set + tags. This table is the migration plan for **task-046**.

### 14.1 Sources (placed in world, gathered to yield)

| ID | Name | Tags | catalog_category | Target capabilities | Notes |
|---|---|---|---|---|---|
| 00001 | Small Tree | `SOURCE`, `WOOD` | `flora` | PLACEABLE(1×1, blocks=true), CATALOGABLE(1.0, "flora") | Generates `chop_small_tree` recipe with `has_tool(axe)` condition. Yields 00010 wood. |
| 00002 | Loose Rocks | `SOURCE`, `STONE` | `minerals` | PLACEABLE(1×1, blocks=false), CATALOGABLE(1.0, "minerals") | Generates `gather_loose_rocks` recipe (no tool needed). Yields 00011 rock. |
| 00003 | Tall Grass | `SOURCE`, `PLANT` | `flora` | PLACEABLE(1×1, blocks=false), CATALOGABLE(0.5, "flora") | Generates `gather_tall_grass` recipe (no tool needed). Yields 00012 fiber. |
| 00004 | Berry Bush | `SOURCE`, `PLANT` | `flora` | PLACEABLE(1×1, blocks=false), CATALOGABLE(1.0, "flora") | Generates `gather_berry_bush` recipe. Yields 00020 berry. |
| 00005 | Stone Boulder | `SOURCE`, `STONE` | `minerals` | PLACEABLE(1×1, blocks=true), CATALOGABLE(1.5, "minerals") | Generates `mine_stone_boulder` recipe with `has_tool(pickaxe)` condition. Yields 00013 stone. |
| 00006 | Iron Deposit | `SOURCE`, `ORE.iron` | `minerals` | PLACEABLE(1×1, blocks=true), CATALOGABLE(2.0, "minerals") | Generates `mine_iron_deposit` recipe with `has_tool(pickaxe)`. Yields 00014 iron ore. |
| 00007 | Crystal Cluster | `SOURCE`, `CRYSTAL` | `minerals` | PLACEABLE(1×1, blocks=true), CATALOGABLE(2.5, "minerals") | Generates `mine_crystal_cluster` recipe with `has_tool(pickaxe)`. Yields 00015 crystal shard. |
| 00008 | Toxic Berries Bush | `SOURCE`, `PLANT` | `flora` | PLACEABLE(1×1, blocks=false), CATALOGABLE(1.0, "flora") | Generates `gather_toxic_berries` recipe. Yields 00021 toxic berry. |

### 14.2 Yield items (carried in inventory, may be consumable)

| ID | Name | Tags | catalog_category | Target capabilities | Consumable effects |
|---|---|---|---|---|---|
| 00010 | Wood | `RESOURCE`, `WOOD`, `BURNABLE.log` | `""` | PORTABLE(1.0), PLACEABLE(0.5×0.5, blocks=false) | n/a |
| 00011 | Rock | `RESOURCE`, `STONE` | `""` | PORTABLE(0.2), PLACEABLE(0.3×0.3, blocks=false) | n/a |
| 00012 | Fiber | `RESOURCE`, `PLANT` | `""` | PORTABLE(0.05) | n/a |
| 00013 | Stone | `RESOURCE`, `STONE` | `""` | PORTABLE(0.5), PLACEABLE(0.5×0.5, blocks=false) | n/a |
| 00014 | Iron Ore | `RESOURCE`, `ORE.iron` | `""` | PORTABLE(0.4) | n/a |
| 00015 | Crystal Shard | `RESOURCE`, `CRYSTAL` | `""` | PORTABLE(0.15) | n/a |
| 00020 | Berry | `RESOURCE`, `CONSUMABLE.edible` | `""` | PORTABLE(0.01) | `eat_berry`: hunger+5, thirst+10 |
| 00021 | Toxic Berry | `RESOURCE`, `CONSUMABLE.edible` | `""` | PORTABLE(0.01) | `eat_toxic_berry`: hunger+10, health-25 |
| 00022 | Meat | `RESOURCE`, `CONSUMABLE.edible` | `""` | PORTABLE(0.3) | `eat_meat`: hunger+25, health+10. Also subject to `meat_rots` after 24h. |

### 14.3 Structures (placed, mostly non-portable)

| ID | Name | Tags | catalog_category | Target capabilities | Notes |
|---|---|---|---|---|---|
| 00101 | Campfire | `STRUCTURE`, `STATION.fire`, `STATION.cook`, `STATION.light` | `survival` | PLACEABLE(1×1, blocks=true), CONTAINER(20.0, accepts=[BURNABLE]), EMITS_LIGHT(4.0, warm_orange, flicker=true), STATION([fire, cook, light]), CATALOGABLE(1.0, "survival") | Instance state: `is_lit: bool`. Recipes `burn_log_in_fireplace`, `cook_meat`, `light_fire` use this. |
| 00102 | Shelter | `STRUCTURE`, `RESPAWN_POINT` | `survival` | PLACEABLE([3 hexes], blocks=true), STATION([respawn]), CATALOGABLE(1.0, "survival") | Multi-hex footprint preserved from existing field. Existing `is_respawn_point: bool` flag absorbed into `STATION.respawn` tag. |
| 00103 | Torch | `STRUCTURE`, `CRAFTED`, `BURNABLE.fuel` | `survival` | PORTABLE(0.5), PLACEABLE(0.5×0.5, blocks=false), EMITS_LIGHT(3.0, warm_orange, flicker=true), CATALOGABLE(1.0, "survival") | **Dual-state** — both PORTABLE (held in inventory or hand) and PLACEABLE (placed on ground/wall). Confirms the design intent. |
| 00104 | Storage Chest | `STRUCTURE`, `STORAGE` | `storage` | PLACEABLE(1×1, blocks=true), CONTAINER(100.0, accepts=[]), CATALOGABLE(1.5, "storage") | Empty `accepts` filter means "anything goes." |
| 00105 | Workbench | `STRUCTURE`, `STATION.craft` | `crafting` | PLACEABLE([2 hexes], blocks=true), STATION([craft]), CATALOGABLE(2.0, "crafting") | Existing `is_crafting_station: bool` flag absorbed into `STATION.craft` tag. Multi-hex footprint preserved. |

### 14.4 Tools (held/equipped, non-consumed)

| ID | Name | Tags | catalog_category | Target capabilities | tool_slot |
|---|---|---|---|---|---|
| 00201 | Axe | `TOOL`, `CRAFTED` | `""` | PORTABLE(2.0) | `&"axe"` (kept) |
| 00202 | Pickaxe | `TOOL`, `CRAFTED` | `""` | PORTABLE(2.5) | `&"pickaxe"` (kept) |
| 00203 | Shovel | `TOOL`, `CRAFTED` | `""` | PORTABLE(1.8) | `&"shovel"` (kept) |
| 00204 | Survival Knife | `TOOL`, `WEAPON`, `HUMAN` | `""` | PORTABLE(0.5) | `&"weapon"` (kept) |
| 00205 | Scanner | `TOOL`, `HUMAN` | `""` | PORTABLE(0.4) | `&"scanner"` (kept) |

Per Open Question §11.6, `tool_slot` is **kept as-is** on PropDef (not folded into a capability). Tools are the only props that use it; adding a TOOL capability for one field is over-engineering.

### 14.5 Anomalies

| ID | Name | Tags | catalog_category | Target capabilities | Notes |
|---|---|---|---|---|---|
| 10001 | Anomaly Fragment | `SOURCE`, `ANOMALY`, `NATIVE_ALIEN` | `anomalies` | PLACEABLE(1×1, blocks=false), CATALOGABLE(3.0, "anomalies") | Currently `gather_time=3` and `yield_type=""` (yields self). Generates `gather_anomaly_fragment` recipe. Origin = NATIVE_ALIEN preserved. |

### 14.6 Migration counts

- **28 PropDef `.tres` files** to migrate
- **8 sources** need their old gather/respawn fields removed and corresponding `gather_*` + `regrow_*` recipes created (16 recipes total)
- **9 yield items** need PORTABLE weight values assigned (table above proposes initial values; tune in playtest)
- **3 consumables** (00020, 00021, 00022) need corresponding `eat_*` recipes with `effects` lists
- **5 structures** need capability composition + the recipes they enable (`burn_log_in_fireplace`, `cook_meat`, `light_fire`, etc.)
- **5 tools** keep `tool_slot` and gain only PORTABLE
- **1 anomaly** needs `gather_anomaly_fragment` recipe

**Total new recipes seeded by this inventory: ~25-30**, all derived mechanically from existing PropDef data. Most are simple gather/eat/regrow recipes; a few are interesting (cook_meat, burn_log_in_fireplace, light_fire).
