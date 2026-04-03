extends Node

## Autoload singleton — day/night phase timer with signals.
## Tracks current phase, elapsed time, and day count.
## No lighting, no visibility refresh, no torch tracking (task-025).

enum TimePhase { DAY, DUSK, NIGHT, DAWN }

const PHASE_DURATIONS: Dictionary = {
	TimePhase.DAY: 180.0,
	TimePhase.DUSK: 30.0,
	TimePhase.NIGHT: 90.0,
	TimePhase.DAWN: 10.0,
}

const VISIBILITY_RADIUS: Dictionary = {
	TimePhase.DAY: 2,
	TimePhase.DUSK: 2,
	TimePhase.NIGHT: 1,
	TimePhase.DAWN: 2,
}

const TORCH_VISIBILITY_RADIUS: int = 2

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
