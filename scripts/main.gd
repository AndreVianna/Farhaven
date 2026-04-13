extends Node

## Bootstrap: loads the world map on game start and wires all systems together.

const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")
const _GatherSound = preload("res://scripts/audio/gather_sound.gd")

var _fly_to_player: Node3D = null
var _gather_sound: Node = null


const _MAPS_DIR: String = "res://data/maps/"
const _GAME_SETTINGS_PATH: String = "res://data/game_settings.tres"


func _ready() -> void:
	_wire_systems()
	HexGrid.load_map(_resolve_startup_map())
	# Apply starting loadout for fresh game (no save file yet).
	# Must run BEFORE save load so save data can override defaults.
	if not SaveManager.has_save():
		_apply_starting_loadout()
	# Auto-load save if exists (cold resume).
	# Deferred so all systems are fully ready before loading state.
	# MUST run before bootstrap so renderers reflect loaded state (catalog, props).
	SaveManager.load_game.call_deferred()
	# After save load, populate renderers for all tiles (all tiles are always rendered).
	# Deferred so child renderers connect their signals first (their _ready()
	# fires before ours, and they use call_deferred for signal wiring).
	_bootstrap_visible_tiles.call_deferred()
	# Scan existing light-emitting props after load (structure_placed doesn't fire on load).
	# Also re-check player torch (scanner has emits_light — doesn't activate until tile_entered).
	# Pass player directly because _find_player() uses groups which may not be ready yet.
	LightingManager.scan_existing_lights.call_deferred()
	var _player_ref: Node = $World/Player
	LightingManager.initialize_player_torch.call_deferred(_player_ref)


func _resolve_startup_map() -> String:
	var settings: GameSettings = null
	if ResourceLoader.exists(_GAME_SETTINGS_PATH):
		settings = load(_GAME_SETTINGS_PATH) as GameSettings
	else:
		push_warning("main.gd: %s missing — falling back to ch1.json." % _GAME_SETTINGS_PATH)
	var filename: String = SaveManager.get_current_map_or_default(settings)
	if filename == "":
		filename = "ch1.json"
	return _MAPS_DIR + filename


func _wire_systems() -> void:
	var player: Node = $World/Player
	var scanner: Node = player.get_node_or_null("ScannerSystem")
	var auto_interaction: Node = player.get_node_or_null("AutoInteractionSystem")
	var crafting: Node = player.get_node_or_null("CraftingSystem")
	var hud: Node = $HUD/HUD

	_wire_hud(player, scanner, auto_interaction, crafting, hud)
	_wire_gather_feedback(player, auto_interaction)
	_wire_survival(player, hud)
	_wire_day_night(hud)
	_wire_save_triggers(player, crafting)
	_wire_fauna(player, scanner, auto_interaction)


func _wire_hud(player: Node, scanner: Node, auto_interaction: Node,
		crafting: Node, hud: Node) -> void:
	if player.has_method("get_inventory"):
		var inv = player.get_inventory()
		if inv != null and hud.has_method("connect_inventory"):
			hud.connect_inventory(inv)
		if player.has_signal("wearables_changed") and hud.has_method("on_wearables_changed"):
			player.wearables_changed.connect(func(): hud.on_wearables_changed(player))
			# Paint the initial equipment state — the signal only fires on
			# subsequent changes and the starter backpack is auto-equipped
			# before this signal connection exists.
			hud.on_wearables_changed(player)
		elif player.has_method("get_equipped_container") and hud.has_method("connect_container_def"):
			hud.connect_container_def(player.get_equipped_container())
	if scanner != null and hud.has_method("connect_catalog"):
		var cat = scanner.get_catalog()
		if cat != null:
			hud.connect_catalog(cat)
	if crafting != null and hud.has_method("connect_crafting"):
		var inv = player.get_inventory() if player.has_method("get_inventory") else null
		if inv != null:
			hud.connect_crafting(crafting, inv)
	if auto_interaction != null and hud.has_method("connect_auto_interaction"):
		hud.connect_auto_interaction(auto_interaction)
	# Wire BuildingSystem → HUD for Build panel
	var building: Node = player.get_node_or_null("BuildingSystem")
	if building != null and hud.has_method("connect_building"):
		hud.connect_building(building)


func _wire_gather_feedback(player: Node, auto_interaction: Node) -> void:
	if auto_interaction != null:
		_fly_to_player = _FlyToPlayer.new()
		_fly_to_player.setup(player)
		$World.add_child(_fly_to_player)
		auto_interaction.auto_gather_completed.connect(_on_gather_fly.bind(player))
	_gather_sound = _GatherSound.new()
	add_child(_gather_sound)
	var hud: Node = $HUD/HUD
	if hud.has_method("connect_sound"):
		hud.connect_sound(_gather_sound)


func _wire_survival(player: Node, hud: Node) -> void:
	var survival: Node = player.get_node_or_null("SurvivalSystem")
	if survival == null:
		return
	survival.stat_changed.connect(hud.update_stat)
	var ground_renderer: Node = $World.get_node_or_null("GroundItemRenderer")
	if ground_renderer != null and ground_renderer.has_method("connect_survival"):
		ground_renderer.connect_survival(survival)
	survival.player_died.connect(SaveManager.save_now)
	survival.player_respawned.connect(SaveManager.save_now)
	# task-082: feed the Status screen's stats section as well.
	var status_panel: Node = hud.get_node_or_null("StatusPanel")
	if status_panel != null and status_panel.has_method("set_survival_system"):
		status_panel.set_survival_system(survival)


func _wire_day_night(hud: Node) -> void:
	DayNightCycle.day_started.connect(func() -> void:
		if is_instance_valid(hud):
			hud.update_day(DayNightCycle.day_count)
	)
	DayNightCycle.phase_changed.connect(func(_old: DayNightCycle.TimePhase, new_phase: DayNightCycle.TimePhase) -> void:
		if is_instance_valid(hud):
			hud.update_phase(DayNightCycle.phase_to_string(new_phase))
		SaveManager.mark_dirty()
	)
	# task-082: feed the Status screen's day counter so it updates with DayNightCycle.
	var status_panel: Node = hud.get_node_or_null("StatusPanel")
	if status_panel != null and status_panel.has_method("set_day_night_cycle"):
		status_panel.set_day_night_cycle(DayNightCycle)


func _wire_save_triggers(player: Node, crafting: Node) -> void:
	if player.has_method("get_inventory"):
		var save_inv = player.get_inventory()
		if save_inv != null and save_inv.has_signal("inventory_changed"):
			save_inv.inventory_changed.connect(SaveManager.mark_dirty)
	# Wearable changes (equip/unequip) are state the save must capture —
	# otherwise swapping a backpack between fires wouldn't persist until
	# an unrelated inventory_changed happened to fire.
	if player.has_signal("wearables_changed"):
		player.wearables_changed.connect(SaveManager.mark_dirty)
	if crafting != null:
		crafting.craft_completed.connect(func(_n: StringName) -> void: SaveManager.mark_dirty())


func _wire_fauna(player: Node, scanner: Node, auto_interaction: Node) -> void:
	var fauna_mgr: Node = player.get_node_or_null("FaunaManager")
	if fauna_mgr == null:
		return

	# fauna_attacked_player → SurvivalSystem.take_damage(damage)
	var survival: Node = player.get_node_or_null("SurvivalSystem")
	if survival != null and survival.has_method("take_damage"):
		fauna_mgr.fauna_attacked_player.connect(
			func(_id: int, damage: int, _species: StringName) -> void:
				survival.take_damage(damage)
		)

	# fauna_attacked_player → ScannerSystem surprise encounter (UNKNOWN → ENCOUNTERED)
	if scanner != null and scanner.has_method("on_fauna_attacked_player"):
		fauna_mgr.fauna_attacked_player.connect(scanner.on_fauna_attacked_player)

	# fauna_attacked_player → ScreenFade.flash(red)
	var screen_fade: Node = get_node_or_null("ScreenFade")
	if screen_fade != null and screen_fade.has_method("flash"):
		fauna_mgr.fauna_attacked_player.connect(
			func(_id: int, damage: int, _species: StringName) -> void:
				if damage > 0:
					screen_fade.flash(Color.RED)
		)

	# fauna_killed → breakdown recipe flow handled by FaunaManager itself
	# (FaunaManager._on_fauna_death places corpse prop → RecipeRuntime auto-fires)
	# No additional wiring needed here.

	# fauna_moved → AutoInteractionSystem auto-defend adjacency check
	# AutoInteractionSystem._on_fauna_moved expects (fauna_id, new_coords) but
	# FaunaManager.fauna_moved emits (id, old_coords, new_coords, species_type).
	# Wire with a lambda adapter to extract the needed args.
	if auto_interaction != null and auto_interaction.has_method("_on_fauna_moved"):
		# Wire FaunaManager reference so auto-defend can query fauna data
		if "_fauna_manager" in auto_interaction:
			auto_interaction._fauna_manager = fauna_mgr
		fauna_mgr.fauna_moved.connect(
			func(id: int, _old: Vector2i, new_c: Vector2i, _sp: StringName) -> void:
				auto_interaction._on_fauna_moved(id, new_c)
		)

	# fauna_attacked_player → HUD floating damage text (red)
	var hud: Node = get_node_or_null("HUD/HUD")
	if hud != null and hud.has_method("connect_fauna_manager"):
		hud.connect_fauna_manager(fauna_mgr)

	# fauna_spawned → PropLabelRenderer for knowledge state markers
	# Deferred: PropLabelRenderer needs a label update API for fauna.
	# When available, wire fauna_mgr.fauna_spawned → label_renderer.on_fauna_spawned

	# auto_defend_triggered → FaunaManager.apply_damage
	if auto_interaction != null and fauna_mgr.has_method("apply_damage"):
		auto_interaction.auto_defend_triggered.connect(fauna_mgr.apply_damage)


func _apply_starting_loadout() -> void:
	var loadout: Dictionary = HexGrid.starting_loadout
	if loadout.is_empty():
		return
	var player: Node = $World/Player
	var inv = player.get_inventory()
	# Equip starting tools.
	var tools: Dictionary = loadout.get("tools", {})
	for slot: String in tools:
		inv.set_tool(StringName(slot), StringName(tools[slot]))
	# Add starting inventory items.
	var items: Array = loadout.get("inventory", [])
	for item in items:
		inv.add_item(StringName(item["type"]), int(item["count"]))


func _on_gather_fly(coords: Vector2i, prop_type: StringName, _amount: int, _player: Node) -> void:
	if _fly_to_player != null:
		_fly_to_player.spawn_fly(coords, prop_type, HexGrid)


func _bootstrap_visible_tiles() -> void:
	var scanner: Node = $World/Player.get_node_or_null("ScannerSystem")
	if scanner == null:
		return
	if scanner.has_method("bootstrap_visible"):
		scanner.bootstrap_visible()
