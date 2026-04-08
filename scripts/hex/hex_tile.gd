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

enum FogState {
	HIDDEN,
	VISIBLE,
}

@export var coords: Vector2i = Vector2i.ZERO
@export var biome: Biome = Biome.GRASSLAND
@export var elevation: int = 0
@export var fog_state: FogState = FogState.HIDDEN
@export var props: Array = []  # Array of Prop


func get_props_by_category(category: int) -> Array:
	var result: Array = []
	for prop in props:
		if prop.category == category:
			result.append(prop)
	return result


func get_props() -> Array:
	var result: Array = []
	for prop in props:
		if prop.is_natural_category():
			result.append(prop)
	return result


func get_structures() -> Array:
	return get_props_by_category(_Prop.Category.STRUCTURE)


func get_anomalies() -> Array:
	var result: Array = []
	for prop in props:
		if prop.is_anomaly():
			result.append(prop)
	return result
