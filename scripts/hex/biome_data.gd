class_name BiomeData
extends Resource

## Per-biome configuration loaded from .tres files.
## resource_table entries: {type: String, chance: float, min_amount: int, max_amount: int, tool_required: String}

@export var biome_name: String = ""
@export var elevation_range: Vector2i = Vector2i(0, 0)
@export var resource_table: Array = []
@export var color: Color = Color.WHITE
