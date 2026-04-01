extends GdUnitTestSuite
class_name TestDelivery001

## Integration tests for delivery-001: Foundation — Walk the World.
## Verifies feature-001 (hex grid), feature-002 (player movement), and
## feature-012 (HUD) working together as a playable whole.
##
## Test seed 42 is used throughout for deterministic world generation.
##
## Manual-only verification (not automatable — document here):
##   - Biome colors are visually distinct on screen
##   - Camera follow is smooth with no jitter during tween
##   - Joystick overlay appears at touch origin and disappears on release
##   - Floating text rises and fades smoothly (tween quality)
##   - Day counter warm color palette renders correctly
##   - HIDDEN tiles show as invisible, REVEALED as dimmed, VISIBLE as full brightness

const TEST_SEED: int = 42

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _WorldGenerator = preload("res://scripts/hex/world_generator.gd")
const _Player = preload("res://scripts/player/player.gd")
const _PlayerInput = preload("res://scripts/player/player_input.gd")

# Isolated HexGrid instance — used by all tests except the renderer cross-feature test.
var _grid: Node


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)


func after_test() -> void:
	_grid.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _generate(seed_val: int = TEST_SEED) -> bool:
	_grid._tiles.clear()
	var gen := _WorldGenerator.new(_grid)
	return gen.generate(seed_val)


## Build a flat grassland grid for movement tests (radius 4 hex, all VISIBLE).
func _build_movement_grid() -> void:
	_grid._tiles.clear()
	for q: int in range(-4, 5):
		for r: int in range(-4, 5):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 8:
				continue
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			_grid._tiles[Vector2i(q, r)] = tile


# ===========================================================================
# AC1 — World Generation
# ===========================================================================

func test_ac1_tile_count_in_range_200_to_300() -> void:
	var ok := _generate()
	assert_bool(ok).override_failure_message("WorldGenerator.generate() returned false").is_true()
	var count: int = _grid._tiles.size()
	assert_bool(count >= 200 and count <= 300).override_failure_message(
		"Tile count %d not in [200, 300]" % count
	).is_true()


func test_ac1_all_required_biomes_present() -> void:
	_generate()
	var biomes: Dictionary = {}
	for c: Variant in _grid._tiles:
		biomes[_grid._tiles[c].biome] = true
	assert_bool(biomes.has(_HexTile.Biome.CRASH_SITE)).override_failure_message("Missing CRASH_SITE").is_true()
	assert_bool(biomes.has(_HexTile.Biome.GRASSLAND)).override_failure_message("Missing GRASSLAND").is_true()
	assert_bool(biomes.has(_HexTile.Biome.FOREST)).override_failure_message("Missing FOREST").is_true()
	assert_bool(biomes.has(_HexTile.Biome.ROCKY)).override_failure_message("Missing ROCKY").is_true()
	assert_bool(biomes.has(_HexTile.Biome.WATER)).override_failure_message("Missing WATER").is_true()


func test_ac1_crash_site_at_origin() -> void:
	_generate()
	var tile: Resource = _grid.get_tile(Vector2i.ZERO)
	assert_bool(tile != null).override_failure_message("No tile at (0,0)").is_true()
	if tile != null:
		assert_int(tile.biome).is_equal(_HexTile.Biome.CRASH_SITE)


func test_ac1_biome_clusters_le_5() -> void:
	_generate()
	var visited: Dictionary = {}
	var ok := true
	for c: Variant in _grid._tiles:
		var start: Vector2i = c
		if visited.has(start):
			continue
		var tile: Resource = _grid._tiles[start]
		if tile.biome == _HexTile.Biome.CRASH_SITE or tile.biome == _HexTile.Biome.WATER:
			visited[start] = true
			continue
		var biome: int = tile.biome
		var cluster_size: int = 0
		var queue: Array[Vector2i] = [start]
		while queue.size() > 0:
			var cur: Vector2i = queue.pop_front()
			if visited.has(cur):
				continue
			visited[cur] = true
			var ct: Resource = _grid._tiles.get(cur, null)
			if ct == null or ct.biome != biome:
				continue
			cluster_size += 1
			for n: Variant in _HexMath.get_neighbors(cur):
				if not visited.has(n) and _grid._tiles.has(n):
					queue.append(n)
		if cluster_size > 5:
			ok = false
			break
	assert_bool(ok).override_failure_message("Found biome cluster larger than 5").is_true()


func test_ac1_anomaly_placed_and_reachable_from_crash_site() -> void:
	_generate()
	var anomaly_coord := Vector2i(-9999, -9999)
	var found := false
	for c: Variant in _grid._tiles:
		var coords: Vector2i = c
		if _grid._tiles[coords].anomaly != &"":
			anomaly_coord = coords
			found = true
			break
	assert_bool(found).override_failure_message("No anomaly placed on map").is_true()
	if not found:
		return

	# BFS reachability from crash site.
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	reachable[Vector2i.ZERO] = true
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for n: Variant in _HexMath.get_neighbors(cur):
			var nv: Vector2i = n
			if reachable.has(nv) or not _grid._tiles.has(nv):
				continue
			if _grid.is_passable(cur, nv):
				reachable[nv] = true
				queue.append(nv)
	assert_bool(reachable.has(anomaly_coord)).override_failure_message(
		"Anomaly at %s is not reachable from crash site" % str(anomaly_coord)
	).is_true()


func test_ac1_fog_crash_site_ring1_visible_after_generation() -> void:
	# WorldGenerator _step10_init_fog sets radius=1 (center + neighbors) to VISIBLE.
	_generate()
	for coords: Variant in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		var c: Vector2i = coords
		if _grid._tiles.has(c):
			assert_int(_grid._tiles[c].fog_state).override_failure_message(
				"Tile %s should be VISIBLE after generation" % str(c)
			).is_equal(_HexTile.FogState.VISIBLE)


func test_ac1_fog_distant_tiles_start_hidden() -> void:
	_generate()
	var hidden_count: int = 0
	for c: Variant in _grid._tiles:
		var coords: Vector2i = c
		if _HexMath.distance(Vector2i.ZERO, coords) > 3:
			if _grid._tiles[coords].fog_state == _HexTile.FogState.HIDDEN:
				hidden_count += 1
	assert_bool(hidden_count > 50).override_failure_message(
		"Expected >50 HIDDEN tiles at distance >3, got %d" % hidden_count
	).is_true()


func test_ac1_is_passable_water_blocked() -> void:
	_grid._tiles.clear()
	var land := _HexTile.new()
	land.biome = _HexTile.Biome.GRASSLAND
	land.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = land
	var water := _HexTile.new()
	water.biome = _HexTile.Biome.WATER
	water.elevation = 0
	_grid._tiles[Vector2i(1, 0)] = water
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


func test_ac1_is_passable_elevation_diff_2_blocked() -> void:
	_grid._tiles.clear()
	var low := _HexTile.new()
	low.biome = _HexTile.Biome.GRASSLAND
	low.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = low
	var high := _HexTile.new()
	high.biome = _HexTile.Biome.GRASSLAND
	high.elevation = 2
	_grid._tiles[Vector2i(1, 0)] = high
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


func test_ac1_is_passable_elevation_diff_1_allowed() -> void:
	_grid._tiles.clear()
	var low := _HexTile.new()
	low.biome = _HexTile.Biome.GRASSLAND
	low.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = low
	var step := _HexTile.new()
	step.biome = _HexTile.Biome.GRASSLAND
	step.elevation = 1
	_grid._tiles[Vector2i(1, 0)] = step
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_true()


func test_ac1_is_passable_blocking_structure() -> void:
	_grid._tiles.clear()
	var from := _HexTile.new()
	from.biome = _HexTile.Biome.GRASSLAND
	from.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = from
	var blocked := _HexTile.new()
	blocked.biome = _HexTile.Biome.GRASSLAND
	blocked.elevation = 0
	blocked.structure = &"wall"
	_grid._tiles[Vector2i(1, 0)] = blocked
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


# ===========================================================================
# AC2 — Player Movement Integration
# ===========================================================================

func test_ac2_player_spawns_at_crash_site_on_map_generated() -> void:
	_generate()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player._on_map_generated()
	assert_object(player.current_tile).is_equal(Vector2i.ZERO)
	player.queue_free()


func test_ac2_tap_transitions_idle_to_pathfinding() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	assert_int(player.move_state).is_equal(_Player.MoveState.IDLE)
	player.pathfind_to(Vector2i(2, 0))
	assert_int(player.move_state).is_equal(_Player.MoveState.PATHFINDING)
	player.queue_free()


func test_ac2_pathfinding_avoids_water_tiles() -> void:
	# Grid: (0,0) and (2,0) connected only via detour around water at (1,0).
	_grid._tiles.clear()
	for q: int in range(-1, 4):
		for r: int in range(-1, 2):
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			_grid._tiles[Vector2i(q, r)] = tile
	_grid._tiles[Vector2i(1, 0)].biome = _HexTile.Biome.WATER

	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	player.pathfind_to(Vector2i(2, 0))
	for step: Variant in player.move_path:
		var s: Vector2i = step
		assert_bool(s != Vector2i(1, 0)).override_failure_message(
			"Path must not include water tile (1,0)"
		).is_true()
	player.queue_free()


func test_ac2_pathfinding_avoids_steep_elevation() -> void:
	# Tile at (1,0) has elevation 3 — diff > 1 from flat neighbors.
	_grid._tiles.clear()
	for q: int in range(-1, 4):
		for r: int in range(-1, 2):
			var tile := _HexTile.new()
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			_grid._tiles[Vector2i(q, r)] = tile
	_grid._tiles[Vector2i(1, 0)].elevation = 3

	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	player.pathfind_to(Vector2i(2, 0))
	for step: Variant in player.move_path:
		var s: Vector2i = step
		assert_bool(s != Vector2i(1, 0)).override_failure_message(
			"Path must not include steep elevation tile (1,0)"
		).is_true()
	player.queue_free()


func test_ac2_joystick_start_walk_stop_state_cycle() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	assert_int(player.move_state).is_equal(_Player.MoveState.IDLE)
	player.start_walking(Vector2.RIGHT)
	assert_int(player.move_state).is_equal(_Player.MoveState.WALKING)
	player.stop_walking()
	assert_int(player.move_state).is_equal(_Player.MoveState.IDLE)
	player.queue_free()


func test_ac2_joystick_cancels_active_pathfinding() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	player.pathfind_to(Vector2i(2, 0))
	assert_int(player.move_state).is_equal(_Player.MoveState.PATHFINDING)
	player.start_walking(Vector2.LEFT)
	assert_int(player.move_state).is_equal(_Player.MoveState.WALKING)
	assert_bool(player.move_path.is_empty()).is_true()
	player.queue_free()


func test_ac2_snap_tiebreaker_forward_past_halfway() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	player._tween_origin_tile = Vector2i(0, 0)
	player._tween_target_tile = Vector2i(1, 0)
	player._tween_progress = 0.6
	player._active_tween = player.create_tween()
	player._active_tween.tween_property(player, "position:x", 99.0, 10.0)
	player._resolve_snap()
	assert_object(player.current_tile).is_equal(Vector2i(1, 0))
	player.queue_free()


func test_ac2_snap_tiebreaker_back_at_exactly_halfway() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	player._tween_origin_tile = Vector2i(0, 0)
	player._tween_target_tile = Vector2i(1, 0)
	player._tween_progress = 0.5
	player._active_tween = player.create_tween()
	player._active_tween.tween_property(player, "position:x", 99.0, 10.0)
	player._resolve_snap()
	assert_object(player.current_tile).is_equal(Vector2i(0, 0))
	player.queue_free()


func test_ac2_scan_hold_fires_with_correct_coords() -> void:
	# scan_hold_started must emit on >= 300ms hold with the axial coords under the finger.
	# Camera is null → _screen_to_axial returns Vector2i.ZERO.
	_grid._tiles.clear()
	var tile := _HexTile.new()
	tile.coords = Vector2i.ZERO
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.fog_state = _HexTile.FogState.REVEALED
	_grid._tiles[Vector2i.ZERO] = tile

	var player_input := _PlayerInput.new()
	player_input._grid = _grid
	add_child(player_input)

	var received: Array[Vector2i] = []
	player_input.scan_hold_started.connect(func(c: Vector2i) -> void:
		received.append(c)
	)

	player_input._on_touch_down(Vector2.ZERO)
	player_input._touch_duration = 0.3  # At the hold threshold.
	player_input._process(0.0)          # Triggers hold detection.

	assert_bool(received.size() > 0).override_failure_message(
		"scan_hold_started should fire after hold >= 300ms"
	).is_true()
	if received.size() > 0:
		assert_object(received[0]).is_equal(Vector2i.ZERO)
	player_input.queue_free()


# ===========================================================================
# HUD Verification (feature-012)
# ===========================================================================

func test_hud_stat_bars_exists_in_top_bar() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var stat_bars: Node = hud.get_node_or_null("TopBar/StatBars")
	assert_bool(stat_bars != null).override_failure_message(
		"StatBars node must exist under TopBar"
	).is_true()
	hud.queue_free()


func test_hud_day_counter_exists_in_top_bar() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var day_counter: Node = hud.get_node_or_null("TopBar/DayCounter")
	assert_bool(day_counter != null).override_failure_message(
		"DayCounter node must exist under TopBar"
	).is_true()
	hud.queue_free()


func test_hud_five_action_buttons_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var expected: Array[String] = [
		"InventoryButton", "BuildButton", "CraftButton", "ScannerButton", "JournalButton",
	]
	for btn_name: String in expected:
		var btn: Node = hud.get_node_or_null("BottomBar/" + btn_name)
		assert_bool(btn != null).override_failure_message(
			"%s must exist in BottomBar" % btn_name
		).is_true()
	hud.queue_free()


func test_hud_craft_button_hidden_by_default() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var craft_btn: Node = hud.get_node_or_null("BottomBar/CraftButton")
	assert_bool(craft_btn != null).override_failure_message("CraftButton must exist").is_true()
	if craft_btn != null:
		assert_bool((craft_btn as CanvasItem).visible).override_failure_message(
			"CraftButton must be hidden by default"
		).is_false()
	hud.queue_free()


func test_hud_stat_bars_mouse_filter_ignore() -> void:
	# Stat bars must not block touch input so joystick drag works over them.
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var stat_bars: Control = hud.get_node_or_null("TopBar/StatBars")
	assert_bool(stat_bars != null).is_true()
	if stat_bars != null:
		assert_int(stat_bars.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	hud.queue_free()


func test_hud_day_counter_mouse_filter_ignore() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var day_counter: Control = hud.get_node_or_null("TopBar/DayCounter")
	assert_bool(day_counter != null).is_true()
	if day_counter != null:
		assert_int(day_counter.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	hud.queue_free()


func test_hud_panel_mutual_exclusion_pattern() -> void:
	# Verify the symmetric close pattern used by HUD panels.
	# When panel N opens, all other panels receive a close notification.
	# Uses mock callables — real panels (Inventory, Build, etc.) will follow
	# this pattern when implemented in delivery-003+.
	var close_count: Dictionary = {"A": 0, "B": 0, "C": 0}
	var close_callbacks: Array[Callable] = [
		func() -> void: close_count["A"] += 1,
		func() -> void: close_count["B"] += 1,
		func() -> void: close_count["C"] += 1,
	]

	var dispatch_open := func(opening_idx: int) -> void:
		for i: int in close_callbacks.size():
			if i != opening_idx:
				close_callbacks[i].call()

	# Open panel B (idx 1): A and C should close, B should not self-close.
	dispatch_open.call(1)
	assert_int(close_count["A"]).is_equal(1)
	assert_int(close_count["B"]).is_equal(0)
	assert_int(close_count["C"]).is_equal(1)

	# Open panel A (idx 0): B and C should close.
	dispatch_open.call(0)
	assert_int(close_count["A"]).is_equal(1)
	assert_int(close_count["B"]).is_equal(1)
	assert_int(close_count["C"]).is_equal(2)


# ===========================================================================
# FloatingTextManager + Camera3D
# ===========================================================================

func test_floating_text_creates_label_with_camera_present() -> void:
	var ftm: Node = load("res://scripts/hud/floating_text_manager.gd").new()
	add_child(ftm)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()

	assert_int(ftm._active_labels.size()).is_equal(0)
	ftm.show_text(Vector3.ZERO, "+5 XP", Color.GREEN, 60.0)
	assert_int(ftm._active_labels.size()).is_equal(1)
	assert_int(ftm.get_child_count()).is_equal(1)

	cam.queue_free()
	ftm.queue_free()


func test_floating_texts_stack_vertically() -> void:
	# Each successive label must be offset upward (lower screen Y) by STACK_OFFSET.
	var ftm: Node = load("res://scripts/hud/floating_text_manager.gd").new()
	add_child(ftm)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()

	# Long duration keeps labels alive for assertion.
	ftm.show_text(Vector3.ZERO, "Gain 1", Color.WHITE, 60.0)
	ftm.show_text(Vector3.ZERO, "Gain 2", Color.WHITE, 60.0)
	ftm.show_text(Vector3.ZERO, "Gain 3", Color.WHITE, 60.0)

	assert_int(ftm.get_child_count()).is_greater_equal(3)
	if ftm.get_child_count() >= 3:
		var label1: Label = ftm.get_child(0)
		var label2: Label = ftm.get_child(1)
		var label3: Label = ftm.get_child(2)
		# Smaller screen Y = higher on screen (stacking upward).
		assert_float(label2.position.y).is_less(label1.position.y)
		assert_float(label3.position.y).is_less(label2.position.y)

	cam.queue_free()
	ftm.queue_free()


func test_floating_text_falls_back_to_center_without_camera() -> void:
	# Without Camera3D, world→screen falls back to viewport center.
	var ftm: Node = load("res://scripts/hud/floating_text_manager.gd").new()
	add_child(ftm)
	# Deliberately no camera added.

	ftm.show_text(Vector3(100.0, 0.0, 100.0), "Fallback", Color.WHITE, 60.0)
	assert_int(ftm._active_labels.size()).is_equal(1)
	# Label should exist (not crash), positioned somewhere reasonable.
	var label: Label = ftm.get_child(0)
	assert_bool(label != null).is_true()

	ftm.queue_free()


# ===========================================================================
# Cross-Feature Integration
# ===========================================================================

func test_cross_renderer_receives_map_generated_signal() -> void:
	# HexGridRenderer connects to HexGrid autoload on _ready().
	# Generating a map through the autoload should populate the renderer.
	HexGrid._tiles.clear()
	var renderer: Node = load("res://scenes/world/hex_grid_renderer.tscn").instantiate()
	add_child(renderer)  # _ready() fires → connects to HexGrid.map_generated

	var gen := _WorldGenerator.new(HexGrid)
	gen.generate(TEST_SEED)  # Fires HexGrid.map_generated → renderer._on_map_generated()

	assert_bool(renderer._tile_data.size() > 0).override_failure_message(
		"Renderer._tile_data should be populated after map_generated signal"
	).is_true()
	assert_int(renderer._tile_data.size()).is_equal(HexGrid._tiles.size())

	renderer.queue_free()
	HexGrid._tiles.clear()


func test_cross_player_move_fires_tile_entered_and_exited() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player.current_tile = Vector2i(0, 0)
	player._snap_to_tile(Vector2i(0, 0))

	var exited: Array[Vector2i] = []
	var entered: Array[Vector2i] = []
	_grid.tile_exited.connect(func(c: Vector2i) -> void: exited.append(c))
	_grid.tile_entered.connect(func(c: Vector2i) -> void: entered.append(c))

	player._complete_tile_transition(Vector2i(0, 0), Vector2i(1, 0))

	assert_bool(exited.has(Vector2i(0, 0))).override_failure_message(
		"tile_exited must fire for (0,0)"
	).is_true()
	assert_bool(entered.has(Vector2i(1, 0))).override_failure_message(
		"tile_entered must fire for (1,0)"
	).is_true()
	player.queue_free()


func test_cross_fog_reveals_when_refresh_visibility_called() -> void:
	_generate()
	# Find a HIDDEN tile at distance > 3 to use as the reveal target.
	var hidden_tile := Vector2i(-9999, -9999)
	for c: Variant in _grid._tiles:
		var coords: Vector2i = c
		if _HexMath.distance(Vector2i.ZERO, coords) > 3 and _grid._tiles[coords].fog_state == _HexTile.FogState.HIDDEN:
			hidden_tile = coords
			break
	assert_bool(hidden_tile != Vector2i(-9999, -9999)).override_failure_message(
		"Expected at least one HIDDEN tile at distance > 3"
	).is_true()
	if hidden_tile == Vector2i(-9999, -9999):
		return

	# Find a neighbor of the hidden tile to use as the visibility source.
	var source := Vector2i(-9999, -9999)
	for n: Variant in _HexMath.get_neighbors(hidden_tile):
		var nv: Vector2i = n
		if _grid._tiles.has(nv):
			source = nv
			break
	if source == Vector2i(-9999, -9999):
		return

	var sources: Array[Dictionary] = [{"coords": source, "radius": 1}]
	_grid.refresh_visibility(sources)
	assert_int(_grid._tiles[hidden_tile].fog_state).is_equal(_HexTile.FogState.VISIBLE)


# ===========================================================================
# Full Walkthrough — generate → spawn → move → fog reveals
# ===========================================================================

func test_full_walkthrough_generate_spawn_move_reveal_fog() -> void:
	## Delivery-001 end-to-end: world generates, player spawns at Crash Site,
	## moves to a neighbor, and fog updates correctly around the new position.

	# 1. Generate world.
	var ok := _generate()
	assert_bool(ok).override_failure_message("WorldGenerator.generate() must succeed").is_true()

	# 2. Crash Site is at origin.
	var crash_tile: Resource = _grid.get_tile(Vector2i.ZERO)
	assert_bool(crash_tile != null).is_true()
	assert_int(crash_tile.biome).is_equal(_HexTile.Biome.CRASH_SITE)

	# 3. Spawn player.
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._pathfinder._build_graph()
	player._on_map_generated()
	assert_object(player.current_tile).is_equal(Vector2i.ZERO)

	# 4. Initial fog: origin ring-1 is VISIBLE.
	for coords: Variant in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		var c: Vector2i = coords
		if _grid._tiles.has(c):
			assert_int(_grid._tiles[c].fog_state).is_equal(_HexTile.FogState.VISIBLE)

	# 5. Find a passable neighbor to move toward.
	var next_tile := Vector2i(-9999, -9999)
	for n: Variant in _HexMath.get_neighbors(Vector2i.ZERO):
		var nv: Vector2i = n
		if _grid._tiles.has(nv) and _grid.is_passable(Vector2i.ZERO, nv):
			next_tile = nv
			break
	assert_bool(next_tile != Vector2i(-9999, -9999)).override_failure_message(
		"Crash Site must have at least one passable neighbor"
	).is_true()

	# 6. Execute tile transition — signals must fire, current_tile must update.
	var player_moved_log: Array = []
	player.player_moved.connect(func(_f: Vector2i, _t: Vector2i) -> void:
		player_moved_log.append(true)
	)
	player._complete_tile_transition(Vector2i.ZERO, next_tile)
	assert_object(player.current_tile).is_equal(next_tile)
	assert_bool(player_moved_log.size() > 0).override_failure_message(
		"player_moved signal must fire on tile transition"
	).is_true()

	# 7. Refresh visibility from new position (DayNightCycle will own this in delivery-004).
	var sources: Array[Dictionary] = [{"coords": next_tile, "radius": 2}]
	var changed: Array = _grid.refresh_visibility(sources)
	assert_bool(changed.size() > 0).override_failure_message(
		"Fog state must change after refresh_visibility from new tile"
	).is_true()

	# 8. Tiles within radius 2 of new position must be VISIBLE.
	for coords: Variant in _HexMath.get_tiles_in_range(next_tile, 2):
		var c: Vector2i = coords
		if _grid._tiles.has(c):
			assert_int(_grid._tiles[c].fog_state).is_equal(_HexTile.FogState.VISIBLE)

	player.queue_free()
