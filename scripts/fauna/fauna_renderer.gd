extends Node3D

## FaunaRenderer — MultiMeshInstance3D pool for fauna bodies.
## Single MultiMesh with max ~3 instances (Chapter 1 fauna count).
## Signal-driven: subscribes to FaunaManager.fauna_spawned / fauna_moved /
## fauna_killed / fauna_despawned signals.
## task-038: Fauna renderer + signal wiring.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")

# --- Constants ---

## Max fauna instances (Chapter 1: 1-3 per night)
const MAX_INSTANCES: int = 8

## Fauna sphere radius
const FAUNA_RADIUS: float = 0.3

## Y offset: sphere sits on ground at center (radius from ground)
const FAUNA_Y_OFFSET: float = 0.3

## Fauna color — red sphere
const FAUNA_COLOR: Color = Color(0.85, 0.15, 0.15, 1.0)

# --- State ---

## fauna_id → instance index in the MultiMesh
var _id_to_index: Dictionary = {}

## instance index → fauna_id (reverse map for swap-remove)
var _index_to_id: Dictionary = {}

## fauna_id → coords (for position queries that work in headless mode)
var _id_to_coords: Dictionary = {}

## The MultiMeshInstance3D child node
var _mmi: MultiMeshInstance3D = null

## Reference to HexGrid (allows override in tests)
var _grid: Node = null

## Reference to FaunaManager (allows override in tests)
var _fauna_manager: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = _get_autoload(&"HexGrid")
	_create_multimesh()
	_connect_fauna_manager()


func _create_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = _make_sphere_mesh()

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.name = "FaunaMultiMesh"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = FAUNA_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mmi.material_override = mat

	add_child(_mmi)


func _make_sphere_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = FAUNA_RADIUS
	mesh.height = FAUNA_RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


# --- Signal wiring ---

func _connect_fauna_manager() -> void:
	if _fauna_manager == null:
		_fauna_manager = _find_fauna_manager()
	if _fauna_manager == null:
		return
	if _fauna_manager.has_signal("fauna_spawned"):
		if not _fauna_manager.fauna_spawned.is_connected(_on_fauna_spawned):
			_fauna_manager.fauna_spawned.connect(_on_fauna_spawned)
	if _fauna_manager.has_signal("fauna_moved"):
		if not _fauna_manager.fauna_moved.is_connected(_on_fauna_moved):
			_fauna_manager.fauna_moved.connect(_on_fauna_moved)
	if _fauna_manager.has_signal("fauna_killed"):
		if not _fauna_manager.fauna_killed.is_connected(_on_fauna_killed):
			_fauna_manager.fauna_killed.connect(_on_fauna_killed)
	if _fauna_manager.has_signal("fauna_despawned"):
		if not _fauna_manager.fauna_despawned.is_connected(_on_fauna_despawned):
			_fauna_manager.fauna_despawned.connect(_on_fauna_despawned)


func _find_fauna_manager() -> Node:
	# FaunaManager is a child of Player (which is under World)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var main: Node = tree.root.get_node_or_null("Main")
	if main == null:
		return null
	var player: Node = main.get_node_or_null("World/Player")
	if player == null:
		return null
	return player.get_node_or_null("FaunaManager")


# --- Signal handlers ---

func _on_fauna_spawned(id: int, coords: Vector2i, _species_type: StringName) -> void:
	add_fauna(id, coords)


func _on_fauna_moved(id: int, _old_coords: Vector2i, new_coords: Vector2i, _species_type: StringName) -> void:
	move_fauna(id, new_coords)


func _on_fauna_killed(id: int, _coords: Vector2i, _species_type: StringName) -> void:
	remove_fauna(id)


func _on_fauna_despawned(id: int, _coords: Vector2i, _species_type: StringName) -> void:
	remove_fauna(id)


# --- Instance management ---

func add_fauna(fauna_id: int, coords: Vector2i) -> void:
	if _mmi == null:
		return
	if _id_to_index.has(fauna_id):
		return  # Already tracked
	var mm: MultiMesh = _mmi.multimesh
	var idx: int = mm.visible_instance_count
	if idx >= MAX_INSTANCES:
		return  # Pool full

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, _make_transform(coords))
	_id_to_index[fauna_id] = idx
	_index_to_id[idx] = fauna_id
	_id_to_coords[fauna_id] = coords


func move_fauna(fauna_id: int, coords: Vector2i) -> void:
	if _mmi == null:
		return
	if not _id_to_index.has(fauna_id):
		return
	var idx: int = _id_to_index[fauna_id]
	_mmi.multimesh.set_instance_transform(idx, _make_transform(coords))
	_id_to_coords[fauna_id] = coords


func remove_fauna(fauna_id: int) -> void:
	if _mmi == null:
		return
	if not _id_to_index.has(fauna_id):
		return
	var idx: int = _id_to_index[fauna_id]
	var mm: MultiMesh = _mmi.multimesh
	var last_idx: int = mm.visible_instance_count - 1

	if idx != last_idx:
		# Swap with last instance
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		mm.set_instance_transform(idx, last_xform)
		# Update the swapped fauna's index mappings
		var swapped_id: int = _index_to_id[last_idx]
		_id_to_index[swapped_id] = idx
		_index_to_id[idx] = swapped_id

	# Remove the last slot
	_index_to_id.erase(last_idx)
	_id_to_index.erase(fauna_id)
	_id_to_coords.erase(fauna_id)
	mm.visible_instance_count = last_idx


# --- Transform helpers ---

func _make_transform(coords: Vector2i) -> Transform3D:
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	elif _grid != null and _grid.has_method("get_tile"):
		var tile = _grid.get_tile(coords)
		if tile != null and "elevation" in tile:
			elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	var pos := Vector3(world_2d.x, elevation_y + FAUNA_Y_OFFSET, world_2d.y)
	var xform := Transform3D.IDENTITY
	xform.origin = pos
	return xform


# --- Public API (for testing) ---

func get_visible_count() -> int:
	if _mmi == null:
		return 0
	return _mmi.multimesh.visible_instance_count


func get_instance_position(fauna_id: int) -> Vector3:
	if _mmi == null or not _id_to_index.has(fauna_id):
		return Vector3.ZERO
	var idx: int = _id_to_index[fauna_id]
	return _mmi.multimesh.get_instance_transform(idx).origin


func get_fauna_coords(fauna_id: int) -> Vector2i:
	return _id_to_coords.get(fauna_id, Vector2i(-99999, -99999))


func has_fauna(fauna_id: int) -> bool:
	return _id_to_index.has(fauna_id)


# --- Autoload helper ---

func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
