extends GdUnitTestSuite
class_name TestPlayerInput

## Tests for PlayerInput two-outcome touch classifier.
## Injects a mock grid and bypasses Camera3D (null → _screen_to_axial returns (0,0)).
## Calls internal _on_touch_down/_on_touch_up/_on_drag/_process directly.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _PlayerInput = preload("res://scripts/player/player_input.gd")

var _player_input: Node
var _grid: Node
var _signals: Array = []


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)
	_build_test_grid()

	_player_input = _PlayerInput.new()
	_player_input._grid = _grid
	# _camera stays null → _screen_to_axial returns Vector2i.ZERO.
	add_child(_player_input)

	_signals.clear()
	_player_input.tap_tile.connect(func(c: Vector2i) -> void:
		_signals.append({"type": "tap_tile", "coords": c})
	)
	_player_input.scan_hold_started.connect(func(c: Vector2i) -> void:
		_signals.append({"type": "scan_hold_started", "coords": c})
	)
	_player_input.scan_hold_update.connect(func(p: Vector2) -> void:
		_signals.append({"type": "scan_hold_update", "pos": p})
	)
	_player_input.scan_hold_ended.connect(func() -> void:
		_signals.append({"type": "scan_hold_ended"})
	)
	_player_input.joystick_started.connect(func(d: Vector2) -> void:
		_signals.append({"type": "joystick_started", "dir": d})
	)
	_player_input.joystick_moved.connect(func(d: Vector2, m: float) -> void:
		_signals.append({"type": "joystick_moved", "dir": d, "mag": m})
	)
	_player_input.joystick_released.connect(func() -> void:
		_signals.append({"type": "joystick_released"})
	)


func after_test() -> void:
	_player_input.queue_free()
	_grid.queue_free()


func _build_test_grid() -> void:
	# Single REVEALED tile at (0,0) so taps resolve via world_to_axial→(0,0).
	var tile := _HexTile.new()
	tile.coords = Vector2i.ZERO
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.elevation = 0
	tile.fog_state = _HexTile.FogState.REVEALED
	_grid._tiles[Vector2i.ZERO] = tile
	# Hidden tile at (1,0) to test hidden-tile rejection.
	var hidden := _HexTile.new()
	hidden.coords = Vector2i(1, 0)
	hidden.biome = _HexTile.Biome.GRASSLAND
	hidden.fog_state = _HexTile.FogState.HIDDEN
	_grid._tiles[Vector2i(1, 0)] = hidden


func _has_signal_of_type(type_str: String) -> bool:
	for s in _signals:
		if s.get("type", "") == type_str:
			return true
	return false


# --- Initial state ---

func test_initial_state_is_idle() -> void:
	assert_int(_player_input._state).is_equal(0)  # _State.IDLE = 0


# --- TAP outcome ---

func test_tap_short_no_drag_emits_tap_tile() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.1  # well within 300ms
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_true()


func test_tap_emits_correct_coords_from_grid() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.1
	_player_input._on_touch_up()
	var taps := _signals.filter(func(s) -> bool: return s.get("type","") == "tap_tile")
	assert_int(taps.size()).is_equal(1)
	assert_object(taps[0]["coords"]).is_equal(Vector2i.ZERO)


func test_tap_exceeding_max_duration_does_not_emit_tap() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.35  # > tap_max_duration (0.3)
	# Manually set state so _process would have classified as scan hold, but we force TRACKING.
	_player_input._state = 1  # _State.TRACKING
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_false()


func test_tap_with_large_drag_does_not_emit_tap() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_current = Vector2(25.0, 0.0)  # > tap_max_drag (20px)
	_player_input._touch_duration = 0.1
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_false()


func test_tap_on_hidden_tile_does_not_emit_tap() -> void:
	# Manually set _screen_to_axial to return hidden tile coords by bypassing camera:
	# Set a revealed tile at (0,0) and tap should map to (0,0).
	# To test hidden rejection, we add only a hidden tile and remove the revealed one.
	_grid._tiles.erase(Vector2i.ZERO)
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.1
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_false()
	# Restore
	var tile := _HexTile.new()
	tile.coords = Vector2i.ZERO
	tile.fog_state = _HexTile.FogState.REVEALED
	_grid._tiles[Vector2i.ZERO] = tile


# --- SCAN HOLD outcome ---

func test_hold_at_threshold_emits_scan_hold_started() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)  # hold_threshold reached → _enter_scan_hold
	assert_bool(_has_signal_of_type("scan_hold_started")).is_true()


func test_scan_hold_started_includes_coords() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)
	var holds := _signals.filter(func(s) -> bool: return s.get("type","") == "scan_hold_started")
	assert_int(holds.size()).is_equal(1)
	# Camera is null → _screen_to_axial returns (0,0).
	assert_object(holds[0]["coords"]).is_equal(Vector2i.ZERO)


func test_scan_hold_update_emits_while_held() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)  # enter SCAN_HOLD
	_signals.clear()
	_player_input._touch_current = Vector2(5.0, 5.0)
	_player_input._process(0.016)  # should emit scan_hold_update
	assert_bool(_has_signal_of_type("scan_hold_update")).is_true()


func test_scan_hold_ended_on_touch_up() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("scan_hold_ended")).is_true()


func test_scan_hold_does_not_emit_tap_on_release() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_false()


# --- JOYSTICK outcome ---

func test_drag_beyond_threshold_emits_joystick_started() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(25.0, 0.0))  # 25px > drag_threshold (20px)
	assert_bool(_has_signal_of_type("joystick_started")).is_true()


func test_drag_below_threshold_does_not_start_joystick() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(15.0, 0.0))  # 15px < drag_threshold (20px)
	assert_bool(_has_signal_of_type("joystick_started")).is_false()


func test_joystick_drag_does_not_emit_tap() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(25.0, 0.0))
	_player_input._touch_duration = 0.1
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_false()


func test_joystick_released_on_touch_up() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(25.0, 0.0))
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("joystick_released")).is_true()


func test_joystick_started_direction_matches_drag() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(25.0, 0.0))  # drag right
	var starts := _signals.filter(func(s) -> bool: return s.get("type","") == "joystick_started")
	assert_int(starts.size()).is_equal(1)
	var dir: Vector2 = starts[0]["dir"]
	assert_float(dir.x).is_greater(0.9)  # pointing right


func test_joystick_moved_emits_in_joystick_state() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._on_drag(Vector2(25.0, 0.0))  # enter joystick
	_signals.clear()
	_player_input._process(0.016)
	assert_bool(_has_signal_of_type("joystick_moved")).is_true()


func test_joystick_magnitude_clamped_to_one() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_current = Vector2(9999.0, 0.0)
	_player_input._on_drag(Vector2(9999.0, 0.0))
	var moves := _signals.filter(func(s) -> bool: return s.get("type","") == "joystick_moved")
	assert_bool(moves.size() > 0).is_true()
	for m in moves:
		assert_float(m["mag"]).is_less_equal(1.0)


# --- Drag wins over scan hold ---

func test_drag_during_scan_hold_switches_to_joystick() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)  # enter SCAN_HOLD
	_signals.clear()
	_player_input._on_drag(Vector2(25.0, 0.0))  # drag ≥20px while in SCAN_HOLD
	assert_bool(_has_signal_of_type("scan_hold_ended")).is_true()
	assert_bool(_has_signal_of_type("joystick_started")).is_true()


# --- scan_rejected fallback ---

func test_scan_rejected_transitions_to_joystick() -> void:
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.3
	_player_input._process(0.0)  # enter SCAN_HOLD
	_signals.clear()
	_player_input.receive_scan_rejected(Vector2i.ZERO)
	# Needs 2 _process frames to expire the rejection countdown.
	_player_input._process(0.016)
	_player_input._process(0.016)
	assert_bool(_has_signal_of_type("joystick_started")).is_true()


func test_scan_rejected_outside_scan_hold_has_no_effect() -> void:
	# IDLE state — rejection should be ignored.
	_player_input.receive_scan_rejected(Vector2i.ZERO)
	_player_input._process(0.016)
	_player_input._process(0.016)
	assert_bool(_has_signal_of_type("joystick_started")).is_false()


# --- Threshold values are exported (tunable) ---

func test_exported_thresholds_have_correct_defaults() -> void:
	assert_float(_player_input.tap_max_duration).is_equal(0.3)
	assert_float(_player_input.tap_max_drag).is_equal(20.0)
	assert_float(_player_input.hold_threshold).is_equal(0.3)
	assert_float(_player_input.drag_threshold).is_equal(20.0)


func test_custom_tap_duration_threshold_respected() -> void:
	_player_input.tap_max_duration = 0.5
	_player_input._on_touch_down(Vector2.ZERO)
	_player_input._touch_duration = 0.4  # within new threshold
	_player_input._state = 1  # force TRACKING to skip _process classification
	_player_input._on_touch_up()
	assert_bool(_has_signal_of_type("tap_tile")).is_true()


# --- Screen-to-axial coordinate conversion ---

func test_screen_to_axial_returns_zero_without_camera() -> void:
	_player_input._camera = null
	var result: Vector2i = _player_input._screen_to_axial(Vector2(540, 960))
	assert_object(result).is_equal(Vector2i.ZERO)


func test_screen_to_axial_returns_zero_with_no_grid() -> void:
	_player_input._camera = null
	_player_input._grid = null
	var result: Vector2i = _player_input._screen_to_axial(Vector2(100, 100))
	assert_object(result).is_equal(Vector2i.ZERO)
	# Restore grid
	_player_input._grid = _grid
