# Catalog

**Source:** `scripts/scanner/catalog.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md), [`catalogable_cap.md`](catalogable_cap.md), [`prop_registry.md`](prop_registry.md), [`hex_grid.md`](hex_grid.md) (for `get_scannable_at`). Owned by [`scanner_system.md`](scanner_system.md). **Distinct from ScannerSystem**: Catalog is a pure data store (RefCounted), ScannerSystem is the controller Node that mutates it.

## What this system is

Catalog is Farhaven's **knowledge database** — a `RefCounted` store that tracks which
catalogable entries the player has seen, in what state, and with what labels. It scans
PropRegistry once at initialisation to build the master list of displayable entries (filtered
by category and anomaly flag), then maintains per-entry `KnowledgeState` (UNKNOWN →
ENCOUNTERED → CATALOGED) as the player scans things. It emits signals on state transitions
and exposes query methods for UI panels.

Catalog is **not a Node**. It is owned by the ScannerSystem instance and lives for as long
as the scanner does. It is serialised directly (via `get_save_data` / `load_save_data`) and
its data is wrapped by ScannerSystem when saved to disk.

## Promises to content

- **Three knowledge states per entry.** `UNKNOWN` (default), `ENCOUNTERED` (known to exist,
  not studied — only reachable for animals via surprise or flee), `CATALOGED` (fully
  documented via scan). The enum is `Catalog.KnowledgeState` and is persisted in saves.
- **Monotonic state transitions.** An entry can go UNKNOWN → ENCOUNTERED or UNKNOWN →
  CATALOGED or ENCOUNTERED → CATALOGED. It can never go backwards (except via `reset()`
  in tests) and never skip into an earlier state.
- **Encounter labels are attached to ENCOUNTERED state only.** `encounter_entry(id, label)`
  takes a human-readable string (`"Hostile"`, `"Shy"`) and stores it. Upgrading to
  CATALOGED clears the label. Labels are surfaced via `get_encounter_label(id)`.
- **`entry_cataloged` and `entry_encountered` signals fire on transitions.** `knowledge_state_changed`
  fires on every transition with old and new state integers. UIs subscribe to any of these
  depending on what they want to react to.
- **The display bucket is derived on emit.** Signal payloads include a `bucket: int` that is
  either a `Prop.Category` enum value or the sentinel `Catalog.ANOMALY_BUCKET = -1`. The
  anomaly bucket is assigned when the entry's `CatalogableCap.show_as_anomaly == true`,
  otherwise bucket equals `entry.prop_category`.
- **Displayable filter is strict.** Only PropDefs with a non-null catalogable cap AND
  (a `Prop.Category` in `DISPLAYED_CATEGORIES` — PLANT, ANIMAL, MINERAL — OR the anomaly
  override) count as catalog-tracked. Structures, equipment, etc. with catalogable caps are
  excluded so the discovery count stays in sync with UI-visible entries.
- **Query API is pure read.** `get_knowledge_state`, `is_cataloged`, `is_encountered`,
  `is_known`, `get_entry`, `has_entry`, `get_discovered_entries`,
  `get_discovered_by_category`, `get_discovered_anomalies`, `get_discovery_count`,
  `get_total_count`, `get_discovery_text`, `get_encounter_label`. None of these mutate.
- **`get_discovered_by_category` excludes anomalies.** If an entry's catalogable cap has
  `show_as_anomaly = true`, it does NOT appear under its underlying `prop_category` — it
  lives only in the anomaly bucket. This keeps the UI tabs clean.
- **`get_scannable_at(coords)` returns the first uncatalogued scannable entry id on a tile,
  or `&""`.** Used by ScannerSystem to pick scan targets. Skips ENCOUNTERED animals (they
  need traps/sneak, not proximity scan). Skips non-catalogable props and entries not in
  the `_all_entries` set.
- **`encounter_entry` enforces that only animals can enter ENCOUNTERED.** Plants and
  minerals can't be "encountered but not known" — they're either unknown or cataloged.
  Calling `encounter_entry` on a non-animal pushes a warning and no-ops.
- **Save format is a dict of id strings → state strings.** `get_save_data` emits
  `{knowledge: {id: "ENCOUNTERED"|"CATALOGED"}, encounter_labels: {id: "label"}}`.
  `load_save_data` parses both plus a legacy `discovered` array for old saves.

## Requirements from content

- **Initialized via `initialize(hex_grid, fauna_manager)`.** ScannerSystem calls this in its
  `_ready`. `hex_grid` must expose `get_tile(coords)`. `fauna_manager` is accepted but not
  actively used in the data path (kept for forward compatibility).
- **PropRegistry must be scanned before Catalog initializes.** `_load_all_entries` walks
  `PropRegistry.get_all()` to build the master list. A Catalog created before PropRegistry
  is ready will have an empty entry set.
- **Catalog entries come from PropDefs.** Content adds a new catalog entry by adding a
  `CatalogableCap` to a PropDef and giving the PropDef a non-empty `display_name` and a
  `prop_category` in `DISPLAYED_CATEGORIES`. No other per-entry file is needed.
- **ID is the PropDef id.** Entry IDs are `StringName` equal to the PropDef's `id` field.
  Save format stores them as plain strings and re-wraps them on load.
- **Anomaly override is per-PropDef.** Setting `catalogable.show_as_anomaly = true` routes
  the entry to the anomaly bucket regardless of its underlying `prop_category`. Content can
  use this to hide spoiler minerals or plants under "Anomalies" during Chapter 1.

## Extension points

- **New DISPLAYED_CATEGORIES.** Adding a new bucket (e.g. FUNGI, LIQUID, OOZE) means
  extending both the `DISPLAYED_CATEGORIES` constant and the CatalogPanel's tab layout.
  The Catalog data structure itself supports any category — it's just filtering that's
  gated on this list.
- **New knowledge states.** The enum `UNKNOWN, ENCOUNTERED, CATALOGED` could grow (e.g.
  `MISIDENTIFIED` for a mystery-story twist). Each new state needs a persistence string
  mapping in `get_save_data` / `load_save_data`.
- **Signal subscription.** Both the Catalog instance and the ScannerSystem emit the same
  entry-transition signals. UIs that want to be decoupled from ScannerSystem's node
  lifecycle should subscribe to the Catalog directly (via `ScannerSystem.get_catalog()`).
- **Tests inject a HexGrid mock.** Pass a mock to `initialize` and the scannable lookups
  will walk whatever tiles the mock returns.

## Genre-specific notes

Catalog is **exploration / science-horror genre flavoured**.

- **Three-state knowledge model is genre-specific.** ENCOUNTERED is the interesting middle
  state that only makes sense in horror/exploration games: "I know it exists but I don't
  know what it is." Most RPGs use two states (unknown / known); some Pokémon-likes use a
  three-state model (seen / caught / documented).
- **Anomaly bucket is a mystery-story hook.** The override flag exists specifically so the
  writers can move strange minerals or spooky plants out of their natural category and into
  a dedicated spoiler tab. A non-mystery game would drop this entirely.
- **Animals-only ENCOUNTERED.** The `encounter_entry` guard against plants and minerals is
  a deliberate choice — plants don't surprise you, they don't flee, they just sit there.
  A strategy game with abstracted creatures might allow any entity to be encountered.
- **The concept of "catalog" itself transfers well.** Any game with a bestiary, herbarium,
  codex, or journal has a similar shape: a master list of entries, per-entry state, UI
  hooks on state changes. Catalog is a clean blueprint for that.

## Known limitations and TODOs

- **PropRegistry coupling is hard.** Catalog depends directly on the global PropRegistry
  autoload. A test that doesn't populate PropRegistry first produces an empty catalog.
  Injectable registry reference would help.
- **`_load_all_entries` is one-shot.** If new PropDefs are added at runtime (hot reload,
  DLC), the catalog doesn't notice. Future: a `reload_entries()` method or a connect to
  a PropRegistry "entries changed" signal.
- **Fauna-sync gap.** The `fauna_manager` reference is passed to `initialize` but not used.
  The comment in `get_scannable_at` says fauna are handled elsewhere. This means hostile
  creatures on the current tile cannot be scanned from the data path alone — scanner has
  to coordinate with FaunaManager separately. Flagged.
- **Backward-compatible `discovered` array path.** `load_save_data` still handles the old
  flat array format ("just list the ids") as a fallback. This can be removed once no live
  save file uses it.
- **Save format uses plain strings for state.** `"ENCOUNTERED"` / `"CATALOGED"` rather than
  integer enums. Fine for stability but slightly less compact than ints.
- **`get_discovery_text()` is hardcoded English.** "1 entry" / "2 entries" pluralisation
  needs a localisation pass when translation lands.
- **No indexing.** `get_discovered_by_category` walks every entry in `_knowledge`. For v1
  catalog sizes this is fine, but a catalog with thousands of entries would want an index
  per category.
