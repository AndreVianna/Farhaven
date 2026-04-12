# Recipe (data class) + siblings

**Source:** `scripts/recipes/recipe.gd` (plus the sibling classes documented below under
*Siblings*: `recipe_input.gd`, `recipe_output.gd`, `recipe_condition.gd`, `recipe_effect.gd`,
`predicate.gd`)
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md) (Recipe extends ScriptBase which extends Gear), inherits
`conditions` / `effects` / `actions` / `duration` from ScriptBase. The *owner* of Recipe
resources at runtime is [`recipe_registry.md`](recipe_registry.md); the *executor* is
[`recipe_runtime.md`](recipe_runtime.md). Consumed by
[`auto_interaction_system.md`](auto_interaction_system.md) (gather verbs),
[`building_system.md`](building_system.md) (build verbs), and
[`discovery_watcher.md`](discovery_watcher.md) (recipe-unlock events).

> **Scope.** This single contract covers the whole Recipe family — the `Recipe` root plus
> its five sibling classes (`RecipeInput`, `RecipeOutput`, `RecipeCondition`, `RecipeEffect`,
> `Predicate`). The siblings are documented inline in the *Siblings* section rather than in
> separate contract files, because each is a small data shape that only exists as a nested
> element of a Recipe `.tres`. A content author always reads them together with the Recipe
> that contains them; splitting them into five files would make the engine-contracts set
> harder to navigate, not easier.

## What this system is

Recipe is the declarative definition of a transformation in Farhaven. Gathering a tree,
crafting a campfire, cooking meat on the fire, constructing a storage chest, burning fuel
in a fireplace — every verb the player can execute is a Recipe resource. A Recipe says:
"when this action fires, if these conditions are met, consume these inputs over this
duration and produce these outputs plus these side-effect changes."

Recipe is intentionally **data only**. It has no methods. Its two direct fields (`inputs`,
`outputs`) plus the four inherited from ScriptBase (`conditions`, `effects`, `actions`,
`duration`) and the four inherited from Gear (`id`, `display_name`, `short_description`,
`long_description`) make up the whole schema. Everything interesting about how a recipe
runs lives in RecipeRuntime, which reads this resource and interprets it.

## Promises to content

- **Ten fields, no hidden state.** The full author-visible schema is `id`, `display_name`,
  `short_description`, `long_description` (from Gear), `conditions`, `effects`, `actions`,
  `duration` (from ScriptBase), plus `inputs` and `outputs` on Recipe itself. A recipe `.tres`
  file never needs any other field.
- **Inputs and outputs are independently optional.** A recipe can have only outputs (a spawn
  event), only inputs (a consume event), both (a craft), or neither (a pure effect). No
  minimum count is enforced at load.
- **`duration = 0` means instant.** Gather-style recipes with zero duration resolve on the
  same frame their `try_start_recipe` call is made. Non-zero durations queue the recipe in
  the runtime's pending queue and resolve after the timer expires (see `recipe_runtime.md`).
- **`actions` drives discovery.** The strings in `actions` are how systems match recipes to
  player verbs — `&"gather"`, `&"craft"`, `&"build"`, `&"cook"`, etc. AutoInteractionSystem's
  proximity gather looks for recipes containing `&"gather"`; BuildingSystem looks for `&"build"`.
  An empty `actions` array means the recipe is passive (fires automatically when conditions
  are met, no verb needed).
- **Each field is typed but loosely typed.** `inputs`, `outputs`, `conditions`, `effects` are
  `Array[Resource]`, not `Array[RecipeInput]`. This is intentional: it lets the engine evolve
  the sub-resource vocabulary without breaking the parent Recipe schema.

## Requirements from content

- **File location.** Recipe `.tres` files must live under `res://data/recipes/` so
  `RecipeRegistry` scans them on `_ready`. The exact sub-folder layout and ID-prefix convention
  are documented in `recipe_registry.md`; Recipe itself does not enforce them.
- **Extends `res://scripts/recipes/recipe.gd`.** The `[gd_resource]` block in the `.tres`
  must reference `recipe.gd` as its script. Inheriting from ScriptBase automatically provides
  the `conditions` / `effects` / `actions` / `duration` fields; authors do not need to
  re-declare them.
- **Sub-resources, not inline dictionaries.** Every entry of `inputs`, `outputs`, `conditions`,
  `effects` must be a sub-resource `[sub_resource type="Resource" id="..."]` with its `script`
  pointing at the appropriate class file (`recipe_input.gd`, `recipe_output.gd`,
  `recipe_condition.gd`, `recipe_effect.gd`). Dictionary-shaped literals will not load.
- **`actions` is `Array[StringName]`.** Use `&"gather"`, not `"gather"`. String literals that
  aren't `StringName` will either fail the typed assignment or silently miss lookups.
- **`duration` is in seconds.** A real-time floating-point value. Negative durations are
  undefined; use 0 for instant.

## Extension points

- **New action verbs.** Adding a new verb (e.g. `&"harvest"`) is purely data: a recipe declares
  `actions = [&"harvest"]`, and whatever system implements the harvest gesture looks for
  recipes with that tag. Recipe itself does not need to change.
- **New input / output types.** Because `inputs` and `outputs` are `Array[Resource]`, new
  sub-resource types can be added (e.g. a future `RecipeContextInput` that reads from
  `WorldContext` instead of inventory) without touching Recipe. The runtime side needs to be
  taught to interpret the new type, but the Recipe schema stays the same.
- **Recipe metadata.** Additional fields (e.g. `unlock_event`, `category_tag`, `difficulty`)
  can be added to `recipe.gd` and existing `.tres` files will load with the new fields set
  to their defaults.

## Genre-specific notes

Recipe itself is **mostly genre-agnostic**. The "inputs + outputs + conditions + effects +
duration" schema describes any rule-based transformation: crafting, spells, strategic
production queues, chemical reactions, diplomacy, dialog trees. A Civ-like game could use
Recipe to model "build unit X costs Y production and Z resources over W turns."

Where genre specificity creeps in is **the sibling classes**, not Recipe:

- `RecipeInput` assumes items come from an inventory, a container, a tile, or the world —
  the four scopes used by Farhaven's survival loop. A turn-based strategy game might want
  different scopes (treasury, city, trade route).
- `RecipeCondition` carries a `Predicate`, and the predicate vocabulary (`has_tool`, `day_is`,
  `near_tile_biome`, etc.) is survival-genre flavoured. A different game would replace the
  predicate kinds.
- `duration` assumes a real-time tick model. A turn-based game would need a separate "duration
  in turns" concept layered on top (flagged for future engine v2).

The Recipe class itself is a neutral carrier. Its value for engine v2 reuse is high.

## Siblings

Every non-trivial Recipe `.tres` composes one or more of the five sibling classes below. They
are each a handful of exported fields and no methods; the runtime interprets them via
`RecipeRuntime` and `PredicateEvaluator`. They are documented here as nested sub-sections
rather than as standalone contracts because their shape is meaningful only in the context of
a Recipe, and a content author always reads them together with the Recipe file that embeds
them.

### RecipeInput

**Source:** `scripts/recipes/recipe_input.gd` — used as entries in `Recipe.inputs`.

A RecipeInput names an ingredient the recipe consumes when it fires. Each input has three
fields:

- **`ref: String`** — either a prop id (e.g. `"P00020"`) or a tag ref prefixed with `&`
  (e.g. `"&BURNABLE"` or `"&BURNABLE.log"`). Tag refs allow fungible matching: any prop
  carrying the tag satisfies the input. The `is_tag()` / `get_tag()` helpers unwrap the
  `&` prefix.
- **`count: int`** — how many of the prop are consumed on fire. Defaults to `1`.
- **`must_hold: bool`** — if true, the input must live in the player's inventory; if false,
  the input can be in the world within reach (a tile prop or a container). Defaults to
  `false`. Content authors using `must_hold` for tools or consumables tighten the recipe's
  source of supply.

**Requirements from content:** `ref` is a `String` (not a `StringName`); the `&` prefix is
positional and must be the first character. `count` must be a positive integer. No loader
enforces that a prop-id `ref` actually resolves in PropRegistry at load time — mis-spelled
ids fail at first-fire.

### RecipeOutput

**Source:** `scripts/recipes/recipe_output.gd` — used as entries in `Recipe.outputs`.

A RecipeOutput names a prop produced when the recipe successfully resolves. Fields:

- **`prop_ref: StringName`** — PropDef id of the produced prop (note: `StringName`, unlike
  RecipeInput's `String`). This is a historical inconsistency flagged for cleanup in the
  deferred engine backlog (task-088).
- **`count: int`** — how many are produced. Defaults to `1`.
- **`prob: float`** — independent probability of this output being produced, in `[0.0, 1.0]`.
  Defaults to `1.0` (always produced). Probabilistic outputs are rolled independently per
  entry; a recipe with two `prob=0.5` outputs can produce zero, one, or both.

**Requirements from content:** outputs that never hit the player's inventory (e.g. world
spawns) still go through the same field. The distinction between "goes to inventory" vs
"goes to the world" is determined by the recipe's action verb and runtime handling, not by
RecipeOutput itself.

### RecipeCondition

**Source:** `scripts/recipes/recipe_condition.gd` — used as entries in `Recipe.conditions`.

A RecipeCondition wraps a Predicate with a `must_sustain` flag that tells the runtime whether
the predicate is evaluated once at recipe start (`false`) or re-evaluated every runtime tick
during the recipe's duration (`true`). Sustained conditions can cause a long-running recipe
to cancel mid-execution if the world state changes (e.g. the player walks away from a
station, the station prop is destroyed, a required tool is dropped).

- **`predicate: Predicate`** — the actual test. See Predicate below.
- **`must_sustain: bool`** — start-only (default) vs per-tick re-check.

**Requirements from content:** a RecipeCondition with a null `predicate` is treated as
"always passes" (no-op). Authors who want an always-true placeholder can leave it unset.

### RecipeEffect

**Source:** `scripts/recipes/recipe_effect.gd` — used as entries in `Recipe.effects`.

A RecipeEffect is a named side-effect that fires when the recipe resolves, in addition to
the consume/produce behavior driven by inputs and outputs. Fields:

- **`kind: StringName`** — a short string identifying the effect kind. The current vocabulary
  is `stat_delta`, `sound`, `fx`, `emit_light`, `spawn_heat`, `world_change`, `grant_recipe`.
  Adding a new kind is a runtime-side change: RecipeEffect itself carries the string
  untouched.
- **`params: Dictionary`** — kind-specific parameters. For `stat_delta`, `{"stat": "hunger",
  "value": 5}`. For `sound`, `{"sound_id": "crunch"}`. For `emit_light`, `{"radius": 5,
  "duration": 60}`. The dictionary is opaque to Recipe — validation lives on the runtime
  side.

**Requirements from content:** `kind` must match one of the runtime-understood vocabulary
strings; unknown kinds are silently ignored by RecipeRuntime today (a warning-on-unknown
validator is deferred to task-088). `params` keys are untyped strings and must match what
the runtime expects for the given kind.

**Overlap with GameEvent effects.** Recipe effects are *not* the same data type as GameEvent
effects, though they share an effect-vocabulary (e.g. both have a `grant_recipe` kind). The
two vocabularies are maintained by different consumers: Recipe effects are applied by
RecipeRuntime when a recipe resolves; GameEvent effects are interpreted by event subscribers
(DiscoveryWatcher, Journal, CutsceneManager) when the event fires. A future refactor may
unify them — deferred to task-088.

### Predicate

**Source:** `scripts/recipes/predicate.gd` — embedded inside a RecipeCondition, also used
directly inside GameEvent preconditions (see `game_event.md`).

A Predicate is the smallest unit of condition logic in the engine. It is an opaque
`{kind, params}` pair that the `PredicateEvaluator` interprets at check time. Fields:

- **`kind: StringName`** — one of the predicate vocabulary strings: `has_tool`, `at_station`,
  `at_tile_type`, `player_stat`, `player_skill`, `player_knows_recipe`, `time_of_day`,
  `weather`, `biome`, `adjacent_to`, `prop_state`, `world_flag`, `animal_nearby`,
  `container_has`, `cataloged`. See DESIGN.md §5 for the canonical list.
- **`params: Dictionary`** — kind-specific parameters. For `has_tool`, `{"tool": "axe"}`.
  For `player_stat`, `{"stat": "health", "op": "ge", "value": 20}`. For `cataloged`,
  `{"prop": "P00108"}`. Opaque to Predicate; validated at evaluation time.

**Requirements from content:** predicate vocabulary is closed — only the listed kinds are
understood. Unknown kinds fail their check (return false). The evaluator lives in
`scripts/recipes/predicate_evaluator.gd` and is consulted by both RecipeRuntime and
DiscoveryWatcher.

**Predicate is consumed outside the Recipe family.** `AutoInteractionSystem` uses the
PredicateEvaluator indirectly to decide whether a proximity gather recipe can start; see
[`auto_interaction_system.md`](auto_interaction_system.md). GameEvent preconditions also
use Predicates directly. The Predicate class is therefore the one Recipe-family sibling
whose reach extends beyond Recipe itself.

## Known limitations and TODOs

- **No recipe versioning.** If a recipe is edited between game versions, existing saves with
  in-flight pending recipes of that id may behave inconsistently. A version field would let
  RecipeRuntime either migrate or discard the pending entry.
- **No localisation story yet.** `display_name`, `short_description`, `long_description` are
  plain strings. Localisation will need a separate translation key table (future work).
- **`effects` is a placeholder hook for non-prop side effects.** The runtime side of `effects`
  exists (stat deltas, grant_recipe, fire_event), but the full catalogue is still being
  expanded. Content should check the Siblings / RecipeEffect section above for the current
  vocabulary.
- **RecipeOutput / RecipeInput type inconsistency.** `RecipeOutput.prop_ref` is a
  `StringName`; `RecipeInput.ref` is a plain `String` (so the `&` tag prefix works). A
  future cleanup should either make both `String` or introduce a proper Ref type. Deferred
  to task-088.
- **No schema validator.** Nothing checks at load time that `inputs`/`outputs` elements are
  actually instances of the right sibling class, that a `must_hold: true` input has a
  resolvable prop id, or that an effect kind is recognised. Malformed recipes surface at
  first-fire. A static validator pass would be cheap; deferred to task-088.
