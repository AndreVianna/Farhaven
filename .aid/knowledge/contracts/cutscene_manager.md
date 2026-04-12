# CutsceneManager
**Source:** `scripts/cutscenes/cutscene_manager.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`cutscene_def.md`](cutscene_def.md), [`event_registry.md`](event_registry.md), [`game_event.md`](game_event.md)

## What this system is

CutsceneManager plays fullscreen video cutscenes with a skip button. On startup it scans
`res://data/cutscenes/` for CutsceneDef `.tres` files, indexes them by id, and connects
to `EventRegistry.event_fired` so that any cutscene whose `trigger_event` matches a
firing event auto-plays. A `play(id)` call builds a high-layer CanvasLayer overlay with a
VideoStreamPlayer (fullscreen) and a Skip button (top-right corner), starts playback, and
fires `cutscene_finished(id, skipped)` when playback either ends naturally or is
interrupted. Only one cutscene can play at a time; additional `play` calls are rejected
until the current one finishes. It is the eleventh autoload in `project.godot`, after
Journal, so its "play on event" subscription sits alongside Journal's unlock subscription
against the same event stream.

## Promises to content

- **Every CutsceneDef under `res://data/cutscenes/` is loaded.** Flat scan; missing folder
  is tolerated silently (authoring expectation: cutscenes may be empty during early
  development).
- **`play(id)` is the single entry point.** Returns true on successful playback start (or
  when the def has an empty `video_path` — an authoring placeholder that still shows the
  overlay), false if another cutscene is playing, if the id is empty or unknown, or if
  the `video_path` is set but the file cannot be loaded.
- **Single-playback policy.** While a cutscene is active, new `play` calls are rejected
  (return false, log a warning, leave the current cutscene alone). `skip()` must be
  called first to interrupt.
- **`cutscene_finished(cutscene_id, skipped)` is the lifecycle signal.** Fires exactly
  once per successfully-started cutscene — with `skipped = true` if the player pressed
  the skip button, pressed `ui_cancel`, or `skip()` was called; `skipped = false` if the
  video's own `finished` signal fired. Failed starts do not emit this signal.
- **Automatic event-triggered playback.** When an event fires and the manager finds a
  loaded CutsceneDef whose `trigger_event` matches the event id, it calls `play(def.id)`
  for the first match. Iteration order is the loaded dictionary order; authoring is
  expected to keep `trigger_event` unique.
- **Overlay is rebuilt every play.** `play` constructs a fresh CanvasLayer → Control →
  VideoStreamPlayer + Button subtree. `skip` / natural-end tears the overlay down and
  clears the references. No state leaks between plays.
- **Headless-safe.** If there is no scene tree (e.g. isolated unit tests), the overlay
  is added as a child of the autoload itself instead of the tree root, so the playback
  lifecycle still runs without crashing.
- **Empty `video_path` is an authoring placeholder.** If the CutsceneDef exists but its
  `video_path` is empty, `play` still returns true and still builds the overlay, but
  with no VideoStream attached. The caller must call `skip()` (or press ui_cancel) to
  end it.
- **`is_playing()` reflects the current state.** True while an overlay is live, false
  when idle. Useful for pausing gameplay or suppressing input while a cutscene plays.
- **`get_def(id)` is a passive lookup.** Returns the CutsceneDef resource or null. Does
  not start playback.
- **Test injection.** `set_defs_for_test(defs)` replaces the scanned dictionary directly,
  letting unit tests exercise play / skip without real files on disk.

## Requirements from content

- **CutsceneDef `.tres` files live directly under `res://data/cutscenes/`.** Flat scan.
- **Every CutsceneDef id must be a StringName starting with `C`.** Asserted at load time.
- **Ids must be unique.** Silent overwrite on collision.
- **`video_path` must be a resource path.** Either absolute (`res://videos/x.ogv`) or
  bare (`videos/x.ogv`, automatically prefixed with `res://`). If the resource exists but
  isn't a VideoStream, `play` returns false and logs.
- **`trigger_event` uniqueness is the author's responsibility.** The event-to-cutscene
  resolution takes the first match; two defs sharing the same trigger is an authoring
  bug, not an engine feature.
- **An active cutscene's Esc / ui_cancel calls `skip()`.** Callers cannot suppress this
  without overriding the `_unhandled_input` chain. Games that want non-skippable
  cutscenes must remove the `ui_cancel` handler or disable the skip button in their
  own fork of the autoload.
- **EventRegistry must exist when CutsceneManager's `_ready` runs.** It does in the
  normal autoload order. If it doesn't (isolated tests), the `event_fired` subscription
  is silently skipped and manual `play` still works.

## Extension points

- **Manual playback.** Any system can call `CutsceneManager.play(id)` from scripted
  sequences (tutorial, game-over screens, death-respawn cinematics).
- **Event-driven playback.** Authoring a cutscene with a non-empty `trigger_event` lets
  the subscriber hook drive the play without gameplay code forwarding anything.
- **Lifecycle subscribers.** Connect to `cutscene_finished` to resume gameplay, show
  UI, or advance a quest after the cutscene ends. The `skipped` boolean distinguishes
  "player wanted to see it" from "player skipped."
- **Test injection.** `set_defs_for_test(defs)` is the seam for unit tests; no
  filesystem required.
- **Overlay parenting.** `_get_overlay_parent` returns the scene tree root, or null
  (falling back to the autoload itself). A game that wants cutscenes inside a sub-scene
  would need to override this.

## Genre-specific notes

CutsceneManager is **fully engine-general**. "Play a fullscreen video with a skip button"
is a pattern usable in any game — cinematics, intro sequences, boss death reveals, game
over, credits. The autoload could be reused unchanged in a second game.

The **event-trigger coupling** is where the only genre-ish flavor lives: tying cutscenes
to the general-purpose GameEvent system is a Farhaven choice that makes sense because
Farhaven already uses events for journal unlocks and recipe grants. A game that didn't
have an event system would strip the `_on_event_fired` handler and rely on manual
`play` calls. Equally reusable.

The **overlay layer choice (`OVERLAY_LAYER = 100`)** assumes a game where HUD layers
sit below 100. Most games follow this convention; games that don't would edit the
constant.

The **Skip button layout** (top-right corner, inset) is a UI convention rather than a
genre choice. Easily customisable by editing the overlay builder.

## Known limitations and TODOs

- **No pause integration.** `play` does not automatically pause gameplay, and `skip` /
  finish do not resume it. Callers that want gameplay frozen during cutscenes must
  `get_tree().paused = true` around the lifecycle themselves.
- **No per-cutscene Skip policy.** Every cutscene can be skipped. "Unskippable intro"
  is not expressible without editing the manager. Task-088 scope.
- **No preload / streaming tuning.** Videos are `load()`ed synchronously at play time.
  Large files cause hitches; streaming preloading is not implemented.
- **No audio ducking.** Gameplay music keeps playing underneath cutscene audio. A game
  with in-cutscene dialog audio should mute the music bus manually.
- **Event-trigger iteration order is undefined.** If two CutsceneDefs share a
  `trigger_event` (authoring bug), whichever the dictionary iterator yields first wins.
  A content validator would catch this at build time; deferred.
- **Overlay is destroyed at skip/finish.** Cutscene state (e.g. current frame time) is
  not preserved for replay. Not a real limitation, just a note.
- **No "restart cutscene" API.** Rewinding in mid-playback requires calling `skip` then
  `play` again — which incurs overlay rebuild and resource reload.
- **Video format is whatever Godot supports.** Typically `.ogv`; other formats require
  importer plugins. Not an engine limit, just an authoring constraint.
