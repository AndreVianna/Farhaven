extends Node3D

## StructureRenderer — renders player-placed structures (origin == CRAFTED).
## Signal-driven: subscribes to HexGrid.structure_placed / structure_destroyed.
## Uses individual Node3D children (not MultiMesh) since structures are low-count (<20).
## Each child is keyed by "coords:type" for O(1) lookup.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")

## Fallback Y offset if mesh height can't be determined.
const PROP_Y_OFFSET: float = 0.3

## Child nodes keyed by "coords_x,coords_y:sub_x,sub_y:type" for fast lookup.
## Includes sub-hex position so multiple structures of the same type on one tile are preserved.
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


func _make_key(coords: Vector2i, structure_type: StringName, sub_hex: Vector2i = Vector2i.ZERO) -> String:
	return "%d,%d:%d,%d:%s" % [coords.x, coords.y, sub_hex.x, sub_hex.y, String(structure_type)]


func _add_structure(coords: Vector2i, structure_type: StringName) -> void:
	# Look up the prop on the tile to get its sub_hex position.
	var sub_hex: Vector2i = Vector2i.ZERO
	if _grid != null and _grid.has_method("get_tile"):
		var tile: Resource = _grid.get_tile(coords)
		if tile != null:
			for prop in tile.props:
				if prop.type == structure_type and prop.origin == _Prop.Origin.CRAFTED:
					sub_hex = prop.sub_hex
					break

	var key: String = _make_key(coords, structure_type, sub_hex)
	# Remove existing if already present (idempotent).
	if _instances.has(key):
		_remove_child_node(key)

	# Resolve mesh from PropDef's PlaceableCap (first variant).
	# Structures without authored meshes don't render.
	# `mesh_from_scene` tracks whether the mesh came from an authored
	# PackedScene (with embedded PBR materials) vs a legacy primitive
	# fallback — the former must NOT be overridden by a solid material.
	var def = PropRegistry.get_def(structure_type)
	var mesh: Mesh
	var y_offset: float = PROP_Y_OFFSET
	var mesh_from_scene: bool = false
	# variant_scale: MeshVariant.scale applied to both visual (MeshInstance3D)
	# and collision composition so authored sizes are the source of truth.
	# Default 1.0 when no scale is authored.
	var variant_scale: float = 1.0

	if def != null and def.placeable != null and def.placeable.meshes != null:
		for mv_entry in def.placeable.meshes:
			var mv: MeshVariant = mv_entry as MeshVariant
			if mv == null or mv.scene == null:
				continue
			var extracted: Array = _extract_mesh_from_scene(mv.scene)
			if extracted[0] != null:
				mesh = extracted[0]
				y_offset = extracted[1]
				mesh_from_scene = true
				# Positive, finite scale only — falls back to 1.0 on bad data.
				if mv.scale > 0.0 and not is_nan(mv.scale):
					variant_scale = mv.scale
				break
	if mesh == null and def != null and def.mesh != null:
		mesh = def.mesh

	if mesh == null:
		# No authored mesh — skip rendering this structure.
		# Emit a warning so authors notice silently-skipped structures.
		push_warning("StructureRenderer: structure '%s' at %s has no mesh — will not render" % [structure_type, coords])
		return

	# Calculate world position: snap to nearest SSH center for 32cm precision.
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(sub_hex)
	var raw_pos: Vector2 = world_2d + sub_hex_offset
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(raw_pos, coords)
	var snapped: Vector2 = ssh_result["snapped_world"]
	var wx: float = snapped.x
	var wz: float = snapped.y
	var elevation_y: float = _get_elevation_y(coords, wx, wz)

	# Create Node3D with MeshInstance3D child. Apply the MeshVariant scale to
	# the root Node3D so both visual (MeshInstance3D) and physics (StaticBody3D)
	# children inherit it. y_offset is scaled accordingly because the mesh AABB
	# was measured at unit scale.
	var node := Node3D.new()
	node.name = "Structure_%s" % key
	node.position = Vector3(wx, elevation_y + y_offset * variant_scale, wz)
	node.scale = Vector3.ONE * variant_scale

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	# Only override the material for legacy primitive-mesh fallback.
	# Authored .glb meshes carry their own PBR materials — overriding
	# would render them flat white regardless of the imported texture.
	if not mesh_from_scene:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = mat
	node.add_child(mesh_instance)

	# Add StaticBody3D with per-prop authored collision shapes (zero or more).
	# Empty collision_shapes → walkthrough prop, no StaticBody3D added.
	# Collision inherits variant_scale via the parent node's scale.
	if def != null:
		var collision_nodes: Array[CollisionShape3D] = _CollisionHelper.create_collision_shapes(def)
		if not collision_nodes.is_empty():
			var static_body := StaticBody3D.new()
			static_body.name = "StaticBody"
			for i in collision_nodes.size():
				var cs_node: CollisionShape3D = collision_nodes[i]
				cs_node.name = "CollisionShape_%d" % i
				static_body.add_child(cs_node)
			node.add_child(static_body)

	add_child(node)
	_instances[key] = node


func _remove_structure(coords: Vector2i, structure_type: StringName) -> void:
	# Find matching key by prefix since we need sub_hex to build exact key.
	var prefix: String = "%d,%d:" % [coords.x, coords.y]
	var suffix: String = ":%s" % String(structure_type)
	for key in _instances.keys():
		if key.begins_with(prefix) and key.ends_with(suffix):
			_remove_child_node(key)
			return


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
			return float(tile.elevation) * _HexGrid.ELEVATION_STEP
	return 0.0


# --- Mesh resolution (PackedScene → Mesh, matching PropRenderer) ---


## Extract the first Mesh from an imported PackedScene (.glb/.gltf).
## Returns [mesh, y_offset] where y_offset is center-to-bottom derived from AABB.
## Returns [null, PROP_Y_OFFSET] when no MeshInstance3D is found.
func _extract_mesh_from_scene(scene: PackedScene) -> Array:
	if scene == null:
		return [null, PROP_Y_OFFSET]
	var root: Node = scene.instantiate()
	if root == null:
		return [null, PROP_Y_OFFSET]
	var mesh_instance: MeshInstance3D = _find_first_mesh_instance(root)
	var mesh: Mesh = null
	var y_offset: float = PROP_Y_OFFSET
	if mesh_instance != null:
		mesh = mesh_instance.mesh
		if mesh != null:
			var aabb: AABB = mesh.get_aabb()
			y_offset = -aabb.position.y
	root.queue_free()
	return [mesh, y_offset]


## Depth-first search for the first MeshInstance3D in a scene tree.
func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result: MeshInstance3D = _find_first_mesh_instance(child)
		if result != null:
			return result
	return null


# --- Public API (for testing) ---


func get_instance_count() -> int:
	return _instances.size()


func get_instance(coords: Vector2i, structure_type: StringName) -> Node3D:
	var prefix: String = "%d,%d:" % [coords.x, coords.y]
	var suffix: String = ":%s" % String(structure_type)
	for key in _instances.keys():
		if key.begins_with(prefix) and key.ends_with(suffix):
			return _instances[key]
	return null


func has_instance(coords: Vector2i, structure_type: StringName) -> bool:
	return get_instance(coords, structure_type) != null


func get_all_keys() -> Array:
	return _instances.keys()


# --- Autoload helper ---


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
