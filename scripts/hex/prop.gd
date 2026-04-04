class_name Prop
extends Resource

## Unified game object placed in a hex tile.
## Replaces ResourceNode. Category defines behavior.

enum Category { RESOURCE, STRUCTURE, ANOMALY, SPAWN }

@export var type: StringName = &""
@export var sub_hex: Vector2i = Vector2i.ZERO        # (sq, sr) within parent hex
@export var category: Category = Category.RESOURCE

# Resource-specific fields
@export var remaining: int = 0
@export var max_amount: int = 0
@export var tool_required: StringName = &""
@export var respawn_time: float = 0.0
@export var rotation_deg: float = 0.0

# Structure-specific fields
@export var footprint: Array[Vector2i] = []           # Sub-hexes this structure occupies
@export var blocks_movement: bool = false
