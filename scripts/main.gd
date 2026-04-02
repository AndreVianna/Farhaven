extends Node

## Bootstrap: loads the world map on game start and wires all systems together.

const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")

var _fly_to_player: Node3D = null


func _ready() -> void:
	_wire_systems()
	HexGrid.load_map("res://data/maps/ch1.json")
	# After map loads, populate renderers for already-visible tiles.
	# MapLoader sets initial tiles to VISIBLE but doesn't emit tile_revealed,
	# so renderers miss the starting hex and its neighbors.
	# Deferred so child renderers connect their signals first (their _ready()
	# fires before ours, and they use call_deferred for signal wiring).
	_bootstrap_visible_tiles.call_deferred()


func _wire_systems() -> void:
	var player: Node = $World/Player
	var scanner: Node = player.get_node_or_null("ScannerSystem")
	var auto_interaction: Node = player.get_node_or_null("AutoInteractionSystem")
	var crafting: Node = player.get_node_or_null("CraftingSystem")
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

	# Connect crafting to HUD
	if crafting != null and hud.has_method("connect_crafting"):
		var inv = player.get_inventory() if player.has_method("get_inventory") else null
		if inv != null:
			hud.connect_crafting(crafting, inv)

	# Connect auto-interaction to HUD (floating text feedback)
	if auto_interaction != null and hud.has_method("connect_auto_interaction"):
		hud.connect_auto_interaction(auto_interaction)

	# Setup fly-to-player visual effect
	if auto_interaction != null:
		_fly_to_player = _FlyToPlayer.new()
		_fly_to_player.setup(player)
		$World.add_child(_fly_to_player)
		auto_interaction.auto_gather_completed.connect(_on_gather_fly.bind(player))


func _on_gather_fly(coords: Vector2i, resource_type: StringName, _amount: int, _player: Node) -> void:
	if _fly_to_player != null:
		_fly_to_player.spawn_fly(coords, resource_type, HexGrid)


func _bootstrap_visible_tiles() -> void:
	var scanner: Node = $World/Player.get_node_or_null("ScannerSystem")
	if scanner == null:
		return
	if scanner.has_method("bootstrap_visible"):
		scanner.bootstrap_visible()
