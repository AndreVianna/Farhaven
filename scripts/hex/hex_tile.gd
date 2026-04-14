class_name HexTile
extends Resource

const _Prop = preload("res://scripts/hex/prop.gd")

enum Biome {
	CRASH_SITE,
	GRASSLAND,
	FOREST,
	ROCKY,
	WATER,
}

@export var coords: Vector2i = Vector2i.ZERO
@export var biome: Biome = Biome.GRASSLAND
@export var elevation: int = 0
@export var props: Array = []  # Array of Prop
## Per-edge wall flags matching HexMath.DIRECTIONS order [E,NE,NW,W,SW,SE].
## true = draw cliff wall face on this edge; false = merge smoothly.
@export var walls: Array[bool] = [false, false, false, false, false, false]


## Returns all natural-origin props (non-structure, non-anomaly).
## Replaces the old is_natural_category() filter with origin check.
func get_props() -> Array:
	var result: Array = []
	for prop in props:
		if prop.origin == _Prop.Origin.NATURAL:
			result.append(prop)
	return result


## Returns all structure props on this tile.
## A prop is a structure if its PropDef has the STRUCTURE tag,
## or if its category is STRUCTURE (legacy compat).
func get_structures() -> Array:
	var result: Array = []
	for prop in props:
		# Check via PropDef STRUCTURE tag
		if PropRegistry.has_def(prop.type):
			var def = PropRegistry.get_def(prop.type)
			if def.has_tag(&"STRUCTURE"):
				result.append(prop)
				continue
			# Also check STATION capability
			if def.station != null:
				result.append(prop)
				continue
		# Legacy fallback: check category field if still present
		if "category" in prop and prop.category == _Prop.Category.STRUCTURE:
			result.append(prop)
	return result


## Returns all anomaly props on this tile.
func get_anomalies() -> Array:
	var result: Array = []
	for prop in props:
		if prop.is_anomaly():
			result.append(prop)
	return result


## Returns props matching a specific PropDef tag.
func get_props_with_tag(tag: StringName) -> Array:
	var result: Array = []
	for prop in props:
		if PropRegistry.has_def(prop.type):
			var def = PropRegistry.get_def(prop.type)
			if def.has_tag(tag):
				result.append(prop)
	return result


## Returns props whose PropDef has the given capability (e.g. &"station", &"portable").
func get_props_with_capability(cap_name: StringName) -> Array:
	var result: Array = []
	for prop in props:
		if PropRegistry.has_def(prop.type):
			var def = PropRegistry.get_def(prop.type)
			if def.has_capability(cap_name):
				result.append(prop)
	return result


## DEPRECATED: kept for backward compatibility during transition.
## Use get_props_with_tag() or get_props_with_capability() instead.
func get_props_by_category(category: int) -> Array:
	var result: Array = []
	for prop in props:
		if prop.category == category:
			result.append(prop)
	return result
