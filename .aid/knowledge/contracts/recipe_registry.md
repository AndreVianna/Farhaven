# RecipeRegistry
**Source:** `scripts/recipes/recipe_registry.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`recipe.md`](recipe.md), [`prop_registry.md`](prop_registry.md)

## What this system is

RecipeRegistry is the in-memory index of every Recipe resource in the project. On game
start it scans `res://data/recipes/`, loads every `.tres` file, validates the id prefix,
and builds five dictionaries: one keyed by recipe id, one keyed by the prop refs each
recipe consumes, one keyed by the tags each recipe matches, one keyed by the player actions
that can trigger each recipe, and one keyed by the station tags each recipe requires.
Callers that ask "what recipes can this prop feed into," "what recipes does 'eat' trigger,"
or "what recipes happen at a campfire" all resolve in constant time against these indexes.
The autoload runs fifth in `project.godot`, after the registries and world layer and before
any system that needs to look up recipes.

## Promises to content

- **Every Recipe under `res://data/recipes/` is loaded.** The scan is flat and picks up any
  `.tres` file whose top-level script is `recipe.gd`. No allow-list, no codegen step.
- **Lookups are constant-time across all five indexes.** `get_recipe(id)`,
  `find_recipes_for_input(prop_ref)`, `find_recipes_for_tag(tag)`,
  `find_recipes_for_action(action)`, and `find_recipes_for_station(station_tag)` all read
  pre-built dictionaries.
- **`get_all_recipes()` returns every loaded recipe.** Used by DiscoveryWatcher to mark
  no-discovery recipes as known from start, and by debug/catalog tooling.
- **Input indexing handles both direct refs and tags.** If a RecipeInput's `ref` starts with
  `&` (tag shorthand), the recipe is indexed under its tag; otherwise under its direct prop
  id. A recipe that consumes a BURNABLE tag and a specific log both lives in both indexes.
- **Station-tag indexing reads through predicates.** Any RecipeCondition whose predicate
  kind is `at_station` has its `tag` param extracted; the recipe is indexed under that tag
  for fast "what can I craft at this station" lookup.
- **Action indexing covers every declared action.** Recipes list their triggering actions
  in a `Recipe.actions` array; the registry walks that array and indexes the recipe under
  each entry.
- **Lookups that find nothing return empty arrays.** `find_recipes_for_tag(&"UNKNOWN")`
  returns `[]`, not null. Callers can iterate the result unconditionally.

## Requirements from content

- **Recipe `.tres` files live directly under `res://data/recipes/`.** Flat scan; no
  sub-folder traversal.
- **Every Recipe id must be a StringName starting with `R`.** Asserted at load time.
  Non-R-prefixed ids abort the scan.
- **Ids must be unique.** `_by_id` overwrites on collision in filesystem order; content must
  guarantee uniqueness.
- **RecipeInput ref format is load-bearing.** Direct refs are prop ids (`"P00108"`); tag
  refs are strings beginning with `&` (`"&BURNABLE"`). The registry trusts `input.is_tag()`
  and `input.get_tag()` to classify them correctly — see the Recipe family contract for the
  input shape.
- **Station tags come from predicates, not from a top-level field.** For a recipe to be
  discoverable by station, it must declare a RecipeCondition with an `at_station` predicate
  whose `tag` param names the station. The registry does not scan the Station cap on the
  PropDef directly.
- **PropRegistry must be loaded before RecipeRegistry's `_ready` runs.** The autoload
  ordering guarantees it. New autoloads inserted between them must not break this, because
  recipe-effect code paths (grant_recipe, tag matching) reach PropRegistry for prop
  metadata.

## Extension points

- **Add a recipe.** Drop a `.tres` file in `res://data/recipes/`. No code change required.
- **New lookup index.** Adding a new `_by_*` dictionary means adding an `_index_*` helper
  and calling it from `_register`. Downstream lookups follow the existing pattern.
- **Inject a mock registry.** [`discovery_watcher.md`](discovery_watcher.md) and
  [`recipe_runtime.md`](recipe_runtime.md) both accept a `_registry` field that defaults to
  this autoload but can be replaced with a stub.
- **Post-load hook.** Like PropRegistry, there is currently no `recipes_loaded` signal.
  DiscoveryWatcher populates its "known from start" set during its own `_ready`, which runs
  after RecipeRegistry's, so the ordering works out without a signal.

## Genre-specific notes

RecipeRegistry is **fully engine-general as a registry**. Any game with data-driven
transformations — crafting, cooking, alchemy, research, unit production — needs exactly
this shape: load resources from a directory, index them by their lookup keys, return
constant-time results. The class could be reused unchanged in a strategy game for unit
recipes or in an RPG for alchemy recipes.

The **genre-specific part** is what counts as a "recipe" — the Recipe family (inputs,
outputs, effects, conditions, predicates) carries Farhaven's crafting/cooking/growing
vocabulary. See [`recipe.md`](recipe.md) for that contract. The registry itself doesn't
know or care; it just loads and indexes whatever Recipe resources exist.

The **station tag plumbing** is Farhaven-survival flavoured: the notion that some recipes
happen at a campfire, others at a workbench, others anywhere, is a survival-game staple.
A game without fixed crafting stations would simply leave the station-tag index empty.

## Known limitations and TODOs

- **No hot-reload.** Edits to `.tres` files at runtime need a game restart.
- **Flat scan only.** No sub-folder organisation. Will need to change as the recipe library
  grows; task-088 deferred work.
- **No duplicate-id detection.** Silent overwrite on collision in filesystem order. Content
  authoring must guarantee uniqueness.
- **Station-tag index only catches `at_station` predicates.** Recipes that express station
  requirements through a different predicate kind or custom logic won't be indexed. If new
  predicate kinds represent station requirements, `_index_station_tags` must be taught
  about them.
- **No validation that referenced prop ids exist in PropRegistry.** If a recipe input
  references `P99999` and that prop doesn't exist, the recipe still loads and is still
  indexed; the failure surfaces later at runtime when the recipe tries to execute. A
  cross-registry validation pass is task-088 scope.
- **No "recipe unlock state" in the registry itself.** Unlock state lives in
  [`discovery_watcher.md`](discovery_watcher.md); the registry exposes every recipe
  unconditionally. Callers that want "only known recipes" filter on their own.
