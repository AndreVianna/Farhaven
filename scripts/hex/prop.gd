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


static func create_resource(type: StringName, remaining: int, max_amount: int,
		tool_required: StringName = &"", respawn_time: float = 0.0,
		rotation_deg: float = 0.0, sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.RESOURCE
	p.remaining = remaining
	p.max_amount = max_amount
	p.tool_required = tool_required
	p.respawn_time = respawn_time
	p.rotation_deg = rotation_deg
	p.sub_hex = sub_hex
	return p


static func create_structure(type: StringName, blocks_movement: bool = false,
		sub_hex: Vector2i = Vector2i.ZERO,
		footprint: Array[Vector2i] = []) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.STRUCTURE
	p.blocks_movement = blocks_movement
	p.sub_hex = sub_hex
	p.footprint = footprint
	return p


static func create_anomaly(type: StringName, sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.ANOMALY
	p.sub_hex = sub_hex
	return p


static func create_spawn(sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = &"spawn"
	p.category = Category.SPAWN
	p.sub_hex = sub_hex
	return p
