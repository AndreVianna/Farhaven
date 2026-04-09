extends Node3D

## StructureRenderer — renders player-placed structures (origin == CRAFTED).
## Signal-driven: subscribes to HexGrid.structure_placed / structure_destroyed.
## Uses individual Node3D children (not MultiMesh) since structures are low-count (<20).
## Each child is keyed by "coords:type" for O(1) lookup.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

## Fallback Y offset if mesh height can't be determined.
const PROP_Y_OFFSET: float = 0.3

## Child nodes keyed by "coords_x,coords_y:type" for fast lookup.
var _instances: Dictionary = {}

## Reference to HexGrid (allows override in tests).
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = _get_autoload(&"HexGrid")
	_connect_signals()


# --- Signal wiring ---


func _connect_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("structure_placed"):
		if not _grid.structure_placed.is_connected(_on_structure_placed):
			_grid.structure_placed.connect(_on_structure_placed)
	if _grid.has_signal("structure_destroyed"):
		if not _grid.structure_destroyed.is_connected(_on_structure_destroyed):
			_grid.structure_destroyed.connect(_on_structure_destroyed)


# --- Signal handlers ---


func _on_structure_placed(coords: Vector2i, structure_type: StringName) -> void:
	_add_structure(coords, structure_type)


func _on_structure_destroyed(coords: Vector2i, structure_type: StringName) -> void:
	_remove_structure(coords, structure_type)


# --- Structure management ---


func _make_key(coords: Vector2i, structure_type: StringName) -> String:
	return "%d,%d:%s" % [coords.x, coords.y, String(structure_type)]


func _add_structure(coords: Vector2i, structure_type: StringName) -> void:
	var key: String = _make_key(coords, structure_type)
	# Remove existing if already present (idempotent).
	if _instances.has(key):
		_remove_child_node(key)

	# Look up the prop on the tile to get its sub_hex position.
	var sub_hex: Vector2i = Vector2i.ZERO
	if _grid != null and _grid.has_method("get_tile"):
		var tile: Resource = _grid.get_tile(coords)
		if tile != null:
			for prop in tile.props:
				if prop.type == structure_type and prop.origin == 1:  # Origin.CRAFTED == 1
					sub_hex = prop.sub_hex
					break

	# Build placeholder mesh from PropDef config.
	var def = PropRegistry.get_def(structure_type)
	var mesh: Mesh
	var color: Color = Color.WHITE
	var y_offset: float = PROP_Y_OFFSET

	if def != null:
		var result: Array = _build_placeholder_mesh(def.placeholder_mesh_type, def.placeholder_params)
		mesh = result[0]
		y_offset = result[1]
		color = def.placeholder_color if def.mesh == null else Color.WHITE
	else:
		# Fallback: generic cube.
		mesh = _make_cube_mesh(0.3)
		y_offset = 0.3

	# Calculate world position: tile center + sub-hex offset + elevation.
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(sub_hex)
	var wx: float = world_2d.x + sub_hex_offset.x
	var wz: float = world_2d.y + sub_hex_offset.y
	var elevation_y: float = _get_elevation_y(coords, wx, wz)

	# Create Node3D with MeshInstance3D child.
	var node := Node3D.new()
	node.name = "Structure_%s" % key
	node.position = Vector3(wx, elevation_y + y_offset, wz)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat
	node.add_child(mesh_instance)

	add_child(node)
	_instances[key] = node


func _remove_structure(coords: Vector2i, structure_type: StringName) -> void:
	var key: String = _make_key(coords, structure_type)
	_remove_child_node(key)


func _remove_child_node(key: String) -> void:
	if not _instances.has(key):
		return
	var node: Node3D = _instances[key]
	_instances.erase(key)
	if is_instance_valid(node):
		remove_child(node)
		node.queue_free()


func _get_elevation_y(coords: Vector2i, wx: float, wz: float) -> float:
	if _grid != null and _grid.has_method("get_terrain_y"):
		return _grid.get_terrain_y(wx, wz)
	if _grid != null and _grid.has_method("get_tile"):
		var tile: Resource = _grid.get_tile(coords)
		if tile != null:
			return float(tile.elevation) * 0.5
	return 0.0


# --- Mesh factories (matching PropRenderer patterns) ---


## Returns [mesh, y_offset] where y_offset is center-to-bottom distance.
func _build_placeholder_mesh(type: StringName, params: Dictionary) -> Array:
	match type:
		&"cylinder":
			var h: float = params.get("height", 0.8)
			return [_make_cylinder_mesh(params.get("radius", 0.2), h), h / 2.0]
		&"cube":
			var hs: float = params.get("half_size", 0.3)
			return [_make_cube_mesh(hs), hs]
		&"box":
			var sx: float = params.get("size_x", 0.5)
			var sy: float = params.get("size_y", 0.15)
			var sz: float = params.get("size_z", 0.5)
			return [_make_box_mesh(Vector3(sx, sy, sz)), sy / 2.0]
		&"sphere":
			var r: float = params.get("radius", 0.3)
			return [_make_sphere_mesh(r), r]
		&"octahedron":
			var r: float = params.get("radius", 0.35)
			return [_make_octahedron_mesh(r), r]
		&"prism":
			var h: float = params.get("height", 0.7)
			return [_make_prism_mesh(params.get("radius", 0.2), h), h / 2.0]
		_:
			return [_make_cube_mesh(0.3), 0.3]


func _make_cylinder_mesh(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


func _make_cube_mesh(half_size: float) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half_size * 2.0, half_size * 2.0, half_size * 2.0)
	return mesh


func _make_box_mesh(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _make_sphere_mesh(radius: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _make_octahedron_mesh(radius: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh


func _make_prism_mesh(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.3
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


# --- Public API (for testing) ---


func get_instance_count() -> int:
	return _instances.size()


func get_instance(coords: Vector2i, structure_type: StringName) -> Node3D:
	var key: String = _make_key(coords, structure_type)
	return _instances.get(key, null)


func has_instance(coords: Vector2i, structure_type: StringName) -> bool:
	var key: String = _make_key(coords, structure_type)
	return _instances.has(key)


func get_all_keys() -> Array:
	return _instances.keys()


# --- Autoload helper ---


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
