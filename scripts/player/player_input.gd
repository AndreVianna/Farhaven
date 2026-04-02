extends Node
class_name PlayerInput

## Two-outcome touch classifier. Child Node of Player.
## Uses _unhandled_input so HUD elements (mouse_filter=STOP) consume first.
##
## Outcomes:
##   TAP        — touch DOWN+UP in <tap_max_duration AND drag <tap_max_drag
##   JOYSTICK   — drag ≥drag_threshold at ANY time

const _HexTile = preload("res://scripts/hex/hex_tile.gd")

# --- Signals ---
signal tap_tile(coords: Vector2i)
signal joystick_started(direction: Vector2)
signal joystick_moved(direction: Vector2, magnitude: float)
signal joystick_released()

# --- Exported thresholds (tunable) ---
@export var tap_max_duration: float = 0.3
@export var tap_max_drag: float = 20.0
@export var drag_threshold: float = 20.0

# --- Internal state ---
enum _State { IDLE, TRACKING, JOYSTICK }

var _state: _State = _State.IDLE
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_current: Vector2 = Vector2.ZERO
var _touch_duration: float = 0.0

# --- Dependencies (injected in _ready; may be replaced in tests) ---
var _camera: Camera3D
var _grid: Node  # HexGrid autoload
var _joystick_overlay: Node  # JoystickOverlay visual node


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	# Camera3D is a sibling of Player in the World node.
	if _camera == null:
		var world: Node = get_parent().get_parent()
		if world != null:
			_camera = world.get_node_or_null("Camera3D") as Camera3D
	# JoystickOverlay visual is the first child of the JoystickOverlay CanvasLayer.
	var joystick_layer: Node = get_tree().root.get_node_or_null("Main/JoystickOverlay")
	if joystick_layer != null and joystick_layer.get_child_count() > 0:
		_joystick_overlay = joystick_layer.get_child(0)


# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_down(event.position)
		else:
			_on_touch_up()
	elif event is InputEventScreenDrag:
		_on_drag(event.position)


func _process(delta: float) -> void:
	match _state:
		_State.TRACKING:
			_touch_duration += delta
			# If held long enough without dragging, start joystick
			if _touch_duration >= tap_max_duration:
				_enter_joystick()
		_State.JOYSTICK:
			_emit_joystick_moved()


# --- Touch event handlers ---

func _on_touch_down(pos: Vector2) -> void:
	_state = _State.TRACKING
	_touch_origin = pos
	_touch_current = pos
	_touch_duration = 0.0


func _on_touch_up() -> void:
	match _state:
		_State.TRACKING:
			var duration_ok: bool = _touch_duration < tap_max_duration
			var drag_ok: bool = (_touch_current - _touch_origin).length() < tap_max_drag
			if duration_ok and drag_ok:
				_emit_tap()
		_State.JOYSTICK:
			joystick_released.emit()
			if _joystick_overlay != null and _joystick_overlay.has_method("hide_visual"):
				_joystick_overlay.hide_visual()
	_state = _State.IDLE


func _on_drag(pos: Vector2) -> void:
	_touch_current = pos
	if _state == _State.TRACKING:
		var drag_dist: float = (_touch_current - _touch_origin).length()
		if drag_dist >= drag_threshold:
			_enter_joystick()


# --- State transitions ---

func _enter_joystick() -> void:
	_state = _State.JOYSTICK
	var drag_vec: Vector2 = _touch_current - _touch_origin
	if _joystick_overlay != null and _joystick_overlay.has_method("show_at"):
		_joystick_overlay.show_at(_touch_origin)
	# Only emit joystick_started if there's actual drag — avoid WALKING with zero direction
	if not drag_vec.is_zero_approx():
		var dir: Vector2 = drag_vec.normalized()
		joystick_started.emit(dir)
	_emit_joystick_moved()


func _emit_joystick_moved() -> void:
	var drag_vec: Vector2 = _touch_current - _touch_origin
	var max_radius: float = 80.0
	if _joystick_overlay != null and _joystick_overlay.has_method("get_max_radius"):
		max_radius = _joystick_overlay.get_max_radius()
	var dir: Vector2 = drag_vec.normalized() if not drag_vec.is_zero_approx() else Vector2.ZERO
	var mag: float = clampf(drag_vec.length() / max_radius, 0.0, 1.0)
	joystick_moved.emit(dir, mag)
	if _joystick_overlay != null and _joystick_overlay.has_method("update_knob"):
		_joystick_overlay.update_knob(_touch_current)


# --- Helpers ---

func _emit_tap() -> void:
	var coords: Vector2i = _screen_to_axial(_touch_current)
	if _grid == null:
		return
	var tile: Resource = _grid.get_tile(coords)
	if tile == null:
		return
	# Only tap on REVEALED or VISIBLE tiles.
	if tile.fog_state == _HexTile.FogState.HIDDEN:
		return
	tap_tile.emit(coords)


## Convert a screen position to axial hex coordinates via Camera3D ray + ground plane.
func _screen_to_axial(screen_pos: Vector2) -> Vector2i:
	if _camera == null:
		return Vector2i.ZERO
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)
	# Intersect the ground plane (y = 0).
	if abs(ray_dir.y) < 0.0001:
		return Vector2i.ZERO
	var t: float = -ray_origin.y / ray_dir.y
	var world_3d: Vector3 = ray_origin + ray_dir * t
	return _grid.world_to_axial(Vector2(world_3d.x, world_3d.z))
