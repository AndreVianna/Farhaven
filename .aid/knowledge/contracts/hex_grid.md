# HexGrid
**Source:** `scripts/hex/hex_grid.gd`
**Category:** genre-specific
**Layer:** autoload
**Depends on:** [`prop_registry.md`](prop_registry.md), [`hex_tile.md`](hex_tile.md)

## What this system is

HexGrid is the world map. It owns every tile in the current map, the player spawn metadata
read from the map JSON, the traversability rules that let the player walk between tiles, and
the continuous terrain-height function that lets the renderer and the player agree on
"how high is the ground at this (x, z) point." Every cross-feature interaction with the map
goes through this singleton: "what tile is here," "who are my neighbors," "can I walk from
A to B," "what props are on this tile," "what's the terrain height under my feet," and the
save/load bookmarks for the current map. It is the second autoload in `project.godot`, right
after PropRegistry, so it can resolve prop capabilities while building save data and while
applying movement rules.

## Promises to content

- **Tile queries are non-destructive and nullable.** `get_tile(coords)` returns the
  HexTile resource or null; `has_tile(coords)` is a cheap membership check; `get_all_tiles()`
  returns the live dictionary (callers must treat it read-only). A missing tile never crashes
  a query — it returns null, an empty array, or the sentinel value 999 for elevation diff.
- **Neighbor and range lookups only return real tiles.** `get_neighbors(coords)` and
  `get_tiles_in_range(center, radius)` filter out coordinates that HexMath would produce but
  that aren't in the loaded map. Callers get valid coords only, never "coordinates that might
  exist." Pure coordinate math without filtering lives in `hex_math.gd`.
- **Traversability is a 4-state classification.** `get_traversal(from, to)` returns
  `WALK` (elevation diff 0–2), `JUMP` (diff 3–4 going up), `DROP` (diff 3–4 going down), or
  `BLOCKED` (diff ≥5, water biome, or any prop on the destination tile tagged
  `BLOCKS_MOVEMENT`). `is_passable(from, to)` is a boolean shortcut.
- **`BLOCKS_MOVEMENT` is data-driven.** The traversal check asks PropRegistry for each prop
  on the destination tile and calls `has_tag(&"BLOCKS_MOVEMENT")`. Content can mark any prop
  as blocking by adding that tag; no code change needed.
- **Terrain height is continuous.** `get_terrain_y(world_x, world_z)` returns a smooth
  height value using a quintic smoothstep between the tile's center, edge midpoints, and
  corners. Water tiles return flat elevation (no interpolation into land). The renderer's
  12-vertex ring layout and the player's foot-on-ground logic both call this function, so
  they always agree on the ground surface.
- **Signals narrate map events.** `map_generated` fires when a map finishes loading;
  `tile_entered` / `tile_exited` track the player's current tile;
  `prop_depleted` / `prop_respawned` mark lifecycle of gatherable props;
  `structure_placed` / `structure_destroyed` bracket building-system changes. Downstream
  autoloads ([`lighting_manager.md`](lighting_manager.md),
  [`day_night_cycle.md`](day_night_cycle.md)) connect to these.
- **Spawn metadata is exposed as plain fields.** `spawn_tile`, `spawn_sub_hex`,
  `spawn_facing_deg`, and `starting_loadout` are populated by MapLoader when it reads the
  map JSON. Game-start code reads them directly — no signal, no method, just fields.
- **Save/load is round-trip lossless for tile state.** `get_save_data()` emits every tile,
  its biome/elevation, and every prop on it (including sub-hex offset, remaining amount,
  rotation, respawn timer). `load_save_data(data)` accepts the same shape and also accepts
  the legacy pre-task-053 format (`resources` / `structure` / `anomaly` arrays) for backward
  compatibility.

## Requirements from content

- **Coordinates are axial `Vector2i`.** `(col, row)` pairs. Flat-top hex orientation.
  Neighbor direction indices are 0=E, 1=NE, 2=NW, 3=W, 4=SW, 5=SE. See `hex_math.gd` for
  the full direction table.
- **`HEX_SIZE` and `ELEVATION_STEP` are load-bearing constants.** `ELEVATION_STEP = 0.5`
  world-units per elevation level. `HEX_SIZE` is defined on HexMath and used by world-to-axial
  projection. Shaders, meshes, and the terrain renderer must use these same constants; ad-hoc
  scaling in scene nodes will desync the ground surface.
- **HexTile resources own props.** Each HexTile has `biome`, `elevation`, `coords`, and a
  `props` array of Prop resources. The registry stores tiles; tile-local props live on
  the HexTile, not on the grid. See [`hex_tile.md`](hex_tile.md) for the tile contract.
- **Maps must be loaded through `load_map(path)` or `load_save_data(data)`.** Direct mutation
  of `_tiles` from outside HexGrid is not supported (the field is conventionally private).
  MapLoader does the JSON-to-HexTile construction; save/load does the save-dict construction.
- **Props that block movement must declare the `BLOCKS_MOVEMENT` tag.** There is no field for
  it on PropDef — it's a StringName tag and only a tag. Content must spell it exactly.
- **Elevation diffs beyond 4 are always blocked.** Flags for "climb" or "teleport" modes
  would need new code; the current traversal function has no escape hatch beyond the three
  tiers.

## Extension points

- **Movement modifiers.** Any system that wants to veto movement beyond the current
  elevation/biome/tag rules would wrap `get_traversal` in its own gate. The registry itself
  has no "movement policies" plug-in surface yet.
- **Prop-category filters.** `get_props_by_category(coords, category)`, `has_structure`,
  and `get_anomaly` already provide common "what's on this tile" filters; new categories
  can be added on HexTile without touching HexGrid's public surface.
- **Spawn metadata on load.** MapLoader writes `spawn_tile` / `spawn_sub_hex` /
  `spawn_facing_deg` / `starting_loadout` before emitting `map_generated`; consumers of the
  signal can read those fields synchronously.
- **Tile visitation signals.** New systems that need to react to "player moved here" or
  "something was built here" connect to the existing signals — no need to poll.

**Consumers.** HexGrid is the world-state hub; the systems that read tile / traversal /
topology from it include [`day_night_cycle.md`](day_night_cycle.md) (via the `tile_entered`
hook for per-tile shader lighting), [`lighting_manager.md`](lighting_manager.md) (local
light aggregation per tile), [`fauna_manager.md`](fauna_manager.md) (spawn tile selection
and creature movement), [`map_loader.md`](map_loader.md) (tile construction at load),
[`survival_system.md`](survival_system.md) (tile-based environmental damage),
[`save_manager.md`](save_manager.md) (full tile-state serialisation),
[`scanner_system.md`](scanner_system.md) + [`catalog.md`](catalog.md) (scannable lookup
per tile), [`auto_interaction_system.md`](auto_interaction_system.md) (proximity gather
radius interacts with tile props), and [`movement_cap.md`](movement_cap.md) (sub-hex
per second speeds are defined against this grid's topology).

## Genre-specific notes

HexGrid is **deeply Farhaven-specific**. A second game on this engine would keep a topology
autoload with the same role but likely not this implementation:

- **Flat-top hex orientation** is baked into every coordinate routine in HexMath and every
  renderer ring assumption. A square-grid game would replace the whole coordinate layer, not
  just configure it.
- **Elevation tiers (WALK_MAX_DIFF=2, JUMP_MAX_DIFF=4)** are a survival-exploration choice.
  A strategy game might use cost-based movement with a full pathfinder and no hard cliffs.
- **Water = always blocked** is a survival-genre decision tied to the "no swimming" scope.
  A naval game would make water a mode, not a blocker.
- **The terrain-height smoothstep** is tied to the 12-vertex ring mesh layout; a game using
  square tiles or a continuous heightmap would compute ground Y completely differently.
- **Signals like `prop_depleted` / `prop_respawned`** assume gather loops with respawn
  timers — very survival-genre. A Catan-like game would emit totally different map events.

The part of HexGrid that does generalise is the **"one autoload owns the world and exposes
topology + traversability + save/load"** shape. That pattern is reusable; the specifics
aren't.

See `scripts/hex/hex_math.gd` for the pure-utility coordinate-math layer (no separate contract
file — the helper is deliberately a stateless utility that HexGrid delegates to) and
[`map_loader.md`](map_loader.md) for how map JSON becomes HexGrid state.

## Known limitations and TODOs

- **No pathfinding.** `get_traversal` is a pairwise check; A* or Dijkstra layers would sit
  on top. Task-088 deferred work.
- **Legacy save format is still accepted.** `load_save_data` branches on whether tiles carry
  `props` (new) or `resources`/`structure`/`anomaly` (legacy). The legacy branch will be
  removed once no pre-task-053 saves exist in the wild. See task-088.
- **Prop position granularity.** Props carry `sub_hex` offsets (fine-grained placement
  within a tile) but HexGrid's public API does not expose sub-hex-aware neighbor queries.
  Callers that need "nearest prop in my sub-hex" must iterate `tile.props` themselves.
- **No map validation on load.** If a saved tile references a prop type that PropRegistry
  doesn't know about, the prop is silently kept with its raw id. Downstream systems
  (BuildingSystem, LightingManager) will miss that prop when they ask PropRegistry for its
  def. A validation pass on load is deferred to task-088.
- **Single map per session.** The grid is cleared on `load_save_data` but multi-map support
  (chunks, biome swaps, portal transitions) is not in scope. Engine-v2 territory.
- **Fauna and dynamic props are not tile-owned yet.** Creatures tracked by FaunaManager do
  not serialize through `get_save_data`; only static tile props do. See
  [`fauna_manager.md`](fauna_manager.md).
