# JournalPanel

**Source:** `ui/journal_panel.gd`
**Category:** engine-ui
**Layer:** ui
**Depends on:** [`journal.md`](journal.md) (autoload), [`journal_entry_registry.md`](journal_entry_registry.md) (autoload), [`journal_entry.md`](journal_entry.md) (data). Embedded inside LogCombinedPanel alongside [`catalog_panel.md`](catalog_panel.md).

## What this system is

JournalPanel is the **read-only player-facing view onto journal state**. It displays the
list of unlocked journal entries, lets the player filter by category (All / Chapter / Lore /
Tutorial), and shows the selected entry's body in a detail pane. It is a `PanelContainer`
typically embedded in LogCombinedPanel (the "Log" combined panel that also contains
CatalogPanel). It has no write path — the player cannot add, delete, or edit journal
entries from the UI. All mutation comes from the engine firing `journal_entry_added` after
unlocking a new entry.

## What it reads from the engine

- **`Journal.get_unlocked_ids() → Array[StringName]`.** The list of entry IDs the player has
  unlocked. Populated initially on `_refresh`; refreshed whenever `journal_entry_added` fires.
- **`Journal.journal_entry_added` signal.** Fires with the new entry's id. The panel listens
  and calls `_refresh` to rebuild its entry list. Duck-typed: if the Journal instance doesn't
  have this signal (test double), no subscription happens.
- **`JournalEntryRegistry.get_entry(id) → Resource`.** Returns the `JournalEntry` data
  resource for a given id. Used for populating rows (display name + category) and detail
  view (title + body + date).
- **`JournalEntry.display_name`, `.category`, `.short_description`, `.long_description`,
  `.body`, `.day_added`.** The five fields the panel reads. `body` is the full-page text
  (used for detail view); `long_description` is a fallback for legacy entries; `category`
  is a StringName used for filtering.

## What it calls back to the engine

**Nothing.** JournalPanel is strictly read-only. It never mutates Journal state, never
calls a registry method beyond `get_entry`, and never fires any engine signal back upstream.
The only things it emits are:

- **`panel_opened`** — a UI-only signal used by the parent LogCombinedPanel for mutual
  exclusion. Not consumed by any engine system.

## Contract with HUD / CombinedPanel parent

- **`toggle()`, `open()`, `close()` are the panel lifecycle API.** LogCombinedPanel (and
  any future embedder) calls these to show or hide the panel. `open()` triggers a `_refresh()`
  and emits `panel_opened`. `close()` just hides.
- **`set_registry(registry)` and `set_journal(journal)`.** Dependency injection hooks for
  tests. The parent panel or test harness can pass a mock registry / journal; `_refresh`
  will re-read from the new source. If not called, the panel auto-resolves both from the
  global autoload tree in `_resolve_dependencies()`.
- **`panel_opened` signal.** Emitted from `open()` for mutual exclusion routing.
- **Close button behaviour is embedding-aware.** When embedded inside a CombinedPanel, the
  close button is hidden (same pattern as CatalogPanel). The panel is closed by closing the
  parent combined panel instead.

## UI structure (so embedders know what they're embedding)

- Header: title + entry counter + close button
- Category filter row: All / Chapter / Lore / Tutorial toggle buttons
- HSplit: entry list (left, 40% width) + detail view (right, 60% width)
- Detail view: title + date_added + scrollable body + "Select an entry." placeholder

The UI is built programmatically in `_build_ui_programmatic` as a fallback if the scene
file doesn't provide the expected nodes (`_build_ui_if_needed` checks and falls through).
This means tests that instantiate via `.new()` get a functional UI.

## Genre-specific notes

JournalPanel is **mostly engine-UI**. Its mechanics transfer to any game with a journal,
codex, encyclopedia, or lore viewer:

- **Master-detail layout is universal.** List of entries on the left, selected entry's
  content on the right. Every game with a codex uses this shape.
- **Category filter is a soft convention.** The four Farhaven categories (All / Chapter /
  Lore / Tutorial) are a design choice, not a hard dependency. A different game would
  declare different filter buttons. The filter logic itself just checks `entry.category`
  against the active filter; it's generic.
- **`body` vs `long_description` split is Farhaven-specific.** The JournalEntry class has
  a dedicated `body` field for the full-page text, and falls back to `long_description`
  for old entries. This is a transitional state documented in `journal_entry.md`. Games
  with a single description field would simplify this.
- **`day_added` display is Farhaven-specific.** The `"Day %d"` format assumes the day/night
  cycle. A game with real-time timestamps or chapter-based dating would reformat.
- **Category filter buttons hardcoded in `FILTER_CATEGORIES`.** Adding a new category
  means extending both the constant and the `FILTER_LABELS` dict. A data-driven filter
  would read the category list from the registry.

The UI separation "data class (JournalEntry) + store (Journal autoload) + loader
(JournalEntryRegistry autoload) + view (JournalPanel)" is a clean pattern worth preserving.

## Known limitations and TODOs

- **No search.** Filtering is by category toggle only. A text search over entry titles
  and bodies is deferred.
- **No sort order.** Entries appear in whatever order `Journal.get_unlocked_ids()` returns
  them — typically unlock order. No alphabetical, date, or chapter sort.
- **Detail view re-reads on every refresh.** If the user is looking at entry X and the
  list refreshes, the detail view is rebuilt from scratch. Smooth in practice but
  technically wasteful.
- **No animation on entry unlock.** A new entry just appears in the list. A polish pass
  could fade it in or highlight it briefly.
- **Filter state is not persisted.** Closing and reopening the panel resets filter to
  "All". Save/load doesn't round-trip UI state.
- **Font sizes are hardcoded.** 28px for title, 22px for counter, 20px for rows, 18px for
  body. No text scaling for accessibility.
- **Close button width is hardcoded at 96×96.** Touch-friendly on mobile but no
  accommodation for different screen densities.
- **Duck-typed Journal interface.** The panel uses `has_method` and `has_signal` guards so
  that a test double without those methods doesn't crash. This is pragmatic but means the
  Journal contract is enforced only implicitly.
- **Selection state lost on filter change if the selected entry is filtered out.** The
  panel detects this (`_is_selected_visible`) and clears `_selected_id`, showing the
  empty detail view. Expected behaviour but potentially disorienting.
