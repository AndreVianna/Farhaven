class_name SpawnableCap
extends Resource

## Minimum number to spawn at once.
@export var spawn_min: int = 1

## Maximum number to spawn at once.
@export var spawn_max: int = 1

## Earliest day the entity can spawn (e.g., 4 for "after day 4").
@export var first_spawn_day: int = 1

## Minimum distance from player to spawn (in hex tiles).
@export var spawn_min_distance: int = 3

## Biome tags this entity can spawn in (e.g., FOREST, GRASSLAND). Empty = any biome.
@export var allowed_biomes: Array[StringName] = []
