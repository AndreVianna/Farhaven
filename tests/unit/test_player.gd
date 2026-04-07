extends GdUnitTestSuite
class_name TestPlayer

## Tests Player continuous movement, JUMPING state, tile transitions,
## slide-along-boundary, snap-to-center, serialization.
## Post-pivot: no pathfinding, no PATHFINDING state.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Player = preload("res://scripts/player/player.gd")

var _grid: Node
var _player: Node3D


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)
	_build_small_grid()
	_player = _Player.new()
	_player._grid = _grid
	add_child(_player)
	_player.current_tile = Vector2i(0, 0)
	_player._snap_to_tile(Vector2i(0, 0))


func after_test() -> void:
	_player.queue_free()
	_grid.queue_free()


## Build a flat grid (elevation 0) for basic tests.
func _build_small_grid() -> void:
	_grid._tiles.clear()
	for q in range(-3, 4):
		for r in range(-3, 4):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 6:
				continue
			var tile = _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			_grid._tiles[Vector2i(q, r)] = tile


## Add elevation variation to specific tiles for traversal testing.
func _set_tile_elevation(coords: Vector2i, elev: int) -> void:
	var tile = _grid._tiles.get(coords)
	if tile != null:
		tile.elevation = elev


# --- MoveState enum tests ---

func test_movestate_has_idle_walking_jumping() -> void:
	assert_int(_Player.MoveState.IDLE).is_equal(0)
	assert_int(_Player.MoveState.WALKING).is_equal(1)
	assert_int(_Player.MoveState.JUMPING).is_equal(2)


func test_initial_state_is_idle() -> void:
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


# --- Joystick start/stop ---

func test_joystick_start_changes_to_walking() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)


func test_joystick_stop_changes_to_idle() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._on_joystick_stop()
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


func test_joystick_move_updates_direction() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._on_joystick_move(Vector2.LEFT, 0.5)
	assert_float(_player._joystick_dir.x).is_less(-0.9)
	assert_float(_player._joystick_magnitude).is_equal_approx(0.5, 0.01)


# --- Continuous movement ---

func test_walking_moves_position_per_frame() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	var old_x: float = _player.position.x
	_player._process_walking(0.1)
	assert_float(_player.position.x).is_greater(old_x)


func test_walking_does_not_move_when_magnitude_zero() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_magnitude = 0.0
	var old_pos: Vector3 = _player.position
	_player._process_walking(0.1)
	assert_float(_player.position.x).is_equal_approx(old_pos.x, 0.001)


# --- current_tile derived from position ---

func test_current_tile_updates_on_boundary_cross() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	# Move enough frames to cross a tile boundary
	for _i in range(100):
		_player._process_walking(0.02)
	assert_bool(_player.current_tile != Vector2i(0, 0)).is_true()


# --- Tile transition signals ---

func test_tile_transition_emits_signals_in_order() -> void:
	var signals_received: Array = []

	_grid.tile_exited.connect(func(coords: Vector2i) -> void:
		signals_received.append({"type": "exited", "coords": coords})
	)
	_grid.tile_entered.connect(func(coords: Vector2i) -> void:
		signals_received.append({"type": "entered", "coords": coords})
	)
	_player.player_moved.connect(func(from: Vector2i, to: Vector2i) -> void:
		signals_received.append({"type": "moved", "from": from, "to": to})
	)

	_player._emit_tile_transition(Vector2i(0, 0), Vector2i(1, 0))

	# Expect: exited, entered, moved (fog refresh doesn't emit in this check)
	var filtered: Array = signals_received.filter(func(s: Dictionary) -> bool:
		return s["type"] in ["exited", "entered", "moved"]
	)
	assert_int(filtered.size()).is_equal(3)
	assert_str(filtered[0]["type"]).is_equal("exited")
	assert_object(filtered[0]["coords"]).is_equal(Vector2i(0, 0))
	assert_str(filtered[1]["type"]).is_equal("entered")
	assert_object(filtered[1]["coords"]).is_equal(Vector2i(1, 0))
	assert_str(filtered[2]["type"]).is_equal("moved")
	assert_object(filtered[2]["from"]).is_equal(Vector2i(0, 0))
	assert_object(filtered[2]["to"]).is_equal(Vector2i(1, 0))


# --- WALK traversal (elevation diff 0-1) ---

func test_walk_traversal_seamless_boundary_crossing() -> void:
	# Adjacent tile at elevation 1 (diff = 1 = WALK)
	_set_tile_elevation(Vector2i(1, 0), 1)
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	for _i in range(100):
		_player._process_walking(0.02)
	# Should have walked into a tile with elevation 1
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)


func test_walk_y_follows_terrain() -> void:
	# Tile (1,0) at elevation 1, current at 0.
	# Player at midpoint should follow the curved terrain surface.
	_set_tile_elevation(Vector2i(1, 0), 1)
	var from_world: Vector2 = _grid.axial_to_world(Vector2i(0, 0))
	var to_world: Vector2 = _grid.axial_to_world(Vector2i(1, 0))
	var mid: Vector2 = (from_world + to_world) * 0.5
	_player.position = Vector3(mid.x, 0.0, mid.y)
	_player._update_elevation_y_interpolated(mid, Vector2i(0, 0), Vector2i(1, 0))
	# Y should match the terrain height computed by get_terrain_y.
	var expected_y: float = _grid.get_terrain_y(mid.x, mid.y)
	assert_float(_player.position.y).is_equal_approx(expected_y, 0.001)


# --- JUMP/DROP traversal (elevation diff 2) ---

func test_jump_triggers_jumping_state() -> void:
	# Set tile (1,0) to elevation 2 (diff = 2, going up = JUMP)
	_set_tile_elevation(Vector2i(1, 0), 2)
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	# Move until boundary
	for _i in range(100):
		if _player.move_state == _Player.MoveState.JUMPING:
			break
		_player._process_walking(0.02)
	assert_int(_player.move_state).is_equal(_Player.MoveState.JUMPING)


func test_drop_triggers_jumping_state() -> void:
	# Set tile (1,0) to elevation 0, current at elevation 2 (diff = 2, going down = DROP)
	_set_tile_elevation(Vector2i(0, 0), 2)
	_player._snap_to_tile(Vector2i(0, 0))
	_set_tile_elevation(Vector2i(1, 0), 0)
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	for _i in range(100):
		if _player.move_state == _Player.MoveState.JUMPING:
			break
		_player._process_walking(0.02)
	assert_int(_player.move_state).is_equal(_Player.MoveState.JUMPING)


func test_joystick_buffered_during_jumping() -> void:
	_set_tile_elevation(Vector2i(1, 0), 2)
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	for _i in range(100):
		if _player.move_state == _Player.MoveState.JUMPING:
			break
		_player._process_walking(0.02)
	# Now in JUMPING — send joystick input, should be buffered
	_player._on_joystick_move(Vector2.LEFT, 0.7)
	assert_float(_player._buffered_dir.x).is_less(0.0)
	assert_float(_player._buffered_magnitude).is_equal_approx(0.7, 0.01)


# --- BLOCKED traversal ---

func test_blocked_water_prevents_crossing() -> void:
	_grid._tiles[Vector2i(1, 0)].biome = _HexTile.Biome.WATER
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	for _i in range(50):
		_player._process_walking(0.02)
	# Player should not be on water tile
	assert_bool(_player.current_tile != Vector2i(1, 0)).is_true()


func test_blocked_steep_elevation_prevents_crossing() -> void:
	# Elevation diff 5 = BLOCKED
	_set_tile_elevation(Vector2i(1, 0), 5)
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	for _i in range(50):
		_player._process_walking(0.02)
	assert_bool(_player.current_tile != Vector2i(1, 0)).is_true()


func test_slide_along_boundary_moves_position() -> void:
	# Block tile to the right, try to slide
	_grid._tiles[Vector2i(1, 0)].biome = _HexTile.Biome.WATER
	var old_pos: Vector3 = _player.position
	# Move at an angle toward the blocked tile — should slide
	_player._on_joystick_start(Vector2(1.0, 0.5).normalized())
	_player._joystick_dir = Vector2(1.0, 0.5).normalized()
	_player._joystick_magnitude = 1.0
	for _i in range(20):
		_player._process_walking(0.02)
	# Position should have moved (sliding), even if not into the blocked tile
	var moved: bool = _player.position.distance_to(old_pos) > 0.01
	assert_bool(moved).is_true()


# --- Snap to tile center ---

func test_no_snap_on_joystick_release() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	# Move a bit so we're offset from center
	_player._process_walking(0.05)
	var pos_before: Vector3 = _player.position
	_player._on_joystick_stop()
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)
	# No snap — player stays where they stopped
	assert_vector(_player.position).is_equal(pos_before)


# --- Serialization ---

func test_save_data_format() -> void:
	_player.current_tile = Vector2i(3, -2)
	var data: Dictionary = _player.get_save_data()
	assert_int(data["tile_col"]).is_equal(3)
	assert_int(data["tile_row"]).is_equal(-2)


func test_load_save_data_restores_position() -> void:
	var data := {"tile_col": 1, "tile_row": -1}
	_player.load_save_data(data)
	assert_object(_player.current_tile).is_equal(Vector2i(1, -1))
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


func test_save_load_round_trip() -> void:
	_player.current_tile = Vector2i(-2, 3)
	var data: Dictionary = _player.get_save_data()
	_player.current_tile = Vector2i(0, 0)
	_player.load_save_data(data)
	assert_object(_player.current_tile).is_equal(Vector2i(-2, 3))


func test_load_save_snaps_to_tile_center() -> void:
	var data := {"tile_col": 1, "tile_row": 0}
	_player.load_save_data(data)
	var expected_world: Vector2 = _grid.axial_to_world(Vector2i(1, 0))
	assert_float(_player.position.x).is_equal_approx(expected_world.x, 0.01)
	assert_float(_player.position.z).is_equal_approx(expected_world.y, 0.01)


# --- Spawn at Crash Site ---

func test_spawns_at_crash_site_on_map_generated() -> void:
	_player._on_map_generated()
	assert_object(_player.current_tile).is_equal(Vector2i(0, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


# --- Facing direction & model rotation ---

func test_facing_direction_updates_on_walk() -> void:
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	_player._process_walking(0.1)
	assert_bool(_player.facing_direction.is_zero_approx()).is_false()


func test_model_rotation_matches_facing() -> void:
	var mock_model := Node3D.new()
	_player.add_child(mock_model)
	_player._model = mock_model
	_player.facing_direction = Vector2(1.0, 0.0)  # facing +X
	_player._update_model_rotation()
	var expected_y: float = atan2(1.0, 0.0)
	assert_float(mock_model.rotation.y).is_equal_approx(expected_y, 0.001)
	mock_model.queue_free()


# --- Camera-relative movement ---

func test_movement_without_camera_is_world_space() -> void:
	_player._camera = null
	_player._on_joystick_start(Vector2.RIGHT)
	_player._joystick_dir = Vector2.RIGHT
	_player._joystick_magnitude = 1.0
	var old_x: float = _player.position.x
	_player._process_walking(0.1)
	# Without camera, joystick RIGHT maps to world +X (no rotation applied)
	assert_float(_player.position.x).is_greater(old_x)
	assert_float(_player.facing_direction.x).is_greater(0.9)
