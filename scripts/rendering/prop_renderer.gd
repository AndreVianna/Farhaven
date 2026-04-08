extends Node3D

## PropRenderer — MultiMeshInstance3D pools for 3D prop meshes.
## One pool per PropDef from PropRegistry, keyed by StringName (prop type id).
## Signal-driven: subscribes to HexGrid map_generated,
## prop_depleted, prop_respawned signals.
## On prop_depleted: swap mesh variant (tree→stump, rock→rubble).
## On prop_respawned: swap back to original mesh.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Constants ---

## Fallback Y offset if mesh height can't be determined.
const PROP_Y_OFFSET: float = 0.3

## Max instances per MultiMesh pool (Chapter 1: ~50 elements max)
const MAX_INSTANCES: int = 128

## HEX_SIZE for offset calculation
const HEX_SIZE: float = 3.0

# --- State ---

## MultiMeshInstance3D nodes keyed by StringName (prop type id)
var _pools: Dictionary = {}

## Normal mesh variants per prop type id
var _normal_meshes: Dictionary = {}

## Depleted mesh variants per prop type id
var _depleted_meshes: Dictionary = {}

## Normal colors per prop type id (for undimmed state)
var _pool_colors: Dictionary = {}

## Per-pool Y offset (center-to-bottom distance of the mesh)
var _pool_y_offsets: Dictionary = {}

## Tile coords -> Array of {prop_type: StringName, pool: StringName, instance_idx: int, depleted: bool}
var _tile_entries: Dictionary = {}

## Reference to HexGrid (allows override in tests)
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_pools()
	_connect_signals()


func _create_pools() -> void:
	for def in PropRegistry.get_all():
		var normal_mesh: Mesh
		var depleted_mesh_res: Mesh
		var y_offset: float = PROP_Y_OFFSET

		if def.mesh != null:
			normal_mesh = def.mesh
		else:
			var result: Array = _build_placeholder_mesh(def.placeholder_mesh_type, def.placeholder_params)
			normal_mesh = result[0]
			y_offset = result[1]

		if def.depleted_mesh != null:
			depleted_mesh_res = def.depleted_mesh
		else:
			var result: Array = _build_placeholder_mesh(def.placeholder_depleted_type, def.placeholder_depleted_params)
			depleted_mesh_res = result[0]

		_normal_meshes[def.id] = normal_mesh
		_depleted_meshes[def.id] = depleted_mesh_res
		_pool_y_offsets[def.id] = y_offset
		var color: Color = def.placeholder_color if def.mesh == null else Color.WHITE
		_pool_colors[def.id] = color
		_create_pool(def.id, normal_mesh, color)


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


func _create_pool(pool_id: StringName, mesh: Mesh, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "PropPool_%s" % pool_id

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = mat

	add_child(mmi)
	_pools[pool_id] = mmi


# --- Mesh factories (placeholder meshes, <500 tris each) ---

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
	# Approximate octahedron with a low-poly sphere
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh


func _make_prism_mesh(radius: float, height: float) -> Mesh:
	# Triangular prism approximated by a 3-sided cylinder
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.3
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


# --- Signal wiring ---

func _connect_signals() -> void:
	_connect_grid_signals()


func _connect_grid_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("map_generated"):
		if not _grid.map_generated.is_connected(_on_map_generated):
			_grid.map_generated.connect(_on_map_generated)
	if _grid.has_signal("prop_depleted"):
		if not _grid.prop_depleted.is_connected(_on_prop_depleted):
			_grid.prop_depleted.connect(_on_prop_depleted)
	if _grid.has_signal("prop_respawned"):
		if not _grid.prop_respawned.is_connected(_on_prop_respawned):
			_grid.prop_respawned.connect(_on_prop_respawned)


# --- Signal handlers ---

func _on_map_generated() -> void:
	_populate_all_visible_tiles()


func _on_prop_depleted(coords: Vector2i, prop_type: StringName) -> void:
	_swap_mesh_variant(coords, prop_type, true)


func _on_prop_respawned(coords: Vector2i, prop_type: StringName) -> void:
	_swap_mesh_variant(coords, prop_type, false)


# --- Prop management ---

func _populate_all_visible_tiles() -> void:
	if _grid == null:
		return
	var tiles: Dictionary = _grid._tiles if "_tiles" in _grid else {}
	for coords in tiles:
		var tile: Resource = tiles[coords]
		if tile == null:
			continue
		_add_props_for_tile(coords, false)


func _add_props_for_tile(coords: Vector2i, dimmed: bool) -> void:
	# Remove existing instances first (re-add with correct state)
	_remove_all_props_at(coords)

	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return

	for prop in tile.get_props():
		var pool_id: StringName = prop.type
		if not _pools.has(pool_id):
			continue
		var is_depleted: bool = prop.remaining <= 0
		_add_prop_instance(coords, prop, pool_id, dimmed, is_depleted)
	for anomaly in tile.get_anomalies():
		_add_anomaly_instance(coords, tile, anomaly, dimmed)


func _add_anomaly_instance(coords: Vector2i, tile: Resource, anomaly: Resource, dimmed: bool) -> void:
	# Find the anomaly pool — use anomaly_fragment type if it exists, otherwise skip
	var anomaly_pool_id: StringName = &"anomaly_fragment"
	if not _pools.has(anomaly_pool_id):
		return
	var mmi: MultiMeshInstance3D = _pools[anomaly_pool_id]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count
	if idx >= MAX_INSTANCES:
		return

	var world_2d: Vector2 = _HexMath.prop_world_position(coords, anomaly.sub_hex)
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	elif tile != null:
		elevation_y = float(tile.elevation) * 0.5
	var y_off: float = _pool_y_offsets.get(anomaly_pool_id, PROP_Y_OFFSET)
	var pos := Vector3(world_2d.x, elevation_y + y_off, world_2d.y)

	var xform := Transform3D.IDENTITY
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)
	mm.set_instance_custom_data(idx, Color(1.0 if dimmed else 0.0, 0.0, 0.0, 1.0))
	_update_pool_material(anomaly_pool_id, dimmed)

	if not _tile_entries.has(coords):
		_tile_entries[coords] = []
	_tile_entries[coords].append({
		"prop_type": &"anomaly",
		"pool": anomaly_pool_id,
		"instance_idx": idx,
		"depleted": false,
	})


func _add_prop_instance(coords: Vector2i, rn: Resource, pool_id: StringName, dimmed: bool, depleted: bool) -> void:
	if not _pools.has(pool_id):
		return

	var mmi: MultiMeshInstance3D = _pools[pool_id]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count

	if idx >= MAX_INSTANCES:
		return

	# Position: tile center + sub-hex offset + elevation
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(rn.sub_hex)
	var wx: float = world_2d.x + sub_hex_offset.x
	var wz: float = world_2d.y + sub_hex_offset.y
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(wx, wz)
	elif tile != null:
		elevation_y = float(tile.elevation) * 0.5
	var y_off: float = _pool_y_offsets.get(pool_id, PROP_Y_OFFSET)
	var pos := Vector3(wx, elevation_y + y_off, wz)

	# Apply rotation
	var xform := Transform3D.IDENTITY
	xform = xform.rotated(Vector3.UP, deg_to_rad(rn.rotation_deg))
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)

	# Custom data: channel 0 = dimmed flag (0.0 or 1.0), channel 1 = depleted flag
	var custom := Color(1.0 if dimmed else 0.0, 1.0 if depleted else 0.0, 0.0, 1.0)
	mm.set_instance_custom_data(idx, custom)

	# Update material color based on dimmed state
	_update_pool_material(pool_id, dimmed)

	if not _tile_entries.has(coords):
		_tile_entries[coords] = []
	_tile_entries[coords].append({
		"prop_type": rn.type,
		"pool": pool_id,
		"instance_idx": idx,
		"depleted": depleted,
	})


func _remove_all_props_at(coords: Vector2i) -> void:
	if not _tile_entries.has(coords):
		return
	while _tile_entries.has(coords) and not _tile_entries[coords].is_empty():
		var entries_list: Array = _tile_entries[coords]
		var info: Dictionary = entries_list[entries_list.size() - 1]
		_hide_instance(info.pool, info.instance_idx)
		entries_list.remove_at(entries_list.size() - 1)
	_tile_entries.erase(coords)


func _hide_instance(pool_id: StringName, instance_idx: int) -> void:
	if not _pools.has(pool_id):
		return
	var mmi: MultiMeshInstance3D = _pools[pool_id]
	var mm: MultiMesh = mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	var last_idx: int = mm.visible_instance_count - 1
	if instance_idx != last_idx:
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		var last_custom: Color = mm.get_instance_custom_data(last_idx)
		mm.set_instance_transform(instance_idx, last_xform)
		mm.set_instance_custom_data(instance_idx, last_custom)
		_update_instance_index(pool_id, last_idx, instance_idx)
	mm.visible_instance_count = last_idx


func _update_instance_index(pool_id: StringName, old_idx: int, new_idx: int) -> void:
	for coords in _tile_entries:
		var entries_list: Array = _tile_entries[coords]
		for info in entries_list:
			if info.pool == pool_id and info.instance_idx == old_idx:
				info.instance_idx = new_idx
				return


func _swap_mesh_variant(coords: Vector2i, prop_type: StringName, to_depleted: bool) -> void:
	if not _tile_entries.has(coords):
		return
	for info in _tile_entries[coords]:
		if info.prop_type == prop_type:
			info.depleted = to_depleted
			# Re-render tile to show swapped mesh
			_rebuild_tile(coords)
			return


func _rebuild_tile(coords: Vector2i) -> void:
	# Determine current fog state
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return
	var dimmed: bool = false
	_remove_all_props_at(coords)
	for prop in tile.get_props():
		var pool_id: StringName = prop.type
		if not _pools.has(pool_id):
			continue
		var is_depleted: bool = prop.remaining <= 0
		_add_prop_instance(coords, prop, pool_id, dimmed, is_depleted)


func _update_pool_material(pool_id: StringName, _dimmed: bool) -> void:
	# Material always uses full color. Darkness handled by shader.
	if not _pools.has(pool_id):
		return
	var mmi: MultiMeshInstance3D = _pools[pool_id]
	var mat: StandardMaterial3D = mmi.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = _pool_colors.get(pool_id, Color.WHITE)


# --- Public API (for testing) ---

func get_pool_visible_count(pool_id) -> int:
	# Accept both StringName and int for backward compatibility with tests
	if pool_id is int:
		# Legacy int index — convert to StringName by iterating pools
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return 0
		return _pools[keys[pool_id]].multimesh.visible_instance_count
	if not _pools.has(pool_id):
		return 0
	return _pools[pool_id].multimesh.visible_instance_count


func get_tile_entries() -> Dictionary:
	return _tile_entries


func get_pool_count() -> int:
	return _pools.size()


func get_pool_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _pools[keys[pool_id]].multimesh.mesh
	if not _pools.has(pool_id):
		return null
	return _pools[pool_id].multimesh.mesh


func get_normal_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _normal_meshes.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _normal_meshes[keys[pool_id]]
	return _normal_meshes.get(pool_id, null)


func get_depleted_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _depleted_meshes.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _depleted_meshes[keys[pool_id]]
	return _depleted_meshes.get(pool_id, null)


func get_pool_material_color(pool_id) -> Color:
	if pool_id is int:
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return Color.BLACK
		pool_id = keys[pool_id]
	if not _pools.has(pool_id):
		return Color.BLACK
	var mat: StandardMaterial3D = _pools[pool_id].material_override as StandardMaterial3D
	if mat == null:
		return Color.BLACK
	return mat.albedo_color
