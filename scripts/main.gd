extends Node

## Bootstrap: generates the world on game start.

func _ready() -> void:
	var generator := WorldGenerator.new(HexGrid)
	generator.generate(randi())
