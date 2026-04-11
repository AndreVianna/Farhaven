# StationCap

**Source:** `scripts/data/capabilities/station_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`recipe_runtime.md`](recipe_runtime.md), [`recipe_registry.md`](recipe_registry.md), [`fauna_manager.md`](fauna_manager.md)

## What this system is

StationCap marks a PropDef as "an interactive station the player can use as the subject
of a recipe or a world action." Crafting benches, cooking fires, anvils, respawn points,
research stations, and every other "go here to do something" prop carries this cap. The
cap itself is a single field: `station_tags`, an array of `StringName` that tags the
station with one or more roles. `&"craft"` marks a crafting bench. `&"respawn"` marks a
respawn point. `&"fireplace"` marks a cook/heat source. Recipes reference stations by
tag, and the RecipeRegistry builds a tag→recipe index at startup so the runtime can
answer "which recipes can be started at this station?" in O(1).

## Promises to content

- **StationCap is opt-in via PropDef.** A PropDef without a `station` cap is not an
  interactive station. Adding the cap plus at least one tag makes the prop visible to
  the recipe runtime and other station consumers.
- **`station_tags` is a `StringName` tag list, not a single role.** A station can carry
  multiple tags (`[&"craft", &"fireplace"]`) and will match any recipe or consumer that
  looks for any one of them. This is how a multi-purpose station (e.g. a hearth that is
  both a cook surface and a respawn point) is authored.
- **RecipeRegistry builds a tag→recipe index at startup.** When recipes are loaded, the
  registry reads each recipe's station tag and inserts the recipe into a dictionary
  keyed by that tag. At runtime, "which recipes does this station support?" is a
  single dictionary lookup — content scales linearly in station tag count, not in
  recipe count.
- **PredicateEvaluator uses the tag list for station predicates.** When a recipe has a
  precondition like "needs a `craft`-tagged station in context," the evaluator reads
  `def.station.station_tags.has(tag)` on the station PropDef in `ctx.station`. The
  check is exact-match.
- **The `&"respawn"` tag is a concrete FaunaManager consumer.** FaunaManager scans for
  stations with `station_tags.has(&"respawn")` when the player needs to be placed at
  the start of a session (or after death). This is how a placed bedroll, cot, or camp
  marker becomes a respawn anchor.
- **StationCap is shared across instances.** Every crafting bench of type `P00400`
  shares one StationCap. Per-instance state — how many recipes are currently running
  at this bench, what is in its fuel container — lives elsewhere (on the spawned node,
  on the attached ContainerCap, on RecipeRuntime's pending queue).
- **Order in `station_tags` does not matter.** The tags are matched by membership, not
  by position.

## Requirements from content

- **Sub-resource shape, not dictionary.** StationCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("station_cap")`.
- **Tags are `StringName`, not `String`.** Typed field enforcement rejects plain strings.
- **Use the established tag vocabulary.** The canonical tags today are `&"craft"`
  (crafting bench), `&"respawn"` (respawn anchor), and `&"fireplace"` (cook/heat).
  New tags are legal but require coordination: whatever recipe or consumer intends to
  react to the new tag must be authored alongside the station using it. Typos silently
  match nothing.
- **Exact-match semantics.** `&"craft"` does not match `&"craft.tier1"`. If a future
  design wants hierarchical station types, authors must list every leaf tag explicitly,
  consistent with the PropDef tag system in [`prop_def.md`](prop_def.md).
- **Composition with PlaceableCap is the norm.** Almost every station is also placeable
  (the player builds it). A station with `station + placeable` is the canonical
  "crafting bench you can build." A station without `placeable` is either part of the
  map-generator output or an authoring mistake.
- **Composition with ContainerCap for fuel / input stations.** A fireplace is
  `station + container + light`: it is interacted with (station), it holds fuel
  (container), and it glows (light). RecipeRuntime's `ctx.container` path then pulls
  fuel from the attached container when a cook recipe runs at this station.

## Extension points

- **Adding a new station tag.** Free-form `StringName`. No central enum to update. Any
  recipe that checks for the new tag must be authored alongside, and RecipeRegistry's
  index will pick it up automatically at load time.
- **Composing station tags.** A `[craft, respawn]` station is a respawn-at-the-anvil
  concept. A `[fireplace, craft]` station unifies cooking and crafting. No engine
  change is needed for any new combination — RecipeRegistry and FaunaManager both
  check tag membership independently.
- **Station-specific recipe gating.** A recipe that requires a specific tag can also
  layer on additional predicates (e.g. "station AND has fuel"). The additional rules
  live on the recipe, not on the cap. StationCap stays stupid.
- **Future richer station metadata.** Fields like `interaction_range: float`,
  `interaction_prompt: StringName`, or `allowed_recipe_tiers: Array[int]` are all
  plausible additions. None are on the cap today. Any new `@export` will round-trip
  and keep existing `.tres` files valid.
- **Station activation state.** The cap describes the role, not "is this station on or
  off." Activation lives on the spawned node. A future "broken anvil" concept might
  want an `enabled` flag; today, stations are always active.

## Genre-specific notes

StationCap is **fully genre-agnostic.** "This world object is a location where the
player does structured actions" describes workbenches, smithies, libraries, markets,
tech nodes, or any game's interactive-point concept. A Civ-like second game could reuse
StationCap unchanged for wonders that grant recipe slots, build sites that accept
upgrade recipes, or tech nodes the player interacts with. A Catan-like game could use
it for port spaces that transform goods.

The **Farhaven tag vocabulary** (`craft`, `respawn`, `fireplace`) is genre-flavored —
those are the roles a survival-sandbox needs — but because the tag list is open, a
second game ships its own vocabulary and everything else keeps working.

The **coupling with the recipe runtime** is the most opinionated part of the cap's
surrounding ecosystem. Recipes reference stations by tag; if a second game did not use
Farhaven's recipe system, it would need a different runtime that also reads
`station_tags`. The cap itself is still fine; only the consumer changes.

The **coupling with FaunaManager for respawn** is a Farhaven-specific convention: the
`&"respawn"` tag becomes a player spawn anchor. A second game that used respawn points
differently (or did not have player death at all) would simply not use the tag.

## Known limitations and TODOs

- **Flat tag list.** No hierarchy, no namespaces. `&"craft"` does not match
  `&"craft.tier1"`. Authors who want tiered stations must list every tier explicitly.
  Consistent with other tag systems in the engine.
- **Single-field shape.** Everything a station knows about itself is in the tag list.
  Richer metadata (interaction range, prompt text, allowed recipe tiers) has to live
  elsewhere or be added as new fields. This is acceptable now but will likely need to
  grow.
- **No per-instance "on/off" state.** A station is always active as far as the cap is
  concerned. A broken anvil is either a different PropDef (no `station` cap) or a
  runtime flag on the spawned node — not a cap field.
- **Tag vocabulary is informal.** There is no central registry or enum for station
  tags. New tags are invented on demand and agreed between the station author and the
  recipe author. Typos produce silent non-matches.
- **No "this station is yours" ownership model.** Any station-tagged PropDef in the
  world is usable by the player who reaches it. Multi-player or factioned ownership
  would need a different layer.
- **Respawn coupling is direct.** FaunaManager searches for `&"respawn"` tags in a
  hardcoded fashion. A future multi-respawn or priority-ordered respawn system would
  need either additional fields on the cap (e.g. `respawn_priority`) or a dedicated
  RespawnCap.
- **No station "capacity."** A crafting bench with one running recipe and a bench with
  three running recipes are treated identically by the cap. Concurrency limits live on
  RecipeRuntime, not on StationCap.
