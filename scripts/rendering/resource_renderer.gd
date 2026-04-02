extends Node3D

## ResourceRenderer — 6 MultiMeshInstance3D pools for 3D resource meshes.
## Pools: wood (green cylinder), stone (gray cube), berries (red sphere),
##        fiber (yellow-green box), ore (dark gray octahedron), crystal (cyan prism).
## Signal-driven: subscribes to HexGrid map_generated, tile_visibility_changed,
## resource_depleted, resource_respawned signals.
## Fog: HIDDEN=not instanced, REVEALED=dimmed (0.4 alpha), VISIBLE=full.
## On resource_depleted: swap mesh variant (tree→stump, rock→rubble).
## On resource_respawned: swap back to original mesh.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")

# --- Constants ---

## Y offset above tile surface for resource meshes
const RESOURCE_Y_OFFSET: float = 0.6

## Max instances per MultiMesh pool (Chapter 1: ~50 elements max)
const MAX_INSTANCES: int = 128

## HEX_SIZE for offset calculation
const HEX_SIZE: float = 3.0

## Resource type pool indices
enum Pool { WOOD, STONE, BERRIES, FIBER, ORE, CRYSTAL }

## Map resource type StringName to Pool index
const TYPE_TO_POOL: Dictionary = {
	&"wood":    Pool.WOOD,
	&"stone":   Pool.STONE,
	&"berries": Pool.BERRIES,
	&"fiber":   Pool.FIBER,
	&"ore":     Pool.ORE,
	&"crystal": Pool.CRYSTAL,
}

## Colors per pool
const POOL_COLORS: Dictionary = {
	Pool.WOOD:    Color(0.2, 0.7, 0.2, 1.0),   # Green
	Pool.STONE:   Color(0.6, 0.6, 0.6, 1.0),   # Gray
	Pool.BERRIES: Color(0.8, 0.15, 0.15, 1.0),  # Red
	Pool.FIBER:   Color(0.6, 0.75, 0.2, 1.0),   # Yellow-green
	Pool.ORE:     Color(0.35, 0.35, 0.4, 1.0),  # Dark gray
	Pool.CRYSTAL: Color(0.2, 0.8, 0.85, 1.0),   # Cyan
}

## Dimmed colors for REVEALED fog state (lower alpha feel via darker tint)
const POOL_COLORS_DIMMED: Dictionary = {
	Pool.WOOD:    Color(0.12, 0.4, 0.12, 1.0),
	Pool.STONE:   Color(0.35, 0.35, 0.35, 1.0),
	Pool.BERRIES: Color(0.45, 0.1, 0.1, 1.0),
	Pool.FIBER:   Color(0.35, 0.42, 0.12, 1.0),
	Pool.ORE:     Color(0.2, 0.2, 0.22, 1.0),
	Pool.CRYSTAL: Color(0.12, 0.45, 0.48, 1.0),
}

# --- State ---

## MultiMeshInstance3D nodes indexed by Pool enum
var _pools: Array = []  # Array of MultiMeshInstance3D

## Depleted mesh variants per pool (stump, rubble, etc.)
var _depleted_meshes: Dictionary = {}

## Normal mesh variants per pool (originals)
var _normal_meshes: Dictionary = {}

## Tile coords -> Array of {resource_type: StringName, pool: int, instance_idx: int, depleted: bool}
var _tile_entries: Dictionary = {}

## Reference to HexGrid (allows override in tests)
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_pools()
	_connect_signals()


func _create_pools() -> void:
	# Wood: green cylinder (tree)
	var wood_mesh := _make_cylinder_mesh(0.2, 0.8)
	_create_pool(Pool.WOOD, wood_mesh, POOL_COLORS[Pool.WOOD])
	_normal_meshes[Pool.WOOD] = wood_mesh
	_depleted_meshes[Pool.WOOD] = _make_cylinder_mesh(0.25, 0.25)  # stump

	# Stone: gray cube (rock)
	var stone_mesh := _make_cube_mesh(0.35)
	_create_pool(Pool.STONE, stone_mesh, POOL_COLORS[Pool.STONE])
	_normal_meshes[Pool.STONE] = stone_mesh
	_depleted_meshes[Pool.STONE] = _make_cube_mesh(0.15)  # rubble

	# Berries: red sphere (bush)
	var berry_mesh := _make_sphere_mesh(0.3)
	_create_pool(Pool.BERRIES, berry_mesh, POOL_COLORS[Pool.BERRIES])
	_normal_meshes[Pool.BERRIES] = berry_mesh
	_depleted_meshes[Pool.BERRIES] = _make_sphere_mesh(0.15)  # picked bush

	# Fiber: yellow-green low box (grass)
	var fiber_mesh := _make_box_mesh(Vector3(0.5, 0.15, 0.5))
	_create_pool(Pool.FIBER, fiber_mesh, POOL_COLORS[Pool.FIBER])
	_normal_meshes[Pool.FIBER] = fiber_mesh
	_depleted_meshes[Pool.FIBER] = _make_box_mesh(Vector3(0.4, 0.05, 0.4))  # cut grass

	# Ore: dark gray octahedron (vein)
	var ore_mesh := _make_octahedron_mesh(0.35)
	_create_pool(Pool.ORE, ore_mesh, POOL_COLORS[Pool.ORE])
	_normal_meshes[Pool.ORE] = ore_mesh
	_depleted_meshes[Pool.ORE] = _make_cube_mesh(0.12)  # rubble

	# Crystal: cyan prism (cluster)
	var crystal_mesh := _make_prism_mesh(0.2, 0.7)
	_create_pool(Pool.CRYSTAL, crystal_mesh, POOL_COLORS[Pool.CRYSTAL])
	_normal_meshes[Pool.CRYSTAL] = crystal_mesh
	_depleted_meshes[Pool.CRYSTAL] = _make_prism_mesh(0.12, 0.25)  # broken shard


func _create_pool(pool_idx: int, mesh: Mesh, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "ResourcePool_%d" % pool_idx

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = mat

	add_child(mmi)
	_pools.append(mmi)


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
	if _grid.has_signal("tile_visibility_changed"):
		if not _grid.tile_visibility_changed.is_connected(_on_tile_visibility_changed):
			_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)
	if _grid.has_signal("resource_depleted"):
		if not _grid.resource_depleted.is_connected(_on_resource_depleted):
			_grid.resource_depleted.connect(_on_resource_depleted)
	if _grid.has_signal("resource_respawned"):
		if not _grid.resource_respawned.is_connected(_on_resource_respawned):
			_grid.resource_respawned.connect(_on_resource_respawned)


# --- Signal handlers ---

func _on_map_generated() -> void:
	_populate_all_visible_tiles()


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	match state:
		_HexTile.FogState.VISIBLE:
			_add_resources_for_tile(coords, false)
		_HexTile.FogState.REVEALED:
			_add_resources_for_tile(coords, true)
		_HexTile.FogState.HIDDEN:
			_remove_all_resources_at(coords)


func _on_resource_depleted(coords: Vector2i, resource_type: StringName) -> void:
	_swap_mesh_variant(coords, resource_type, true)


func _on_resource_respawned(coords: Vector2i, resource_type: StringName) -> void:
	_swap_mesh_variant(coords, resource_type, false)


# --- Resource management ---

func _populate_all_visible_tiles() -> void:
	if _grid == null:
		return
	var tiles: Dictionary = _grid._tiles if "_tiles" in _grid else {}
	for coords in tiles:
		var tile: Resource = tiles[coords]
		if tile == null:
			continue
		match tile.fog_state:
			_HexTile.FogState.VISIBLE:
				_add_resources_for_tile(coords, false)
			_HexTile.FogState.REVEALED:
				_add_resources_for_tile(coords, true)
			# HIDDEN: skip


func _add_resources_for_tile(coords: Vector2i, dimmed: bool) -> void:
	# Remove existing instances first (re-add with correct state)
	_remove_all_resources_at(coords)

	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return

	for rn in tile.resource_nodes:
		var pool_idx: int = TYPE_TO_POOL.get(rn.type, -1)
		if pool_idx < 0:
			continue
		var is_depleted: bool = rn.remaining <= 0
		_add_resource_instance(coords, rn, pool_idx, dimmed, is_depleted)


func _add_resource_instance(coords: Vector2i, rn: Resource, pool_idx: int, dimmed: bool, depleted: bool) -> void:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return

	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count

	if idx >= MAX_INSTANCES:
		return

	# Position: tile center + resource offset + elevation
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5

	var world_offset: Vector2 = _PropUtils.offset_to_world(rn.offset, HEX_SIZE)
	var pos := Vector3(world_2d.x + world_offset.x, elevation_y + RESOURCE_Y_OFFSET, world_2d.y + world_offset.y)

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
	_update_pool_material(pool_idx, dimmed)

	if not _tile_entries.has(coords):
		_tile_entries[coords] = []
	_tile_entries[coords].append({
		"resource_type": rn.type,
		"pool": pool_idx,
		"instance_idx": idx,
		"depleted": depleted,
	})


func _remove_all_resources_at(coords: Vector2i) -> void:
	if not _tile_entries.has(coords):
		return
	while _tile_entries.has(coords) and not _tile_entries[coords].is_empty():
		var entries_list: Array = _tile_entries[coords]
		var info: Dictionary = entries_list[entries_list.size() - 1]
		_hide_instance(info.pool, info.instance_idx)
		entries_list.remove_at(entries_list.size() - 1)
	_tile_entries.erase(coords)


func _hide_instance(pool_idx: int, instance_idx: int) -> void:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return
	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mm: MultiMesh = mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	var last_idx: int = mm.visible_instance_count - 1
	if instance_idx != last_idx:
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		var last_custom: Color = mm.get_instance_custom_data(last_idx)
		mm.set_instance_transform(instance_idx, last_xform)
		mm.set_instance_custom_data(instance_idx, last_custom)
		_update_instance_index(pool_idx, last_idx, instance_idx)
	mm.visible_instance_count = last_idx


func _update_instance_index(pool_idx: int, old_idx: int, new_idx: int) -> void:
	for coords in _tile_entries:
		var entries_list: Array = _tile_entries[coords]
		for info in entries_list:
			if info.pool == pool_idx and info.instance_idx == old_idx:
				info.instance_idx = new_idx
				return


func _swap_mesh_variant(coords: Vector2i, resource_type: StringName, to_depleted: bool) -> void:
	if not _tile_entries.has(coords):
		return
	for info in _tile_entries[coords]:
		if info.resource_type == resource_type:
			info.depleted = to_depleted
			# Re-render tile to show swapped mesh
			_rebuild_tile(coords)
			return


func _rebuild_tile(coords: Vector2i) -> void:
	# Determine current fog state
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return
	var dimmed: bool = tile.fog_state == _HexTile.FogState.REVEALED
	_remove_all_resources_at(coords)
	for rn in tile.resource_nodes:
		var pool_idx: int = TYPE_TO_POOL.get(rn.type, -1)
		if pool_idx < 0:
			continue
		var is_depleted: bool = rn.remaining <= 0
		_add_resource_instance(coords, rn, pool_idx, dimmed, is_depleted)


func _update_pool_material(pool_idx: int, dimmed: bool) -> void:
	# Material reflects the most recent add — in practice, tiles at the same
	# fog level share a pool, so this works for placeholder rendering.
	# Full per-instance coloring would use custom_data in a shader.
	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mat: StandardMaterial3D = mmi.material_override as StandardMaterial3D
	if mat == null:
		return
	if dimmed:
		mat.albedo_color = POOL_COLORS_DIMMED.get(pool_idx, POOL_COLORS[pool_idx])
	else:
		mat.albedo_color = POOL_COLORS[pool_idx]


# --- Public API (for testing) ---

func get_pool_visible_count(pool_idx: int) -> int:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return 0
	return _pools[pool_idx].multimesh.visible_instance_count


func get_tile_entries() -> Dictionary:
	return _tile_entries


func get_pool_count() -> int:
	return _pools.size()


func get_pool_mesh(pool_idx: int) -> Mesh:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return null
	return _pools[pool_idx].multimesh.mesh


func get_normal_mesh(pool_idx: int) -> Mesh:
	return _normal_meshes.get(pool_idx, null)


func get_depleted_mesh(pool_idx: int) -> Mesh:
	return _depleted_meshes.get(pool_idx, null)


func get_pool_material_color(pool_idx: int) -> Color:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return Color.BLACK
	var mat: StandardMaterial3D = _pools[pool_idx].material_override as StandardMaterial3D
	if mat == null:
		return Color.BLACK
	return mat.albedo_color
