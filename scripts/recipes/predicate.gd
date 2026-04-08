class_name Predicate
extends Resource

## Predicate kind — one of the vocabulary from DESIGN.md §5:
## has_tool, at_station, at_tile_type, player_stat, player_skill,
## player_knows_recipe, time_of_day, weather, biome, adjacent_to,
## prop_state, world_flag, animal_nearby, container_has, cataloged.
@export var kind: StringName

## Kind-specific parameters.
## Examples: {"tool": "axe"}, {"tag": "cook"}, {"stat": "health", "op": "ge", "value": 20}.
@export var params: Dictionary = {}
