extends GdUnitTestSuite
class_name TestPlayer

## Tests Player state machine, tile transitions, snap tiebreaker, serialization.
## Note: Tween-based tests require scene tree, so we add Player as child.

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
	_player._grid = _grid  # Inject test grid before _ready fires.
	add_child(_player)
	# Manually build pathfinder graph since map_generated didn't fire.
	_player._pathfinder._build_graph()
	_player.current_tile = Vector2i(0, 0)
	_player._snap_to_tile(Vector2i(0, 0))


func after_test() -> void:
	_player.queue_free()
	_grid.queue_free()


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


# --- MoveState enum tests ---

func test_initial_state_is_idle() -> void:
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


# --- Pathfinding state transitions ---

func test_pathfind_to_changes_state() -> void:
	_player.pathfind_to(Vector2i(2, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)


func test_pathfind_to_same_tile_stays_idle() -> void:
	_player.pathfind_to(Vector2i(0, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


func test_pathfind_to_nonexistent_tile_stays_idle() -> void:
	_player.pathfind_to(Vector2i(99, 99))
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


func test_pathfind_sets_move_path() -> void:
	_player.pathfind_to(Vector2i(2, 0))
	assert_bool(_player.move_path.size() > 0).is_true()


# --- Walking state transitions ---

func test_start_walking_changes_state() -> void:
	_player.start_walking(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)


func test_start_walking_cancels_pathfinding() -> void:
	_player.pathfind_to(Vector2i(2, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)
	_player.start_walking(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)
	assert_bool(_player.move_path.is_empty()).is_true()


func test_stop_walking_goes_idle() -> void:
	_player.start_walking(Vector2.RIGHT)
	_player.stop_walking()
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


# --- Tile transition sequence ---

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

	# Directly call transition to avoid needing real tween completion.
	_player._complete_tile_transition(Vector2i(0, 0), Vector2i(1, 0))

	assert_int(signals_received.size()).is_equal(3)
	assert_str(signals_received[0]["type"]).is_equal("exited")
	assert_object(signals_received[0]["coords"]).is_equal(Vector2i(0, 0))
	assert_str(signals_received[1]["type"]).is_equal("entered")
	assert_object(signals_received[1]["coords"]).is_equal(Vector2i(1, 0))
	assert_str(signals_received[2]["type"]).is_equal("moved")
	assert_object(signals_received[2]["from"]).is_equal(Vector2i(0, 0))
	assert_object(signals_received[2]["to"]).is_equal(Vector2i(1, 0))


func test_tile_transition_updates_current_tile() -> void:
	_player._complete_tile_transition(Vector2i(0, 0), Vector2i(1, 0))
	assert_object(_player.current_tile).is_equal(Vector2i(1, 0))


# --- Snap tiebreaker ---

func test_snap_forward_when_past_halfway() -> void:
	# Simulate mid-tween state.
	_player._tween_origin_tile = Vector2i(0, 0)
	_player._tween_target_tile = Vector2i(1, 0)
	_player._tween_progress = 0.6
	_player._active_tween = _player.create_tween()
	# Tween something trivial so it's "running".
	_player._active_tween.tween_property(_player, "position:x", 99.0, 10.0)

	_player._resolve_snap()
	assert_object(_player.current_tile).is_equal(Vector2i(1, 0))


func test_snap_back_when_at_or_before_halfway() -> void:
	_player._tween_origin_tile = Vector2i(0, 0)
	_player._tween_target_tile = Vector2i(1, 0)
	_player._tween_progress = 0.5
	_player._active_tween = _player.create_tween()
	_player._active_tween.tween_property(_player, "position:x", 99.0, 10.0)

	_player._resolve_snap()
	assert_object(_player.current_tile).is_equal(Vector2i(0, 0))


func test_snap_back_when_just_started() -> void:
	_player._tween_origin_tile = Vector2i(0, 0)
	_player._tween_target_tile = Vector2i(1, 0)
	_player._tween_progress = 0.1
	_player._active_tween = _player.create_tween()
	_player._active_tween.tween_property(_player, "position:x", 99.0, 10.0)

	_player._resolve_snap()
	assert_object(_player.current_tile).is_equal(Vector2i(0, 0))


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
	assert_bool(_player.move_path.is_empty()).is_true()


func test_save_load_round_trip() -> void:
	_player.current_tile = Vector2i(-2, 3)
	var data: Dictionary = _player.get_save_data()
	_player.current_tile = Vector2i(0, 0)
	_player.load_save_data(data)
	assert_object(_player.current_tile).is_equal(Vector2i(-2, 3))


# --- State machine transition table ---

func test_idle_to_pathfinding_on_tap() -> void:
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)
	_player.pathfind_to(Vector2i(1, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)


func test_idle_to_walking_on_joystick() -> void:
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)
	_player.start_walking(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)


func test_pathfinding_to_walking_on_joystick() -> void:
	_player.pathfind_to(Vector2i(2, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)
	_player.start_walking(Vector2.LEFT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)
	assert_bool(_player.move_path.is_empty()).is_true()


func test_pathfinding_to_pathfinding_on_new_tap() -> void:
	_player.pathfind_to(Vector2i(2, 0))
	_player.pathfind_to(Vector2i(-1, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)


func test_walking_to_idle_on_release() -> void:
	_player.start_walking(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)
	_player.stop_walking()
	assert_int(_player.move_state).is_equal(_Player.MoveState.IDLE)


func test_walking_to_pathfinding_on_tap() -> void:
	_player.start_walking(Vector2.RIGHT)
	assert_int(_player.move_state).is_equal(_Player.MoveState.WALKING)
	_player.pathfind_to(Vector2i(2, 0))
	assert_int(_player.move_state).is_equal(_Player.MoveState.PATHFINDING)
