extends Node

## Bootstrap: loads the world map on game start and wires all systems together.

const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")
const _GatherSound = preload("res://scripts/audio/gather_sound.gd")

var _fly_to_player: Node3D = null
var _gather_sound: Node = null


func _ready() -> void:
	_wire_systems()
	HexGrid.load_map("res://data/maps/ch1.json")
	# Auto-load save if exists (cold resume).
	# Deferred so all systems are fully ready before loading state.
	# MUST run before bootstrap so renderers reflect loaded state (catalog, fog, props).
	SaveManager.load_game.call_deferred()
	# After save load, populate renderers for already-visible tiles.
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

	# Setup sound hooks (gather ding + craft success)
	_gather_sound = _GatherSound.new()
	add_child(_gather_sound)
	if hud.has_method("connect_sound"):
		hud.connect_sound(_gather_sound)

	# Wire SurvivalSystem signals
	var survival: Node = player.get_node_or_null("SurvivalSystem")
	if survival != null:
		# Stat bars wiring: SurvivalSystem.stat_changed → HUD.update_stat
		survival.stat_changed.connect(hud.update_stat)
		# GroundItemRenderer wiring
		var ground_renderer: Node = $World.get_node_or_null("GroundItemRenderer")
		if ground_renderer != null and ground_renderer.has_method("connect_survival"):
			ground_renderer.connect_survival(survival)
		# SaveManager: immediate save on critical events
		survival.player_died.connect(SaveManager.save_now)
		survival.player_respawned.connect(SaveManager.save_now)

	# Wire DayNightCycle signals to HUD day counter
	DayNightCycle.day_started.connect(func() -> void:
		if is_instance_valid(hud):
			hud.update_day(DayNightCycle.day_count)
	)
	DayNightCycle.phase_changed.connect(func(_old: DayNightCycle.TimePhase, new_phase: DayNightCycle.TimePhase) -> void:
		if is_instance_valid(hud):
			hud.update_phase(DayNightCycle.phase_to_string(new_phase))
		SaveManager.mark_dirty()
	)

	# Wire remaining state-change signals to SaveManager dirty flag
	if player.has_method("get_inventory"):
		var save_inv = player.get_inventory()
		if save_inv != null and save_inv.has_signal("inventory_changed"):
			save_inv.inventory_changed.connect(SaveManager.mark_dirty)
	if crafting != null:
		crafting.craft_completed.connect(func(_n: StringName) -> void: SaveManager.mark_dirty())


func _on_gather_fly(coords: Vector2i, prop_type: StringName, _amount: int, _player: Node) -> void:
	if _fly_to_player != null:
		_fly_to_player.spawn_fly(coords, prop_type, HexGrid)


func _bootstrap_visible_tiles() -> void:
	var scanner: Node = $World/Player.get_node_or_null("ScannerSystem")
	if scanner == null:
		return
	if scanner.has_method("bootstrap_visible"):
		scanner.bootstrap_visible()
