# HexTile

**Source:** `scripts/hex/hex_tile.gd`
**Category:** core
**Layer:** data
**Depends on:** [`biome_data.md`](biome_data.md) (via `biome` enum), [`prop_def.md`](prop_def.md) (via `props` array elements and PropRegistry tag lookups)

## What this system is

HexTile is the per-tile `Resource` that HexGrid stores in its `_tiles` dictionary. It is the
data shape that describes a single hexagonal cell of the world: coordinates, biome, elevation,
and the list of props (natural, structure, and anomaly) currently sitting on that cell.
HexTile has no behaviour — it is a container. Its only "smart" methods are filter helpers
that walk `props` and return subsets by tag, capability, origin, or category.

Note the distinction from HexGrid: HexGrid is the autoload that owns the whole tile map and
does coordinate math. HexTile is the per-cell record. A system that wants "the forest at
(12, 4)" calls `HexGrid.get_tile(Vector2i(12, 4))` and receives a HexTile.

## Promises to content

- **`coords`, `biome`, `elevation` are the minimal identity.** Every HexTile instance carries
  its grid coordinate, a biome enum value, and an integer elevation. These three fields are
  what HexGridRenderer and every system that filters tiles needs to know. Callers can rely on
  them being populated after MapLoader finishes.
- **`props` is mutable.** The array of props on a tile is not frozen at load time. Systems
  like BuildingSystem (`see building_system.md`), AutoInteractionSystem (see
  `auto_interaction_system.md`), and FaunaManager (see `fauna_manager.md`) append and remove
  props from this array during gameplay. Readers must tolerate this — there is no snapshot
  semantics.
- **Filter helpers return new arrays.** `get_props()`, `get_structures()`, `get_anomalies()`,
  `get_props_with_tag(tag)`, and `get_props_with_capability(cap_name)` each return a fresh
  `Array` containing references to props still owned by the tile. Modifying the returned array
  does not affect the underlying `props` field — but mutating a prop in the returned array
  does mutate the real prop (they are shared references).
- **`get_props_with_tag` and `get_props_with_capability` consult PropRegistry.** These helpers
  resolve the prop's PropDef through the PropRegistry autoload to check tags and capability
  presence. They return an empty array for props whose `type` has no registered PropDef rather
  than crashing.
- **`get_props()` filters by origin, not category.** It returns only props whose `origin` is
  `NATURAL`. Structures (CRAFTED) and anomalies (anomaly flag) are excluded. This is the v1
  "gatherable natural props on this tile" query.

## Requirements from content

- **HexTile is not authored by hand.** Content does not write `.tres` files for individual
  hex tiles. Tiles are created by MapLoader from map JSON at session start and by FaunaManager/
  BuildingSystem/AutoInteractionSystem at runtime when needed. The contract for "what shape a
  tile has" is therefore implicit in what MapLoader emits (see `map_loader.md`).
- **`biome` must be a valid `Biome` enum value.** MapLoader maps each biome filename to an
  integer via alphabetical sort order; any tile whose `biome` int is outside the enum range
  will confuse the renderer and any system doing biome-specific logic. The valid set in v1 is
  `CRASH_SITE`, `GRASSLAND`, `FOREST`, `ROCKY`, `WATER`.
- **`elevation` must fit a signed 16-bit integer.** MapLoader clamps incoming map JSON values
  to `[-32000, 32000]` and warns on out-of-range; systems downstream assume this range when
  computing elevation differences or packing tiles.
- **`props` entries must be Prop instances.** The array is typed `Array` (not `Array[Prop]`)
  for historical reasons, but every system that reads `props` assumes every entry is a `Prop`.
  Inserting something that isn't a Prop will crash downstream.

## Extension points

- **New filter helpers.** Adding a new way to query tile contents (e.g. `get_props_in_radius`)
  is a one-method addition to `hex_tile.gd`. It only needs to walk `props` and filter — no
  other system needs to change.
- **Extending Biome.** Adding a new biome (desert, swamp, ruins) means adding an enum value,
  adding a matching BiomeData `.tres`, and updating HexGridRenderer's palette. Existing code
  that switches on the enum will need explicit handling, but existing HexTile instances remain
  valid because biome integers are forward-compatible.
- **Tile metadata.** Content can add fields (e.g. `owner`, `temperature`, `visited_count`)
  directly to `hex_tile.gd`. Existing save formats will ignore unknown fields on load; new
  saves will persist them once SaveManager's tile serialiser is taught about them.

## Genre-specific notes

- **Hex grid is Farhaven-specific.** The HexTile type itself assumes a hex grid. A square-grid
  or continuous-world game would use a different tile type or no tile type at all. A Civ-like
  successor built on this engine could reuse HexTile more or less as-is (its shape is generic
  enough), but a Skyrim-like open-world successor would discard it.
- **`biome` enum values are Chapter 1-specific.** The v1 set of five biomes is a game-design
  artefact. The enum pattern itself is reusable; the actual values will be replaced or extended
  per chapter/genre.
- **`elevation` semantics are Farhaven-specific.** The v1 elevation integer is used by
  MovementCap's `JUMP` mode (see `movement_cap.md`) and by blocking checks — it encodes
  "how high above the reference plane" on a 2.5D hex map. A flat 2D survival game would
  leave this at 0 everywhere; a 3D first-person game would replace it with real Y.
- **`props` as a flat array is genre-agnostic.** Most games need "things on this cell" for
  roughly the same reasons.

## Known limitations and TODOs

- **Deprecated `get_props_by_category`.** The method walks `props` looking at a legacy
  `prop.category` field. Pre-capabilities props still set it; new props leave it unset. The
  method exists for transitional compatibility and is explicitly marked for removal. New code
  should use `get_props_with_tag(&"STRUCTURE")` or `get_props_with_capability(&"station")`
  instead.
- **No spatial index inside `props`.** Filtering walks the array linearly. Tiles with many
  props pay O(n) for every filter call. HexTiles rarely have more than a handful of props,
  so this is not currently a problem, but it's a known scaling floor.
- **No "sub-hex grid" on HexTile.** Props carry their own `sub_hex` offset, and collision
  queries walk the props list rather than indexing into a 2D array. A future engine v2 might
  add a sub-hex occupancy grid on HexTile to make placement queries O(1).
- **`get_structures` has legacy-branch coupling.** It first checks the PropDef STRUCTURE tag,
  then falls through to the old `prop.category == STRUCTURE` test. The legacy branch exists
  for a narrow window of old save files and will be pruned when those saves cannot be loaded
  anymore.
