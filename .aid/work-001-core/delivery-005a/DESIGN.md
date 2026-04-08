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

### 3.3 `category_tag`

A single StringName per PropDef that the Catalog UI uses to group props for display ("Flora", "Fauna", "Mineral", "Anomaly", "Wood", "Tool", "Structure"). **This field is purely for UI grouping and never controls behavior.** It replaces what `Category` enum was being used for in the Catalog screen.

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
  inputs:      [{ ref_or_tag, count }]
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
- **`inputs`** — list of `{ref_or_tag, count}`. Each entry specifies either a specific PropDef ref (e.g. `branch`) **or** a tag (e.g. `BURNABLE.log`). Tag inputs are fungible — any prop with the tag matching satisfies the input. Inputs are **consumed** when the recipe resolves (unless an output declares them as a passthrough — see Trap example).
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

### 7.6 Meat rotting (passive, time-based)

```yaml
id: meat_rots
kind: transform
inputs: [{ ref: cooked_meat, count: 1 }]
outputs: [{ ref: rotten_meat, count: 1, prob: 1.0 }]
effects: []
conditions:
  - { predicate: { kind: prop_state, prop: ambient, field: temperature, op: gt, value: 10 }, must_sustain: true }
actions: []
time: 86400      # 24 in-game hours
unlock_when: []
```

Passive, time-based. Sustain condition: temperature must stay > 10°C (or whatever scale). If the meat enters cold storage (temperature drops), the sustain fails and the rot timer **resets** (or pauses — see §8.3 for cancellation policy). Preservation emerges naturally from the model.

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

- Remove `Category` enum from behavioral logic. Keep the enum **temporarily** as a typedef for the `category_tag` field, or migrate `category_tag` directly to `StringName` and delete the enum.
- Add `tags: Array[StringName]` field.
- Add `category_tag: StringName` field (replaces behavioral use of `Category`).
- Add capability fields: `portable: PortableCap`, `placeable: PlaceableCap`, `container: ContainerCap`, `emits_light: LightCap`, `movable: MovableCap`, `station: StationCap`, `catalogable: CatalogableCap`. Each is its own small Resource (or Dictionary) and is `null`/empty when the capability is not present.
- Migrate existing `.tres` files to fill in capability fields and tags. Most existing props will need PORTABLE + PLACEABLE + CATALOGABLE entries derived from their old fields.

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
- **Pause-resume sustain failure** — current cancel policy is cancel-and-return-inputs only. Pause-resume is an open implementation question (§11) that we may need for `meat_rots` and `grow_wheat`.
- **`on_sustain_fail` recipe field** — fixed default in delivery-005a; configurable later.
- **NPC-taught recipes / scroll recipes as a system** — supported by the model (via `world_flag` unlocks or `grant_recipe` effects), but no NPC or scroll content ships in this delivery.
- **Recipe difficulty tiers, skill prerequisites, partial discovery hints** — out of scope.
- **Local Lighting System** — was task-039 in the original delivery-005a scope. This survives as its own task in the new task list (it's independent of the Recipe refactor).

---

## 11. Open implementation questions

These are unresolved details that will need a call before or during implementation. The current document does **not** decide them; the implementation tasks should flag them when they hit them.

1. **Pause-resume vs reset-on-cancel for `meat_rots` (and `grow_wheat`).** When the sustain condition fails (meat enters cold storage), should the timer pause (preservation) or reset (resume rotting from scratch when warmed)? Pause-resume is a more permissive variant of cancel and may need its own field.
2. **Where does `current_weight` live on Inventory?** Computed each query from contained props, or cached and updated incrementally? Performance vs simplicity tradeoff.
3. **Sub-recipe input sourcing.** When a recipe input has `source: container` (like `burn_log_in_fireplace`), the input comes from the station's CONTAINER, not the player inventory. We need a clean way to disambiguate input sources: `player_inventory`, `container`, `world_tile`, etc. Currently sketched as a `source` field on the input entry; needs to be formalized.
4. **Recipe collisions.** What if multiple recipes match the same situation (e.g. player can either `chop_tree` or `inspect_tree` while holding an axe near a tree)? UI must present a choice. Default policy: present all eligible recipes as a quick-pick menu; let the player choose. Sort by `kind` and `time`.
5. **Catalog of un-discovered recipes.** Should the player see "?? recipe" placeholders for recipes they haven't unlocked yet, or no entry at all? Likely "no entry" for delivery-005a (less UI work).
6. **Save/load of pending recipes.** When the player saves mid-cook, the pending queue must persist. Bound inputs and bound stations need stable IDs across save/load.
7. **`category_tag` enum or StringName?** The capability set already eliminates the enum's behavioral role. For UI grouping, StringName is more flexible (no migration on add) but enum is type-safe. Lean: StringName for now, switch to enum later only if we need exhaustive switches in UI code.
8. **Recipe ordering inside DiscoveryWatcher.** When several recipes unlock simultaneously (e.g. picking up a prop unlocks 3 recipes), in what order are they granted? Probably doesn't matter, but worth confirming.

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
