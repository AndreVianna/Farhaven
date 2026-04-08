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


# REMOVE in task-051: use capability/tag queries
func get_props_by_category(category: int) -> Array:
	var result: Array = []
	for prop in props:
		if prop.category == category:
			result.append(prop)
	return result


# REMOVE in task-051: use origin filter
func get_props() -> Array:
	var result: Array = []
	for prop in props:
		if prop.is_natural_category():
			result.append(prop)
	return result


# REMOVE in task-051: use STATION/STRUCTURE tag query
func get_structures() -> Array:
	return get_props_by_category(_Prop.Category.STRUCTURE)


func get_anomalies() -> Array:
	var result: Array = []
	for prop in props:
		if prop.is_anomaly():
			result.append(prop)
	return result
