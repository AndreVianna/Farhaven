# GameEvent (data class)

**Source:** `scripts/core/event.gd`
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md) (GameEvent extends ScriptBase which extends Gear), inherits `conditions` / `effects` / `actions` / `duration` from ScriptBase. Owned at runtime by [`event_registry.md`](event_registry.md); checked and fired by [`recipe_runtime.md`](recipe_runtime.md) and [`discovery_watcher.md`](discovery_watcher.md).

> **Note.** This contract covers only the `GameEvent` data class itself — the `.tres` resource
> shape and the tiny in-class API (`is_active`, `can_fire`, `fire`, `reset`). The loader and
> firing infrastructure are covered by `event_registry.md`; the pre-condition evaluation is
> covered by `predicate.md` and the conditions/effects it inherits are covered by their own
> data-class contracts under task-083c scope.

## What this system is

GameEvent is Farhaven's representation of a **milestone, world flag, tutorial step, or
chapter gate**. It is executable like a Recipe (it has `conditions`, `effects`, `actions`,
`duration` from ScriptBase) but instead of producing items, it tracks **how many times it
has fired** via the `count` field. World flags and one-shot achievements are just GameEvents
with `max_count == 1`; limited-use tutorials use `max_count == N`; unlimited events (rare)
use `max_count == 0`.

The distinction from Recipe is intent: a Recipe produces outputs; a GameEvent records that
something happened and gates downstream systems based on that record. "Crafting stone axe
unlocks stone-axe recipe" is modelled as a GameEvent with a `grant_recipe` effect, not as
a Recipe.

## Promises to content

- **Two extra fields over ScriptBase.** GameEvent adds only `count: int` (runtime state) and
  `max_count: int` (schema). Everything else (`id`, `display_name`, `conditions`, `effects`,
  `actions`, `duration`, descriptions) is inherited from ScriptBase via Gear.
- **`max_count` semantics.** `0` = unlimited fires, `1` = one-shot (the common milestone /
  flag case), `N > 1` = limited tutorial that fires N times before stopping. `max_count == 1`
  is the default so authors can leave it out for the typical milestone case.
- **`count` is runtime state, not schema.** Content authors should leave `count` at its
  default (0) in `.tres` files. SaveManager persists and restores `count`; EventRegistry
  reads it on load.
- **Tiny in-class API.** `is_active()` returns true once `count >= 1` (the flag is set).
  `can_fire()` returns true while `count < max_count` (or always for unlimited).
  `fire()` increments `count` and returns whether the increment succeeded (false if already
  maxed). `reset()` zeros `count` (used by tests and game-reset paths). No other methods.
- **Firing never mutates side-effects directly.** Calling `fire()` on a GameEvent only
  increments its counter. Executing the inherited `effects` (and checking the inherited
  `conditions` first) is the responsibility of whatever system calls `fire()` — typically
  `EventRegistry.try_fire` (see `event_registry.md`). The data class is deliberately dumb.

## Requirements from content

- **File location.** GameEvent `.tres` files must live under `res://data/events/` so
  EventRegistry scans them on `_ready`. The exact sub-folder convention (chapter / tutorial /
  flags) is documented in `event_registry.md`.
- **Script reference.** The `.tres` file must bind `script = ExtResource(event.gd)`. Inheriting
  from ScriptBase automatically provides conditions/effects/actions/duration; authors do not
  need to re-declare them.
- **ID convention.** The `id` field is a `StringName` typically prefixed by a single letter
  (e.g. `&"E00001"` for chapter events, other prefixes for tutorials / flags). The exact
  prefix rule is enforced by EventRegistry, not by this class.
- **`count` defaults to 0.** Never ship `.tres` files with a non-zero `count` — that would
  look like a pre-fired event at game start and confuse downstream gating logic.
- **`max_count` defaults to 1.** Most milestones are one-shot, so authors usually leave this
  alone. Explicit `max_count = 0` (unlimited) or `max_count = N` (limited tutorial) is the
  opt-out.
- **No inputs / outputs.** GameEvent inherits ScriptBase, not Recipe. Events that should
  produce items are Recipes, not GameEvents.

## Extension points

- **New effect kinds for events.** Because `effects` is `Array[RecipeEffect]`, adding a new
  side-effect kind (e.g. a future `start_cutscene` effect) only requires extending the
  effect class and teaching the runtime to interpret it. GameEvent itself does not need to
  change.
- **Conditional event chains.** A GameEvent with `conditions` referencing another event's
  `count` (via a predicate that reads `EventRegistry.get_event(id).count`) creates an implicit
  event graph. The shape is data-driven; no code extension is needed to build a DAG of
  mutually gated events.
- **Tutorial progression.** Setting `max_count` to the number of tutorial steps and firing
  the same event id at each step creates a step counter. Downstream systems check
  `event.count >= N` rather than `event.is_active()`.

## Genre-specific notes

GameEvent is **genre-agnostic**. The "milestone / flag / counter with preconditions and
side effects" pattern transfers to any rule-based game. A Civ-like game would use GameEvents
for turn-based milestones, era transitions, tech unlocks, diplomatic flags. A visual novel
would use them for story branches. A roguelike for seen-this-enemy records.

Where genre specificity appears is in **what effects GameEvents use and what predicates
evaluate their conditions**. Those vocabularies (`grant_recipe`, `unlock_journal`, `day_is`,
`near_tile_biome`) are Farhaven-flavoured, but they are the responsibility of the effect and
predicate classes, not GameEvent itself.

The design choice "events carry conditions and effects, not just a flag bit" is also worth
noting: a strategy game could model all research / tech unlocks as GameEvents with
preconditions `researched(X)` and effects `unlock(Y)`, effectively building a tech tree out
of event nodes. Farhaven's current use is more narrow (milestones + gates), but the data
shape allows the broader use.

## Known limitations and TODOs

- **No "once per day" or "once per chapter" semantics.** `max_count` is a total lifetime
  limit. Events that should reset per chapter or per in-game day currently need a manual
  reset call somewhere in the codebase. A future field (`reset_on_day_change: bool` or
  similar) could bake this into the class.
- **No event-fired timestamp.** The class records *how many* times an event has fired but not
  *when*. Downstream systems that want "last time this fired" must track it themselves. This
  may be added when save format is next extended.
- **No event tags / categories.** There is no built-in way to query "all tutorial events" or
  "all chapter events" — callers must either use naming conventions or walk all events in
  EventRegistry. A future tag field could live directly on GameEvent.
- **`_recipe` preload quirk.** `event.gd` itself doesn't import anything Farhaven-specific.
  But because it extends `ScriptBase`, any test that loads `event.gd` transitively loads the
  predicate / condition / effect classes. This is fine in practice but worth knowing when
  debugging test harness issues.
