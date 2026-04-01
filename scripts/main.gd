extends Node

## Bootstrap: loads the world map on game start and wires all systems together.

func _ready() -> void:
	_wire_systems()
	HexGrid.load_map("res://data/maps/ch1.json")


func _wire_systems() -> void:
	var player: Node = $World/Player
	var scanner: Node = player.get_node_or_null("ScannerSystem")
	var player_input: Node = player.get_node_or_null("PlayerInput")
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

	# Wire scan_rejected back to PlayerInput for joystick fallback
	if scanner != null and player_input != null:
		if scanner.has_signal("scan_rejected") and player_input.has_method("receive_scan_rejected"):
			scanner.scan_rejected.connect(player_input.receive_scan_rejected)
