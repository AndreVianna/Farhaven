class_name BiomeData
extends Resource

## Per-biome configuration loaded from .tres files.
## prop_table entries: {type: String, max_amount: int, [chance: float, min_amount: int]}
## `type` and `max_amount` are used by map_loader.gd for per-instance overrides.
## `chance` and `min_amount` are reserved for future procedural biome generation
## (populate biomes at runtime instead of loading fully-specified JSON maps).

@export var biome_name: String = ""
@export var elevation_range: Vector2i = Vector2i(0, 0)
@export var prop_table: Array = []
@export var color: Color = Color.WHITE
@export var color_variations: Array[Color] = []
