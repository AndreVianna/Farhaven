class_name Prop
extends Resource

## Unified game object placed in a hex tile.
## Replaces the old ResourceNode class. Category defines behavior.

enum Category {
	PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE,
	STRUCTURE, VEHICLE, EQUIPMENT, STORAGE,
}

enum Origin {
	NATURAL, CRAFTED, HUMAN, NATIVE_ALIEN, UNKNOWN,
}

@export var type: StringName = &""
@export var sub_hex: Vector2i = Vector2i.ZERO        # (sq, sr) within parent hex
@export var category: Category = Category.PLANT
@export var origin: Origin = Origin.NATURAL

# Prop-specific fields
@export var remaining: int = 0
@export var max_amount: int = 0
@export var tool_required: StringName = &""
@export var respawn_time: float = 0.0
@export var rotation_deg: float = 0.0

# Structure-specific fields
@export var footprint: Array[Vector2i] = []           # Sub-hexes this structure occupies
@export var blocks_movement: bool = false


## Returns true if this prop is considered an anomaly (derived state).
func is_anomaly() -> bool:
	return origin != Origin.NATURAL and origin != Origin.CRAFTED


## Returns true if this prop has a natural origin.
## Replaces the old category-range check (task-051 migration).
func is_natural_category() -> bool:
	return origin == Origin.NATURAL


static func create_prop(type: StringName, remaining: int, max_amount: int,
		tool_required: StringName = &"", respawn_time: float = 0.0,
		rotation_deg: float = 0.0, sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.PLANT
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
	p.category = Category.MINERAL
	p.origin = Origin.UNKNOWN
	p.sub_hex = sub_hex
	return p
