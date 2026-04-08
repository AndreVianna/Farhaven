extends GdUnitTestSuite
class_name TestDayNightLighting

const _DayNightCycle = preload("res://scripts/day_night/day_night_cycle.gd")

var _dnc: _DayNightCycle
var _env: WorldEnvironment
var _sun: DirectionalLight3D


func before_test() -> void:
	_dnc = _DayNightCycle.new()
	add_child(_dnc)
	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	add_child(_env)
	_sun = DirectionalLight3D.new()
	add_child(_sun)


func after_test() -> void:
	_sun.queue_free()
	_env.queue_free()
	_dnc.queue_free()
	_sun = null
	_env = null
	_dnc = null


# --- register_lighting: null-safe ---

func test_register_lighting_null_env_no_crash() -> void:
	_dnc.register_lighting(null, _sun)
	assert_bool(true).is_true()  # just verifying no crash


func test_register_lighting_null_sun_no_crash() -> void:
	_dnc.register_lighting(_env, null)
	assert_bool(true).is_true()


func test_register_lighting_both_null_no_crash() -> void:
	_dnc.register_lighting(null, null)
	assert_bool(true).is_true()


func test_register_lighting_stores_env() -> void:
	_dnc.register_lighting(_env, _sun)
	assert_object(_dnc._env).is_equal(_env)


func test_register_lighting_stores_sun() -> void:
	_dnc.register_lighting(_env, _sun)
	assert_object(_dnc._sun).is_equal(_sun)


# --- Lighting constants: warm palette ---

func test_lighting_params_has_all_phases() -> void:
	assert_bool(_DayNightCycle.LIGHTING_PARAMS.has(_DayNightCycle.TimePhase.DAY)).is_true()
	assert_bool(_DayNightCycle.LIGHTING_PARAMS.has(_DayNightCycle.TimePhase.DUSK)).is_true()
	assert_bool(_DayNightCycle.LIGHTING_PARAMS.has(_DayNightCycle.TimePhase.NIGHT)).is_true()
	assert_bool(_DayNightCycle.LIGHTING_PARAMS.has(_DayNightCycle.TimePhase.DAWN)).is_true()


func test_day_sun_energy_is_brightest() -> void:
	var day_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAY]["sun_energy"]
	var night_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.NIGHT]["sun_energy"]
	assert_float(day_energy).is_greater(night_energy)


func test_night_sun_energy_is_dimmest() -> void:
	var night_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.NIGHT]["sun_energy"]
	var dusk_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DUSK]["sun_energy"]
	var dawn_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAWN]["sun_energy"]
	assert_float(night_energy).is_less(dusk_energy)
	assert_float(night_energy).is_less(dawn_energy)


func test_lighting_applied_immediately_on_register() -> void:
	var day_sun_color: Color = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAY]["sun_color"]
	_dnc.register_lighting(_env, _sun)
	assert_float(_sun.light_color.r).is_equal_approx(day_sun_color.r, 0.001)
	assert_float(_sun.light_color.g).is_equal_approx(day_sun_color.g, 0.001)
	assert_float(_sun.light_color.b).is_equal_approx(day_sun_color.b, 0.001)


func test_lighting_applied_sun_energy_on_register() -> void:
	var day_sun_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAY]["sun_energy"]
	_dnc.register_lighting(_env, _sun)
	assert_float(_sun.light_energy).is_equal_approx(day_sun_energy, 0.001)


func test_lighting_applied_ambient_color_on_register() -> void:
	var day_ambient: Color = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAY]["ambient_color"]
	_dnc.register_lighting(_env, _sun)
	assert_float(_env.environment.ambient_light_color.r).is_equal_approx(day_ambient.r, 0.001)


func test_lighting_applied_ambient_energy_on_register() -> void:
	var day_energy: float = _DayNightCycle.LIGHTING_PARAMS[_DayNightCycle.TimePhase.DAY]["ambient_energy"]
	_dnc.register_lighting(_env, _sun)
	assert_float(_env.environment.ambient_light_energy).is_equal_approx(day_energy, 0.001)


# --- phase_to_string helper ---

func test_phase_to_string_day() -> void:
	assert_str(_DayNightCycle.phase_to_string(_DayNightCycle.TimePhase.DAY)).is_equal("DAY")


func test_phase_to_string_dusk() -> void:
	assert_str(_DayNightCycle.phase_to_string(_DayNightCycle.TimePhase.DUSK)).is_equal("DUSK")


func test_phase_to_string_night() -> void:
	assert_str(_DayNightCycle.phase_to_string(_DayNightCycle.TimePhase.NIGHT)).is_equal("NIGHT")


func test_phase_to_string_dawn() -> void:
	assert_str(_DayNightCycle.phase_to_string(_DayNightCycle.TimePhase.DAWN)).is_equal("DAWN")


# --- No-crash when lighting not registered ---

func test_advance_phase_no_crash_without_lighting() -> void:
	# DayNightCycle advances phases without lighting registered — must not crash
	_dnc._process(105.0)  # DAY → DUSK
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DUSK)


func test_full_cycle_no_crash_without_lighting() -> void:
	_dnc._process(240.0)
	assert_int(_dnc.current_phase).is_equal(_DayNightCycle.TimePhase.DAY)
