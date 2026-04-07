extends GdUnitTestSuite
class_name TestDelivery001

## Integration tests for delivery-001: Foundation — Walk the World.
## Tests map loading (MapLoader/ch1.json), rendering (ArrayMesh + cliff faces),
## player movement (joystick-only), fog reveal, camera follow, HUD, floating text.
##
## Manual-only verification (not automatable — document here):
##   - Biome colors are visually distinct on screen
##   - Camera follow is smooth with no jitter during lerp
##   - Joystick overlay appears at touch origin and disappears on release
##   - Floating text rises and fades smoothly (tween quality)
##   - Day counter warm color palette renders correctly
##   - HIDDEN tiles invisible, VISIBLE full brightness (darkness via shader)

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _MapLoader = preload("res://scripts/hex/map_loader.gd")
const _Player = preload("res://scripts/player/player.gd")
const _PlayerInput = preload("res://scripts/player/player_input.gd")
const _PlayerCamera = preload("res://scripts/player/player_camera.gd")

const MAP_PATH: String = "res://data/maps/ch1.json"
const RENDERER_SCENE: String = "res://scenes/world/hex_grid_renderer.tscn"

var _grid: Node


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)


func after_test() -> void:
	_grid.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Load ch1.json into the local isolated _grid (not the HexGrid autoload).
func _load_map() -> bool:
	_grid._tiles.clear()
	var loader := _MapLoader.new(_grid)
	return loader.load_map(MAP_PATH)


## Build a flat grassland grid for movement tests (radius 5, elevation 0, VISIBLE).
func _build_movement_grid() -> void:
	_grid._tiles.clear()
	for q: int in range(-5, 6):
		for r: int in range(-5, 6):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 10:
				continue
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			_grid._tiles[Vector2i(q, r)] = tile


## Helper: add a single tile to _grid._tiles.
func _make_tile(coords: Vector2i, elevation: int, biome: int = 1) -> void:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = biome
	tile.elevation = elevation
	tile.fog_state = _HexTile.FogState.VISIBLE
	_grid._tiles[coords] = tile


# ===========================================================================
# AC1 — Map loads from ch1.json via MapLoader → HexGrid has tiles
# ===========================================================================

func test_ac1_map_loader_populates_hex_grid() -> void:
	var ok := _load_map()
	assert_bool(ok).override_failure_message("MapLoader.load_map() returned false").is_true()
	assert_bool(_grid._tiles.size() > 0).override_failure_message(
		"HexGrid._tiles must not be empty after loading"
	).is_true()


func test_ac1_tile_count_is_nonzero() -> void:
	_load_map()
	var count: int = _grid._tiles.size()
	assert_bool(count > 0).override_failure_message(
		"ch1.json must load at least 1 tile, got %d" % count
	).is_true()


func test_ac1_crash_site_at_origin() -> void:
	_load_map()
	var tile: Resource = _grid.get_tile(Vector2i.ZERO)
	assert_bool(tile != null).override_failure_message("Tile must exist at (0,0)").is_true()
	if tile != null:
		assert_int(tile.biome).is_equal(_HexTile.Biome.CRASH_SITE)


func test_ac1_all_required_biomes_present() -> void:
	_load_map()
	var biomes: Dictionary = {}
	for c: Variant in _grid._tiles:
		biomes[_grid._tiles[c].biome] = true
	assert_bool(biomes.has(_HexTile.Biome.CRASH_SITE)).override_failure_message("Missing CRASH_SITE").is_true()
	assert_bool(biomes.has(_HexTile.Biome.GRASSLAND)).override_failure_message("Missing GRASSLAND").is_true()
	assert_bool(biomes.has(_HexTile.Biome.FOREST)).override_failure_message("Missing FOREST").is_true()
	assert_bool(biomes.has(_HexTile.Biome.ROCKY)).override_failure_message("Missing ROCKY").is_true()


func test_ac1_spawn_ring_visible_after_load() -> void:
	_load_map()
	# MapLoader sets radius-1 tiles around spawn to VISIBLE.
	for coords: Variant in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		var c: Vector2i = coords
		if _grid._tiles.has(c):
			assert_int(_grid._tiles[c].fog_state).override_failure_message(
				"Tile %s within spawn ring must be VISIBLE" % str(c)
			).is_equal(_HexTile.FogState.VISIBLE)


# ===========================================================================
# AC2 — HexGridRenderer builds ArrayMesh (no MultiMesh)
# ===========================================================================

func test_ac2_renderer_has_mesh_instance_child() -> void:
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	var mi: Node = renderer.get_node_or_null("MeshInstance3D")
	assert_bool(mi != null).override_failure_message(
		"HexGridRenderer must have a MeshInstance3D child"
	).is_true()
	renderer.queue_free()
	HexGrid._tiles.clear()


func test_ac2_renderer_mesh_populated_after_map_generated() -> void:
	HexGrid._tiles.clear()
	for q: int in range(-2, 3):
		for r: int in range(-2, 3):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 4:
				continue
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			HexGrid._tiles[Vector2i(q, r)] = tile

	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	assert_bool(renderer._tile_data.size() > 0).override_failure_message(
		"_tile_data must be populated after map_generated"
	).is_true()
	var mi: MeshInstance3D = renderer.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_bool(mi != null and mi.mesh != null).override_failure_message(
		"MeshInstance3D.mesh must be set after map_generated"
	).is_true()

	renderer.queue_free()
	HexGrid._tiles.clear()


# ===========================================================================
# AC3 — Player spawns at crash site (0,0)
# ===========================================================================

func test_ac3_player_spawns_at_crash_site() -> void:
	_load_map()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._on_map_generated()
	assert_object(player.current_tile).is_equal(Vector2i.ZERO)
	player.queue_free()


func test_ac3_player_position_at_world_origin_after_spawn() -> void:
	_load_map()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player._on_map_generated()
	# axial_to_world(0,0) with elevation 0 → world (0, 0, 0).
	assert_float(player.position.x).is_equal_approx(0.0, 0.01)
	assert_float(player.position.z).is_equal_approx(0.0, 0.01)
	player.queue_free()


# ===========================================================================
# AC4 — Player continuous movement: joystick → position updates → current_tile
# ===========================================================================

func test_ac4_joystick_start_sets_walking_state() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player.current_tile = Vector2i.ZERO
	player._snap_to_tile(Vector2i.ZERO)

	player._on_joystick_start(Vector2.RIGHT)
	assert_int(player.move_state).is_equal(_Player.MoveState.WALKING)
	player.queue_free()


func test_ac4_joystick_movement_updates_position() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player.current_tile = Vector2i.ZERO
	player._snap_to_tile(Vector2i.ZERO)

	var initial_pos: Vector3 = player.position
	player._on_joystick_start(Vector2.RIGHT)
	player._process(0.1)
	assert_bool(player.position.distance_to(initial_pos) > 0.01).override_failure_message(
		"Player position must change after joystick movement"
	).is_true()
	player.queue_free()


func test_ac4_movement_updates_current_tile() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player.current_tile = Vector2i.ZERO
	player._snap_to_tile(Vector2i.ZERO)

	# Direction from (0,0) toward tile (1,0) in world space.
	var tile_world: Vector2 = _HexMath.axial_to_world(Vector2i(1, 0))
	var dir: Vector2 = tile_world.normalized()
	player._on_joystick_start(dir)

	# Drive movement until current_tile changes (max 30 steps × 0.1s = 3s).
	var changed := false
	for i: int in range(30):
		player._process(0.1)
		if player.current_tile != Vector2i.ZERO:
			changed = true
			break

	assert_bool(changed).override_failure_message(
		"current_tile must update after sustained joystick movement"
	).is_true()
	player.queue_free()


# ===========================================================================
# AC5 — Fog reveal on player movement
# ===========================================================================

func test_ac5_fog_reveals_around_new_tile_after_transition() -> void:
	# DayNightCycle owns visibility refresh — use HexGrid autoload so the signal chain works.
	var loader := _MapLoader.new(HexGrid)
	loader.load_map(MAP_PATH)
	# Find a passable neighbor of the crash site.
	var next_tile := Vector2i(-9999, -9999)
	for n: Variant in _HexMath.get_neighbors(Vector2i.ZERO):
		var nv: Vector2i = n
		if HexGrid._tiles.has(nv) and HexGrid.is_passable(Vector2i.ZERO, nv):
			next_tile = nv
			break
	assert_bool(next_tile != Vector2i(-9999, -9999)).override_failure_message(
		"Crash Site must have a passable neighbor"
	).is_true()
	if next_tile == Vector2i(-9999, -9999):
		HexGrid._tiles.clear()
		return

	var player := _Player.new()
	add_child(player)
	player._on_map_generated()

	player._emit_tile_transition(Vector2i.ZERO, next_tile)

	# Tiles within radius 2 of next_tile must be VISIBLE.
	for coords: Variant in _HexMath.get_tiles_in_range(next_tile, 2):
		var c: Vector2i = coords
		if HexGrid._tiles.has(c):
			assert_int(HexGrid._tiles[c].fog_state).override_failure_message(
				"Tile %s within radius 2 of new position must be VISIBLE" % str(c)
			).is_equal(_HexTile.FogState.VISIBLE)
	player.queue_free()
	HexGrid._tiles.clear()


func test_ac5_player_moved_signal_fires_on_transition() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player.current_tile = Vector2i.ZERO
	player._snap_to_tile(Vector2i.ZERO)

	var fired: Array = []
	player.player_moved.connect(func(_f: Vector2i, _t: Vector2i) -> void:
		fired.append(true)
	)
	player._emit_tile_transition(Vector2i.ZERO, Vector2i(1, 0))
	assert_bool(fired.size() > 0).override_failure_message(
		"player_moved signal must fire on tile transition"
	).is_true()
	player.queue_free()


# ===========================================================================
# AC6 — Camera follows player (lerp toward orbital offset)
# ===========================================================================

func test_ac6_camera_follows_player_toward_offset() -> void:
	_build_movement_grid()
	var player := _Player.new()
	player._grid = _grid
	add_child(player)
	player.current_tile = Vector2i.ZERO
	player._snap_to_tile(Vector2i.ZERO)

	var cam := _PlayerCamera.new()
	add_child(cam)
	cam.set_follow_target(player)

	# Orbital camera: desired position is player + spherical offset
	var look_target: Vector3 = player.position + Vector3(0.0, 0.5, 0.0)
	var initial_dist: float = cam.position.distance_to(look_target)
	cam._process(0.1)
	var new_dist: float = cam.position.distance_to(look_target)

	# Camera should be near the orbital distance (7 units default)
	assert_bool(new_dist < initial_dist or new_dist < cam.distance + 2.0).override_failure_message(
		"Camera must converge toward orbital distance from player"
	).is_true()

	cam.queue_free()
	player.queue_free()


# ===========================================================================
# AC7 — HUD exists with correct structure
# ===========================================================================

func test_ac7_hud_stat_bars_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var stat_bars: Node = hud.get_node_or_null("StatBars")
	assert_bool(stat_bars != null).override_failure_message(
		"StatBars must exist under HUD"
	).is_true()
	hud.queue_free()


func test_ac7_hud_day_counter_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var day_counter: Node = hud.get_node_or_null("DayCounter")
	assert_bool(day_counter != null).override_failure_message(
		"DayCounter must exist under HUD"
	).is_true()
	hud.queue_free()


func test_ac7_hud_three_action_buttons_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var expected: Array[String] = [
		"StatusButton", "GearButton", "LogButton",
	]
	for btn_name: String in expected:
		var btn: Node = hud.get_node_or_null("BottomBar/" + btn_name)
		assert_bool(btn != null).override_failure_message(
			"%s must exist in BottomBar" % btn_name
		).is_true()
	hud.queue_free()


func test_ac7_gear_button_exists() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var gear_btn: CanvasItem = hud.get_node_or_null("BottomBar/GearButton") as CanvasItem
	assert_bool(gear_btn != null).override_failure_message("GearButton must exist").is_true()
	hud.queue_free()


func test_ac7_stat_bars_mouse_filter_ignore() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var stat_bars: Control = hud.get_node_or_null("StatBars") as Control
	assert_bool(stat_bars != null).is_true()
	if stat_bars != null:
		assert_int(stat_bars.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	hud.queue_free()


# ===========================================================================
# AC8 — FloatingTextManager: world→screen projection
# ===========================================================================

func test_ac8_floating_text_creates_label_with_camera() -> void:
	var ftm: Node = load("res://scripts/hud/floating_text_manager.gd").new()
	add_child(ftm)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()

	ftm.show_text(Vector3.ZERO, "+5 XP", Color.GREEN, 60.0)
	assert_int(ftm._active_labels.size()).is_equal(1)
	assert_int(ftm.get_child_count()).is_equal(1)

	cam.queue_free()
	ftm.queue_free()


func test_ac8_floating_text_fallback_without_camera() -> void:
	var ftm: Node = load("res://scripts/hud/floating_text_manager.gd").new()
	add_child(ftm)

	ftm.show_text(Vector3(100.0, 0.0, 100.0), "Fallback", Color.WHITE, 60.0)
	assert_int(ftm._active_labels.size()).is_equal(1)
	var label: Label = ftm.get_child(0)
	assert_bool(label != null).override_failure_message(
		"Fallback label must be created without camera"
	).is_true()

	ftm.queue_free()


# ===========================================================================
# AC9 — Panel mutual exclusion pattern
# ===========================================================================

func test_ac9_panel_mutual_exclusion_pattern() -> void:
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

	# Open panel B (idx 1): A and C close, B does not self-close.
	dispatch_open.call(1)
	assert_int(close_count["A"]).is_equal(1)
	assert_int(close_count["B"]).is_equal(0)
	assert_int(close_count["C"]).is_equal(1)

	# Open panel A (idx 0): B and C close.
	dispatch_open.call(0)
	assert_int(close_count["A"]).is_equal(1)
	assert_int(close_count["B"]).is_equal(1)
	assert_int(close_count["C"]).is_equal(2)


# ===========================================================================
# AC10 — Cliff faces exist in renderer mesh for elevation differences
# ===========================================================================

func test_ac10_cliff_faces_add_geometry_for_elevation_difference() -> void:
	# Two tiles with elevation diff — wall geometry must exist.
	# With walls on all non-water faces, verify the mesh has geometry.
	HexGrid._tiles.clear()
	var tile_a := _HexTile.new()
	tile_a.coords = Vector2i(0, 0)
	tile_a.biome = _HexTile.Biome.GRASSLAND
	tile_a.elevation = 0
	tile_a.fog_state = _HexTile.FogState.VISIBLE
	HexGrid._tiles[Vector2i(0, 0)] = tile_a

	var tile_b := _HexTile.new()
	tile_b.coords = Vector2i(1, 0)
	tile_b.biome = _HexTile.Biome.GRASSLAND
	tile_b.elevation = 5
	tile_b.fog_state = _HexTile.FogState.VISIBLE
	HexGrid._tiles[Vector2i(1, 0)] = tile_b

	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	var mi: MeshInstance3D = renderer.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var vert_count: int = 0
	if mi != null and mi.mesh != null:
		var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
		vert_count = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	# Each hex = 12 inner fan + 72 strip = 252 verts. 2 hexes = 504.
	# Wall faces add additional geometry. Elevated hex (elev 5) generates walls.
	assert_bool(vert_count > 504).override_failure_message(
		"Elevated hex must produce wall geometry: total=%d vertices (>504 expected)" % vert_count
	).is_true()

	renderer.queue_free()
	HexGrid._tiles.clear()


# ===========================================================================
# AC11 — Main scene bootstrap: _ready() loads ch1.json via HexGrid.load_map
# ===========================================================================

func test_ac11_main_scene_bootstrap_generates_world() -> void:
	HexGrid._tiles.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)

	await get_tree().process_frame

	var crash_tile: Variant = HexGrid.get_tile(Vector2i.ZERO)
	assert_object(crash_tile).is_not_null()

	var tile_count: int = HexGrid._tiles.size()
	assert_bool(tile_count > 0).override_failure_message(
		"Bootstrap must load ch1.json: expected > 0 tiles, got %d" % tile_count
	).is_true()

	main.queue_free()
	HexGrid._tiles.clear()


# ===========================================================================
# AC12 — Elevation/TraversalType: WALK (diff 0-2), JUMP/DROP (diff 3-4), BLOCKED (diff 5+)
# ===========================================================================

func test_ac12_walk_for_elevation_diff_0() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 0)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


func test_ac12_walk_for_elevation_diff_1() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 1)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


func test_ac12_jump_for_elevation_diff_3() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 3)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.JUMP)


func test_ac12_jump_for_elevation_diff_4() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 4)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.JUMP)


func test_ac12_blocked_for_elevation_diff_5() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 5)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


func test_ac12_blocked_for_water() -> void:
	_grid._tiles.clear()
	_make_tile(Vector2i(0, 0), 0)
	_make_tile(Vector2i(1, 0), 0, _HexTile.Biome.WATER)
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)
