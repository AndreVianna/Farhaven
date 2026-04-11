# ScannerSystem

**Source:** `scripts/scanner/scanner_system.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`catalog.md`](catalog.md) (owns and mutates a Catalog instance), [`prop_def.md`](prop_def.md), [`catalogable_cap.md`](catalogable_cap.md), [`hex_grid.md`](hex_grid.md), [`survival_system.md`](survival_system.md) (for activity cost/drain), [`fauna_manager.md`](fauna_manager.md) (for surprise-encounter wiring). Not an autoload — child Node of Player. **Distinct from Catalog** which is a pure data store (see `catalog.md`).

## What this system is

ScannerSystem is the **proximity auto-scan controller**. It owns one Catalog instance, runs a
per-frame scan loop that picks the nearest uncatalogued prop within `SCAN_RANGE` hexes, and
drives a progress timer that completes the scan on exit. When complete, it updates the
Catalog and fires signals so HUD and journal can react. It also handles two "knowledge
transitions" for fauna — surprise encounter (first contact from a hostile) and shy encounter
(first flee from a shy creature) — and runs a passive identification pass that labels visible
props as identified / encountered / unknown for the renderer.

The separation from Catalog is important: **Catalog is the data store**; ScannerSystem is
the **controller** that drives scan lifecycle on top of the data.

## Promises to content

- **One scan at a time.** The system maintains a single `_is_scanning` flag. Only one scan is
  in progress ever; the next one starts automatically when the current one finishes or is
  interrupted.
- **Nearest uncatalogued wins.** On each frame, the system scans the player's tile plus six
  neighbours (within `SCAN_RANGE = 1` hex), asks Catalog for the first scannable entry at
  each, and picks the closest. If multiple candidates share a distance, the one the grid
  returns first wins (deterministic per session but not specified across sessions).
- **Leaving range interrupts immediately.** There is no grace period. If the player walks
  more than `SCAN_RANGE` from the target mid-scan, `scan_interrupted` fires, scanning drain
  stops, and the system immediately looks for a new target on the next frame.
- **Scan duration is per-category with anomaly override.** Plants and minerals take 2s,
  animals take 3s, others take 2s. A prop whose `catalogable.show_as_anomaly == true`
  overrides to 3s regardless of its underlying category.
- **Scan progress updates fire every tick.** `scan_progress_updated(progress: float)` fires
  each frame during a scan, with `progress ∈ [0, 1]`. HUD progress bars read this.
- **Completion emits three signals.** `scan_completed(entry_id)`, `entry_cataloged(entry_id,
  bucket)`, and `knowledge_state_changed(entry_id, old, new)` all fire in that order. The
  bucket is either a `Prop.Category` int or `Catalog.ANOMALY_BUCKET`.
- **Surprise encounter fires on first hostile contact.** `on_fauna_attacked_player` (called
  by AutoInteractionSystem's defend path or by FaunaManager directly) marks the species as
  ENCOUNTERED with label `"Hostile"` if it wasn't already known.
- **Passive identification runs per visible tile.** `_check_passive_identification(coords)`
  walks the tile's props and emits `element_identified` / `element_encountered` /
  `element_unknown` based on catalog state. This is what lets the renderer show different
  labels on visible props.
- **`bootstrap_visible()` runs passive ID for every loaded tile.** Called by Main after
  map load to populate initial labels.
- **Activity drain is SurvivalSystem-integrated.** On scan start, `apply_activity_cost(&"scanning")`
  and `start_activity_drain(&"scanning")` are called on the sibling SurvivalSystem. On
  completion or interruption, `stop_activity_drain(&"scanning")` fires.
- **Save/load delegates to Catalog.** `get_save_data` and `load_save_data` wrap Catalog's
  serialisation in a `{"catalog": ...}` dict.

## Requirements from content

- **Must be child of Player.** Walks `get_parent()` to find the player and reads
  `player.current_tile`. The sibling `SurvivalSystem` is found by scanning parent's children
  for one with an `apply_activity_cost` method.
- **HexGrid autoload must be registered.** Used directly as the typed `HexGrid` global in
  `_ready`. Tests can override the `_grid` field before `_ready`.
- **Scannable props need the `CatalogableCap`.** Only PropDefs with a non-null catalogable
  cap are queryable via `Catalog.get_scannable_at`. A prop with the cap but flagged
  `show_as_anomaly = true` routes to the anomaly bucket.
- **Display name is non-empty to be eligible.** Catalog's `_is_displayable` check includes
  the PropDef's display name non-emptiness. Entries without a display name are invisible
  to the catalog UI even if catalogable.
- **Animals need special entry path.** Uncataloged animals that already have ENCOUNTERED
  state cannot be scanned by proximity (the scanner only sees UNKNOWN animals). Cataloguing
  encountered animals requires a trap or sneak mechanic (deferred to F-010 scope).

## Extension points

- **Connect `entry_cataloged` for UI.** CatalogPanel listens via the Catalog instance
  directly (since the Catalog itself emits identical signals). HUD's log combined panel
  routes the counter update through this.
- **`get_catalog()` returns the owned Catalog instance.** AutoInteractionSystem uses this to
  fetch the catalog for its legacy gather gate. New systems that need catalog lookups should
  go through this accessor.
- **`is_scanning()` and `get_scan_progress()` are polled.** Signals are the preferred path
  but a one-shot status query exists for debug/HUD tooling.
- **Scan duration tuning.** Content can change `SCAN_DURATIONS` constants without touching
  the scan logic. Long-term these will move to per-species `CatalogableCap.scan_time`
  fields (flagged below).
- **Inject `_grid` and `_catalog` for tests.** Both are `var`s set in `_ready` but can be
  overridden before the node enters the tree.

## Genre-specific notes

ScannerSystem is **horror / exploration genre flavoured**.

- **Proximity scanning as a verb.** The "walk up to a thing, wait for scan bar to fill" loop
  is classic first-person exploration (Alien: Isolation, SOMA, Subnautica's scanner tool,
  Prey's psychoscope). A combat-focused game would replace this with a passive identification
  or eyeball-aim scanner.
- **ENCOUNTERED / CATALOGED state is horror-flavoured.** The three-state knowledge model
  (unknown / encountered-but-not-understood / fully documented) is a specific choice for
  building unease: you know a wolf exists because it bit you, but you haven't studied it yet.
  A Pokédex-style collection game would use a similar two-state model.
- **Activity drain is survival-flavoured.** The idea that scanning costs thirst is specific
  to Farhaven's survival layer. A science-fiction exploration game might instead cost "scanner
  battery" or "film exposures."
- **Anomaly bucket is Farhaven-specific.** The concept of "some things override their
  category to live in a separate anomaly tab" is tied to Chapter 1's mystery-story framing.
  A pure nature-sim game wouldn't need it.
- **Fauna surprise-encounter is horror-flavoured.** Fires specifically on first hostile
  contact to create a "what just happened" beat in the log.

The **Catalog + ScannerSystem split** (data store + controller) is reusable: any game with
a knowledge-gating system benefits from keeping the store pure data and the controller
a Node.

## Known limitations and TODOs

- **SCAN_DURATIONS is a constant dict.** Tunable only via code. Should move to
  `CatalogableCap.scan_time` per species. Currently the cap has a `scan_time` field that
  isn't consulted — a small cleanup.
- **SCAN_RANGE is 1.** Hardcoded. No way to boost with a tool or upgrade. A future
  ScannerCap or a SurvivalUpgrade system could lift this.
- **No multi-scan.** Only one scan in progress at a time. A busier player who approaches a
  cluster of unknowns has to wait through each one sequentially. An upgrade path might
  allow 2-3 simultaneous scans.
- **Passive identification runs on every visible tile.** `bootstrap_visible` iterates every
  loaded tile, and there's no incremental refresh during play — new props that arrive on a
  tile after bootstrap need a manual refresh pass. Currently that refresh happens implicitly
  on next visit.
- **Encountered-animal gating.** Animals in ENCOUNTERED state cannot be cataloged by proximity,
  but there's no trap/sneak mechanic to unlock them in v1. The F-010 feature flag covers
  this but isn't implemented; animals discovered via surprise stay half-known indefinitely.
- **Fauna scanner path is incomplete.** The comment "Fauna handled by ScannerSystem via
  FaunaManager; not queried here at data layer" in `catalog.gd` hints at a cross-system
  coupling that isn't fully wired up. Hostile fauna on the current tile can't be proximity-
  scanned in v1.
- **Dependency injection pattern is ad-hoc.** `_resolve_dependencies` is called via
  `call_deferred` from AutoInteractionSystem — a workaround for sibling initialisation order.
  A cleaner pattern would be explicit Player-level wiring.
