extends GdUnitTestSuite
class_name TestDayNightCycle

const _DayNightCycle = preload("res://scripts/day_night/day_night_cycle.gd")

var _dnc: _DayNightCycle


func before_test() -> void:
	_dnc = _DayNightCycle.new()
	add_child(_dnc)


func after_test() -> void:
	_dnc.queue_free()
	_dnc = null


# --- Initial state ---

func test_initial_phase_is_day() -> void:
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)


func test_initial_phase_elapsed_is_zero() -> void:
	assert_float(_dnc.phase_elapsed).is_equal(0.0)


func test_initial_day_count_is_one() -> void:
	assert_int(_dnc.day_count).is_equal(1)


func test_initial_is_daytime_true() -> void:
	assert_bool(_dnc.is_daytime).is_true()


# --- Phase constants ---

func test_phase_durations_day() -> void:
	assert_float(_DayNightCycle.PHASE_DURATIONS[_DayNightCycle.TimePhase.DAY]).is_equal(105.0)


func test_phase_durations_dusk() -> void:
	assert_float(_DayNightCycle.PHASE_DURATIONS[_DayNightCycle.TimePhase.DUSK]).is_equal(15.0)


func test_phase_durations_night() -> void:
	assert_float(_DayNightCycle.PHASE_DURATIONS[_DayNightCycle.TimePhase.NIGHT]).is_equal(105.0)


func test_phase_durations_dawn() -> void:
	assert_float(_DayNightCycle.PHASE_DURATIONS[_DayNightCycle.TimePhase.DAWN]).is_equal(15.0)


func test_full_cycle_total_duration() -> void:
	var total: float = 0.0
	for dur in _DayNightCycle.PHASE_DURATIONS.values():
		total += dur
	assert_float(total).is_equal(240.0)


func test_visibility_radius_day() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DAY]).is_equal(2)


func test_visibility_radius_dusk() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DUSK]).is_equal(2)


func test_visibility_radius_night() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.NIGHT]).is_equal(1)


func test_visibility_radius_dawn() -> void:
	assert_int(_DayNightCycle.VISIBILITY_RADIUS[_DayNightCycle.TimePhase.DAWN]).is_equal(2)


func test_torch_visibility_radius() -> void:
	assert_int(_DayNightCycle.TORCH_VISIBILITY_RADIUS).is_equal(2)


# --- Phase transition: DAY → DUSK ---

func _simulate_delta(dnc: _DayNightCycle, delta: float) -> void:
	dnc._process(delta)


func test_day_to_dusk_transition() -> void:
	_simulate_delta(_dnc, 105.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DUSK)


func test_day_to_dusk_is_daytime_false() -> void:
	_simulate_delta(_dnc, 105.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_day_to_dusk_emits_dusk_signal() -> void:
	var fired: Array = []
	_dnc.dusk.connect(func() -> void: fired.append(true))
	_simulate_delta(_dnc, 105.0)
	assert_int(fired.size()).is_equal(1)


func test_day_to_dusk_emits_phase_changed() -> void:
	var events: Array = []
	_dnc.phase_changed.connect(func(old: _DayNightCycle.TimePhase, new: _DayNightCycle.TimePhase) -> void:
		events.append({"old": old, "new": new})
	)
	_simulate_delta(_dnc, 105.0)
	assert_int(events.size()).is_equal(1)
	assert_int(events[0]["old"]).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_int(events[0]["new"]).is_equal(_DayNightCycle.TimePhase.DUSK)


func test_day_to_dusk_day_count_unchanged() -> void:
	_simulate_delta(_dnc, 105.0)
	assert_int(_dnc.day_count).is_equal(1)


# --- Phase transition: DUSK → NIGHT ---

func test_dusk_to_night_transition() -> void:
	_simulate_delta(_dnc, 105.0)  # → DUSK
	_simulate_delta(_dnc, 15.0)   # → NIGHT
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.NIGHT)


func test_dusk_to_night_is_daytime_still_false() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_dusk_to_night_emits_night_signal() -> void:
	var fired: Array = []
	_dnc.night.connect(func() -> void: fired.append(true))
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_int(fired.size()).is_equal(1)


func test_dusk_to_night_day_count_unchanged() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_int(_dnc.day_count).is_equal(1)


# --- Phase transition: NIGHT → DAWN ---

func test_night_to_dawn_transition() -> void:
	_simulate_delta(_dnc, 105.0)  # → DUSK
	_simulate_delta(_dnc, 15.0)   # → NIGHT
	_simulate_delta(_dnc, 105.0)  # → DAWN
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAWN)


func test_night_to_dawn_is_daytime_true() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	assert_bool(_dnc.is_daytime).is_true()


func test_night_to_dawn_increments_day_count() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	assert_int(_dnc.day_count).is_equal(2)


func test_night_to_dawn_emits_dawn_signal() -> void:
	var fired: Array = []
	_dnc.dawn.connect(func() -> void: fired.append(true))
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	assert_int(fired.size()).is_equal(1)


# --- Phase transition: DAWN → DAY ---

func test_dawn_to_day_transition() -> void:
	_simulate_delta(_dnc, 105.0)  # → DUSK
	_simulate_delta(_dnc, 15.0)   # → NIGHT
	_simulate_delta(_dnc, 105.0)  # → DAWN
	_simulate_delta(_dnc, 15.0)   # → DAY
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)


func test_dawn_to_day_is_daytime_true() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_bool(_dnc.is_daytime).is_true()


func test_dawn_to_day_emits_day_started() -> void:
	var fired: Array = []
	_dnc.day_started.connect(func() -> void: fired.append(true))
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_int(fired.size()).is_equal(1)


func test_dawn_to_day_day_count_stays_at_two() -> void:
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	_simulate_delta(_dnc, 105.0)
	_simulate_delta(_dnc, 15.0)
	assert_int(_dnc.day_count).is_equal(2)


# --- Full cycle ---

func test_full_cycle_returns_to_day() -> void:
	_simulate_delta(_dnc, 240.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)


func test_full_cycle_day_count_increments_once() -> void:
	_simulate_delta(_dnc, 240.0)
	assert_int(_dnc.day_count).is_equal(2)


func test_two_full_cycles_day_count_is_three() -> void:
	_simulate_delta(_dnc, 240.0)
	_simulate_delta(_dnc, 240.0)
	assert_int(_dnc.day_count).is_equal(3)


func test_full_cycle_emits_all_signals() -> void:
	var dusk_fired: Array = []
	var night_fired: Array = []
	var dawn_fired: Array = []
	var day_started_fired: Array = []
	_dnc.dusk.connect(func() -> void: dusk_fired.append(true))
	_dnc.night.connect(func() -> void: night_fired.append(true))
	_dnc.dawn.connect(func() -> void: dawn_fired.append(true))
	_dnc.day_started.connect(func() -> void: day_started_fired.append(true))
	_simulate_delta(_dnc, 240.0)
	assert_int(dusk_fired.size()).is_equal(1)
	assert_int(night_fired.size()).is_equal(1)
	assert_int(dawn_fired.size()).is_equal(1)
	assert_int(day_started_fired.size()).is_equal(1)


func test_full_cycle_phase_changed_emits_four_times() -> void:
	var events: Array = []
	_dnc.phase_changed.connect(func(old: _DayNightCycle.TimePhase, new: _DayNightCycle.TimePhase) -> void:
		events.append({"old": old, "new": new})
	)
	_simulate_delta(_dnc, 240.0)
	assert_int(events.size()).is_equal(4)


# --- Partial delta accumulation ---

func test_phase_elapsed_accumulates() -> void:
	_simulate_delta(_dnc, 50.0)
	assert_float(_dnc.phase_elapsed).is_equal(50.0)


func test_phase_elapsed_resets_on_transition() -> void:
	_simulate_delta(_dnc, 105.0)
	assert_float(_dnc.phase_elapsed).is_equal(0.0)


func test_phase_elapsed_carries_over_remainder() -> void:
	_simulate_delta(_dnc, 110.0)  # 105 → DUSK, 5.0 overflow
	assert_float(_dnc.phase_elapsed).is_equal(5.0)


# --- is_daytime per phase ---

func test_is_daytime_true_during_day() -> void:
	assert_bool(_dnc.is_daytime).is_true()


func test_is_daytime_false_during_dusk() -> void:
	_simulate_delta(_dnc, 105.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_is_daytime_false_during_night() -> void:
	_simulate_delta(_dnc, 120.0)
	assert_bool(_dnc.is_daytime).is_false()


func test_is_daytime_true_during_dawn() -> void:
	_simulate_delta(_dnc, 225.0)
	assert_bool(_dnc.is_daytime).is_true()


# --- Save / load round-trip ---

func test_save_data_has_required_keys() -> void:
	var data: Dictionary = _dnc.get_save_data()
	assert_bool(data.has("day_count")).is_true()
	assert_bool(data.has("phase")).is_true()
	assert_bool(data.has("phase_elapsed")).is_true()
	assert_bool(data.has("chapter_id")).is_true()


func test_save_load_round_trip_day_count() -> void:
	_simulate_delta(_dnc, 225.0)  # → DAWN, day_count=2
	var data: Dictionary = _dnc.get_save_data()
	var dnc2: _DayNightCycle = _DayNightCycle.new()
	dnc2.load_save_data(data)
	assert_int(dnc2.day_count).is_equal(2)
	dnc2.free()


func test_save_load_round_trip_phase() -> void:
	_simulate_delta(_dnc, 105.0)  # → DUSK
	var data: Dictionary = _dnc.get_save_data()
	var dnc2: _DayNightCycle = _DayNightCycle.new()
	dnc2.load_save_data(data)
	assert_int(dnc2.current_phase).is_equal(_DayNightCycle.TimePhase.DUSK)
	dnc2.free()


func test_save_load_round_trip_phase_elapsed() -> void:
	_simulate_delta(_dnc, 115.0)  # → DUSK + 10s elapsed
	var data: Dictionary = _dnc.get_save_data()
	var dnc2: _DayNightCycle = _DayNightCycle.new()
	dnc2.load_save_data(data)
	assert_float(dnc2.phase_elapsed).is_equal_approx(10.0, 0.001)
	dnc2.free()


func test_save_load_round_trip_is_daytime_dusk() -> void:
	_simulate_delta(_dnc, 105.0)  # → DUSK (not daytime)
	var data: Dictionary = _dnc.get_save_data()
	var dnc2: _DayNightCycle = _DayNightCycle.new()
	dnc2.load_save_data(data)
	assert_bool(dnc2.is_daytime).is_false()
	dnc2.free()


func test_save_load_round_trip_is_daytime_dawn() -> void:
	_simulate_delta(_dnc, 225.0)  # → DAWN (daytime)
	var data: Dictionary = _dnc.get_save_data()
	var dnc2: _DayNightCycle = _DayNightCycle.new()
	dnc2.load_save_data(data)
	assert_bool(dnc2.is_daytime).is_true()
	dnc2.free()


func test_save_data_initial_values() -> void:
	var data: Dictionary = _dnc.get_save_data()
	assert_int(data["day_count"]).is_equal(1)
	assert_int(data["phase"]).is_equal(_DayNightCycle.TimePhase.DAY)
	assert_float(data["phase_elapsed"]).is_equal(0.0)
	assert_int(data["chapter_id"]).is_equal(1)
