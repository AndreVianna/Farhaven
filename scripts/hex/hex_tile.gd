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
	REVEALED,
	VISIBLE,
}

@export var coords: Vector2i = Vector2i.ZERO
@export var biome: Biome = Biome.GRASSLAND
@export var elevation: int = 0
@export var fog_state: FogState = FogState.HIDDEN
@export var props: Array = []  # Array of Prop
