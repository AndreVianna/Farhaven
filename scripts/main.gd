extends Node

## Bootstrap: loads the world map on game start.

func _ready() -> void:
	HexGrid.load_map("res://data/maps/ch1.json")
