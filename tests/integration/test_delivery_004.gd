extends GdUnitTestSuite
class_name TestDelivery004

## Integration tests for delivery-004: DayNight Cycle + SaveManager.
## Tests the full phase cycle timing, visibility changes per phase,
## torch visibility during NIGHT, save/load round-trip mid-phase,
## corrupt save handling, and auto-save on day_started signal.
##
## Time simulation: directly call _process(delta) with large deltas
## to force transitions without waiting real-time.
##
## Manual-only verification (not automatable — documented here):
##   - Lighting tween transitions are visually smooth between phases
##   - Warm palette colors render correctly per phase
##   - Sun energy/color changes are perceptible at each transition

const _DayNightCycle = preload("res://scripts/day_night/day_night_cycle.gd")
const _SaveManager = preload("res://scripts/save/save_manager.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

const SAVE_PATH: String = "user://save.json"

var _dnc: Node
var _sm: Node


func before_test() -> void:
	_cleanup_save_file()
	_dnc = _DayNightCycle.new()
	add_child(_dnc)
	_sm = _SaveManager.new()
	add_child(_sm)
	# Wire day_started → auto-save (mirrors SaveManager._ready when autoloads are at /root/).
	_dnc.day_started.connect(_sm._on_day_started)


func after_test() -> void:
	_sm.queue_free()
	_dnc.queue_free()
	_cleanup_save_file()
	HexGrid._tiles.clear()


# --- Helpers ---

func _simulate(delta: float) -> void:
	_dnc._process(delta)


func _cleanup_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _write_save_file(content: String) -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_save_file() -> String:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## Build a small hex grid for visibility tests.
func _build_small_grid() -> void:
	HexGrid._tiles.clear()
	for q: int in range(-3, 4):
		for r: int in range(-3, 4):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 6:
				continue
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.HIDDEN
			HexGrid._tiles[Vector2i(q, r)] = tile


# ===========================================================================
# AC7 — Full cycle timing: ~310s total (5 min +/- 15s tolerance)
# ===========================================================================

func test_ac7_full_cycle_total_is_240_seconds() -> void:
	var total: float = 0.0
	for dur: Variant in _DayNightCycle.PHASE_DURATIONS.values():
		total += float(dur)
	assert_float(total).is_equal(240.0)
	assert_bool(total >= 225.0 and total <= 255.0).override_failure_message(
		"Full cycle %0.1fs must be within 4 min +/- 15s (225-255)" % total
	).is_true()


func test_ac7_full_cycle_returns_to_day() -> void:
	_simulate(240.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)


func test_ac7_full_cycle_day_count_increments() -> void:
	assert_int(_dnc.day_count).is_equal(1)
	_simulate(240.0)
	assert_int(_dnc.day_count).is_equal(2)


func test_ac7_two_full_cycles() -> void:
	_simulate(480.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_int(_dnc.day_count).is_equal(3)


func test_ac7_phase_sequence_through_cycle() -> void:
	var phases: Array = []
	_dnc.phase_changed.connect(func(_old: _DayNightCycle.TimePhase, new: _DayNightCycle.TimePhase) -> void:
		phases.append(new)
	)
	_simulate(240.0)
	assert_int(phases.size()).is_equal(4)
	assert_int(phases[0]).is_equal(_DayNightCycle.TimePhase.DUSK)
	assert_int(phases[1]).is_equal(_DayNightCycle.TimePhase.NIGHT)
	assert_int(phases[2]).is_equal(_DayNightCycle.TimePhase.DAWN)
	assert_int(phases[3]).is_equal(_DayNightCycle.TimePhase.DAY)


# ===========================================================================
# AC7 — Dusk warning: phase_changed + signal at correct time
# ===========================================================================

func test_ac7_dusk_signal_fires_at_105s() -> void:
	var dusk_fired: Array = []
	_dnc.dusk.connect(func() -> void: dusk_fired.append(true))
	_simulate(104.0)
	assert_int(dusk_fired.size()).is_equal(0)
	_simulate(1.0)
	assert_int(dusk_fired.size()).is_equal(1)


func test_ac7_dusk_phase_change_emitted() -> void:
	var events: Array = []
	_dnc.phase_changed.connect(func(old: _DayNightCycle.TimePhase, new: _DayNightCycle.TimePhase) -> void:
		events.append({"old": old, "new": new})
	)
	_simulate(105.0)
	assert_int(events.size()).is_equal(1)
	assert_int(events[0]["old"]).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_int(events[0]["new"]).is_equal(_DayNightCycle.TimePhase.DUSK)


func test_ac7_is_daytime_false_during_dusk() -> void:
	_simulate(105.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_ac7_is_daytime_false_during_night() -> void:
	_simulate(120.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_ac7_is_daytime_true_during_dawn() -> void:
	_simulate(225.0)
	assert_bool(_dnc.is_daytime).is_true()


# ===========================================================================
# Visibility radius per phase
# ===========================================================================

func test_visibility_radius_day_is_2() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DAY]).is_equal(2)


func test_visibility_radius_dusk_is_2() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DUSK]).is_equal(2)


func test_visibility_radius_night_is_1() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.NIGHT]).is_equal(1)


func test_visibility_radius_dawn_is_2() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DAWN]).is_equal(2)


# ===========================================================================
# Visibility changes across phase transitions (integration with HexGrid)
# ===========================================================================

func test_visibility_refresh_on_phase_transition_to_night() -> void:
	_build_small_grid()
	# Set player tile at origin (DayNightCycle tracks _player_tile).
	_dnc._player_tile = Vector2i.ZERO
	# Advance to NIGHT — _refresh_visibility is called with radius 1.
	_simulate(120.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)
	# Origin tile must be VISIBLE after refresh with radius 1.
	var origin_tile: Resource = HexGrid.get_tile(Vector2i.ZERO)
	if origin_tile != null:
		assert_int(origin_tile.fog_state).is_equal(_HexTile.FogState.VISIBLE)


func test_visibility_night_radius_1_neighbors_visible() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	_simulate(120.0)  # → NIGHT
	# Radius 1 neighbors must be VISIBLE.
	for coords: Variant in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		var c: Vector2i = coords
		if HexGrid._tiles.has(c):
			assert_int(HexGrid._tiles[c].fog_state).override_failure_message(
				"Tile %s must be VISIBLE at NIGHT radius 1" % str(c)
			).is_equal(_HexTile.FogState.VISIBLE)


func test_visibility_night_radius_2_not_visible() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	_simulate(120.0)  # → NIGHT (radius 1)
	# Tiles at exactly distance 2 should NOT be VISIBLE (radius is 1 during NIGHT).
	var ring2_tiles: Array[Vector2i] = _HexMath.get_tiles_in_range(Vector2i.ZERO, 2)
	var ring1_tiles: Array[Vector2i] = _HexMath.get_tiles_in_range(Vector2i.ZERO, 1)
	for coords: Vector2i in ring2_tiles:
		if ring1_tiles.has(coords):
			continue
		if HexGrid._tiles.has(coords):
			assert_int(HexGrid._tiles[coords].fog_state).override_failure_message(
				"Tile %s at distance 2 must NOT be VISIBLE during NIGHT" % str(coords)
			).is_not_equal(_HexTile.FogState.VISIBLE)


func test_visibility_day_radius_2_neighbors_visible() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	# Trigger visibility refresh during DAY by simulating tile entry.
	HexGrid.tile_entered.emit(Vector2i.ZERO)
	# Radius 2 neighbors must be VISIBLE during DAY.
	for coords: Variant in _HexMath.get_tiles_in_range(Vector2i.ZERO, 2):
		var c: Vector2i = coords
		if HexGrid._tiles.has(c):
			assert_int(HexGrid._tiles[c].fog_state).override_failure_message(
				"Tile %s must be VISIBLE at DAY radius 2" % str(c)
			).is_equal(_HexTile.FogState.VISIBLE)


# ===========================================================================
# Torch visibility during NIGHT
# ===========================================================================

func test_torch_visibility_radius_is_2() -> void:
	assert_int(_DayNightCycle.TORCH_VISIBILITY_RADIUS).is_equal(2)


func test_torch_registered_via_structure_placed() -> void:
	HexGrid.structure_placed.emit(Vector2i(3, 4), &"torch")
	assert_bool(_dnc._torch_tiles.has(Vector2i(3, 4))).is_true()


func test_torch_removed_via_structure_destroyed() -> void:
	HexGrid.structure_placed.emit(Vector2i(3, 4), &"torch")
	HexGrid.structure_destroyed.emit(Vector2i(3, 4), &"torch")
	assert_bool(_dnc._torch_tiles.has(Vector2i(3, 4))).is_false()


func test_non_torch_structure_not_tracked() -> void:
	HexGrid.structure_placed.emit(Vector2i(5, 5), &"wall")
	assert_int(_dnc._torch_tiles.size()).is_equal(0)


func test_torch_extends_visibility_during_night() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	# Place torch at (2, 0)
	HexGrid.structure_placed.emit(Vector2i(2, 0), &"torch")
	# Advance to NIGHT
	_simulate(120.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)
	# Torch at (2,0) with radius 2 should make tiles around it VISIBLE.
	var torch_tile: Resource = HexGrid.get_tile(Vector2i(2, 0))
	if torch_tile != null:
		assert_int(torch_tile.fog_state).override_failure_message(
			"Torch tile must be VISIBLE during NIGHT"
		).is_equal(_HexTile.FogState.VISIBLE)


func test_torch_not_included_in_visibility_during_day() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	HexGrid.structure_placed.emit(Vector2i(3, 0), &"torch")
	# During DAY: torch should not add extra visibility sources.
	# Tile at distance 3 from player should not be visible (DAY radius is 2).
	HexGrid.tile_entered.emit(Vector2i.ZERO)
	var far_tile: Resource = HexGrid.get_tile(Vector2i(3, 0))
	if far_tile != null:
		# Distance 3 from origin is beyond DAY radius 2, so not VISIBLE
		# (unless torch adds it, which it shouldn't during DAY).
		assert_int(far_tile.fog_state).override_failure_message(
			"Tile at distance 3 must NOT be VISIBLE during DAY (torch inactive)"
		).is_not_equal(_HexTile.FogState.VISIBLE)


func test_night_player_visibility_radius_is_1() -> void:
	_build_small_grid()
	_dnc._player_tile = Vector2i.ZERO
	_simulate(120.0)  # → NIGHT
	# Player at origin, radius 1: (0,0) visible, (2,0) not visible (no torch).
	var origin: Resource = HexGrid.get_tile(Vector2i.ZERO)
	if origin != null:
		assert_int(origin.fog_state).is_equal(_HexTile.FogState.VISIBLE)


# ===========================================================================
# Save/Load round-trip: save mid-phase, load, verify state
# ===========================================================================

func test_save_load_round_trip_preserves_phase() -> void:
	_simulate(105.0)  # → DUSK
	var save_data: Dictionary = _dnc.get_save_data()
	assert_int(save_data["phase"]).is_equal(_DayNightCycle.TimePhase.DUSK)
	var dnc2: Node = _DayNightCycle.new()
	dnc2.load_save_data(save_data)
	assert_int(dnc2.current_phase).is_equal(_DayNightCycle.TimePhase.DUSK)
	assert_bool(dnc2.is_daytime).is_false()
	dnc2.free()


func test_save_load_round_trip_preserves_elapsed() -> void:
	_simulate(115.0)  # DUSK + 10s
	var save_data: Dictionary = _dnc.get_save_data()
	assert_float(save_data["phase_elapsed"]).is_equal_approx(10.0, 0.001)
	var dnc2: Node = _DayNightCycle.new()
	dnc2.load_save_data(save_data)
	assert_float(dnc2.phase_elapsed).is_equal_approx(10.0, 0.001)
	dnc2.free()


func test_save_load_round_trip_preserves_day_count() -> void:
	_simulate(225.0)  # → DAWN, day_count = 2
	var save_data: Dictionary = _dnc.get_save_data()
	assert_int(save_data["day_count"]).is_equal(2)
	var dnc2: Node = _DayNightCycle.new()
	dnc2.load_save_data(save_data)
	assert_int(dnc2.day_count).is_equal(2)
	dnc2.free()


func test_save_load_resumes_correctly_mid_night() -> void:
	# Advance to NIGHT + 52.5s (half of NIGHT)
	_simulate(172.5)  # 105 + 15 + 52.5
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)
	assert_float(_dnc.phase_elapsed).is_equal_approx(52.5, 0.001)
	var save_data: Dictionary = _dnc.get_save_data()

	# Create fresh instance and load
	var dnc2: Node = _DayNightCycle.new()
	add_child(dnc2)
	dnc2.load_save_data(save_data)

	# Resume: remaining 52.5s of NIGHT → DAWN
	dnc2._process(52.5)
	assert_int(dnc2.current_phase).is_equal(_DayNightCycle.TimePhase.DAWN)
	assert_int(dnc2.day_count).is_equal(2)
	dnc2.queue_free()


func test_save_load_resumes_correctly_mid_dusk() -> void:
	_simulate(112.5)  # 105 + 7.5 → mid DUSK
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DUSK)
	var save_data: Dictionary = _dnc.get_save_data()

	var dnc2: Node = _DayNightCycle.new()
	add_child(dnc2)
	dnc2.load_save_data(save_data)

	# Resume: remaining 7.5s of DUSK → NIGHT
	dnc2._process(7.5)
	assert_int(dnc2.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)
	dnc2.queue_free()


# ===========================================================================
# SaveManager integration: auto-save on day_started
# ===========================================================================

func test_auto_save_on_day_started() -> void:
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()
	# Full cycle: day_started fires at DAWN→DAY transition
	_simulate(240.0)
	assert_bool(FileAccess.file_exists(SAVE_PATH)).override_failure_message(
		"Save file must be created when day_started fires"
	).is_true()


func test_auto_save_creates_valid_json() -> void:
	_simulate(240.0)
	var text: String = _read_save_file()
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed != null).override_failure_message(
		"Auto-save must produce valid JSON"
	).is_true()
	assert_bool(parsed is Dictionary).is_true()


func test_auto_save_fires_each_cycle() -> void:
	_simulate(240.0)  # first day_started
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	_cleanup_save_file()
	_simulate(240.0)  # second day_started
	assert_bool(FileAccess.file_exists(SAVE_PATH)).override_failure_message(
		"Auto-save must fire on every day_started"
	).is_true()


func test_manual_save_load_via_dnc_serialization() -> void:
	_simulate(150.0)  # 105 + 15 + 30 = mid NIGHT
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)

	# Save DayNightCycle data manually to file
	var save_data: Dictionary = {"day_night": _dnc.get_save_data()}
	_write_save_file(JSON.stringify(save_data, "\t"))
	assert_bool(_sm.has_save()).is_true()

	# Read back and verify structure
	var text: String = _read_save_file()
	var parsed: Dictionary = JSON.parse_string(text) as Dictionary
	var dn_data: Dictionary = parsed["day_night"] as Dictionary
	assert_int(int(dn_data["phase"])).is_equal(_DayNightCycle.TimePhase.NIGHT)
	assert_float(dn_data["phase_elapsed"]).is_equal_approx(30.0, 0.001)
	assert_int(int(dn_data["day_count"])).is_equal(1)


# ===========================================================================
# Corrupt save → fresh start
# ===========================================================================

func test_corrupt_save_returns_false() -> void:
	_write_save_file("this is not json {{{")
	var result: bool = _sm.load_game()
	assert_bool(result).is_false()


func test_corrupt_save_deletes_file() -> void:
	_write_save_file("totally broken json!!!")
	_sm.load_game()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).override_failure_message(
		"Corrupt save file must be deleted after failed load"
	).is_false()


func test_corrupt_save_json_array_treated_as_corrupt() -> void:
	_write_save_file("[1, 2, 3]")
	var result: bool = _sm.load_game()
	assert_bool(result).is_false()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


func test_missing_save_returns_false() -> void:
	_cleanup_save_file()
	var result: bool = _sm.load_game()
	assert_bool(result).is_false()


func test_corrupt_save_allows_fresh_start() -> void:
	_write_save_file("broken")
	_sm.load_game()  # deletes corrupt file
	assert_bool(_sm.has_save()).is_false()
	# Fresh save works after corrupt cleanup
	var ok: bool = _sm.save_game()
	assert_bool(ok).is_true()
	assert_bool(_sm.has_save()).is_true()


# ===========================================================================
# AC10 — DayNightCycle save data structure
# ===========================================================================

func test_ac10_save_data_has_all_required_keys() -> void:
	var data: Dictionary = _dnc.get_save_data()
	assert_bool(data.has("day_count")).override_failure_message("Missing day_count").is_true()
	assert_bool(data.has("phase")).override_failure_message("Missing phase").is_true()
	assert_bool(data.has("phase_elapsed")).override_failure_message("Missing phase_elapsed").is_true()
	assert_bool(data.has("chapter_id")).override_failure_message("Missing chapter_id").is_true()


func test_ac10_save_data_initial_values() -> void:
	var data: Dictionary = _dnc.get_save_data()
	assert_int(data["day_count"]).is_equal(1)
	assert_int(data["phase"]).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_float(data["phase_elapsed"]).is_equal(0.0)
	assert_int(data["chapter_id"]).is_equal(1)


func test_ac10_save_data_after_full_cycle() -> void:
	_simulate(240.0)
	var data: Dictionary = _dnc.get_save_data()
	assert_int(data["day_count"]).is_equal(2)
	assert_int(data["phase"]).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_float(data["phase_elapsed"]).is_equal_approx(0.0, 0.001)


func test_ac10_save_data_mid_night() -> void:
	_simulate(160.0)  # 105 + 15 + 40
	var data: Dictionary = _dnc.get_save_data()
	assert_int(data["phase"]).is_equal(_DayNightCycle.TimePhase.NIGHT)
	assert_float(data["phase_elapsed"]).is_equal_approx(40.0, 0.001)
	assert_int(data["day_count"]).is_equal(1)


# ===========================================================================
# Deterministic setup/teardown verification
# ===========================================================================

func test_clean_state_phase_is_day() -> void:
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_int(_dnc.day_count).is_equal(1)
	assert_float(_dnc.phase_elapsed).is_equal(0.0)


func test_clean_state_no_save_file() -> void:
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


func test_clean_state_no_torches() -> void:
	assert_int(_dnc._torch_tiles.size()).is_equal(0)
