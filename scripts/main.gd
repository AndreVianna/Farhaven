extends Node

## Bootstrap: loads the world map on game start and wires all systems together.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")

func _ready() -> void:
	_wire_systems()
	HexGrid.load_map("res://data/maps/ch1.json")
	# After map loads, populate renderers for already-visible tiles.
	# MapLoader sets initial tiles to VISIBLE but doesn't emit tile_revealed,
	# so renderers miss the starting hex and its neighbors.
	_bootstrap_visible_tiles()


func _wire_systems() -> void:
	var player: Node = $World/Player
	var scanner: Node = player.get_node_or_null("ScannerSystem")
	var hud: Node = $HUD/HUD

	# Connect inventory to HUD
	if player.has_method("get_inventory"):
		var inv = player.get_inventory()
		if inv != null and hud.has_method("connect_inventory"):
			hud.connect_inventory(inv)

	# Connect catalog to HUD
	if scanner != null and hud.has_method("connect_catalog"):
		var cat = scanner.get_catalog()
		if cat != null:
			hud.connect_catalog(cat)


func _bootstrap_visible_tiles() -> void:
	var scanner: Node = $World/Player.get_node_or_null("ScannerSystem")
	if scanner == null:
		return
	# Iterate all tiles and trigger passive identification for any that are
	# already VISIBLE (set by MapLoader during load_map).
	for coords in HexGrid._tiles:
		var tile = HexGrid._tiles[coords]
		if tile != null and tile.fog_state == _HexTile.FogState.VISIBLE:
			if scanner.has_method("_check_passive_identification"):
				scanner._check_passive_identification(coords)
