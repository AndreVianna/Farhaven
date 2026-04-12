# JournalEntry

**Source:** `scripts/journal/journal_entry.gd`
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md), [`journal.md`](journal.md), [`journal_entry_registry.md`](journal_entry_registry.md), [`event_registry.md`](event_registry.md)

## What this system is

JournalEntry is the data resource for a single piece of long-form narrative content that the
player can unlock and read in the Journal panel. Chapters, lore snippets, discovered notes,
and tutorial pages are all JournalEntry `.tres` files. JournalEntry is pure data: it does
not track its own unlock state (that lives on `Journal`), it does not choose when to be
shown (that is driven by GameEvent effects), and it does not render itself (that is the UI
panel's job). Like CutsceneDef, the data shape is engine plumbing only in delivery-006d;
the real journal chapters come in delivery-007.

## Promises to content

- **Identity is inherited from Gear.** Every JournalEntry carries an `id`, `display_name`,
  `short_description`, and `long_description` via Gear. `display_name` is the chapter title,
  `short_description` is a one-line teaser, and `long_description` is reinterpreted as the
  longer-form teaser shown above the body in the Journal panel.
- **The `body` field is the full text.** JournalEntry adds a dedicated `body` field (marked
  `@export_multiline` in the script) to hold the full content of the entry. The UI convention
  is: show `long_description` as a teaser paragraph, and show `body` as the full page on
  click. This split exists specifically so the panel can render an entry list with short
  previews without loading the entire body string into every row.
- **`category` lets the panel group entries.** The field is a `StringName` bucket name —
  `&"chapter"`, `&"lore"`, `&"tutorial"` are the current convention. JournalEntry itself
  enforces nothing; it is up to the panel to read the field and lay entries out accordingly.
- **`day_added` is advisory only.** It records which in-game day the author expected this
  entry to become unlockable. It is **not** an automatic unlock gate: the real unlock path
  is a GameEvent effect that calls `Journal.add_entry(id)`. A content author who wants a
  day-gated unlock must still author the event and the effect. Setting `day_added` only
  tells the journal panel what day label to show next to the entry.
- **Entries are read-only once authored.** Like other Gear subclasses, the runtime never
  mutates the `.tres` file on disk. The in-memory copy is shared — do not mutate it or the
  change will ripple across every caller holding a reference.

## Requirements from content

- **File location.** Every JournalEntry must live as a `.tres` file under the journal data
  directory (`res://data/journal/` by convention). JournalEntryRegistry scans this folder on
  startup and indexes every entry it finds.
- **Id prefix.** Ids must be `StringName` values starting with `J` (for example `&"J00001"`).
  The prefix is enforced by JournalEntryRegistry, not by JournalEntry itself.
- **Script reference.** The `.tres` file must bind its top-level `script` to
  `res://scripts/journal/journal_entry.gd`. Tooling that generates entries must emit this
  ExtResource entry.
- **`body` is intended for multi-line text.** Use `\n` for line breaks. The panel layer
  chooses how to render paragraph breaks and whether to apply BBCode; JournalEntry makes
  no formatting guarantees.
- **`category` is a `StringName`.** Plain strings will fail the typed assignment. Content
  should stick to the existing vocabulary (`chapter`, `lore`, `tutorial`) unless the panel
  has been updated to handle new buckets.
- **`day_added = 0`** means "available from the start." Any positive value is informational
  and does not change unlock logic.
- **Unlock path must go through GameEvent.** The intended pattern is: a GameEvent with an
  `unlock_journal_entry` effect that calls `Journal.add_entry(entry_id)`. A JournalEntry
  that is never referenced by such an effect will be loadable but unreachable — it will
  never appear in the journal panel.

## Extension points

- **GameEvent effect binding.** The canonical extension is: author a new GameEvent whose
  effect list includes `unlock_journal_entry` with your JournalEntry's id. This flows through
  EventRegistry → Journal.add_entry → Journal's `entry_added` signal → panel refresh.
- **Scanner/discovery-driven unlocks.** Because DiscoveryWatcher translates catalog states
  into GameEvent firings, discovery-driven journal unlocks work end-to-end without
  JournalEntry knowing anything about scanners. The wiring lives in DiscoveryWatcher and
  the GameEvent effect list; JournalEntry is just the payload.
- **Adding new fields.** Extra per-entry metadata (author, illustration path, section anchors,
  related-entries list) can be added as `@export` fields. Existing entries remain valid
  because new exports default to sensible values. The UI panel reads only the fields it
  knows about; unknown fields are ignored.
- **Custom rendering.** JournalEntry stores a `body` string; it does not prescribe how that
  string is rendered. A panel that wants to support rich markup, images, or embedded links
  can parse `body` on its own terms. This is an intentional separation — the data class
  stays lean.

## Genre-specific notes

JournalEntry is **fully genre-agnostic.** The shape — id, title, teaser, body, category,
advisory-day — describes a unit of unlockable narrative content that any game with a
codex/journal/lore panel could reuse. A Civ-like or Catan-like second game could ship
JournalEntry unchanged for its tech-tree flavor text, era history entries, or faction
biographies. Nothing in the class references hex grids, survival stats, scanners, or
real-time play.

The **only Farhaven-flavored piece** is the `day_added` field's implicit assumption that the
game has an "in-game day counter" at all (it references `DayNightCycle.day_count` by
convention). A turn-based game that used "turn number" or a strategy game that used
"era number" could reinterpret the field as "advisory phase index" without changing the
shape. The field is a plain `int` and has no hard binding to DayNightCycle at the class
level — the binding is entirely at the UI rendering layer.

## Known limitations and TODOs

- **Content is deferred to delivery-007.** Delivery-006d ships the JournalEntry class and
  Journal/JournalEntryRegistry plumbing only. Real chapter text, real unlock events, and a
  real catalog of entries come in delivery-007. The current 006d goal is "the plumbing loads
  and can display an empty journal panel without crashing."
- **`day_added` is not load-validated.** A JournalEntry with `day_added = 9999` will load
  fine; the panel will just show a number that never matches reality. No runtime gate
  enforces "do not show until day N."
- **`category` is a free-form `StringName`.** Typos produce silent new buckets rather than
  load errors. A future validator could warn about unknown categories.
- **No illustration / media slot.** The current fields are text-only. An `illustration` slot
  (Texture2D) and an `audio` slot (AudioStream) are reasonable additions but are out of
  scope for 006d.
- **No cross-entry links.** There is no built-in way for one JournalEntry's body to link to
  another by id. The UI panel could implement this by parsing BBCode, but the data class
  offers no native support.
- **No "read" state in the data class.** JournalEntry does not track whether the player has
  opened it. That state (if it exists) lives on `Journal` and in the save file. This is the
  correct layering but worth flagging for content authors expecting a `read` flag.
