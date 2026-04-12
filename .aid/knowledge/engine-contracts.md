# Engine Contracts — Index

**Status:** Complete (delivery-006d task-083). 45 per-system contract files plus this index,
authored across sub-tasks 083a (template + sample), 083b (autoloads), 083c (data + capabilities),
083d (systems + UI), and 083e (final review + cross-reference pass). Ready for Andre review.

## What this is

Each entry below points at an explicit **engine contract** for one system: a prose document
that states what the system promises to content authors, what it requires from content, where
its extension points are, what parts of it are genre-specific to Farhaven vs reusable for a
second game, and what its known limitations are. The full contract template and the rationale
live in `.aid/work-001-core/delivery-006d/DETAIL.md` (task-083).

**How to read a contract.** Each file has six fixed sections: *What this system is*, *Promises
to content*, *Requirements from content*, *Extension points*, *Genre-specific notes*, and
*Known limitations and TODOs*. Content authors should focus on "Promises" and "Requirements";
engine authors should additionally read "Extension points" and "Genre-specific notes"; anyone
considering a second game built on this engine should read "Genre-specific notes" across every
contract to understand the v1 genre surface.

**How to read this index.** Entries are grouped by layer — data → autoloads → systems → UI —
following the order in which the engine initialises. Within each layer, entries are ordered by
how foundational they are (things other systems depend on come first).

**Link convention.** Contract filenames match the canonical snake_case name of the system
(`prop_def.md`, `hex_grid.md`, `journal_panel.md`). Every entry below points at a file that
exists on disk — there are no `[contract pending]` stubs.

---

## Data / capability layer

Resources that describe content. These are loaded from `.tres` files by the autoloads in the
next section. They have no runtime behavior of their own — they are pure data shapes.

### Base and composition

- **[Gear](contracts/gear.md)** — base class with `id`, `display_name`, `short_description`,
  `long_description`. Every data resource extends Gear.
- **[PropDef](contracts/prop_def.md)** — composition root for "everything is a prop."
  Inherits Gear identity, opts into zero or more capabilities. **Sample contract — complete.**

### Capability classes (12)

Each capability is a small optional `Resource` attached to a PropDef as a sub-resource. They
are independently opt-in and non-interacting.

- **[PortableCap](contracts/portable_cap.md)** — makes a prop carryable, holds `size` in
  slot-units (post-006b rename from `weight`).
- **[PlaceableCap](contracts/placeable_cap.md)** — pure marker class; presence enables
  player placement via BuildingSystem.
- **[ContainerCap](contracts/container_cap.md)** — gives a prop internal storage; holds
  `capacity_size` (slot-units) and an `accepts_filter` tag allowlist.
- **[LightCap](contracts/light_cap.md)** — makes a prop emit light; radius, colour, flicker.
- **[MovableCap](contracts/movable_cap.md)** — lets a placed prop be pushed or repositioned;
  holds `push_cost`. Distinct from MovementCap — runtime consumer pending.
- **[StationCap](contracts/station_cap.md)** — marks a prop as an interactive station
  (`craft`, `respawn`, `fireplace`, etc.); holds a free-form `station_tags` list.
- **[CatalogableCap](contracts/catalogable_cap.md)** — makes a prop scannable and
  catalog-trackable; holds scan time, anomaly override, icon, and open properties dict.
- **[EnduranceCap](contracts/endurance_cap.md)** — hit points plus vulnerability /
  resistance / immunity tag lists (genre-specific: survival/RPG).
- **[MovementCap](contracts/movement_cap.md)** — map-movement modes (WALK/SWIM/FLY/...) with
  per-mode `[normal, max]` speed pairs in sub-hex per second (genre-specific: hex grid,
  real-time).
- **[CombatCap](contracts/combat_cap.md)** — attack/defense GameEvent lists; **runtime not
  yet implemented** (scheduled for delivery-006d task-088).
- **[BehaviorCap](contracts/behavior_cap.md)** — creature AI policy: detection range,
  activity cycle, group behavior, diet tags, reaction events (genre-adjacent: fauna AI).
- **[SpawnableCap](contracts/spawnable_cap.md)** — world-spawn parameters: count range,
  first-day gate, minimum distance from player, biome allowlist.

### Other data resources

- **[CutsceneDef](contracts/cutscene_def.md)** — declarative cutscene description (media
  path, trigger-event id, advisory duration), used by CutsceneManager. Engine plumbing only
  in 006d; content comes in delivery-007.
- **[JournalEntry](contracts/journal_entry.md)** — single journal-entry resource (id, title,
  teaser, full `body`, category, advisory `day_added`), loaded by JournalEntryRegistry.
  Engine plumbing only in 006d; content comes in delivery-007.
- **[GameEvent](contracts/game_event.md)** — event definition with preconditions, effects,
  and max-count. Data class consumed by [`event_registry.md`](contracts/event_registry.md)
  (loader / firing infrastructure).
- **[Recipe](contracts/recipe.md)** — the `Recipe` data class root (id, inputs, outputs,
  conditions, effects, actions, duration). The five sibling classes (`RecipeInput`,
  `RecipeOutput`, `RecipeCondition`, `RecipeEffect`, `Predicate`) are documented inline in
  the Siblings section of the Recipe contract rather than as separate files — they are
  small data shapes that only exist as nested elements inside a Recipe. The loader is
  `recipe_registry.md`; the runtime executor is `recipe_runtime.md`.
- **[BiomeData](contracts/biome_data.md)** — biome configuration resource (colour, elevation
  range, prop table) loaded from `res://data/biomes/*.tres`.
- **[HexTile](contracts/hex_tile.md)** — single hex-tile resource with coords, biome,
  elevation, and a prop list. This is the data shape, not the HexGrid autoload.

---

## Autoload layer (12)

Singletons registered in `project.godot`, initialised in the order listed below (which is the
real order in `project.godot` — PropRegistry runs first so every later autoload can call
`PropRegistry.get_def` unconditionally).

- **[PropRegistry](contracts/prop_registry.md)** — scans `res://data/props/` on `_ready`,
  exposes `get_def(id)`, `has_def(id)`, `get_all()`. Owner of every PropDef in memory.
- **[HexGrid](contracts/hex_grid.md)** — map topology and coordinate math. The pure-utility
  coordinate helpers live in `scripts/hex/hex_math.gd` (no separate contract — stateless
  utility that HexGrid delegates to).
- **[DayNightCycle](contracts/day_night_cycle.md)** — in-game time, day/dusk/night/dawn
  transitions, tick signals.
- **[LightingManager](contracts/lighting_manager.md)** — global light state, phase-driven
  light toggling, LightCap aggregation.
- **[RecipeRegistry](contracts/recipe_registry.md)** — loads Recipe resources, exposes
  lookup and unlock state.
- **[EventRegistry](contracts/event_registry.md)** — loads GameEvent resources, provides
  `try_fire` and event-count persistence.
- **[DiscoveryWatcher](contracts/discovery_watcher.md)** — bridges scanner/catalog events
  into EventRegistry firings.
- **[RecipeRuntime](contracts/recipe_runtime.md)** — runs recipe lifecycle (start, sustain,
  complete, cancel), owns WorldContext and PredicateEvaluator.
- **[Journal](contracts/journal.md)** — player-facing journal state: unlocked entries,
  add/has queries, signals.
- **[JournalEntryRegistry](contracts/journal_entry_registry.md)** — loads JournalEntry
  resources.
- **[CutsceneManager](contracts/cutscene_manager.md)** — plays CutsceneDef sequences,
  signals on start/end.
- **[SaveManager](contracts/save_manager.md)** — full-state serialisation and restore
  across every autoload.

---

## System layer

World-level systems that are **not** autoloads but are created and owned by the running scene.
They coordinate behavior across multiple autoloads.

- **[AutoInteractionSystem](contracts/auto_interaction_system.md)** — player proximity-based
  interaction dispatch: gather recipe matching, tween-based gather timer, auto-pickup of
  ground items, and an auto-defend stub.
- **[BuildingSystem](contracts/building_system.md)** — player placement of Placeable props.
  Thin UX wrapper over `recipe_runtime.md` that handles placement mode, tile validation,
  highlight display, and SSH-snapped structure prop creation.
- **[FaunaManager](contracts/fauna_manager.md)** — night-time creature simulation: spawn,
  movement, contact damage, corpse placement, dawn despawn. Reads species config from
  SpawnableCap / BehaviorCap / MovementCap / EnduranceCap.
- **[SurvivalSystem](contracts/survival_system.md)** — HP / hunger / thirst tick clock plus
  activity costs, death + respawn sequence, and ground-item store.
- **[ScannerSystem](contracts/scanner_system.md)** — proximity auto-scan controller. Owns
  a [Catalog](contracts/catalog.md) instance and drives its state transitions. The
  separation is deliberate: ScannerSystem is the controller Node, Catalog is the pure data
  store.
- **[Catalog](contracts/catalog.md)** — knowledge data store (RefCounted) tracking
  UNKNOWN/ENCOUNTERED/CATALOGED state per entry, owned by ScannerSystem.
- **[Inventory](contracts/inventory.md)** — owned by Player, not an autoload. Prop slots +
  four fixed tool slots, size-based capacity enforcement, save/load.
- **[MapLoader](contracts/map_loader.md)** — one-shot JSON-to-HexGrid loader. Supports
  both the new `props` array format and the legacy `resources+structure+anomaly` format.

---

## UI layer

Contracts for what the UI panels depend on from the engine. These are thinner contracts: they
list what engine state the panel reads, what signals it subscribes to, and what actions it can
trigger back. They exist so that future UI rewrites can swap the panel without accidentally
relying on an undeclared engine assumption.

- **[HUD](contracts/hud.md)** — root HUD container. Owns stat bars, day counter, floating
  text, notifications, placement label, craft flash, and three combined panels (Status,
  Gear, Log). Routes external system signals to the right child widget and enforces mutual
  panel exclusion.
- **[JournalPanel](contracts/journal_panel.md)** — read-only view over Journal +
  JournalEntryRegistry. Master-detail layout with category filter. Embedded inside
  LogCombinedPanel alongside CatalogPanel.
- **[StatusCombinedPanel](contracts/status_combined_panel.md)** — STATUS button's two-column
  panel: left = stats + discoveries + nav sections, right = embedded InventoryPanel. Reads
  SurvivalSystem, DayNightCycle, Catalog, Inventory.
- **[InventoryPanel](contracts/inventory_panel.md)** — touch-first inventory drawer. Reads
  Inventory slots + tool slots, writes only via `Inventory.use_item` (tap-to-consume with a
  toxic-flora confirmation dialog).
- **[CatalogPanel](contracts/catalog_panel.md)** — read-only view over Catalog. Four-tab
  layout (Flora / Fauna / Minerals / Anomalies), counter header, per-entry rows that
  render ENCOUNTERED placeholders vs CATALOGED full entries. Embedded inside
  LogCombinedPanel alongside JournalPanel.

---

## Totals

- **Data / capability contracts: 20** — Gear, PropDef, 12 capability classes (Portable,
  Placeable, Container, Light, Movable, Station, Catalogable, Endurance, Movement, Combat,
  Behavior, Spawnable), CutsceneDef, JournalEntry, GameEvent, Recipe (with its five sibling
  classes documented inline in the Recipe Siblings section), BiomeData, HexTile.
- **Autoload contracts: 12** — PropRegistry, HexGrid, DayNightCycle, LightingManager,
  RecipeRegistry, EventRegistry, DiscoveryWatcher, RecipeRuntime, Journal,
  JournalEntryRegistry, CutsceneManager, SaveManager.
- **System contracts: 8** — AutoInteractionSystem, BuildingSystem, FaunaManager,
  SurvivalSystem, ScannerSystem, Catalog (split off from ScannerSystem to separate the
  RefCounted data store from the controller Node), Inventory, MapLoader.
- **UI contracts: 5** — HUD, JournalPanel, StatusCombinedPanel, InventoryPanel, CatalogPanel.

**Final total: 45 per-system contract files in `contracts/` + 1 index (this file) = 46
markdown files for the engine-contracts deliverable.** The DETAIL estimate of "~32" treated
the Recipe family as a single contract (still true in this delivery — the five siblings are
documented inline in `recipe.md`) and did not separately list Gear / BiomeData / HexTile /
JournalEntry / CutsceneDef / Catalog; counting those individually produces 45. No contracts
were merged or dropped during the 083e final review; the Recipe siblings (RecipeInput /
RecipeOutput / RecipeCondition / RecipeEffect / Predicate) were deliberately documented
inline in `recipe.md` rather than as five extra files because their shape is meaningful
only inside a containing Recipe.

---

## Dependency rules

- A contract may only declare dependencies on contracts in an **earlier** layer (data →
  autoload → system → UI), plus on other contracts in its **own** layer when composition
  demands it (e.g. PropDef depends on the capabilities).
- Cross-layer back-references are fine in prose (e.g. a data contract noting which autoload
  owns it) but must not create a hard cycle.
- When Contract A lists B under *Depends on*, Contract B should mention A in its *Extension
  points*, *Consumers* note, or *Genre-specific notes* where relevant, so the graph is
  navigable in both directions. The 083e review pass verified this across all 45 contracts
  and added explicit *Consumers* backlink summaries to the four most widely-depended-on
  contracts (PropDef, PropRegistry, HexGrid, EventRegistry).
