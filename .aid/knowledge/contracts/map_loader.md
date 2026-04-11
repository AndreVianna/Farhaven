# MapLoader

**Source:** `scripts/hex/map_loader.gd`
**Category:** core
**Layer:** system
**Depends on:** [`biome_data.md`](biome_data.md), [`hex_tile.md`](hex_tile.md), [`prop_def.md`](prop_def.md), [`prop_registry.md`](prop_registry.md), [`hex_grid.md`](hex_grid.md). Not an autoload — a `RefCounted` instantiated by Main / game-start code with an injected HexGrid reference.

## What this system is

MapLoader is the **one-shot world construction step**. It parses a JSON level file, creates
`HexTile` resources for every declared tile, populates them with `Prop` instances based on
either the new `props` array format or the legacy `resources + structure + anomaly` format,
stores the spawn position and starting loadout on the grid, and validates the result for
reachability and biome/elevation sanity. It is a `RefCounted` that gets freed by the GC
once `load_map` returns — no persistent state.

It is not invoked at runtime after the initial load. Respawns do not re-run it; structure
placement does not re-run it; save/load bypasses it entirely by serialising HexGrid's tile
dictionary directly.

## Promises to content

- **Supports both the new and the legacy map JSON format.** The new format has a `props`
  array per tile with full Prop data (`type`, `origin`, `sub_hex`, `tool_required`,
  `respawn_time`, `rotation`, `remaining`, `max_amount`). The legacy format has separate
  `resources`, `structure`, and `anomaly` keys. Both produce identical HexTile output.
- **Biome discovery is alphabetical.** MapLoader scans `res://data/biomes/` at init, sorts
  the discovered filenames, and assigns each an integer index. The map JSON's `biome`
  string is looked up against this sorted list; a typo falls back to biome index 0.
- **Per-instance defaults come from biome `prop_table`.** If a map JSON prop entry omits
  `remaining` or `max_amount`, MapLoader reads the tile's biome's `BiomeData.prop_table`
  for a matching type and uses its `max_amount`. Failing that, defaults to 3/3.
- **Spawn format is forgiving.** The JSON `spawn` array can be 2, 4, or 5 elements:
  `[tile_col, tile_row]`, `[..., sub_hex_q, sub_hex_r]`, or
  `[..., sub_hex_q, sub_hex_r, facing_deg]`. Missing elements default to zero. Older maps
  with just two elements still work.
- **`starting_loadout` is stored verbatim on the grid.** MapLoader reads
  `root.get("starting_loadout", {})` and writes it to `_grid.starting_loadout`. Main code
  later reads this to configure the player's initial inventory and tools.
- **Validation is non-fatal.** Every check (tile count out of range, spawn tile missing,
  invalid elevation, unreachable tile, bad tile key) emits `push_warning` but does not
  abort loading. A map that mostly works but has a few unreachable tiles will still load.
- **Reachability validation uses flood-fill from spawn.** BFS over passable edges from the
  spawn tile; every non-water tile that isn't reached emits a warning with its coords,
  biome, and elevation.
- **Tile count is bounded at `[TILE_COUNT_MIN=200, TILE_COUNT_MAX=300]`.** Outside this range
  warns but loads. These constants are tuned to the Chapter 1 map size.
- **`HexGrid.map_generated` fires on success.** The completion signal allows downstream
  systems (FaunaManager, SurvivalSystem, renderers) to wait for the map before running
  their own initialisation.

## Requirements from content

- **Map file must be JSON with a `tiles` dictionary.** The root must be a Dictionary with
  a `tiles` key that maps string keys `"col,row"` to per-tile data. Missing `tiles` is a
  fatal-return-false condition.
- **Tile keys must be `"<col>,<row>"` with integer values.** `parts.size() != 2` triggers a
  skip warning. Whitespace around values is tolerated (`strip_edges()`).
- **Biome filenames must be `.tres`.** Non-`.tres` files in `data/biomes/` are ignored. Sub-
  folders are not scanned.
- **Biome filename basename is the JSON biome key.** `forest.tres` → JSON `"biome": "forest"`.
- **Props with `origin == NATURAL` get auto-populated defaults.** For non-natural props
  (structures, anomalies) the defaults are `remaining = 0, max_amount = 0` unless explicitly
  set in the JSON.
- **`tool_required` and `respawn_time` fall through to PropDef.** If the JSON doesn't set
  them, MapLoader reads them from the PropRegistry entry for the prop type. Content can
  rely on this: a map author doesn't need to repeat what's already on the PropDef.
- **HexGrid must have a mutable `_tiles` dictionary, `spawn_tile`, `spawn_sub_hex`,
  `spawn_facing_deg`, and `starting_loadout` fields plus a `map_generated` signal.**
  These are the concrete things MapLoader writes to. Any HexGrid implementation that wants
  to work with MapLoader must expose this surface.
- **PropRegistry must be scanned before MapLoader runs.** `_make_prop` and the new-format
  path both call `PropRegistry.get_def` / `PropRegistry.has_def` to look up per-prop
  defaults. An empty registry produces props with no tool_required and no respawn_time.

## Extension points

- **New map JSON fields.** Adding fields to the root dict is harmless — MapLoader only
  reads what it knows about. Adding fields to per-tile dicts is similarly safe.
- **New biome files.** Drop a `.tres` into `data/biomes/` with the desired filename (to
  control sort order) and reference it in map JSON. No MapLoader code changes.
- **Tile count bounds.** Adjust `TILE_COUNT_MIN` / `TILE_COUNT_MAX` constants for a
  different chapter. The validation is advisory so this is cosmetic.
- **Custom validators.** Add a new `_validate_*` method and call it from `_validate`. Each
  validator is a fail-soft warning emitter.

## Genre-specific notes

MapLoader is **mostly genre-agnostic** inside its own boundary. The JSON-to-tile-dictionary
pattern transfers to any game with tile-based levels. Where genre specificity shows up:

- **Hex-grid + sub-hex precision is Farhaven-specific.** A square-grid or continuous-world
  game would use different coordinate types. The JSON structure would have to change
  accordingly.
- **Biome discovery via filename sort is a simple convention.** Works for any game with a
  fixed biome vocabulary; a game with procedurally generated biomes would need a different
  loader entirely.
- **The `props` array shape is tied to Farhaven's Prop type.** Different games with different
  entity types would reshape this field. The key insight worth preserving is "per-tile
  instance data lives in an array keyed off a shared prop definition."
- **Reachability validation is survival-genre flavoured.** A game with teleportation or
  loading zones wouldn't need flood-fill reachability.
- **Starting loadout in the map file is survival-flavoured.** A chapter-based survival game
  can change what the player starts with per map. A game with a single character progression
  would store that data elsewhere.

The **fail-soft validation posture** is worth calling out as a deliberate design choice:
loud warnings, no hard failures, so a map with one typo still loads for playtesting. A
production game would want stricter validation before shipping.

## Known limitations and TODOs

- **No schema validation.** The JSON shape is only checked at consumption points; an
  unexpected key or typo is silently accepted.
- **Legacy format branch is kept alive.** The `resources + structure + anomaly` code path
  exists for old map files. It can be removed once every live map is migrated to the new
  `props` format.
- **Single flat tile dict.** No support for multi-level / multi-region maps. A future
  chapter with distinct zones would need either multiple map files or a region-layer
  concept on top.
- **Biome lookup uses filename order.** Renaming a biome `.tres` file silently re-assigns
  its integer index and breaks every existing save and map JSON that referenced the old
  index. See `biome_data.md` for the same limitation from the data-class side.
- **Reachability only considers passability, not traversal cost.** A tile that is reachable
  but only via a long awkward path is flagged as fine. "Unreachable with the player's
  current movement cap" (which depends on elevation jump limits) is not checked.
- **`_validate` loops all tiles even if biome bitmask + anomaly flag are never used.** The
  two local variables (`biomes`, `has_anomaly`) are assigned but not read afterwards — dead
  code left from an earlier version of the validator. Harmless but worth cleaning up.
- **MapLoader is not hot-reloadable.** Once a map is loaded, there is no API to re-load it
  without resetting the whole game. Editor tooling that wants live map reload must call
  `load_map` again with the same grid and accept that all runtime state will be wiped.
