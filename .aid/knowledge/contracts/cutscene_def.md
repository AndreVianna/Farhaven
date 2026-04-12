# CutsceneDef

**Source:** `scripts/data/cutscene_def.gd`
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md), [`cutscene_manager.md`](cutscene_manager.md), [`event_registry.md`](event_registry.md)

## What this system is

CutsceneDef is the declarative description of a single playable cutscene clip. It bundles the
metadata the engine needs to look a cutscene up, decide when it should play, and hand it to
the renderer or media layer. It is pure data: a CutsceneDef does not play itself, cannot tick,
and holds no playback state. Actual playback is the job of CutsceneManager, which takes a
CutsceneDef, reads its `video_path`, and drives the media layer. In delivery-006d the system
is engine plumbing only — the content side (real clips, real trigger events) is scheduled
for delivery-007.

## Promises to content

- **Identity is inherited from Gear.** Every CutsceneDef carries an `id`, `display_name`,
  `short_description`, and `long_description` by virtue of extending Gear. Content authors
  can reuse the same identity fields they already know from PropDef and JournalEntry.
- **CutsceneManager looks cutscenes up by id.** Once a CutsceneDef `.tres` lives in the
  cutscene directory and has been loaded, calling `CutsceneManager.play(id)` (or whatever
  the manager's equivalent is) finds it without further configuration.
- **The `trigger_event` field is a soft binding.** Setting `trigger_event` to a GameEvent id
  expresses the authoring intent "when this event fires, play this cutscene." Whether the
  actual wiring goes through an EventRegistry listener, a DiscoveryWatcher subscription, or
  a manual `CutsceneManager.play()` call is up to the manager — CutsceneDef itself only
  stores the id. `&""` means "no automatic trigger; play this cutscene programmatically only."
- **Missing media is non-fatal.** `video_path` may be empty during authoring and CutsceneManager
  is expected to handle the missing-file case gracefully (skip, log, continue). A cutscene
  with no `video_path` still loads and is still discoverable by id; it just cannot play.
- **`duration_seconds` is advisory only.** It is a hint for the editor and for any UI that
  wants to show "approximate length," not a playback timer. The real length of the clip is
  whatever the media file says.

## Requirements from content

- **File location.** Every CutsceneDef must live as a `.tres` file under the cutscene data
  directory (`res://data/cutscenes/` by convention). The exact directory is enforced by
  whatever registry or scan step CutsceneManager runs at startup; CutsceneDef itself makes
  no claim on location.
- **Id prefix.** Ids must be `StringName` values starting with `C` (for example `&"C00001"`).
  The prefix is a Farhaven convention shared with the rest of the Gear hierarchy; it is
  enforced by the owning registry, not by CutsceneDef.
- **Script reference.** The `.tres` file must bind its top-level `script` to
  `res://scripts/data/cutscene_def.gd`. Tooling that generates CutsceneDefs must emit this
  ExtResource entry.
- **`video_path` is relative to `res://`.** The string is passed to Godot's resource loader
  or to a media plugin; absolute OS paths will not resolve inside a shipped build.
- **`trigger_event` must reference an existing GameEvent id, or be empty.** CutsceneDef does
  not validate this at load time; an unknown id will silently fail to trigger. A future
  content validator should cross-check these ids against EventRegistry (deferred to
  task-088).
- **`duration_seconds` is an `int`.** Authoring tools that want fractional durations should
  round up and treat the field as a coarse hint.

## Extension points

- **Hook into EventRegistry.** The canonical wiring pattern is: CutsceneManager subscribes to
  EventRegistry's `event_fired` signal, sees an id it cares about, and looks up the
  CutsceneDef whose `trigger_event` matches. Adding a new auto-triggered cutscene requires
  only authoring a new `.tres` with the right `trigger_event`; no code change in CutsceneManager.
- **Hook into DiscoveryWatcher.** Because DiscoveryWatcher translates discovery states into
  GameEvent firings, any catalog-driven cutscene can be plumbed end-to-end by pointing a
  CutsceneDef at a discovery-driven event id. No direct DiscoveryWatcher awareness lives in
  CutsceneDef.
- **Manual playback.** CutsceneManager exposes a programmatic `play(id)` path for cutscenes
  with no `trigger_event`. This is how cutscene playback is driven from tutorials, scripted
  sequences, and debug tooling.
- **Adding new metadata.** Extra fields (subtitle track, skip policy, fade timings) can be
  added to CutsceneDef with `@export` and will flow through Godot's resource serialisation
  automatically. Existing `.tres` files remain valid because new exports default to sensible
  values. No registry code needs to change unless the new field affects scanning or lookup.

## Genre-specific notes

CutsceneDef is **largely genre-agnostic.** The three concepts it captures — a path to a media
file, an optional event trigger, and an advisory duration — transfer cleanly to any game that
wants data-driven cutscenes. A Civ-like or Catan-like second game could reuse CutsceneDef
unchanged for opening/ending animations, era-transition videos, tutorial clips, or victory
screens. The class makes no assumption about hex grids, real-time ticks, or survival mechanics.

The **only Farhaven-specific piece** is the coupling to Farhaven's GameEvent system via the
`trigger_event` field. A second game that used a different event bus would either reinterpret
`trigger_event` as a key into its own event system (easy, since it is just a `StringName`) or
rename the field. Either way, CutsceneDef itself does not hard-code any Farhaven behavior.

The clip format is also genre-agnostic — `video_path` is just a string, so whether the media
is Ogg Theora, WebM, a still image, or a Godot AnimationPlayer scene is up to CutsceneManager
and the authoring pipeline.

## Known limitations and TODOs

- **Content is deferred to delivery-007.** Delivery-006d ships the CutsceneDef class and
  CutsceneManager plumbing only. No real clips, no real trigger events, no real `.tres` files
  in `data/cutscenes/` beyond placeholders. The acceptance criterion for 006d is "the plumbing
  loads and can play an empty cutscene without crashing."
- **No subtitle / caption support.** The current fields are deliberately minimal. A caption
  track, a localisation key, and a skip policy are all reasonable additions but are out of
  scope for 006d.
- **No multi-file cutscene support.** One CutsceneDef is one media file. Cutscenes that span
  multiple clips must be chained in CutsceneManager or re-authored as a single file.
- **No playback state in the data class.** CutsceneDef does not track "has been played,"
  "how many times," or "last play timestamp." Those live in CutsceneManager (and, for
  once-only cutscenes, in the save-game state). This is the correct layering — data is data —
  but content authors should be aware that deduplication logic lives on the manager side.
- **`trigger_event` is not validated at load.** An invalid id in `trigger_event` will silently
  fail to fire. A future content validator should scan every CutsceneDef and verify the id
  resolves inside EventRegistry (deferred to task-088).
