# Recipe (data class)

**Source:** `scripts/recipes/recipe.gd`
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md) (Recipe extends ScriptBase which extends Gear), inherits `conditions` / `effects` / `actions` / `duration` from ScriptBase. References `recipe_input.md`, `recipe_output.md`, `recipe_effect.md`, `recipe_condition.md`, `predicate.md` (each element of `inputs` / `outputs` / `effects` / `conditions` is an instance of one of those sub-resource types). The *owner* of Recipe resources at runtime is [`recipe_registry.md`](recipe_registry.md); the *executor* is [`recipe_runtime.md`](recipe_runtime.md).

> **Note.** This contract covers only the `Recipe` data class itself — the `.tres` resource
> shape, field-by-field. The family of sibling classes it composes (RecipeInput, RecipeOutput,
> RecipeEffect, RecipeCondition, Predicate) is covered by task-083c's contracts. The runtime
> that *executes* recipes is covered by `recipe_runtime.md`. The loader/lookup layer that owns
> them is `recipe_registry.md`.

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

## Known limitations and TODOs

- **No recipe versioning.** If a recipe is edited between game versions, existing saves with
  in-flight pending recipes of that id may behave inconsistently. A version field would let
  RecipeRuntime either migrate or discard the pending entry.
- **No localisation story yet.** `display_name`, `short_description`, `long_description` are
  plain strings. Localisation will need a separate translation key table (future work).
- **`effects` is a placeholder hook for non-prop side effects.** The runtime side of `effects`
  exists (stat deltas, grant_recipe, fire_event), but the full catalogue is still being
  expanded. Content should check `recipe_effect.md` for the current list.
- **Recipe family contract ambiguity.** The engine-contracts index originally planned a single
  contract file covering Recipe + RecipeInput + RecipeOutput + RecipeEffect + RecipeCondition +
  Predicate. Task-083c's scope carves some of those off into their own files. For now this
  contract stays narrowly scoped to the Recipe root; the 083e cross-reference pass will
  reconcile any overlap.
