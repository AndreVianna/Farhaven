extends Node3D

## Wires lighting nodes to DayNightCycle on scene ready.

func _ready() -> void:
	var env: WorldEnvironment = $WorldEnvironment
	var sun: DirectionalLight3D = $Sun
	DayNightCycle.register_lighting(env, sun)
