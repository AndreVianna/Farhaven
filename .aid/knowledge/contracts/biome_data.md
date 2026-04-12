# BiomeData

**Source:** `scripts/hex/biome_data.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** — (pure leaf resource; referenced by `map_loader.md` and `hex_tile.md`)

## What this system is

BiomeData is a per-biome configuration `Resource` loaded from `.tres` files in `res://data/biomes/`.
Each biome file describes how tiles of that biome look (colour, colour variations) and what
natural props populate them (a `prop_table` of prop type plus default stack sizes). BiomeData
is pure data — it has no methods and no behaviour. It exists so that biome authors can edit
Grassland, Forest, Rocky, Water, and Crash Site as independent files rather than baking those
values into code.

## Promises to content

- **Alphabetical filename order defines biome index.** MapLoader sorts the discovered `.tres`
  filenames before assigning them to the integer indices that `HexTile.biome` and the hex grid
  renderer both key off. As long as a biome keeps its filename stable, its integer id is stable
  across runs and platforms.
- **Fields default to safe empties.** A freshly created BiomeData with no fields set is valid:
  empty `prop_table` produces zero default props, empty `color_variations` makes the renderer
  fall back to `color`, and `elevation_range` defaults to `(0, 0)`.
- **`prop_table` is read by MapLoader, not enforced.** Each entry is a `Dictionary` (not a
  typed class) with keys `type`, `max_amount`, and optional `chance`, `min_amount`. MapLoader
  uses `type` and `max_amount` for per-instance defaults when a tile's JSON `props` entry
  omits them; the other fields are reserved for future procedural population and currently
  have no runtime effect.
- **`color_variations` is optional palette noise.** If the list is non-empty, the renderer
  picks from it per tile to break up large monochrome biome regions. Empty list → all tiles
  use the solid `color`.

## Requirements from content

- **File location.** Every BiomeData `.tres` must live directly under `res://data/biomes/` —
  no sub-folders. MapLoader scans that folder flat and ignores everything that doesn't end
  in `.tres`.
- **Filename equals biome id.** The basename of the file (without `.tres`) is what the map
  JSON uses in its per-tile `biome` field. For example `forest.tres` makes `"biome": "forest"`
  the correct key in map JSON. A typo in the map JSON silently falls back to biome index 0.
- **`biome_name` is display-only.** The human-readable name in the resource is never used as
  a lookup key — lookups go through the filename. Leaving it blank will not break loading.
- **`prop_table` entry shape.** Each entry must be a `Dictionary` literal with at minimum
  `type` (String or StringName) and `max_amount` (int). Adding unknown keys is harmless but
  adding fewer than the two required keys will cause MapLoader to fall back to the hardcoded
  default of 3 / 3.
- **No runtime creation.** BiomeData is only loaded from disk. Nothing in the engine creates
  BiomeData instances at runtime; there is no API for doing so.

## Extension points

- **Adding a new biome.** Drop a new `.tres` into `data/biomes/`, choose a filename that
  sorts into the desired integer slot (biome id is filename-order-determined), extend the
  `HexTile.Biome` enum to match, update the renderer's biome palette, and reference the
  filename in map JSON. No code changes needed in MapLoader itself.
- **Adding new prop_table fields.** The dictionary shape is duck-typed, so content can add
  new keys (e.g. `chance`, `min_amount`, `seed`) that future procedural systems will read.
  Existing code that only reads `type`/`max_amount` will ignore them.
- **Colour variation palette.** Content can add or remove `color_variations` entries without
  code changes. An empty list disables variation; a long list gives more visual noise.

## Genre-specific notes

BiomeData is **Farhaven-specific** in three ways:

- The `elevation_range` field assumes a hex-grid world with per-tile integer elevation — a
  concept that transfers to any tile-based game but not to a continuous-terrain RPG.
- The `prop_table` pattern (biome declares what can spawn there) is survival-genre typical:
  it assumes "biome determines what resources are present," which is how Minecraft, The Long
  Dark, Don't Starve, and most crafting survival games work. A Civ-like strategy game might
  instead key spawnables on tile improvements or strategic resources rather than biomes.
- Biome enum itself (Crash Site, Grassland, Forest, Rocky, Water) is **Chapter 1-specific**.
  Future chapters will add desert, swamp, ruins, etc. The enum integer widening is a trivial
  change; the point is that the v1 biome set is a game-design artefact, not a general-purpose
  terrain vocabulary.

The resource shape itself — colour + variations + prop population table — is general enough
to survive a genre shift. An engine-v2 strategy game could reuse BiomeData unchanged as long
as it re-interprets `prop_table` as "strategic resources on this biome."

## Known limitations and TODOs

- **No procedural population yet.** The `chance` and `min_amount` fields in `prop_table`
  entries are defined but unused. A future worldgen pass will read them to populate empty
  biome tiles without a hand-authored JSON map; until then they are decorative.
- **No rarity / weight system.** All prop_table entries are equally eligible. A future biome
  might want "rare mineral appears on 5% of tiles" — this would require extending the entry
  dictionary and the (future) procedural populator.
- **Filename-order-determines-id is fragile.** Renaming a biome file silently re-assigns its
  integer id and invalidates every existing save and map JSON that referenced the old id.
  A future pass should move biome identity to an explicit `id` field in the resource itself.
- **No elevation enforcement.** `elevation_range` is currently advisory — MapLoader does not
  check that a tile's elevation actually falls inside its biome's declared range. A validation
  pass could be added when procedural population lands.
