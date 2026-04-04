class_name ResourceNode
extends Resource

@export var type: StringName = &""
@export var remaining: int = 0
@export var max_amount: int = 0
@export var tool_required: StringName = &""
@export var respawn_time: float = 0.0              # Seconds until respawn after depletion (0 = no respawn)
@export var offset: Vector2 = Vector2.ZERO       # Normalized -1 to 1, relative to hex center
@export var rotation_deg: float = 0.0             # Degrees, converted to radians at render time
