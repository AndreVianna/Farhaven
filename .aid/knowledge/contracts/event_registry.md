# EventRegistry
**Source:** `scripts/core/event_registry.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`game_event.md`](game_event.md)

## What this system is

EventRegistry is the in-memory index of every GameEvent resource in the project. GameEvents
are the engine's general-purpose "something happened" records — they carry preconditions,
effects, a firing count, and a cap on how many times they can fire. The registry loads them
on startup, exposes them by id, provides the canonical `try_fire` entry point, and emits a
single `event_fired` signal whenever any event successfully fires. Every system that cares
about world events — DiscoveryWatcher for recipe unlocks, Journal for entry reveals,
CutsceneManager for triggered cinematics — connects to that one signal and filters by the
event's own data. The autoload runs sixth in `project.godot`, after RecipeRegistry and
before DiscoveryWatcher, so downstream listeners are wired up in a deterministic order.

## Promises to content

- **Every GameEvent under `res://data/events/` is loaded.** Flat scan, picks up every
  `.tres` file whose top-level script is `event.gd`.
- **`try_fire(event)` is the single firing path.** It delegates to `GameEvent.fire()` for
  the can-fire and increment logic, then emits `event_fired(event_id, event)` on success.
  Callers never poke the event directly — always through this method.
- **`event_fired` is the single subscription point.** One signal fires for every successful
  event firing. Subscribers include DiscoveryWatcher (`grant_recipe` effects), Journal
  (`unlock_journal_entry` effects), and CutsceneManager (`trigger_event` mapping). New
  listeners connect to the same signal.
- **`is_active(id)` is a cheap has-fired-yet check.** Returns true only if the event exists
  and its count is greater than zero. Callers that want "has this event ever fired" don't
  need to reach into the event's count directly.
- **`get_all_events()` returns every loaded event.** DiscoveryWatcher's `_index_discovery_events`
  uses this to scan for `grant_recipe` effects during its own `_ready`.
- **Save/load round-trips firing counts.** `get_save_data()` emits a `{id_string: count}`
  dictionary for every event with `count > 0` — absent events stay at zero. `load_save_data(data)`
  restores counts onto the loaded events. Event bodies (conditions, effects, max_count)
  are not serialised; they are authored data and always re-loaded fresh.
- **Directory may be missing without error.** If `res://data/events/` doesn't exist, the
  scan silently returns an empty index. Systems that depend on events will just find no
  events; nothing crashes.

## Requirements from content

- **GameEvent `.tres` files live directly under `res://data/events/`.** Flat scan.
- **Every GameEvent id must be a StringName starting with `E`.** Asserted at load time.
- **Ids must be unique.** Silent overwrite on collision.
- **`GameEvent.fire()` owns the can-fire logic.** The registry does not re-check preconditions
  — it trusts the event's own `can_fire` / `fire` implementation. Content authors rely on
  the event class for precondition semantics (max count, one-shot, conditional preconditions).
- **Effects are read by listeners, not by the registry.** The registry does not interpret
  `eff.kind` — it only emits the signal. Interpretation lives in each subscriber. See
  [`discovery_watcher.md`](discovery_watcher.md) for `grant_recipe`, [`journal.md`](journal.md)
  for `unlock_journal_entry`, [`cutscene_manager.md`](cutscene_manager.md) for
  `trigger_event`, and [`recipe_runtime.md`](recipe_runtime.md) for other effect kinds.
- **Firing is manual.** There is no auto-fire loop. Gameplay code that detects an event
  condition — a catalog entry being added, a day boundary, a player action — calls
  `try_fire` explicitly. (The one partial exception is DiscoveryWatcher, which re-evaluates
  pending events when the catalog changes, but even that ends in a `try_fire` call.)

## Extension points

- **Add an event.** Drop a `.tres` file in `res://data/events/`. No code change required.
- **New effect kinds.** Add a new subscriber to `event_fired` that matches on the new
  `eff.kind`. RecipeRuntime already handles `stat_delta`, `grant_recipe`, and
  `unlock_journal_entry`; other systems can pick up their own kinds through the same signal.
- **Trigger an event manually.** Any system can call `EventRegistry.try_fire(event)`
  where `event` is a GameEvent resource — typically obtained via `get_event(id)` or stored
  as an exported reference on the caller.
- **Mock the registry.** DiscoveryWatcher and RecipeRuntime both accept a `_event_registry`
  field that defaults to this autoload but can be replaced in tests.

**Consumers.** The current subscribers to `event_fired` are
[`discovery_watcher.md`](discovery_watcher.md) (re-evaluates pending recipe-unlock events
when the catalog changes), [`journal.md`](journal.md) (handles `unlock_journal_entry`
effects), [`cutscene_manager.md`](cutscene_manager.md) (maps trigger events to CutsceneDef
playback), and [`recipe_runtime.md`](recipe_runtime.md) (applies `stat_delta` and other
side-effect kinds). Cap classes that *author* events into their own fields —
[`behavior_cap.md`](behavior_cap.md) (reaction events),
[`combat_cap.md`](combat_cap.md) (attack/defense events),
[`cutscene_def.md`](cutscene_def.md) (trigger event id) — depend on EventRegistry only
for the event ids to resolve.

## Genre-specific notes

EventRegistry is **fully engine-general**. "Track named events with effects, emit a signal
when they fire" is a pattern usable in any game. A strategy game's "first contact with
civilization X," an RPG's "quest Y started," a puzzle game's "level Z completed" — all map
to the same shape. The class could be reused unchanged.

What is Farhaven-specific is **the effect vocabulary** — `grant_recipe`, `unlock_journal_entry`,
`stat_delta`. Those strings are what Farhaven's runtime understands. A second game on this
engine would invent its own effect kinds and write its own subscribers; the registry
itself needs no edits.

The **distinction between events and recipes** is also intentional: recipes are deterministic
transformations of inputs into outputs, driven by the player; events are flags that flip
when the world reaches a particular state, observed by every subscriber. Both shapes are
engine-general but the separation is a Farhaven design choice — a more OO engine might
unify them.

## Known limitations and TODOs

- **No hot-reload.**
- **Flat scan only.** No sub-folder organisation.
- **No duplicate-id detection.**
- **No precondition validation.** The registry does not verify that events' preconditions
  reference real predicates, real prop ids, or valid StringNames. Malformed conditions
  surface at runtime when `can_fire` runs them.
- **No event dependency graph.** "Event A must fire before event B" is currently expressed
  through preconditions inside B that check whether A has fired. There is no explicit DAG
  view, so cycles or orphans are caught only by playtest. Future scope.
- **Effect interpretation is distributed.** Every subscriber matches on `eff.kind` and
  pulls params from `eff.params`. That's flexible but means adding a new effect kind
  requires touching every system that might care. A pluggable effect-handler registry would
  be cleaner; task-088 deferred work.
- **Save data only stores counts.** If the runtime wants to remember "event fired at day 3,
  time 14:00" for narrative replay, it would need to add that metadata itself. Currently
  only the fire count persists.
