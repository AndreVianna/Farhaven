extends Node3D

## Player — continuous joystick movement, derived current_tile, tile transitions.
## Uses Node3D with per-frame position updates (not CharacterBody3D).
## current_tile is derived from HexMath.world_to_axial(position), not set directly.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

enum MoveState { IDLE, WALKING, JUMPING }

signal player_moved(from: Vector2i, to: Vector2i)

@export var move_speed: float = 4.0

## Elevation scale: world Y per elevation level.
const ELEVATION_SCALE: float = 0.3

## Jump arc height above the higher tile.
const JUMP_ARC_HEIGHT: float = 0.5

var current_tile: Vector2i = Vector2i.ZERO
var move_state: MoveState = MoveState.IDLE
var facing_direction: Vector2 = Vector2.ZERO

var _grid: Node  # HexGrid reference (autoload or test substitute)
var _joystick_dir: Vector2 = Vector2.ZERO
var _joystick_magnitude: float = 0.0
var _buffered_dir: Vector2 = Vector2.ZERO
var _buffered_magnitude: float = 0.0
var _jump_tween: Tween
var _snap_tween: Tween


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_grid.map_generated.connect(_on_map_generated)
	_connect_player_input()


func _connect_player_input() -> void:
	var pi: Node = get_node_or_null("PlayerInput")
	if pi == null:
		return
	if pi.has_signal("joystick_started"):
		pi.joystick_started.connect(_on_joystick_start)
	if pi.has_signal("joystick_moved"):
		pi.joystick_moved.connect(_on_joystick_move)
	if pi.has_signal("joystick_released"):
		pi.joystick_released.connect(_on_joystick_stop)


func _on_map_generated() -> void:
	current_tile = Vector2i.ZERO
	move_state = MoveState.IDLE
	_joystick_dir = Vector2.ZERO
	_joystick_magnitude = 0.0
	_snap_to_tile(current_tile)


func _process(delta: float) -> void:
	if move_state == MoveState.WALKING:
		_process_walking(delta)


## Snap the player's world position to the given tile center.
func _snap_to_tile(coords: Vector2i) -> void:
	var world_2d: Vector2 = _grid.axial_to_world(coords)
	var tile = _grid.get_tile(coords)
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * ELEVATION_SCALE
	position = Vector3(world_2d.x, elevation_y, world_2d.y)


# --- Joystick signal handlers ---

func _on_joystick_start(direction: Vector2) -> void:
	_cancel_snap_tween()
	if move_state == MoveState.JUMPING:
		_buffered_dir = direction
		_buffered_magnitude = 1.0
		return
	move_state = MoveState.WALKING
	_joystick_dir = direction
	_joystick_magnitude = 1.0


func _on_joystick_move(direction: Vector2, magnitude: float) -> void:
	if move_state == MoveState.JUMPING:
		_buffered_dir = direction
		_buffered_magnitude = magnitude
		return
	if move_state != MoveState.WALKING:
		_cancel_snap_tween()
		move_state = MoveState.WALKING
	_joystick_dir = direction
	_joystick_magnitude = magnitude


func _on_joystick_stop() -> void:
	_joystick_dir = Vector2.ZERO
	_joystick_magnitude = 0.0
	_buffered_dir = Vector2.ZERO
	_buffered_magnitude = 0.0
	if move_state == MoveState.JUMPING:
		# Will snap to tile center when jump lands
		return
	move_state = MoveState.IDLE
	_tween_snap_to_center()


# --- Continuous movement ---

func _process_walking(delta: float) -> void:
	if _joystick_dir.is_zero_approx() or _joystick_magnitude < 0.01:
		return

	facing_direction = _joystick_dir.normalized()
	var velocity_2d: Vector2 = facing_direction * move_speed * _joystick_magnitude
	var movement := Vector3(velocity_2d.x, 0.0, velocity_2d.y) * delta

	var new_pos: Vector3 = position + movement
	var new_pos_2d := Vector2(new_pos.x, new_pos.z)
	var candidate_tile: Vector2i = _HexMath.world_to_axial(new_pos_2d)

	if candidate_tile != current_tile:
		var traversal: int = _grid.get_traversal(current_tile, candidate_tile)
		match traversal:
			_grid.TraversalType.WALK:
				position = new_pos
				var old_walk_tile: Vector2i = current_tile
				_update_elevation_y_interpolated(new_pos_2d, old_walk_tile, candidate_tile)
				_emit_tile_transition(old_walk_tile, candidate_tile)
			_grid.TraversalType.JUMP, _grid.TraversalType.DROP:
				_start_jump(candidate_tile, traversal)
			_grid.TraversalType.BLOCKED:
				_slide_along_boundary(velocity_2d, delta)
	else:
		position = new_pos
		_update_elevation_y_same_tile()


## Interpolate Y position based on distance to source and destination tile centers.
func _update_elevation_y_interpolated(pos_2d: Vector2, from: Vector2i, to: Vector2i) -> void:
	var from_world: Vector2 = _grid.axial_to_world(from)
	var to_world: Vector2 = _grid.axial_to_world(to)
	var from_tile = _grid.get_tile(from)
	var to_tile = _grid.get_tile(to)
	if from_tile == null or to_tile == null:
		return
	var from_y: float = float(from_tile.elevation) * ELEVATION_SCALE
	var to_y: float = float(to_tile.elevation) * ELEVATION_SCALE
	var total_dist: float = from_world.distance_to(to_world)
	if total_dist < 0.001:
		position.y = to_y
		return
	var progress: float = clampf(from_world.distance_to(pos_2d) / total_dist, 0.0, 1.0)
	position.y = lerpf(from_y, to_y, progress)


## Keep Y at current tile elevation.
func _update_elevation_y_same_tile() -> void:
	var tile = _grid.get_tile(current_tile)
	if tile != null:
		position.y = float(tile.elevation) * ELEVATION_SCALE


# --- Jump/Drop ---

func _start_jump(target: Vector2i, traversal_type: int) -> void:
	move_state = MoveState.JUMPING
	_buffered_dir = _joystick_dir
	_buffered_magnitude = _joystick_magnitude

	var target_world_2d: Vector2 = _grid.axial_to_world(target)
	var target_tile = _grid.get_tile(target)
	var target_y: float = 0.0
	if target_tile != null:
		target_y = float(target_tile.elevation) * ELEVATION_SCALE

	var target_pos := Vector3(target_world_2d.x, target_y, target_world_2d.y)
	var higher_y: float = maxf(position.y, target_y)
	var arc_peak: float = higher_y + JUMP_ARC_HEIGHT

	var is_jump_up: bool = traversal_type == _grid.TraversalType.JUMP
	var duration: float = 0.3 if is_jump_up else 0.2

	_cancel_jump_tween()
	_jump_tween = create_tween()
	_jump_tween.set_ease(Tween.EASE_IN_OUT)
	_jump_tween.set_trans(Tween.TRANS_QUAD)

	# XZ movement: linear to target
	_jump_tween.tween_property(self, "position:x", target_pos.x, duration)
	_jump_tween.parallel().tween_property(self, "position:z", target_pos.z, duration)

	# Y arc: up then down
	var half: float = duration * 0.5
	_jump_tween.parallel().tween_property(self, "position:y", arc_peak, half)
	_jump_tween.tween_property(self, "position:y", target_y, half)

	var old_tile: Vector2i = current_tile
	_jump_tween.finished.connect(func() -> void:
		_jump_tween = null
		_emit_tile_transition(old_tile, target)
		_snap_to_tile(current_tile)
		_on_jump_landed()
	)


func _on_jump_landed() -> void:
	if _joystick_magnitude > 0.01 and not _buffered_dir.is_zero_approx():
		move_state = MoveState.WALKING
		_joystick_dir = _buffered_dir
		_joystick_magnitude = _buffered_magnitude
	else:
		move_state = MoveState.IDLE
		_tween_snap_to_center()
	_buffered_dir = Vector2.ZERO
	_buffered_magnitude = 0.0


# --- Slide along boundary ---

## Project velocity parallel to the hex edge of the blocked tile.
func _slide_along_boundary(velocity_2d: Vector2, delta: float) -> void:
	var current_world: Vector2 = _grid.axial_to_world(current_tile)
	var blocked_world: Vector2 = _grid.axial_to_world(
		_HexMath.world_to_axial(Vector2(position.x, position.z) + velocity_2d * delta)
	)
	# Boundary normal: from current tile center toward blocked tile center
	var boundary_normal: Vector2 = (blocked_world - current_world)
	if boundary_normal.is_zero_approx():
		return
	boundary_normal = boundary_normal.normalized()

	# Project velocity onto the tangent (perpendicular to normal)
	var tangent: Vector2 = Vector2(-boundary_normal.y, boundary_normal.x)
	var slide_speed: float = velocity_2d.dot(tangent)
	var slide_velocity: Vector2 = tangent * slide_speed

	var slide_movement := Vector3(slide_velocity.x, 0.0, slide_velocity.y) * delta
	var slide_pos: Vector3 = position + slide_movement
	var slide_pos_2d := Vector2(slide_pos.x, slide_pos.z)
	var slide_candidate: Vector2i = _HexMath.world_to_axial(slide_pos_2d)

	# Only apply slide if we stay in current tile or move to a passable tile
	if slide_candidate == current_tile:
		position = slide_pos
		_update_elevation_y_same_tile()
	elif _grid.get_traversal(current_tile, slide_candidate) == _grid.TraversalType.WALK:
		position = slide_pos
		var old_slide_tile: Vector2i = current_tile
		_update_elevation_y_interpolated(slide_pos_2d, old_slide_tile, slide_candidate)
		_emit_tile_transition(old_slide_tile, slide_candidate)


# --- Snap to tile center ---

func _tween_snap_to_center() -> void:
	_cancel_snap_tween()
	var world_2d: Vector2 = _grid.axial_to_world(current_tile)
	var tile = _grid.get_tile(current_tile)
	var target_y: float = 0.0
	if tile != null:
		target_y = float(tile.elevation) * ELEVATION_SCALE
	var target_pos := Vector3(world_2d.x, target_y, world_2d.y)

	_snap_tween = create_tween()
	_snap_tween.set_ease(Tween.EASE_OUT)
	_snap_tween.set_trans(Tween.TRANS_QUAD)
	_snap_tween.tween_property(self, "position", target_pos, 0.1)


func _cancel_snap_tween() -> void:
	if _snap_tween != null and _snap_tween.is_running():
		_snap_tween.kill()
	_snap_tween = null


func _cancel_jump_tween() -> void:
	if _jump_tween != null and _jump_tween.is_running():
		_jump_tween.kill()
	_jump_tween = null


# --- Tile transition signals ---

func _emit_tile_transition(from: Vector2i, to: Vector2i) -> void:
	# 1. tile_exited(A)
	_grid.tile_exited.emit(from)
	# 2. Update current_tile = B
	current_tile = to
	# 3. tile_entered(B)
	_grid.tile_entered.emit(to)
	# 4. Reveal fog (temporary — delivery-004 DayNightCycle takes over)
	if _grid.has_method("refresh_visibility"):
		var sources: Array[Dictionary] = [{"coords": to, "radius": 2}]
		_grid.refresh_visibility(sources)
	# 5. player_moved(A, B)
	player_moved.emit(from, to)


# --- Serialization ---

func get_save_data() -> Dictionary:
	return {
		"tile_col": current_tile.x,
		"tile_row": current_tile.y,
	}


func load_save_data(data: Dictionary) -> void:
	var col: int = data.get("tile_col", 0)
	var row: int = data.get("tile_row", 0)
	current_tile = Vector2i(col, row)
	move_state = MoveState.IDLE
	_joystick_dir = Vector2.ZERO
	_joystick_magnitude = 0.0
	_cancel_jump_tween()
	_cancel_snap_tween()
	_snap_to_tile(current_tile)
