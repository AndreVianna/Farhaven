class_name HexTile
extends Resource

const _Prop = preload("res://scripts/hex/prop.gd")

## Biome name table. The int VALUES stored on tiles are assigned by
## MapLoader._biome_id_to_int at load time, which sorts .tres
## filenames alphabetically — NOT from this enum. So far the enum
## ordering happens to match the alphabetical B00001..B00008 order,
## but code that compares `tile.biome == Biome.WATER` is really
## comparing against "position of B00005.tres in the sorted list".
## If biome files are ever renamed or reordered the enum will
## silently desync. Treat this enum as a human-readable label, not a
## source of truth — prefer `biome_id: StringName` lookups in new
## code.
enum Biome {
	CRASH_SITE,
	GRASSLAND,
	FOREST,
	ROCKY,
	WATER,
	VOLCANIC,
	ALPINE,
	SHORELINE,
}

@export var coords: Vector2i = Vector2i.ZERO
@export var biome: Biome = Biome.GRASSLAND
@export var elevation: int = 0
@export var props: Array = []  # Array of Prop
## Per-edge wall flags matching HexMath.DIRECTIONS order [E,NE,NW,W,SW,SE].
## true = draw cliff wall face on this edge; false = merge smoothly.
@export var walls: Array[bool] = [false, false, false, false, false, false]
## Water surface elevation. Only meaningful for WATER biome tiles.
## elevation = bottom depth, water_level = surface height.
@export var water_level: int = 0
## Water behavior type: 'leveled' (lakes) or 'flowing' (rivers).
@export var water_type: String = ""
## Environmental hazard intensity, 0 = safe. Non-zero values index
## into the biome's HazardCap drain arrays (level N → index N-1).
## Tables can be any length — usually 4 but extensible per biome.
## SurvivalSystem saturates at the last defined level if a tile's
## temperature exceeds the table length. Default 0 so existing maps
## load unchanged.
@export var temperature: int = 0


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
