extends Node3D

## Player — continuous joystick movement, derived current_tile, tile transitions.
## Uses Node3D with per-frame position updates (not CharacterBody3D).
## current_tile is derived from HexMath.world_to_axial(position), not set directly.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")

## Starter equipment: PropDef id of the backpack the player begins with.
## Read on _ready() / load_save_data() — if no wearable occupies the
## corresponding body slot yet, the player is equipped with it.
const STARTER_BACKPACK_ID: StringName = &"P00301"

## Signal emitted whenever equipped_wearables changes. BodySchemaWidget and
## the inventory panel header both subscribe to refresh from this.
signal wearables_changed()

enum MoveState { IDLE, WALKING, JUMPING }

signal player_moved(from: Vector2i, to: Vector2i)

@export var move_speed: float = 4.0

## Elevation scale: world Y per elevation level.
## MUST match HexGridRenderer.ELEVATION_STEP (0.5).
const ELEVATION_SCALE: float = 0.5

## Jump arc height above the higher tile.
const JUMP_ARC_HEIGHT: float = 0.5

var current_tile: Vector2i = Vector2i.ZERO
var move_state: MoveState = MoveState.IDLE
var facing_direction: Vector2 = Vector2.ZERO

## Wearables currently equipped on the player's body, keyed by WearableCap
## Place enum (Place → PropDef). The item occupying Place.BACK, when it is
## a container, drives the inventory grid dimensions.
var equipped_wearables: Dictionary = {}
var inventory: _Inventory = _Inventory.new()

var _grid: Node  # HexGrid reference (autoload or test substitute)
var _camera: Node  # Camera3D sibling (for camera-relative movement)
var _joystick_dir: Vector2 = Vector2.ZERO
var _joystick_magnitude: float = 0.0
var _buffered_dir: Vector2 = Vector2.ZERO
var _buffered_magnitude: float = 0.0
var _model: Node3D  # PlayerModel child
var _jump_tween: Tween
var _snap_tween: Tween
var _was_moving: bool = false


func _ready() -> void:
	_equip_starter_backpack_if_needed()
	if _grid == null:
		_grid = HexGrid
	_grid.map_generated.connect(_on_map_generated)
	_connect_player_input()
	_model = get_node_or_null("PlayerModel")
	# Camera is a sibling under World (not a child of Player).
	if _camera == null:
		var world: Node = get_parent()
		if world != null:
			_camera = world.get_node_or_null("Camera3D")


func get_inventory() -> _Inventory:
	return inventory


## Return the PropDef currently equipped in Place.BACK, or null when no
## container is worn. Convenience used by UI code that only cares about
## the inventory-driving slot.
func get_equipped_container() -> _PropDef:
	return equipped_wearables.get(_WearableCap.Place.BACK, null)


## Equip a PropDef on its declared wearable slot. Replaces any prior
## occupant of that slot. When the newly equipped prop carries a
## ContainerCap and occupies Place.BACK, the inventory grid is resized
## to its dimensions. Emits wearables_changed once the mutation settles.
## Returns true on success, false when the prop is not a wearable.
func equip(def: _PropDef) -> bool:
	if def == null or def.wearable == null:
		return false
	var place: int = def.wearable.place
	equipped_wearables[place] = def
	if place == _WearableCap.Place.BACK and def.container != null:
		if inventory.get_all_items().is_empty():
			inventory.resize_grid(def.container.grid_width, def.container.grid_height)
	wearables_changed.emit()
	return true


## Remove whatever is in the given slot. No-op when the slot is empty.
func unequip(place: int) -> void:
	if equipped_wearables.erase(place):
		wearables_changed.emit()


## Equips the starter backpack on Place.BACK if that slot is empty and
## PropRegistry is available. Idempotent. The grid is only resized when
## the inventory is empty so a save's serialized dimensions win over the
## backpack's defaults and nothing is dropped.
func _equip_starter_backpack_if_needed() -> void:
	if equipped_wearables.has(_WearableCap.Place.BACK):
		return
	var registry: Node = get_node_or_null("/root/PropRegistry")
	if registry == null or not registry.has_method("get_def"):
		return
	var def: _PropDef = registry.get_def(STARTER_BACKPACK_ID)
	if def == null or def.wearable == null:
		return
	equip(def)


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


func _update_model_rotation() -> void:
	if _model == null or facing_direction.is_zero_approx():
		return
	_model.rotation.y = atan2(facing_direction.x, facing_direction.y)


func _on_map_generated() -> void:
	current_tile = _grid.spawn_tile
	move_state = MoveState.IDLE
	_joystick_dir = Vector2.ZERO
	_joystick_magnitude = 0.0
	_snap_to_spawn()


## Place the player at the HexGrid spawn point using tile + sub-hex offset +
## facing direction. Falls back to tile center if no sub-hex/facing is set.
func _snap_to_spawn() -> void:
	var tile_center_2d: Vector2 = _grid.axial_to_world(current_tile)
	var offset_2d: Vector2 = _HexMath.sub_axial_to_world(_grid.spawn_sub_hex)
	var world_2d: Vector2 = tile_center_2d + offset_2d
	var terrain_y: float = _grid.get_terrain_y(world_2d.x, world_2d.y)
	position = Vector3(world_2d.x, terrain_y, world_2d.y)

	# Apply facing: editor stores degrees in canvas convention (0=up/north,
	# 90=east). Convert to the (x, z) facing_direction vector the model uses.
	var facing_deg: float = _grid.spawn_facing_deg
	var angle_rad: float = deg_to_rad(facing_deg - 90.0)
	facing_direction = Vector2(cos(angle_rad), sin(angle_rad))
	_update_model_rotation()


func _process(delta: float) -> void:
	if move_state == MoveState.WALKING:
		_process_walking(delta)


## Snap the player's world position to the given tile center.
func _snap_to_tile(coords: Vector2i) -> void:
	var world_2d: Vector2 = _grid.axial_to_world(coords)
	var terrain_y: float = _grid.get_terrain_y(world_2d.x, world_2d.y)
	position = Vector3(world_2d.x, terrain_y, world_2d.y)


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
	# Stop movement drain
	if _was_moving:
		var survival: Node = _get_survival_system()
		if survival and survival.has_method("stop_activity_drain"):
			survival.stop_activity_drain(&"moving")
		_was_moving = false
	if move_state == MoveState.JUMPING:
		return
	move_state = MoveState.IDLE
	# Player stays where they stopped — no snap to center


# --- Continuous movement ---

func _process_walking(delta: float) -> void:
	if _joystick_dir.is_zero_approx() or _joystick_magnitude < 0.01:
		# Stopped moving
		if _was_moving:
			var survival_stop: Node = _get_survival_system()
			if survival_stop and survival_stop.has_method("stop_activity_drain"):
				survival_stop.stop_activity_drain(&"moving")
			_was_moving = false
		return

	# Rotate joystick direction by camera yaw for camera-relative movement.
	var raw_dir: Vector2 = _joystick_dir.normalized()
	if _camera != null and _camera.has_method("get_yaw"):
		raw_dir = raw_dir.rotated(-_camera.get_yaw())
	facing_direction = raw_dir
	_update_model_rotation()
	var velocity_2d: Vector2 = facing_direction * move_speed * _joystick_magnitude

	# Track movement drain start/stop
	var is_moving: bool = velocity_2d.length_squared() > 0.01
	if is_moving and not _was_moving:
		var survival_start: Node = _get_survival_system()
		if survival_start and survival_start.has_method("start_activity_drain"):
			survival_start.start_activity_drain(&"moving")
	_was_moving = is_moving

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


## Update Y from curved terrain at current XZ position.
## When crossing tiles, the terrain Y already handles the interpolation
## because get_terrain_y considers the hex the point is actually in.
func _update_elevation_y_interpolated(_pos_2d: Vector2, _from: Vector2i, _to: Vector2i) -> void:
	position.y = _grid.get_terrain_y(position.x, position.z)


## Keep Y at current terrain height.
func _update_elevation_y_same_tile() -> void:
	position.y = _grid.get_terrain_y(position.x, position.z)


# --- Jump/Drop ---

func _start_jump(target: Vector2i, traversal_type: int) -> void:
	move_state = MoveState.JUMPING
	_buffered_dir = _joystick_dir
	_buffered_magnitude = _joystick_magnitude

	var current_world_2d: Vector2 = _grid.axial_to_world(current_tile)
	var target_world_2d: Vector2 = _grid.axial_to_world(target)

	# Land just past the border (10% into the target hex), not at center
	var border_point_2d: Vector2 = current_world_2d.lerp(target_world_2d, 0.55)
	var target_y: float = _grid.get_terrain_y(border_point_2d.x, border_point_2d.y)
	var land_pos := Vector3(border_point_2d.x, target_y, border_point_2d.y)

	var higher_y: float = maxf(position.y, target_y)
	var arc_peak: float = higher_y + JUMP_ARC_HEIGHT

	var is_jump_up: bool = traversal_type == _grid.TraversalType.JUMP
	var duration: float = 0.15 if is_jump_up else 0.12  # short & subtle

	_cancel_jump_tween()
	_jump_tween = create_tween()

	# XZ movement: linear to border landing point
	_jump_tween.set_ease(Tween.EASE_IN_OUT)
	_jump_tween.set_trans(Tween.TRANS_QUAD)
	_jump_tween.tween_property(self, "position:x", land_pos.x, duration)
	_jump_tween.parallel().tween_property(self, "position:z", land_pos.z, duration)

	# Y movement: arc up (parabola), gravity down (straight fall)
	var half: float = duration * 0.5
	if is_jump_up:
		# Jumping UP: arc over the peak then land
		_jump_tween.parallel().tween_property(self, "position:y", arc_peak, half).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_jump_tween.tween_property(self, "position:y", target_y, half).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		# Dropping DOWN: small hop off the edge then fall with gravity
		var hop_y: float = position.y + JUMP_ARC_HEIGHT * 0.3
		_jump_tween.parallel().tween_property(self, "position:y", hop_y, half * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_jump_tween.tween_property(self, "position:y", target_y, half * 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	var old_tile: Vector2i = current_tile
	_jump_tween.finished.connect(func() -> void:
		_jump_tween = null
		_emit_tile_transition(old_tile, target)
		# NO snap to center — player continues from where they landed
		_on_jump_landed()
	)


func _on_jump_landed() -> void:
	if _joystick_magnitude > 0.01 and not _buffered_dir.is_zero_approx():
		move_state = MoveState.WALKING
		_joystick_dir = _buffered_dir
		_joystick_magnitude = _buffered_magnitude
	else:
		move_state = MoveState.IDLE
		# No snap — player stays at landing point
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
	var target_y: float = _grid.get_terrain_y(world_2d.x, world_2d.y)
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
	# 4. player_moved(A, B)
	player_moved.emit(from, to)


# --- Survival System Helper ---


func _get_survival_system() -> Node:
	for child in get_children():
		if child.has_method("apply_activity_cost"):
			return child
	return null


# --- Serialization ---

func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"tile_col": current_tile.x,
		"tile_row": current_tile.y,
		"facing_x": facing_direction.x,
		"facing_y": facing_direction.y,
	}
	if inventory != null:
		data["inventory"] = inventory.get_save_data()
	# Persist equipped wearables as slot-name → prop-id so the enum values
	# themselves are not baked into saves (they can be reordered later).
	var wearables_data: Dictionary = {}
	for place_value in equipped_wearables:
		var def: _PropDef = equipped_wearables[place_value]
		if def == null:
			continue
		var slot_name: StringName = _WearableCap.place_to_string(place_value)
		if slot_name == &"":
			continue
		wearables_data[String(slot_name)] = String(def.id)
	data["equipped_wearables"] = wearables_data
	return data


func load_save_data(data: Dictionary) -> void:
	var col: int = data.get("tile_col", 0)
	var row: int = data.get("tile_row", 0)
	current_tile = Vector2i(col, row)
	move_state = MoveState.IDLE
	_joystick_dir = Vector2.ZERO
	_joystick_magnitude = 0.0
	facing_direction = Vector2(
		float(data.get("facing_x", 0.0)),
		float(data.get("facing_y", 0.0)),
	)
	_cancel_jump_tween()
	_cancel_snap_tween()
	_snap_to_tile(current_tile)
	_update_model_rotation()
	if inventory != null and data.has("inventory"):
		inventory.load_save_data(data["inventory"])
	# Restore wearables before the starter fallback so saved state wins.
	# _equip_starter_backpack_if_needed may call equip(), which emits the
	# signal on its own. If nothing new is equipped (e.g. the save already
	# had a backpack in Place.BACK), we still need to notify listeners so
	# the HUD / BodySchemaWidget refresh from the loaded state instead of
	# staying pinned to whatever was painted at startup.
	equipped_wearables.clear()
	if data.has("equipped_wearables"):
		_load_wearables_data(data["equipped_wearables"])
	_equip_starter_backpack_if_needed()
	wearables_changed.emit()


func _load_wearables_data(wearables_data: Dictionary) -> void:
	var registry: Node = get_node_or_null("/root/PropRegistry")
	if registry == null or not registry.has_method("get_def"):
		return
	for slot_name in wearables_data:
		var prop_id: StringName = StringName(wearables_data[slot_name])
		var def: _PropDef = registry.get_def(prop_id)
		if def == null or def.wearable == null:
			push_warning("Player.load: unknown/invalid wearable %s in slot %s" %
				[prop_id, slot_name])
			continue
		var place: int = _WearableCap.string_to_place(StringName(slot_name))
		if place < 0:
			push_warning("Player.load: unknown wearable slot %s — skipped" % slot_name)
			continue
		equipped_wearables[place] = def
