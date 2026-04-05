extends Node

## Autoload singleton — day/night phase timer with signals, lighting, and visibility management.
## task-024: phase timer + signals
## task-025: lighting tweens, centralized refresh_visibility, torch tracking

enum TimePhase { DAY, DUSK, NIGHT, DAWN }

const PHASE_DURATIONS: Dictionary = {
	TimePhase.DAY: 105.0,
	TimePhase.DUSK: 15.0,
	TimePhase.NIGHT: 105.0,
	TimePhase.DAWN: 15.0,
}

const VISIBILITY_RADIUS: Dictionary = {
	TimePhase.DAY: 2,
	TimePhase.DUSK: 2,
	TimePhase.NIGHT: 1,
	TimePhase.DAWN: 2,
}

const TORCH_VISIBILITY_RADIUS: int = 2

## Warm palette lighting per phase.
## ambient_color/energy control sky fill; sun_color/energy control the directional key light.
const LIGHTING_PARAMS: Dictionary = {
	TimePhase.DAY: {
		"ambient_color": Color(0.9, 0.85, 0.75),
		"ambient_energy": 0.3,
		"sun_color": Color(1.0, 0.95, 0.8),
		"sun_energy": 1.2,
	},
	TimePhase.DUSK: {
		"ambient_color": Color(0.85, 0.45, 0.15),
		"ambient_energy": 0.2,
		"sun_color": Color(1.0, 0.6, 0.3),
		"sun_energy": 0.6,
	},
	TimePhase.NIGHT: {
		"ambient_color": Color(0.25, 0.18, 0.40),
		"ambient_energy": 0.08,
		"sun_color": Color(0.2, 0.15, 0.35),
		"sun_energy": 0.05,
	},
	TimePhase.DAWN: {
		"ambient_color": Color(0.95, 0.65, 0.5),
		"ambient_energy": 0.2,
		"sun_color": Color(1.0, 0.7, 0.55),
		"sun_energy": 0.5,
	},
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
var _lighting_tween: Tween = null

# --- Visibility ---
var _player_tile: Vector2i = Vector2i.ZERO
var _torch_tiles: Array[Vector2i] = []


func _ready() -> void:
	HexGrid.tile_entered.connect(_on_tile_entered)
	HexGrid.structure_placed.connect(_on_structure_placed)
	HexGrid.structure_destroyed.connect(_on_structure_destroyed)


func _process(delta: float) -> void:
	phase_elapsed += delta
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
	_refresh_visibility()


# --- Lighting API ---

## Register WorldEnvironment and DirectionalLight3D for lighting transitions.
## Safe to call with nulls (headless/test environments).
func register_lighting(env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	_apply_lighting_immediate()


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


func _start_lighting_tween() -> void:
	if _env == null or _sun == null:
		return
	if _env.environment == null:
		return
	if _lighting_tween != null and _lighting_tween.is_valid():
		_lighting_tween.kill()
	var params: Dictionary = LIGHTING_PARAMS[current_phase]
	var duration: float = minf(PHASE_DURATIONS[current_phase], 5.0)
	_lighting_tween = create_tween()
	_lighting_tween.set_parallel(true)
	_lighting_tween.tween_property(_env.environment, "ambient_light_color", params["ambient_color"], duration)
	_lighting_tween.tween_property(_env.environment, "ambient_light_energy", params["ambient_energy"], duration)
	_lighting_tween.tween_property(_sun, "light_color", params["sun_color"], duration)
	_lighting_tween.tween_property(_sun, "light_energy", params["sun_energy"], duration)


# --- Visibility management ---

func _on_tile_entered(coords: Vector2i) -> void:
	_player_tile = coords
	_refresh_visibility()


func _on_structure_placed(coords: Vector2i, structure_type: StringName) -> void:
	if structure_type != &"torch":
		return
	if not _torch_tiles.has(coords):
		_torch_tiles.append(coords)
	if current_phase == TimePhase.NIGHT:
		_refresh_visibility()


func _on_structure_destroyed(coords: Vector2i, structure_type: StringName) -> void:
	if structure_type != &"torch":
		return
	_torch_tiles.erase(coords)
	if current_phase == TimePhase.NIGHT:
		_refresh_visibility()


func _refresh_visibility() -> void:
	var radius: int = VISIBILITY_RADIUS[current_phase]
	var sources: Array[Dictionary] = [{"coords": _player_tile, "radius": radius}]
	if current_phase == TimePhase.NIGHT:
		for torch_coords: Vector2i in _torch_tiles:
			sources.append({"coords": torch_coords, "radius": TORCH_VISIBILITY_RADIUS})
	HexGrid.refresh_visibility(sources)


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
	_refresh_visibility()


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
		current_phase = int(data["phase"]) as TimePhase
		is_daytime = current_phase == TimePhase.DAY or current_phase == TimePhase.DAWN
	if data.has("phase_elapsed"):
		phase_elapsed = float(data["phase_elapsed"])
