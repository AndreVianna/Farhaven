extends Node3D

## Player — movement state machine, tile transitions, tween orchestration.
## Uses Node3D + Tween (not CharacterBody3D). Discrete tile-to-tile movement
## with visual interpolation.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

enum MoveState { IDLE, WALKING, PATHFINDING }

signal player_moved(from: Vector2i, to: Vector2i)

@export var move_speed: float = 4.0

var current_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var move_state: MoveState = MoveState.IDLE
var move_path: Array[Vector2i] = []
var facing_direction: Vector2 = Vector2.ZERO

var _grid: Node  # HexGrid reference (autoload or test substitute)
var _pathfinder: PlayerPathfinder
var _active_tween: Tween
var _tween_origin_tile: Vector2i = Vector2i.ZERO
var _tween_target_tile: Vector2i = Vector2i.ZERO
var _tween_progress: float = 0.0


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_pathfinder = PlayerPathfinder.new()
	_pathfinder.setup(_grid)
	_grid.map_generated.connect(_on_map_generated)
	_connect_player_input()


func _connect_player_input() -> void:
	var pi: Node = get_node_or_null("PlayerInput")
	if pi == null:
		return
	pi.tap_tile.connect(pathfind_to)
	pi.joystick_started.connect(start_walking)
	pi.joystick_moved.connect(walk_direction)
	pi.joystick_released.connect(stop_walking)


func _on_map_generated() -> void:
	# Spawn at Crash Site (0, 0).
	current_tile = Vector2i.ZERO
	target_tile = Vector2i.ZERO
	move_state = MoveState.IDLE
	move_path.clear()
	_snap_to_tile(current_tile)


## Snap the player's world position to the given tile center.
func _snap_to_tile(coords: Vector2i) -> void:
	var world_2d: Vector2 = _grid.axial_to_world(coords)
	var tile = _grid.get_tile(coords)
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.3
	position = Vector3(world_2d.x, elevation_y, world_2d.y)


## Get the pathfinder (for testing and external access).
func get_pathfinder() -> PlayerPathfinder:
	return _pathfinder


# --- Public movement API (called by PlayerInput) ---

## Start pathfinding to a target tile (tap-to-move).
func pathfind_to(target: Vector2i) -> void:
	if target == current_tile:
		return
	var tile = _grid.get_tile(target)
	if tile == null:
		return

	var path: Array[Vector2i] = _pathfinder.find_path(current_tile, target)
	if path.is_empty():
		return

	# Cancel any active tween.
	_cancel_tween()

	# If currently walking (joystick), snap first.
	if move_state == MoveState.WALKING:
		_resolve_snap()

	# Remove current tile from path (we're already here).
	if path.size() > 0 and path[0] == current_tile:
		path.remove_at(0)

	if path.is_empty():
		return

	move_path = path
	target_tile = path[path.size() - 1]
	move_state = MoveState.PATHFINDING
	_advance_path()


## Start continuous joystick walking in a direction.
func start_walking(direction: Vector2) -> void:
	if move_state == MoveState.PATHFINDING:
		# Joystick always wins — cancel path immediately.
		_cancel_tween()
		move_path.clear()
	move_state = MoveState.WALKING
	_walk_toward(direction)


## Continue joystick walking — update direction.
func continue_walking(direction: Vector2, _magnitude: float) -> void:
	if move_state != MoveState.WALKING:
		return
	# Only start a new tween if we're not already mid-tween.
	if _active_tween == null or not _active_tween.is_running():
		_walk_toward(direction)


## Update joystick walking direction (connected to PlayerInput.joystick_moved).
func walk_direction(direction: Vector2, magnitude: float) -> void:
	continue_walking(direction, magnitude)


## Stop joystick — apply snap tiebreaker.
func stop_walking() -> void:
	if move_state != MoveState.WALKING:
		return
	_resolve_snap()
	move_state = MoveState.IDLE


# --- Internal movement ---

## Walk toward the best neighbor in the given direction.
func _walk_toward(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	facing_direction = direction.normalized()
	var candidate: Vector2i = _pick_neighbor_in_direction(current_tile, facing_direction)
	if candidate == current_tile:
		return
	if not _grid.is_passable(current_tile, candidate):
		return

	_tween_to_tile(candidate)


## Pick the neighbor closest to the given direction vector.
func _pick_neighbor_in_direction(from: Vector2i, direction: Vector2) -> Vector2i:
	var from_world: Vector2 = _grid.axial_to_world(from)
	var best_dot: float = -2.0
	var best: Vector2i = from
	var neighbors: Array[Vector2i] = _grid.get_neighbors(from)
	for n in neighbors:
		var n_world: Vector2 = _grid.axial_to_world(n)
		var to_neighbor: Vector2 = (n_world - from_world).normalized()
		var dot: float = direction.dot(to_neighbor)
		if dot > best_dot:
			best_dot = dot
			best = n
	return best


## Advance to the next tile in the pathfinding path.
func _advance_path() -> void:
	if move_path.is_empty():
		move_state = MoveState.IDLE
		return
	var next: Vector2i = move_path[0]
	move_path.remove_at(0)
	_tween_to_tile(next)


## Tween the player from current position to the target tile.
func _tween_to_tile(to: Vector2i) -> void:
	_cancel_tween()
	_tween_origin_tile = current_tile
	_tween_target_tile = to

	var world_2d: Vector2 = _grid.axial_to_world(to)
	var tile = _grid.get_tile(to)
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.3

	var target_pos := Vector3(world_2d.x, elevation_y, world_2d.y)
	var dist: float = position.distance_to(target_pos)
	var duration: float = dist / move_speed if move_speed > 0.0 else 0.1
	duration = maxf(duration, 0.05)

	# Update facing direction.
	var from_world: Vector2 = _grid.axial_to_world(_tween_origin_tile)
	var to_world: Vector2 = _grid.axial_to_world(to)
	var dir: Vector2 = to_world - from_world
	if not dir.is_zero_approx():
		facing_direction = dir.normalized()

	_tween_progress = 0.0
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", target_pos, duration)
	_active_tween.parallel().tween_method(_update_tween_progress, 0.0, 1.0, duration)
	_active_tween.finished.connect(_on_tween_finished)


func _update_tween_progress(value: float) -> void:
	_tween_progress = value


func _on_tween_finished() -> void:
	_active_tween = null
	_tween_progress = 0.0
	_complete_tile_transition(_tween_origin_tile, _tween_target_tile)

	match move_state:
		MoveState.PATHFINDING:
			_advance_path()
		MoveState.WALKING:
			# Next tile will be tweened on next joystick_move signal.
			pass
		MoveState.IDLE:
			pass


## Execute the 4-step tile transition sequence.
func _complete_tile_transition(from: Vector2i, to: Vector2i) -> void:
	# 1. Emit tile_exited
	_grid.tile_exited.emit(from)
	# 2. Update current_tile
	current_tile = to
	target_tile = to
	# 3. Emit tile_entered
	_grid.tile_entered.emit(to)
	# 4. Emit player_moved
	player_moved.emit(from, to)


## Cancel any active tween immediately.
func _cancel_tween() -> void:
	if _active_tween != null and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = null


## Snap tiebreaker: >50% forward, <=50% back.
func _resolve_snap() -> void:
	if _active_tween == null or not _active_tween.is_running():
		# Not mid-tween, nothing to snap.
		return

	var snap_to: Vector2i
	if _tween_progress > 0.5:
		snap_to = _tween_target_tile
	else:
		snap_to = _tween_origin_tile

	_cancel_tween()

	if snap_to != current_tile:
		# Complete transition to snap target.
		_complete_tile_transition(current_tile, snap_to)

	_snap_to_tile(snap_to)
	_tween_progress = 0.0


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
	target_tile = current_tile
	move_state = MoveState.IDLE
	move_path.clear()
	_cancel_tween()
	_snap_to_tile(current_tile)
