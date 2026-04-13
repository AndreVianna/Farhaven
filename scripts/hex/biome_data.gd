class_name BiomeData
extends Gear

## Per-biome configuration loaded from .tres files.
##
## Inherits `id`, `display_name`, `short_description`, `long_description`
## from Gear. Biome files follow the `B00NNN.tres` convention with a
## matching `id = &"B00NNN"` value so biomes stay consistent with the
## other Gear subclasses (PropDef P00xxx, Recipe R00xxx, etc.).

@export var color: Color = Color.WHITE
@export var color_variations: Array[Color] = []
