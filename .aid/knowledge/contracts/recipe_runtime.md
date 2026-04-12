# RecipeRuntime
**Source:** `scripts/recipes/recipe_runtime.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`recipe_registry.md`](recipe_registry.md), [`recipe.md`](recipe.md), [`discovery_watcher.md`](discovery_watcher.md), [`prop_registry.md`](prop_registry.md), [`journal.md`](journal.md), [`inventory.md`](inventory.md)

## What this system is

RecipeRuntime is the recipe execution engine. It takes a Recipe resource plus a
WorldContext (describing the player, tile, station, container, and evaluator state), checks
that the recipe is known, validates and consumes the inputs, either resolves instantly
(duration ≤ 0) or enqueues the recipe for timed resolution, and ticks pending recipes every
frame to check sustain conditions and complete them when their duration elapses. On
resolution it rolls output probabilities, delivers outputs to the right destination (player
inventory → tile → signal fallback), and dispatches effects (stat deltas on the player,
recipe grants via DiscoveryWatcher, journal entries, everything else emitted as an
`effect_requested` signal). It is the eighth autoload in `project.godot`, after
DiscoveryWatcher, so its "is this recipe known" check always has the authoritative answer.

## Promises to content

- **`try_start_recipe(recipe, ctx)` is the single entry point for starting a recipe.** It
  returns a `PendingRecipe` handle on success or null on any failure. Callers never touch
  the internal queue directly.
- **Recipes must be known to start.** Unknown recipes return null immediately without
  consuming inputs. See [`discovery_watcher.md`](discovery_watcher.md) for how known-ness
  is tracked.
- **Conditions are evaluated via PredicateEvaluator.** Every RecipeCondition with a
  predicate is checked against the passed context. A failing condition aborts the start
  and leaves the world untouched.
- **Input consumption is atomic.** If any input fails to consume, every already-consumed
  input is rolled back before the call returns null. The world never sees a half-consumed
  recipe on a failed start.
- **Inputs come from the right place.** Inputs marked `must_hold` consume from the player's
  inventory (`Inventory.get_inventory()`); inputs without `must_hold` consume from the
  player's "vicinity" — in priority order: the context's container, its station, then
  the current tile's props. This makes it possible to pull fuel from a campfire's stash
  without the player holding the wood directly.
- **Instant recipes resolve synchronously.** If `recipe.duration <= 0.0`, `try_start_recipe`
  resolves the recipe immediately and returns a fully-resolved PendingRecipe (already
  removed from the queue).
- **Timed recipes tick via `_process`.** Every frame, each pending recipe's `elapsed`
  advances by `delta`, sustain conditions are re-checked, and completed recipes resolve.
  A recipe whose sustain condition fails cancels with reason `"sustain_failed"` (inputs
  are returned to their sources where possible).
- **Outputs roll probabilistically.** Each `RecipeOutput` rolls an independent `randf()`
  against its `prob`; failing outputs produce nothing. Probabilities below 1.0 are a real
  authoring feature, not a bug.
- **Output delivery cascades.** First try the player's inventory (via `add_item`); if
  it returns less than the requested count, the remainder spawns as loose props on the
  context's tile; if there's no tile either, a `push_warning` fires and the remainder is
  dropped. No silent loss into the void for tiled contexts.
- **Effects route to specialised paths.** `stat_delta` finds the player's SurvivalSystem
  and clamps the named stat to `[0, 100]`. `grant_recipe` delegates to DiscoveryWatcher.
  `unlock_journal_entry` delegates to Journal.add_entry. Every other effect kind is
  broadcast via `effect_requested(eff)` for other systems to handle (sound, fx, emit_light,
  spawn_heat, world_change, etc.).
- **Signals narrate lifecycle.** `recipe_started(recipe_id)` on queue insertion,
  `recipe_resolved(recipe_id, outputs, effects)` on completion, `recipe_cancelled(recipe_id,
  reason)` on abort. `effect_requested(effect)` for anything the runtime doesn't handle
  directly.
- **`cancel_recipe(pending, reason)` is idempotent in effect.** Calling it returns inputs
  to their sources (inventory for must-hold, tile for vicinity) and removes the pending
  entry. Calling it twice on the same pending is benign but emits the signal twice — don't.

## Requirements from content

- **Callers provide a WorldContext.** The context must expose at least `player` for
  must-hold inputs and stat_delta effects. For vicinity consumption, at least one of
  `container`, `station`, or `tile` must be populated. For sustain predicate evaluation,
  whatever fields the predicates reference must be present.
- **RecipeInput `ref` format determines consumption path.** Direct prop refs (`P00108`)
  consume exactly that prop; tag refs (`&BURNABLE`) consume any prop whose PropDef has
  that tag. Tag consumption pulls through PropRegistry to check tags; unknown prop types
  simply don't match.
- **Tag-refs cannot be returned on cancel.** Because the bound input stores the tag ref
  and not the resolved concrete prop, the cancellation path skips returning tag inputs.
  Callers that rely on cancellation must prefer direct refs or accept the loss.
- **Stat names for `stat_delta` are hardcoded.** Only `hunger`, `thirst`, and `health`/`hp`
  are understood. Other stat names fall through to the generic `effect_requested` signal.
- **SurvivalSystem is found via child iteration.** The runtime walks the player's children
  looking for a node that has `hp`, `hunger`, and `thirst` fields. Alternative survival
  implementations must expose the same fields or the lookup fails and the effect is
  broadcast instead.
- **Inventory must expose `add_item`, `has_item`, `remove_item`, `get_slots`.** The
  minimum interface RecipeRuntime calls on a player inventory. Alternative inventory
  implementations must match.
- **Container props expose their contents as `props` or `container_items`.** The vicinity
  consumption logic checks both field names. Custom container shapes must expose one of
  them.
- **Random number generation is injectable.** `_rng` accepts a `Callable` that returns
  a float in `[0, 1]`. Tests set it to a deterministic source; production uses `randf()`.

## Extension points

- **New effect kinds.** Any system can connect to `effect_requested` and match on
  `eff.kind`. The runtime handles the built-in kinds explicitly and emits the signal for
  everything else.
- **Custom inventory / container shapes.** As long as they expose the same method and
  field surfaces described above, they drop in.
- **Injected dependencies.** `_registry`, `_discovery`, and `_rng` all accept overrides
  for testing or for alternate content sources.
- **Manual resolution.** External code can call `cancel_recipe(pending)` on any timed
  recipe to abort it (e.g. player cancels crafting), or can construct its own PendingRecipe
  and pass it to the private `_resolve` for test scaffolding — the latter is internal-use
  only but technically available.

## Genre-specific notes

RecipeRuntime is **mostly engine-general** as an execution loop. "Take a declarative
recipe, check conditions, consume inputs, wait N seconds, produce outputs, apply effects"
is a pattern that transfers to nearly any game with crafting — RPGs, survival games,
factory games, strategy games with build queues. The core loop could be reused.

The **Farhaven-specific parts**:

- **The vicinity-consumption priority `container → station → tile.props`** is a survival
  design choice. A factory game might consume from a connected pipe network; an RPG
  might only consume from the player's inventory. The hard-coded priority would need to
  change.
- **SurvivalSystem integration.** The hardcoded `hunger` / `thirst` / `health` stat
  dispatch is Farhaven's survival vocabulary. A different game would either rename the
  stats or add more branches.
- **The built-in effect vocabulary (`stat_delta`, `grant_recipe`, `unlock_journal_entry`)**
  matches Farhaven's current feature set. A different game would add its own effect kinds
  via subscribers; the runtime itself wouldn't change, but its vocabulary would grow.
- **Real-time `_process` ticking.** A turn-based game would advance elapsed time on turn
  boundaries instead of frames. The queue structure is compatible; only the tick driver
  would change.
- **Inventory full → overflow to tile** is a survival-flavoured choice. A strategy game
  might fail the production entirely instead.

## Known limitations and TODOs

- **Tag inputs cannot round-trip on cancel.** The bound-inputs record stores the tag, not
  the resolved prop, so cancellation silently drops tag inputs. Fixing this requires
  remembering the actual consumed prop ids — deferred to task-088.
- **No parallel limit.** A player can start any number of timed recipes at once. There's
  no "crafting queue size" cap, no per-station concurrency limit. Content must design
  around this or add its own gating.
- **`_get_survival_system` walks children linearly.** Fine today (player has a handful
  of children); if the player becomes a complex scene tree, cache the reference.
- **Effect dispatch is hard-coded.** Every built-in effect kind is a `match` branch.
  Adding a new kind means editing the runtime. A pluggable effect registry would
  decouple this; task-088 scope.
- **Output probability is all-or-nothing.** Each output rolls once and either produces
  its full count or nothing. Partial-count outputs (roll 3 of 5) are not supported.
- **No recipe priority / preference.** Two recipes that both match the same trigger fire
  in whatever order the registry lookups return them. Disambiguation must live in the
  caller.
- **Sustain failure always returns inputs to "source."** If the sources have moved since
  the recipe started (container destroyed, tile fell away), inputs may be lost. Task-088
  scope.
- **`recipe_resolved` effects array contains the raw effect resources.** Subscribers that
  want to replay effects get references, not copies — mutating those effects in a
  subscriber mutates the underlying Recipe. Treat as read-only.
