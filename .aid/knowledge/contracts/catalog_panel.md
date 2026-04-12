# CatalogPanel

**Source:** `ui/catalog_panel.gd`
**Category:** engine-ui
**Layer:** ui
**Depends on:** [`catalog.md`](catalog.md), [`prop_def.md`](prop_def.md) (via the data returned by Catalog queries), `Prop.Category` enum (from `prop.gd`). Embedded inside LogCombinedPanel alongside [`journal_panel.md`](journal_panel.md).

## What this system is

CatalogPanel is the **read-only view onto the Catalog's discovered entries**. It is a
`PanelContainer` rendering a tab bar (Flora / Fauna / Minerals / Anomalies), a discovery
counter in the header, and a list of entry rows per tab. Each row is a `CatalogEntryUI`
widget that shows either a full entry (for CATALOGED state) or a "Unidentified Fauna
(label)" placeholder (for ENCOUNTERED state).

It does not own the catalog data — Catalog is the source of truth. The panel subscribes
to Catalog's two transition signals and refreshes itself when either fires.

## What it reads from the engine

- **`Catalog.get_discovery_text() → String`.** Used for the counter label ("N entries" or
  pluralisation variant). Refreshed on `entry_cataloged` and `entry_encountered` even when
  the panel is closed — the counter stays live.
- **`Catalog.get_discovered_by_category(prop_category: int) → Array`.** Called per tab
  during `_refresh`. Returns entries with state ≥ ENCOUNTERED in the given category,
  excluding anomaly-flagged entries.
- **`Catalog.get_discovered_anomalies() → Array`.** Returns entries with state ≥
  ENCOUNTERED that have `catalogable.show_as_anomaly = true`. Renders to the Anomalies
  tab regardless of underlying prop category.
- **`Catalog.get_knowledge_state(entry_id: StringName) → int`.** For each row, used to
  decide whether to render a full entry or the encountered placeholder.
- **`Catalog.get_encounter_label(entry_id) → String`.** For encountered-only entries,
  returns the label string ("Hostile" / "Shy") stored when the encounter happened.
- **`Catalog.entry_cataloged(entry_id, bucket)` signal.** Connected in `set_catalog`.
  Triggers a refresh if visible, or just updates the counter if hidden.
- **`Catalog.entry_encountered(entry_id, label)` signal.** Same routing as above.
- **Each entry result is a PropDef.** The `entry` field of each row is a full PropDef
  resource; `CatalogEntryUI.setup(def)` uses its `display_name`, `short_description`,
  `long_description`, and catalogable cap fields to render.

## What it calls back to the engine

**Nothing.** Catalog state is written by ScannerSystem (via `catalog.catalog_entry`,
`catalog.encounter_entry`) in response to scan completion, surprise encounter, or flee
encounter. The UI has no mutation path back into Catalog.

The panel emits:

- **`panel_opened`** — a UI-only signal used by LogCombinedPanel for mutual exclusion.

## Contract with LogCombinedPanel parent

- **`set_catalog(cat: Catalog)`.** Dependency injection. Disconnects any previous catalog's
  signals, stores the new reference, and connects the transition signals. Tests can inject
  mocks.
- **`toggle()`, `open()`, `close()`** — standard panel lifecycle. `open()` runs `_refresh()`
  and emits `panel_opened`.
- **Mutual exclusion** — LogCombinedPanel routes `panel_opened` for the three-panel
  exclusion logic (Status / Gear / Log).

## UI structure

- Header: title "CATALOG" + counter + close button
- Tab bar: four fixed tabs — `Flora`, `Fauna`, `Minerals`, `Anomalies`
- Per tab: a `VBoxContainer` scrollable list of `CatalogEntryUI` rows

The four tabs map directly to the four display buckets:

| Tab | Source | Prop.Category |
|---|---|---|
| Flora | `get_discovered_by_category(PLANT)` | PLANT |
| Fauna | `get_discovered_by_category(ANIMAL)` | ANIMAL |
| Minerals | `get_discovered_by_category(MINERAL)` | MINERAL |
| Anomalies | `get_discovered_anomalies()` | — (override flag) |

Tabs and lists are defined in the `.tscn` scene file; the panel only wires them up.

## Genre-specific notes

CatalogPanel is **horror / exploration / science-adventure flavoured**.

- **Tabs are Farhaven's Chapter 1 categories.** Flora / Fauna / Minerals / Anomalies is
  the Chapter 1 display bucket set. Future chapters may add Fungi, Liquids, Ooze, etc.
  The tab structure is hardcoded in the scene tree — adding a new tab requires a scene edit
  and updating `_populate_list_by_category` call site.
- **The three-state knowledge display (full vs encountered placeholder) is Farhaven-specific.**
  It supports the "you saw a thing but don't know what it is" horror beat. A Pokédex-style
  collection game would have two states (seen/caught); a combat RPG would have one (known).
- **Anomaly bucket is a narrative hook.** The Anomalies tab exists because Chapter 1's
  story has things that don't fit a clean category. A pure nature-sim catalog would drop it.
- **Master-list-of-tabs-plus-counter is generic.** Any bestiary / herbarium / lorebook uses
  this shape. CatalogPanel's UI structure could be reused for a Pokédex-style catalog by
  swapping the data source.

The shape of the engine → UI contract (Catalog + signals + per-category query methods)
is the reusable part. A second game could keep CatalogPanel almost as-is and replace only
the tab set and the query methods behind them.

## Known limitations and TODOs

- **Tab set is hardcoded.** Adding a new category (Fungi, Liquid) requires editing the
  scene file (add a new tab), editing `_refresh` (add a new `_populate_list_by_category`
  call), and extending `Catalog.DISPLAYED_CATEGORIES`. A data-driven tab list would be
  cleaner.
- **No search or filter inside a tab.** Large catalogs would benefit from text search.
  Deferred.
- **No sort order.** Rows appear in whatever order `Catalog.get_discovered_by_category`
  returns them — essentially dict iteration order. Not deterministic across runs for
  unordered entries. A future pass could sort alphabetically or by discovery time.
- **Counter pluralisation is English-only.** `"1 entry"` / `"%d entries"`. Needs a
  localisation pass.
- **No per-row tap / detail drill-in.** Each row shows its content inline. Tapping doesn't
  expand to a full-page view. Contrast with JournalPanel, which has a dedicated detail
  pane. Flagged as a UX asymmetry to reconcile.
- **ENCOUNTERED entries show a flat placeholder.** The "Unidentified Fauna (Hostile)" row
  has no image, no silhouette, no teaser text. Horror games might want something more
  atmospheric.
- **Catalog reference is stored by strong reference.** If Catalog is replaced at runtime
  (which doesn't happen in v1 but could happen in tests), the panel's `set_catalog` handles
  the disconnect cleanly.
- **Scene-file nodes are required.** The `@onready` variables assume the scene file
  provides the exact tree layout. Unlike JournalPanel, CatalogPanel has no programmatic-
  build fallback, so tests must load the full `.tscn`.
- **No save/load of UI state.** Active tab resets on panel close/open. Minor UX issue.
