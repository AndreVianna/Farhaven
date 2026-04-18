class_name Prop
extends Resource

## Unified game object placed in a hex tile.
## Replaces the old ResourceNode class. Category defines behavior.

enum Category {
	PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE,
	STRUCTURE, VEHICLE, EQUIPMENT, STORAGE,
	STUFF,
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

# Feature-011 per-instance overrides. Sentinel values (< 0 for signed
# fields) mean "use the procedural default from the seed". These are
# only effective when the effective placement preset resolves to
# SINGLE; scatter presets distribute copies procedurally so pinning
# just the center copy would break the visual illusion.
@export var placement_override: int = -1       # -1 = inherit from PlacementCap
@export var variant_override: int = -1          # -1 = seeded random variant
@export var scale_override: float = -1.0        # < 0 = seeded scale
@export var rotation_override: float = -1.0     # < 0 = seeded rotation (else degrees)


## True when this instance pins its variant through the override.
func has_variant_override() -> bool:
	return variant_override >= 0


## True when this instance pins its scale through the override.
func has_scale_override() -> bool:
	return scale_override > 0.0


## True when this instance pins its rotation through the override.
func has_rotation_override() -> bool:
	return rotation_override >= 0.0



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


static func create_structure(type: StringName,
		sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.STRUCTURE
	p.sub_hex = sub_hex
	return p


static func create_anomaly(type: StringName, sub_hex: Vector2i = Vector2i.ZERO) -> Prop:
	var p := Prop.new()
	p.type = type
	p.category = Category.MINERAL
	p.origin = Origin.UNKNOWN
	p.sub_hex = sub_hex
	return p
