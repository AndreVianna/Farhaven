# Journal
**Source:** `scripts/journal/journal.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`event_registry.md`](event_registry.md), [`journal_entry_registry.md`](journal_entry_registry.md), [`game_event.md`](game_event.md), [`journal_entry.md`](journal_entry.md)

## What this system is

Journal is the player-facing "what I've discovered" state tracker. It holds the set of
unlocked JournalEntry ids in a dictionary, provides idempotent add/has queries, and emits
a signal the first time an entry is unlocked. Crucially, it is deliberately minimal: it
knows nothing about the entries' titles, bodies, or categories — that metadata lives in
JournalEntryRegistry, which the UI panel queries separately. Journal's only job is "has
the player seen this yet?" It auto-subscribes to `EventRegistry.event_fired` so that any
GameEvent with an `unlock_journal_entry` effect triggers an add without gameplay code
having to route anything manually. It is the ninth autoload in `project.godot`, after
EventRegistry, so the subscription can be wired up during its own `_ready`.

## Promises to content

- **`add_entry(id)` is idempotent.** Calling it twice with the same id returns true the
  first time (newly added) and false every subsequent time (already unlocked). The
  `journal_entry_added(id)` signal fires exactly once — on the first add.
- **Empty ids are rejected silently.** `add_entry(&"")` returns false without side effects.
  Callers that pipe in ids from event params don't need to check for empty strings.
- **`is_unlocked(id)` is a cheap check.** Dictionary lookup; UI panels call it per-entry
  when rendering.
- **`get_unlocked_ids()` returns a typed `Array[StringName]`.** Useful for save code and
  for listing all-known entries in one pass.
- **Event-driven unlocks are automatic.** Any GameEvent with an `unlock_journal_entry`
  effect whose `params.entry_id` is non-empty triggers an `add_entry` when the event fires.
  Gameplay code never has to call `Journal.add_entry` directly for that path — firing the
  event is enough.
- **Direct unlocks are also supported.** Code paths that don't go through events
  (cheat menus, tutorial autoplay, RecipeRuntime's direct `unlock_journal_entry` effect
  handling) can call `Journal.add_entry(id)` at any time.
- **Unlocks are permanent within a run.** There is no `lock_entry` or `clear_entry`. The
  only way to lose an unlock is to reload a save that didn't contain it.
- **No registry validation.** `add_entry` deliberately does not check whether the id
  exists in JournalEntryRegistry. Callers can add synthetic ids for testing without
  seeding the registry, and BDD scenarios can drive the Journal without the data layer
  being present.
- **Save/load round-trips the unlocked set.** `get_save_data()` emits the id array;
  `load_save_data(data)` replaces the current set wholesale (clearing and repopulating).

## Requirements from content

- **Entry ids are StringNames.** The Journal stores them in a dictionary keyed by
  StringName; callers passing plain Strings will end up with different keys and fail
  lookups silently.
- **Unlock paths converge on `add_entry`.** Whether triggered by an event effect, a
  recipe effect, or direct code, every unlock eventually calls `add_entry`. Callers
  building new unlock sources should do the same instead of writing to `_unlocked`
  directly.
- **Metadata lookup must go through `JournalEntryRegistry`.** Journal itself carries no
  title, no body, no category. UI panels that want to display entries ask
  `JournalEntryRegistry.get_entry(id)` for the resource and read its fields there. A
  display system that tries to ask Journal for the title will find nothing.
- **EventRegistry must exist when Journal's `_ready` runs.** It does — EventRegistry is
  autoload six, Journal is autoload nine. Do not insert a new autoload between them that
  removes EventRegistry from the tree.
- **Events that unlock journal entries must carry the effect directly.** The effect kind
  must be exactly `unlock_journal_entry` and the params must include a non-empty `entry_id`
  StringName. Any other format is silently ignored.

## Extension points

- **New unlock paths.** Any system can call `Journal.add_entry(id)` at any time. Cheat
  menus, tutorial hooks, and cutscene sequencers all use this.
- **Subscribe to unlocks.** `journal_entry_added(entry_id)` fires once per new unlock.
  The journal panel UI listens here to pop "new entry" notifications; achievement and
  audio feedback systems can listen too.
- **Mock the event registry.** `_event_registry` is an injectable field that defaults to
  the autoload but can be replaced in tests.
- **Alternative metadata sources.** Because Journal doesn't know about the registry, a UI
  variant could look up metadata from a different source (e.g. a localised content
  database) without touching Journal.

## Genre-specific notes

Journal is **fully engine-general**. "Track unlocked entries in a set, emit a signal on
first unlock, round-trip via save data" is a pattern usable in any game. The same shape
works for RPG codex entries, strategy game lore dumps, puzzle game hints, fighting game
character profiles. The class could be reused unchanged in a second game.

The **Farhaven-specific parts** are entirely on the content side — what an entry is
(species sighting, anomaly log, environmental observation), how entries are unlocked
(cataloguing, exploration, quest milestones), and what the panel looks like. None of that
lives in Journal. The autoload is a pure set-of-strings with a signal.

The **deliberate separation from JournalEntryRegistry** is a Farhaven design choice that
generalises well: it lets tests run without seeding a content library, lets content add
entries without touching unlock code, and lets the UI panel be rewritten independently.
A second game would almost certainly keep this split.

## Known limitations and TODOs

- **No metadata.** The journal remembers ids and nothing else — no timestamps, no
  "discovered on day N," no "discovered via event E." Narrative replay features would
  need a separate store.
- **No categories or filtering.** Callers that want "only species entries" must ask
  JournalEntryRegistry for each id's category and filter themselves.
- **No notification queue.** `journal_entry_added` fires synchronously during the event
  that triggered it. If multiple entries unlock in the same frame (e.g. a cutscene grants
  a bundle), the UI receives multiple signals in rapid succession with no batching.
- **No un-unlock.** Temporary entries ("this page will disappear after you read it") are
  not supported. Task-088 defers this if needed.
- **Registry validation is intentionally absent.** That's a feature for tests but a mild
  risk in production: a typoed event param will silently add a non-existent entry. A
  validator tool that cross-checks Journal.add_entry call sites against
  JournalEntryRegistry ids at content build time would catch this.
- **Save format is a flat array.** No versioning, no metadata envelope. If the save shape
  needs to evolve, a migration pass will be required.
