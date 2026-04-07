extends Camera3D

## Third-person orbital camera — spherical follow with auto-rotation,
## manual orbit (right-side drag), pinch zoom, occlusion raycast, and
## map AABB clamping.  Sibling of Player (not child) to avoid jitter.

# ── Exports ──────────────────────────────────────────────────────────
@export var distance: float = 7.0
@export var distance_min: float = 5.0
@export var distance_max: float = 12.0
@export var pitch_deg: float = 40.0
@export var pitch_min: float = 20.0
@export var pitch_max: float = 70.0
@export var orbit_sensitivity: float = 0.3
@export var zoom_sensitivity: float = 0.01
@export var auto_follow_delay: float = 2.0
@export var auto_follow_speed: float = 2.0
@export var camera_fov: float = 60.0
@export var follow_speed: float = 8.0

# ── Internal state ───────────────────────────────────────────────────
var _yaw: float = 0.0
var _pitch_deg_current: float = 0.0
var _idle_timer: float = 0.0
var _is_orbiting: bool = false
var _orbit_touch_index: int = -1
var _orbit_last_pos: Vector2 = Vector2.ZERO
var _pinch_touch_indices: Array[int] = []
var _pinch_positions: Dictionary = {}   # int -> Vector2
var _pinch_distance: float = 0.0
var _target: Node3D = null
var _map_bounds: Rect2 = Rect2()
var _has_bounds: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────

func _ready() -> void:
	_target = get_parent().get_node_or_null("Player")
	fov = camera_fov
	_pitch_deg_current = pitch_deg
	if _target and _target.facing_direction != Vector2.ZERO:
		var fd: Vector2 = _target.facing_direction
		_yaw = atan2(-fd.x, -fd.y)
	HexGrid.map_generated.connect(_compute_bounds)


func _process(delta: float) -> void:
	if _target == null:
		return

	_update_auto_follow(delta)

	var look_target: Vector3 = _target.position + Vector3(0.0, 0.5, 0.0)
	var offset: Vector3 = _compute_offset()
	var desired: Vector3 = _target.position + offset

	# Occlusion raycast — snap closer when terrain blocks view.
	desired = _apply_occlusion(look_target, desired)

	# Map bounds clamping.
	if _has_bounds:
		desired.x = clampf(desired.x, _map_bounds.position.x, _map_bounds.end.x)
		desired.z = clampf(desired.z, _map_bounds.position.y, _map_bounds.end.y)

	position = position.lerp(desired, follow_speed * delta)
	look_at(look_target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

# ── Orbit input ──────────────────────────────────────────────────────

func _handle_touch(event: InputEventScreenTouch) -> void:
	var idx: int = event.index
	if event.pressed:
		_pinch_positions[idx] = event.position
		# Start orbit only if in the right 40 % of the screen.
		if _orbit_touch_index == -1 and _is_right_zone(event.position):
			_orbit_touch_index = idx
			_orbit_last_pos = event.position
			_is_orbiting = true
		# Track fingers for pinch (need exactly two).
		if _pinch_touch_indices.size() < 2:
			_pinch_touch_indices.append(idx)
			if _pinch_touch_indices.size() == 2:
				_pinch_distance = _current_pinch_spread()
	else:
		_pinch_positions.erase(idx)
		if idx == _orbit_touch_index:
			_orbit_touch_index = -1
			_is_orbiting = false
		_pinch_touch_indices.erase(idx)


func _handle_drag(event: InputEventScreenDrag) -> void:
	var idx: int = event.index
	_pinch_positions[idx] = event.position

	# Orbit drag — event.relative is per-frame pixel displacement.
	# Yaw is radians, pitch is degrees — different scale factors needed.
	if idx == _orbit_touch_index:
		_yaw += event.relative.x * orbit_sensitivity * 0.02
		_pitch_deg_current -= event.relative.y * orbit_sensitivity * 0.5
		_pitch_deg_current = clampf(_pitch_deg_current, pitch_min, pitch_max)
		_idle_timer = 0.0
		_orbit_last_pos = event.position

	# Pinch zoom.
	if _pinch_touch_indices.size() == 2 and idx in _pinch_touch_indices:
		var spread: float = _current_pinch_spread()
		if _pinch_distance > 0.0:
			var diff: float = spread - _pinch_distance
			distance -= diff * zoom_sensitivity
			distance = clampf(distance, distance_min, distance_max)
		_pinch_distance = spread

# ── Auto-follow ──────────────────────────────────────────────────────

func _update_auto_follow(delta: float) -> void:
	if _is_orbiting:
		_idle_timer = 0.0
		return
	_idle_timer += delta
	if _idle_timer < auto_follow_delay:
		return
	if _target.facing_direction == Vector2.ZERO:
		return
	var fd: Vector2 = _target.facing_direction
	var target_yaw: float = atan2(-fd.x, -fd.y)
	_yaw = lerp_angle(_yaw, target_yaw, auto_follow_speed * delta)

# ── Spherical offset ─────────────────────────────────────────────────

func _compute_offset() -> Vector3:
	var pitch_rad: float = deg_to_rad(_pitch_deg_current)
	var x: float = distance * sin(_yaw) * cos(pitch_rad)
	var y: float = distance * sin(pitch_rad)
	var z: float = distance * cos(_yaw) * cos(pitch_rad)
	return Vector3(x, y, z)

# ── Occlusion ────────────────────────────────────────────────────────

func _apply_occlusion(from: Vector3, to: Vector3) -> Vector3:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return to
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # terrain layer
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return to
	# Pull camera just in front of the hit point.
	return result.position + (from - to).normalized() * 0.3

# ── Map bounds ───────────────────────────────────────────────────────

func _compute_bounds() -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	for coords: Vector2i in HexGrid._tiles:
		var world_2d: Vector2 = HexGrid.axial_to_world(coords)
		min_x = minf(min_x, world_2d.x)
		max_x = maxf(max_x, world_2d.x)
		min_z = minf(min_z, world_2d.y)
		max_z = maxf(max_z, world_2d.y)

	var padding: float = 9.0
	_map_bounds = Rect2(
		min_x - padding,
		min_z - padding,
		(max_x - min_x) + padding * 2.0,
		(max_z - min_z) + padding * 2.0,
	)
	_has_bounds = true

# ── Helpers ──────────────────────────────────────────────────────────

func _is_right_zone(pos: Vector2) -> bool:
	return pos.x > get_viewport().get_visible_rect().size.x * 0.6


func _current_pinch_spread() -> float:
	if _pinch_touch_indices.size() < 2:
		return 0.0
	var a: int = _pinch_touch_indices[0]
	var b: int = _pinch_touch_indices[1]
	if not _pinch_positions.has(a) or not _pinch_positions.has(b):
		return 0.0
	return (_pinch_positions[a] as Vector2).distance_to(_pinch_positions[b] as Vector2)

# ── Public API ───────────────────────────────────────────────────────

func set_follow_target(target: Node3D) -> void:
	_target = target


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch_deg_current


# --- Serialization ---

func get_save_data() -> Dictionary:
	return {
		"yaw": _yaw,
		"pitch": _pitch_deg_current,
		"distance": distance,
	}


func load_save_data(data: Dictionary) -> void:
	_yaw = float(data.get("yaw", 0.0))
	_pitch_deg_current = float(data.get("pitch", pitch_deg))
	distance = clampf(float(data.get("distance", 7.0)), distance_min, distance_max)
