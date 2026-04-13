# BiomeData

**Source:** `scripts/hex/biome_data.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** — (pure leaf resource; referenced by `map_loader.md` and `hex_tile.md`)

## What this system is

BiomeData is a per-biome configuration `Resource` loaded from `.tres` files in `res://data/biomes/`.
It extends `Gear`, so every biome carries an `id` (stable key), `display_name` (human label)
and optional descriptions — matching the id convention used by PropDef (`P00xxx`), Recipe
(`R00xxx`), GameEvent (`E00xxx`), and the other Gear subclasses. Biome files follow the
`B00NNN.tres` pattern.
Each biome file describes how tiles of that biome look — either a list of `terrain_textures`
(the renderer hash-picks one per tile for per-tile variation) or a single fallback `color` —
and now carries only cosmetic fields plus the inherited Gear identity. `prop_table` and
`elevation_range` have both been dropped from the resource; biome authors edit Grassland,
Forest, Rocky, Water, and Crash Site as independent files rather than baking those values
into code. BiomeData is pure data — no methods, no behaviour.

## Promises to content

- **Alphabetical filename order defines biome index.** MapLoader sorts the discovered `.tres`
  filenames before assigning them to the integer indices that `HexTile.biome` and the hex grid
  renderer both key off. As long as a biome keeps its filename stable, its integer id is stable
  across runs and platforms.
- **Fields default to safe empties.** A freshly created BiomeData with no fields set is valid:
  an empty `terrain_textures` list makes the renderer fall back to the solid `color`.
- **`terrain_textures` is optional per-tile variation.** If the list is non-empty, the hex
  grid renderer hash-picks one Texture2D per tile (deterministic on tile coords) and creates
  a separate MeshInstance3D / textured shader material per `(biome, variation_index)` bucket.
  Empty list → all tiles of that biome fall back to the solid `color` via the color-only
  shader.
- **`color` is the fallback tint.** Always defined, even on biomes that also carry textures;
  used when a texture fails to load or when code needs a representative swatch (e.g. the
  level editor's biome picker).

## Requirements from content

- **File location.** Every BiomeData `.tres` must live directly under `res://data/biomes/` —
  no sub-folders. MapLoader scans that folder flat and ignores everything that doesn't end
  in `.tres`.
- **Filename matches `id` field.** Files follow the `B00NNN.tres` convention and the resource's
  `id` field must match (e.g. `B00003.tres` has `id = &"B00003"`). Map JSON references biomes by
  filename stem, which in turn is used as lookup key to the sorted biome array at load time.
- **`display_name` is human-readable.** Inherited from Gear. The human-readable name in the
  resource is never used as a lookup key — lookups go through filename / id. Leaving it blank
  will not break loading.
- **Texture assets.** Each `terrain_textures` entry is a `Texture2D` reference, expected to
  live under `res://assets/textures/biomes/` with the convention `B00NNN_<slug>_<n>.png`.
  The renderer samples each texture in hex-local UV space so one copy of the image fits
  one hex tile.
- **No runtime creation.** BiomeData is only loaded from disk. Nothing in the engine creates
  BiomeData instances at runtime; there is no API for doing so.

## Extension points

- **Adding a new biome.** Drop a new `.tres` into `data/biomes/`, choose a filename that
  sorts into the desired integer slot (biome id is filename-order-determined), extend the
  `HexTile.Biome` enum to match, update the renderer's biome palette, and reference the
  filename in map JSON. No code changes needed in MapLoader itself.
- **Texture variation count.** Content can add or remove entries in `terrain_textures`
  without code changes. An empty list disables textures and falls back to `color`; a long
  list gives more per-tile visual variety.

## Genre-specific notes

BiomeData is **Farhaven-specific** in two ways:

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
- **Filename-order-determines-runtime-index.** The sorted filename defines the integer slot
  that map JSON references by stem. BiomeData now carries its own `id` field (B00NNN) matching
  the filename, so the data plane is stable; the runtime integer-index mapping still comes from
  alphabetical file order — renaming a biome file does still shift every subsequent biome's
  runtime index. A later pass could teach MapLoader to key off `id` instead of filename order
  once more than 10 biomes exist.
