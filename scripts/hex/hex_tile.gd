class_name HexTile
extends Resource

const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

enum Biome {
	CRASH_SITE,
	GRASSLAND,
	FOREST,
	ROCKY,
	WATER,
}

enum FogState {
	HIDDEN,
	REVEALED,
	VISIBLE,
}

@export var coords: Vector2i = Vector2i.ZERO
@export var biome: Biome = Biome.GRASSLAND
@export var elevation: int = 0
@export var fog_state: FogState = FogState.HIDDEN
@export var structure: StringName = &""
@export var resource_nodes: Array = []  # Array of ResourceNode
@export var anomaly: StringName = &""
