# JournalEntryRegistry
**Source:** `scripts/journal/journal_entry_registry.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`journal_entry.md`](journal_entry.md), [`journal.md`](journal.md)

## What this system is

JournalEntryRegistry is the metadata catalog for journal entries. It scans
`res://data/journal/` on startup and indexes every JournalEntry `.tres` file by id,
exactly mirroring PropRegistry's pattern. Its job is to answer "what is the title of entry
`J00017`?" or "give me every entry in category FAUNA" — the exact questions Journal
deliberately doesn't answer. The UI panel pairs this registry with the Journal autoload:
Journal says "these ids are unlocked," the registry resolves each id to its display
content. It is the tenth autoload in `project.godot`, running after Journal so test fixtures
that seed Journal first find the registry ready.

## Promises to content

- **Every JournalEntry under `res://data/journal/` is loaded.** Flat scan, picks up any
  `.tres` whose top-level script is `journal_entry.gd`.
- **Missing directory is not an error.** If `res://data/journal/` doesn't exist, the scan
  silently stays empty. Wave 1 authoring (delivery-006c task-075b) explicitly tolerates
  an empty data folder because entries land in delivery-007.
- **`get_entry(id)` returns the resource or null.** Callers check for null before reading
  fields.
- **`has_entry(id)` is a cheap presence check.** Useful for validators that want to cross-check
  Journal unlock ids against authored entries.
- **`get_all_ids()` returns every authored id.** Returned as `Array[StringName]`.
- **`get_all_entries()` returns every entry resource.** Useful for "unlock everything"
  cheat menus or full-catalog debug tools.
- **`get_entries_by_category(category)` filters by the entry's `category` StringName field.**
  Currently the only secondary index. If a category is unknown, returns an empty array.
- **Test helpers exist.** `register_entry(entry)` lets unit tests inject in-memory
  JournalEntry fixtures without touching the filesystem; `clear()` empties the registry
  between tests. Both are public but intended for tests, not gameplay.

## Requirements from content

- **Entry `.tres` files live directly under `res://data/journal/`.** Flat scan only.
- **Every entry id must be a StringName starting with `J`.** Asserted at load time.
- **Ids must be unique across the entry set.** Silent overwrite on collision in filesystem
  order; content must guarantee uniqueness.
- **Entries must extend `journal_entry.gd`.** Files whose script points elsewhere are
  silently skipped.
- **The `category` field is a StringName.** `get_entries_by_category` compares with `==`
  on StringName, not String. Ad-hoc string categories will fail lookups.
- **Metadata fields (title, body, category) live on the JournalEntry resource.** The
  registry doesn't know about them; panels read them from the returned resource. See
  [`journal_entry.md`](journal_entry.md) for the resource contract.

## Extension points

- **Add an entry.** Drop a `.tres` file in `res://data/journal/`. No code change required.
- **Test injection.** `register_entry(...)` and `clear()` let unit tests bypass the
  filesystem. BDD scenarios that want specific entries available can seed them this way.
- **Additional indexes.** Adding a new `get_entries_by_X` helper means iterating
  `_defs.values()` and filtering. The design is deliberately minimal; there is no
  automatic pre-index for secondary fields beyond category. Secondary indexes can be
  added per-need.

## Genre-specific notes

JournalEntryRegistry is **fully engine-general**. The shape — "load content resources
from a directory, index them by id, support category filtering" — works for any
collectible-log system: RPG codex, cookbook, field guide, spy dossier, Pokédex.

Even the **category-as-StringName** choice is generic: any content model with a small
enum of groups benefits from the same filter. The Farhaven entry categories (fauna,
flora, anomalies, locations, etc.) are authoring-side data, not registry-side.

The deliberate separation from [`journal.md`](journal.md) — "unlock tracking here,
metadata there" — is the one engine-design choice baked into this file, and it
generalises well. Any second game should keep the split.

## Known limitations and TODOs

- **No hot-reload.** Edits to `.tres` files at runtime need a game restart.
- **Flat scan only.** No sub-folder organisation. Wave-1 expectation is a small entry
  library; delivery-007 will populate it. If the set grows beyond a few hundred, task-088
  will consider sub-folder support.
- **No duplicate-id detection.** Silent overwrite; content authoring must guarantee
  uniqueness.
- **Only one secondary index (category).** Other useful groupings (by tag, by biome, by
  unlock source) are not pre-indexed. Callers must iterate and filter themselves.
- **No cross-registry validation at load time.** The registry does not check whether
  entry ids referenced by EventRegistry's `unlock_journal_entry` effects exist. Bad ids
  surface only when the effect fires and Journal silently adds a non-existent id. A
  content-build validator is deferred to task-088.
- **Test helpers are public but unpoliced.** `register_entry` and `clear` can be called
  from gameplay code. They aren't gated by any build flag; discipline must keep them in
  tests only.
- **Wave-1 tolerates an empty folder.** Once delivery-007 ships entries, missing-folder
  tolerance can become a stricter warn-or-error. Not urgent.
