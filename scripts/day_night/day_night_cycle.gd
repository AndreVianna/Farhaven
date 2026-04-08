extends Node

## Autoload singleton — day/night phase timer with signals and lighting tweens.
## task-024: phase timer + signals
## task-025: lighting tweens

enum TimePhase { DAY, DUSK, NIGHT, DAWN }

const PHASE_DURATIONS: Dictionary = {
	TimePhase.DAY: 105.0,
	TimePhase.DUSK: 15.0,
	TimePhase.NIGHT: 105.0,
	TimePhase.DAWN: 15.0,
}

## Warm palette lighting per phase.
## ambient_color/energy control sky fill; sun_color/energy control the directional key light.
const LIGHTING_PARAMS: Dictionary = {
	TimePhase.DAY: {
		"ambient_color": Color(0.9, 0.85, 0.75),
		"ambient_energy": 0.4,
		"sun_color": Color(1.0, 0.95, 0.8),
		"sun_energy": 1.4,
	},
	TimePhase.DUSK: {
		"ambient_color": Color(0.9, 0.4, 0.1),
		"ambient_energy": 0.15,
		"sun_color": Color(1.0, 0.5, 0.2),
		"sun_energy": 0.4,
	},
	TimePhase.NIGHT: {
		"ambient_color": Color(0.1, 0.08, 0.2),
		"ambient_energy": 0.03,
		"sun_color": Color(0.1, 0.08, 0.2),
		"sun_energy": 0.02,
	},
	TimePhase.DAWN: {
		"ambient_color": Color(0.95, 0.55, 0.35),
		"ambient_energy": 0.2,
		"sun_color": Color(1.0, 0.6, 0.4),
		"sun_energy": 0.5,
	},
}

## Hex shader darkness per phase (0.0 = bright, 1.0 = pitch black).
const DARKNESS_VALUES: Dictionary = {
	TimePhase.DAY: 0.0,
	TimePhase.DUSK: 0.7,
	TimePhase.NIGHT: 0.7,
	TimePhase.DAWN: 0.0,
}

# --- Signals ---
signal phase_changed(old_phase: TimePhase, new_phase: TimePhase)
signal dawn()
signal dusk()
signal night()
signal day_started()

# --- State ---
var current_phase: TimePhase = TimePhase.DAY
var phase_elapsed: float = 0.0
var day_count: int = 1
var is_daytime: bool = true

# --- Lighting ---
var _env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _hex_material: ShaderMaterial = null
var _lighting_tween: Tween = null


func _ready() -> void:
	HexGrid.tile_entered.connect(_on_tile_entered)


const TIME_SCALE: float = 1.0  # Set > 1.0 for timelapse testing (e.g. 20.0)

func _process(delta: float) -> void:
	phase_elapsed += delta * TIME_SCALE
	var duration: float = PHASE_DURATIONS[current_phase]
	while phase_elapsed >= duration:
		phase_elapsed -= duration
		_advance_phase()
		duration = PHASE_DURATIONS[current_phase]


func _advance_phase() -> void:
	var old_phase: TimePhase = current_phase
	match current_phase:
		TimePhase.DAY:
			current_phase = TimePhase.DUSK
			is_daytime = false
			phase_changed.emit(old_phase, current_phase)
			dusk.emit()
		TimePhase.DUSK:
			current_phase = TimePhase.NIGHT
			phase_changed.emit(old_phase, current_phase)
			night.emit()
		TimePhase.NIGHT:
			current_phase = TimePhase.DAWN
			day_count += 1
			is_daytime = true
			phase_changed.emit(old_phase, current_phase)
			dawn.emit()
		TimePhase.DAWN:
			current_phase = TimePhase.DAY
			phase_changed.emit(old_phase, current_phase)
			day_started.emit()
	_start_lighting_tween()


# --- Lighting API ---

## Register WorldEnvironment and DirectionalLight3D for lighting transitions.
## Safe to call with nulls (headless/test environments).
func register_lighting(env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	_apply_lighting_immediate()


## Register the hex grid ShaderMaterial for darkness transitions.
func register_hex_material(mat: ShaderMaterial) -> void:
	_hex_material = mat


func _apply_lighting_immediate() -> void:
	if _env == null or _sun == null:
		return
	if _env.environment == null:
		return
	var params: Dictionary = LIGHTING_PARAMS[current_phase]
	_env.environment.ambient_light_color = params["ambient_color"]
	_env.environment.ambient_light_energy = params["ambient_energy"]
	_sun.light_color = params["sun_color"]
	_sun.light_energy = params["sun_energy"]
	if _hex_material != null:
		_hex_material.set_shader_parameter("darkness", DARKNESS_VALUES[current_phase])


func _start_lighting_tween() -> void:
	if _env == null or _sun == null:
		return
	if _env.environment == null:
		return
	if _lighting_tween != null and _lighting_tween.is_valid():
		_lighting_tween.kill()
	var params: Dictionary = LIGHTING_PARAMS[current_phase]
	var duration: float = minf(PHASE_DURATIONS[current_phase], 5.0) / TIME_SCALE
	_lighting_tween = create_tween()
	_lighting_tween.set_parallel(true)
	_lighting_tween.tween_property(_env.environment, "ambient_light_color", params["ambient_color"], duration)
	_lighting_tween.tween_property(_env.environment, "ambient_light_energy", params["ambient_energy"], duration)
	_lighting_tween.tween_property(_sun, "light_color", params["sun_color"], duration)
	_lighting_tween.tween_property(_sun, "light_energy", params["sun_energy"], duration)
	if _hex_material != null:
		var target_darkness: float = DARKNESS_VALUES[current_phase]
		_lighting_tween.tween_method(_set_hex_darkness, _hex_material.get_shader_parameter("darkness"), target_darkness, duration)


func _set_hex_darkness(value: float) -> void:
	if _hex_material != null:
		_hex_material.set_shader_parameter("darkness", value)


# --- Player tracking (for shader player_world_pos parameter) ---

func _on_tile_entered(coords: Vector2i) -> void:
	if _hex_material != null:
		var world_pos: Vector2 = HexMath.axial_to_world(coords)
		_hex_material.set_shader_parameter("player_world_pos", world_pos)


## Skip directly to dawn phase. Used for night-death respawn.
func skip_to_dawn() -> void:
	var old_phase: TimePhase = current_phase
	current_phase = TimePhase.DAWN
	phase_elapsed = 0.0
	day_count += 1
	is_daytime = true
	phase_changed.emit(old_phase, current_phase)
	dawn.emit()
	_apply_lighting_immediate()
	if _hex_material != null:
		_hex_material.set_shader_parameter("darkness", 0.0)


# --- Helpers ---

static func phase_to_string(phase: TimePhase) -> String:
	match phase:
		TimePhase.DAY:
			return "DAY"
		TimePhase.DUSK:
			return "DUSK"
		TimePhase.NIGHT:
			return "NIGHT"
		TimePhase.DAWN:
			return "DAWN"
	return "DAY"


# --- Serialization ---

func get_save_data() -> Dictionary:
	return {
		"day_count": day_count,
		"phase": current_phase,
		"phase_elapsed": phase_elapsed,
		"chapter_id": 1,
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("day_count"):
		day_count = int(data["day_count"])
	if data.has("phase"):
		var phase_int: int = int(data["phase"])
		if phase_int < 0 or phase_int >= TimePhase.size():
			push_warning("DayNightCycle.load_save_data: invalid phase %d — defaulting to DAY" % phase_int)
			phase_int = TimePhase.DAY
		current_phase = phase_int as TimePhase
		is_daytime = current_phase == TimePhase.DAY or current_phase == TimePhase.DAWN
	if data.has("phase_elapsed"):
		phase_elapsed = maxf(0.0, float(data["phase_elapsed"]))

	# Re-apply lighting so the loaded phase is reflected visually immediately,
	# instead of waiting for the next natural phase transition.
	_apply_lighting_immediate()
