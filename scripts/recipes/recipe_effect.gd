class_name RecipeEffect
extends Resource

## Effect kind — one of: stat_delta, sound, fx, emit_light, spawn_heat,
## world_change, grant_recipe.
@export var kind: StringName

## Kind-specific parameters.
## Examples: {"stat": "hunger", "value": 5}, {"sound_id": "crunch"},
## {"radius": 5, "duration": 60}.
@export var params: Dictionary = {}
