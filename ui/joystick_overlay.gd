extends Control
class_name JoystickOverlay

## Floating joystick visual — base circle at touch origin + knob following finger.
## Shown when joystick mode activates; hidden on release.
## player_input.gd drives show_at / update_knob / hide_visual.

signal joystick_started(origin: Vector2)
signal joystick_moved(direction: Vector2, magnitude: float)
signal joystick_released()

@export var max_radius: float = 80.0
@export var base_radius: float = 80.0
@export var knob_radius: float = 30.0

var _origin: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE


## Show joystick base at origin. Emits joystick_started.
func show_at(origin: Vector2) -> void:
	_origin = origin
	_knob_pos = origin
	visible = true
	queue_redraw()
	joystick_started.emit(origin)


## Update knob position to finger_pos (clamped within max_radius). Emits joystick_moved.
func update_knob(finger_pos: Vector2) -> void:
	var delta: Vector2 = finger_pos - _origin
	var clamped: Vector2 = delta.limit_length(max_radius)
	_knob_pos = _origin + clamped
	queue_redraw()
	var dir: Vector2 = delta.normalized() if not delta.is_zero_approx() else Vector2.ZERO
	var mag: float = clampf(delta.length() / max_radius, 0.0, 1.0)
	joystick_moved.emit(dir, mag)


## Hide joystick visual only (no signal). Called by player_input.gd on touch UP.
func hide_visual() -> void:
	visible = false


## Hide joystick and emit joystick_released. Use for standalone activation.
func hide_overlay() -> void:
	visible = false
	joystick_released.emit()


## Returns the configured maximum radius (read by player_input.gd for magnitude calc).
func get_max_radius() -> float:
	return max_radius


func _draw() -> void:
	# Base circle — semi-transparent white ring + fill.
	draw_circle(_origin, base_radius, Color(1.0, 1.0, 1.0, 0.12))
	draw_arc(_origin, base_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55), 3.0)
	# Knob — solid circle.
	draw_circle(_knob_pos, knob_radius, Color(1.0, 1.0, 1.0, 0.65))
