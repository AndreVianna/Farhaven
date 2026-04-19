class_name BiomeData
extends Gear

## Per-biome configuration loaded from .tres files.
##
## Inherits `id`, `display_name`, `short_description`, `long_description`
## from Gear. Biome files follow the `B00NNN.tres` convention with a
## matching `id = &"B00NNN"` value so biomes stay consistent with the
## other Gear subclasses (PropDef P00xxx, Recipe R00xxx, etc.).

## Variations for terrain rendering. When this list is non-empty the hex
## grid renderer hash-picks one texture per tile, which gives visual
## variety to a biome without having to tile a single seamless image.
## When the list is empty the renderer falls back to the solid `color`
## below so the game still has something to show.
@export var terrain_textures: Array[Texture2D] = []

## Fallback solid color when `terrain_textures` is empty OR the renderer
## needs a tint to debug a missing asset.
@export var color: Color = Color.WHITE

## Generative prop distribution table — driven by the Map Editor
## "Populate" command. Each BiomeProp entry names a PropDef id, a
## spawn probability, a grouping count range, and placement
## conditions (elevation, nearby biomes, nearby props). Empty =
## biome contributes no generative props.
@export var natural_props: Array[Resource] = []
