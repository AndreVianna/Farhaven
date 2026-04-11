# Engine Contracts — Index

**Status:** In progress (task-083, delivery-006d). Sample contract (`prop_def.md`) landed via
task-083a. Remaining files will be filled in by task-083b (autoloads), task-083c (data +
capabilities), and task-083d (systems + UI). Final cross-reference pass is task-083e.

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
(`prop_def.md`, `hex_grid.md`, `journal_panel.md`). A `[contract pending]` marker means the
contract file has not been authored yet; it will be delivered by one of task-083b/c/d.

---

## Data / capability layer

Resources that describe content. These are loaded from `.tres` files by the autoloads in the
next section. They have no runtime behavior of their own — they are pure data shapes.

### Base and composition

- **[Gear](contracts/gear.md)** — [contract pending] — base class with `id`, `display_name`,
  `short_description`, `long_description`. Every data resource extends Gear.
- **[PropDef](contracts/prop_def.md)** — composition root for "everything is a prop."
  Inherits Gear identity, opts into zero or more capabilities. **Sample contract — complete.**

### Capability classes (12)

Each capability is a small optional `Resource` attached to a PropDef as a sub-resource. They
are independently opt-in and non-interacting.

- **[PortableCap](contracts/portable_cap.md)** — [contract pending] — makes a prop carryable,
  holds size.
- **[PlaceableCap](contracts/placeable_cap.md)** — [contract pending] — makes a prop
  world-placeable, holds footprint.
- **[ContainerCap](contracts/container_cap.md)** — [contract pending] — gives a prop internal
  storage, capacity and filter rules.
- **[LightCap](contracts/light_cap.md)** — [contract pending] — makes a prop emit light,
  radius and colour.
- **[MovableCap](contracts/movable_cap.md)** — [contract pending] — lets a prop be pushed or
  repositioned after placement.
- **[StationCap](contracts/station_cap.md)** — [contract pending] — marks a prop as an
  interactive station (crafting, respawn, etc.).
- **[CatalogableCap](contracts/catalogable_cap.md)** — [contract pending] — makes a prop
  scannable and catalog-trackable, holds scan time and anomaly override.
- **[EnduranceCap](contracts/endurance_cap.md)** — [contract pending] — hit points plus
  vulnerability / resistance / immunity lists (genre-specific: survival).
- **[MovementCap](contracts/movement_cap.md)** — [contract pending] — map-movement modes and
  per-mode speeds (genre-specific: hex grid, real-time).
- **[CombatCap](contracts/combat_cap.md)** — [contract pending] — attack/defense GameEvent
  lists (runtime not yet implemented).
- **[BehaviorCap](contracts/behavior_cap.md)** — [contract pending] — creature AI policy:
  detection range, activity cycle, diet, reactions.
- **[SpawnableCap](contracts/spawnable_cap.md)** — [contract pending] — world-spawn
  parameters: count range, first-day gate, biome filter.

### Other data resources

- **[CutsceneDef](contracts/cutscene_def.md)** — [contract pending] — declarative cutscene
  description, used by CutsceneManager.
- **[JournalEntry](contracts/journal_entry.md)** — [contract pending] — single journal-entry
  resource, loaded by JournalEntryRegistry. *(Note: may be folded into the Journal contract
  during the 083e review if it has no standalone surface.)*
- **[GameEvent](contracts/game_event.md)** — [contract pending] — event definition with
  preconditions, effects, and max-count, used by EventRegistry.
- **[Recipe family](contracts/recipe.md)** — [contract pending] — covers `Recipe`,
  `RecipeInput`, `RecipeOutput`, `RecipeEffect`, `RecipeCondition`, and `Predicate` as a single
  contract (they only make sense together).
- **[BiomeData](contracts/biome_data.md)** — [contract pending] — biome configuration resource.
- **[HexTile](contracts/hex_tile.md)** — [contract pending] — single hex-tile resource; note
  this is a data shape, not the HexGrid autoload.

---

## Autoload layer (12)

Singletons registered in `project.godot`, initialised in the order listed below (which is the
real order in `project.godot` — PropRegistry runs first so every later autoload can call
`PropRegistry.get_def` unconditionally).

- **[PropRegistry](contracts/prop_registry.md)** — [contract pending] — scans
  `res://data/props/` on `_ready`, exposes `get_def(id)`, `has_def(id)`, `get_all()`. Owner of
  every PropDef in memory.
- **[HexGrid](contracts/hex_grid.md)** — [contract pending] — map topology and coordinate math
  (with a reference to `hex_math.md` for the pure-utility layer).
- **[DayNightCycle](contracts/day_night_cycle.md)** — [contract pending] — in-game time,
  day/dusk/night/dawn transitions, tick signals.
- **[LightingManager](contracts/lighting_manager.md)** — [contract pending] — global light
  state, phase-driven light toggling, LightCap aggregation.
- **[RecipeRegistry](contracts/recipe_registry.md)** — [contract pending] — loads Recipe
  resources, exposes lookup and unlock state.
- **[EventRegistry](contracts/event_registry.md)** — [contract pending] — loads GameEvent
  resources, provides `try_fire` and event-count persistence.
- **[DiscoveryWatcher](contracts/discovery_watcher.md)** — [contract pending] — bridges
  scanner/catalog events into EventRegistry firings.
- **[RecipeRuntime](contracts/recipe_runtime.md)** — [contract pending] — runs recipe
  lifecycle (start, sustain, complete, cancel), owns WorldContext and PredicateEvaluator.
- **[Journal](contracts/journal.md)** — [contract pending] — player-facing journal state:
  unlocked entries, add/has queries, signals.
- **[JournalEntryRegistry](contracts/journal_entry_registry.md)** — [contract pending] —
  loads JournalEntry resources.
- **[CutsceneManager](contracts/cutscene_manager.md)** — [contract pending] — plays
  CutsceneDef sequences, signals on start/end.
- **[SaveManager](contracts/save_manager.md)** — [contract pending] — full-state
  serialisation and restore across every autoload.

---

## System layer

World-level systems that are **not** autoloads but are created and owned by the running scene.
They coordinate behavior across multiple autoloads.

- **[AutoInteractionSystem](contracts/auto_interaction_system.md)** — [contract pending] —
  player proximity-based interaction dispatch, legacy gather fallback.
- **[BuildingSystem](contracts/building_system.md)** — [contract pending] — player placement
  of Placeable props, footprint validation, rotation.
- **[FaunaManager](contracts/fauna_manager.md)** — [contract pending] — spawn loop for
  SpawnableCap props, activity cycle integration, per-creature Behavior ticking.
- **[SurvivalSystem](contracts/survival_system.md)** — [contract pending] — hunger, thirst,
  health, exhaustion bookkeeping and day/night modulation.
- **[Scanner / ScannerSystem + Catalog](contracts/scanner_system.md)** — [contract pending] —
  scan lifecycle, ENCOUNTERED/CATALOGED transitions, catalog state, anomaly bucket.
- **[Inventory](contracts/inventory.md)** — [contract pending] — owned by Player, not an
  autoload. Regular slots and tool slots, capacity enforcement, save/load.
- **[MapLoader](contracts/map_loader.md)** — [contract pending] — loads map JSON into HexGrid
  state at session start.

---

## UI layer

Contracts for what the UI panels depend on from the engine. These are thinner contracts: they
list what engine state the panel reads, what signals it subscribes to, and what actions it can
trigger back. They exist so that future UI rewrites can swap the panel without accidentally
relying on an undeclared engine assumption.

- **[Hud](contracts/hud.md)** — [contract pending] — root HUD container, coordinates all
  child panels.
- **[JournalPanel](contracts/journal_panel.md)** — [contract pending] — reads Journal state
  and JournalEntryRegistry resources.
- **[StatusCombinedPanel](contracts/status_combined_panel.md)** — [contract pending] — reads
  SurvivalSystem stats, Scanner/Catalog state, discovery state.
- **[InventoryPanel](contracts/inventory_panel.md)** — [contract pending] — reads Player
  inventory, binds drag/drop to Inventory actions.
- **[CatalogPanel](contracts/catalog_panel.md)** — [contract pending] — reads Catalog state
  from Scanner/ScannerSystem.

---

## Totals

- Data / capability contracts: 19 (Gear + PropDef + 12 caps + CutsceneDef + JournalEntry +
  GameEvent + Recipe-family + BiomeData + HexTile)
- Autoload contracts: 12
- System contracts: 7
- UI contracts: 5

**Target total: ~43 files.** The DETAIL estimate of "~32" treats the Recipe family as a single
contract and does not separately list BiomeData / HexTile / Gear / JournalEntry / CutsceneDef;
when those are counted individually the figure rises. Task-083b/c/d agents should confirm the
final count against this index during 083e.

---

## Dependency rules

- A contract may only declare dependencies on contracts in an **earlier** layer (data →
  autoload → system → UI), plus on other contracts in its **own** layer when composition
  demands it (e.g. PropDef depends on the capabilities).
- Cross-layer back-references are fine in prose (e.g. a data contract noting which autoload
  owns it) but must not create a hard cycle.
- When Contract A lists B under *Depends on*, Contract B should mention A in its *Extension
  points* or *Genre-specific notes* where relevant, so the graph is navigable in both directions.
  The 083e pass verifies this.
