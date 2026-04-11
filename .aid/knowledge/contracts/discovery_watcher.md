# DiscoveryWatcher
**Source:** `scripts/recipes/discovery_watcher.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`recipe_registry.md`](recipe_registry.md), [`event_registry.md`](event_registry.md), [`recipe.md`](recipe.md), [`game_event.md`](game_event.md)

## What this system is

DiscoveryWatcher owns the player's known-recipes list — the set of recipes the player is
allowed to start. It sits at the intersection of EventRegistry and RecipeRegistry: on
startup it scans every GameEvent for `grant_recipe` effects and builds a "discovery event
index" (recipe_id → the event that unlocks it). Recipes with no discovery event are marked
as known from the beginning. When any GameEvent fires, the watcher inspects its effects and
grants any `grant_recipe` targets. When the player's catalog changes (a species or
structure is scanned), the watcher re-evaluates every pending discovery event against the
current world state and fires the ones whose conditions now pass. It is the seventh autoload
in `project.godot`, after EventRegistry, so the discovery event index is built against a
fully-loaded event set.

## Promises to content

- **Every recipe is in exactly one of three states.** "Unknown but discoverable" (has a
  discovery event, event hasn't fired), "unknown and undiscoverable" (no discovery event
  and marked unknown — currently unreachable in practice), and "known" (either granted
  at startup because no discovery event exists, or granted later because a discovery event
  fired).
- **Recipes with no `grant_recipe` event are known from game start.** The watcher scans
  every recipe at `_ready` and auto-marks those without a matching discovery event entry.
  Content that wants a recipe to be unlockable must declare a discovery event.
- **`is_known(recipe_id)` is the canonical check.** RecipeRuntime calls it before starting
  a recipe; UI panels call it to grey out locked entries. A recipe that hasn't been granted
  returns false.
- **`grant_recipe(recipe_id)` is idempotent.** Calling it with an already-known recipe is
  a no-op; the `recipe_unlocked` signal is emitted only on the first grant.
- **`recipe_unlocked(recipe_id)` fires once per new grant.** Journal, tutorial hints, and
  SFX systems subscribe to this for "new recipe discovered!" feedback.
- **The watcher auto-subscribes to `EventRegistry.event_fired`.** Content never has to
  manually forward events to the watcher; firing an event that carries a `grant_recipe`
  effect is sufficient.
- **Catalog changes trigger re-evaluation.** If a Catalog instance is injected (typically
  owned by ScannerSystem on the player), the watcher connects to its `entry_cataloged`
  signal and calls `check_unlocks` with a freshly-built WorldContext. Discovery events
  whose conditions reference the catalog will naturally unlock as species are scanned.
- **`check_unlocks(ctx)` is a manual re-evaluation hook.** External systems can call it
  whenever they suspect a pending event might now be satisfiable — tool equip changes,
  station unlocks, etc. It iterates pending discovery events, evaluates each event's
  conditions via PredicateEvaluator, and fires the ones that pass.
- **Save/load round-trips the known set.** `get_save_data()` emits the known recipe ids as
  a StringName array; `load_save_data(data)` replaces the current set wholesale.

## Requirements from content

- **Discovery events carry a `grant_recipe` effect.** The effect's `params.recipe_id` names
  the recipe to unlock. Any event with such an effect is automatically treated as a
  discovery event for that recipe; the mapping is built from the effect, not from a
  separate declaration.
- **Recipe unlock goes through events, not through direct writes.** Gameplay code that
  wants to unlock a recipe in response to some condition must define a GameEvent with a
  `grant_recipe` effect and fire that event (either directly via
  `EventRegistry.try_fire` or by satisfying the event's own conditions and letting
  `check_unlocks` discover it).
- **`check_unlocks` needs a WorldContext.** Callers who don't have a context can rely on
  the internal `_build_current_context` path (triggered by catalog changes), but external
  re-evaluations should pass a properly constructed context so predicates see the current
  player, tile, and station state.
- **Predicates evaluate against the context.** Discovery event conditions can use any
  predicate kind that PredicateEvaluator understands. If a predicate references state not
  on the context, it returns false and the event stays pending.
- **Only one discovery event per recipe.** `_discovery_events[recipe_id] = event` stores a
  single entry; if two events both grant the same recipe, the iteration order of
  `EventRegistry.get_all_events` decides which wins. Authoring must keep this 1:1.
- **The Catalog must be injected explicitly.** The watcher has no way to find a Catalog on
  its own — the ScannerSystem that owns the catalog assigns it by writing to `_catalog`.
  Unit tests that exercise catalog-driven unlocks must do the same.

## Extension points

- **Direct grant.** Any system can call `DiscoveryWatcher.grant_recipe(recipe_id)` to
  unlock a recipe unconditionally (e.g. cheat menus, tutorial autograts). The normal
  signals fire.
- **Subscribe to unlock notifications.** Connect to `recipe_unlocked` to react to new
  recipes becoming available.
- **Inject mocks.** `_registry`, `_event_registry`, and `_catalog` all accept overrides
  before `_ready` runs. Unit tests swap these to avoid touching the real autoloads.
- **Manual re-evaluation hooks.** Gameplay code that mutates state referenced by
  discovery-event predicates can call `check_unlocks(ctx)` explicitly.

## Genre-specific notes

DiscoveryWatcher is **mostly engine-general**. The pattern — "recipes are gated by events,
and a single watcher handles the gating" — transfers to any game with progression: skill
trees, tech research, recipe books, quest chains. A strategy game could reuse the class
unchanged for "tech unlock on condition."

The **Farhaven-specific parts** are:

- **The catalog integration.** The `entry_cataloged` signal coupling assumes a survival
  game with a species-and-structure catalog. A game without that signal simply wouldn't
  inject a catalog and the re-evaluation path would only fire on explicit `check_unlocks`
  calls.
- **"Recipes" as the unlock unit.** A second game might unlock tech nodes, quest steps,
  or abilities instead. The watcher would become a more generic `ProgressionWatcher` with
  the same shape but a different content type.
- **The 1:1 event-to-recipe mapping.** Some games want one event to unlock a bundle of
  related recipes. That's expressible today by putting multiple `grant_recipe` effects
  on the same event, but the `_discovery_events` dictionary only remembers one event per
  recipe for re-evaluation purposes. A many-to-many model would need a different index.

## Known limitations and TODOs

- **No rich context for re-evaluation.** The automatic `_build_current_context` only fills
  in `grid`, `day_night`, and `catalog`. Discovery events that reference `player`, `tile`,
  `station`, or `container` from the context will not evaluate correctly via the automatic
  path; they need a manual `check_unlocks(ctx)` call from code that has those references.
- **`check_unlocks` is linear in pending events.** Fine today; if the event set grows into
  the thousands, a pre-index of "events that depend on catalog state" would amortise cost.
- **No "re-lock" path.** Recipes are granted permanently. There is no `revoke_recipe`;
  content that wants a temporary unlock must track the temporary state outside the watcher.
- **Discovery event index is built once at `_ready`.** Events added at runtime (e.g.
  via a modding API) are not automatically scanned. A `_index_discovery_events` re-run
  would fix this; not yet exposed.
- **Non-unique per recipe.** If multiple events grant the same recipe, only one is
  remembered for re-evaluation. The grant itself still works — either event firing will
  call `grant_recipe` — but "is this pending" questions only look at one.
- **Save format is a flat list.** No metadata about when or how a recipe was granted.
  Narrative replay ("you learned this on day 4") would need extra storage. See task-088.
