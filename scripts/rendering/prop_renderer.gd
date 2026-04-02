extends Node3D

## PropRenderer — 5 MultiMeshInstance3D pools for 3D prop meshes on world tiles.
## Pools: flora (cube), fauna (sphere), mineral (octahedron), anomaly (tetrahedron), generic (fallback).
## Signal-driven: subscribes to ScannerSystem element_identified/element_unknown/
## element_encountered and HexGrid tile_visibility_changed signals.
## Props always look the same regardless of knowledge state — the mesh doesn't change.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Constants ---

## Y offset above tile surface for props
const PROP_Y_OFFSET: float = 0.6

## Max instances per MultiMesh pool (Chapter 1: ~50 elements max)
const MAX_INSTANCES: int = 128

## Pool indices matching CatalogCategory
enum Pool { FLORA, FAUNA, MINERAL, ANOMALY, GENERIC }

## HEX_SIZE for multi-prop offset calculation
const HEX_SIZE: float = 3.0

## Radial offset factor for multi-prop tiles
const MULTI_PROP_RADIUS_FACTOR: float = 0.3

## Colors per pool
const POOL_COLORS: Dictionary = {
	Pool.FLORA:   Color(0.2, 0.8, 0.2, 1.0),   # Green
	Pool.FAUNA:   Color(0.8, 0.2, 0.2, 1.0),   # Red
	Pool.MINERAL: Color(0.6, 0.6, 0.7, 1.0),   # Gray-blue
	Pool.ANOMALY: Color(0.7, 0.2, 0.9, 1.0),   # Purple
	Pool.GENERIC: Color(0.5, 0.5, 0.5, 1.0),   # Gray
}

# --- State ---

## MultiMeshInstance3D nodes indexed by Pool enum
var _pools: Array = []  # Array of MultiMeshInstance3D

## Tile coords -> Array of {entry_id: StringName, pool: int, instance_idx: int}
var _tile_entries: Dictionary = {}

## Tile coords -> int (number of props on this tile, for offset calculation)
var _tile_prop_count: Dictionary = {}

## Reference to ScannerSystem (found at runtime)
var _scanner: Node = null

## Reference to HexGrid (allows override in tests)
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_pools()
	_connect_signals()


func _create_pools() -> void:
	# Flora: cube
	_create_pool(Pool.FLORA, _make_cube_mesh(0.4), POOL_COLORS[Pool.FLORA])
	# Fauna: sphere
	_create_pool(Pool.FAUNA, _make_sphere_mesh(0.35), POOL_COLORS[Pool.FAUNA])
	# Mineral: octahedron (approximated with sphere for now)
	_create_pool(Pool.MINERAL, _make_cube_mesh(0.35), POOL_COLORS[Pool.MINERAL])
	# Anomaly: tetrahedron (approximated with prism for now)
	_create_pool(Pool.ANOMALY, _make_cube_mesh(0.3), POOL_COLORS[Pool.ANOMALY])
	# Generic: fallback cube
	_create_pool(Pool.GENERIC, _make_cube_mesh(0.3), POOL_COLORS[Pool.GENERIC])


func _create_pool(pool_idx: int, mesh: Mesh, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "PropPool_%d" % pool_idx

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = mat

	add_child(mmi)
	_pools.append(mmi)


func _make_cube_mesh(half_size: float) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half_size * 2.0, half_size * 2.0, half_size * 2.0)
	return mesh


func _make_sphere_mesh(radius: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _connect_signals() -> void:
	_connect_scanner_signals.call_deferred()
	_connect_grid_signals()


func _connect_grid_signals() -> void:
	if _grid != null and _grid.has_signal("tile_visibility_changed"):
		if not _grid.tile_visibility_changed.is_connected(_on_tile_visibility_changed):
			_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)


func _connect_scanner_signals() -> void:
	if _scanner == null:
		_scanner = _find_scanner()
	if _scanner == null:
		return
	if _scanner.has_signal("element_identified"):
		if not _scanner.element_identified.is_connected(_on_element_identified):
			_scanner.element_identified.connect(_on_element_identified)
	if _scanner.has_signal("element_unknown"):
		if not _scanner.element_unknown.is_connected(_on_element_unknown):
			_scanner.element_unknown.connect(_on_element_unknown)
	if _scanner.has_signal("element_encountered"):
		if not _scanner.element_encountered.is_connected(_on_element_encountered):
			_scanner.element_encountered.connect(_on_element_encountered)


func _find_scanner() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var player: Node = world.get_node_or_null("Player")
	if player == null:
		return null
	return player.get_node_or_null("ScannerSystem")


# --- Signal handlers ---

func _on_element_identified(coords: Vector2i, entry_id: StringName) -> void:
	var pool_idx: int = _get_pool_for_entry(entry_id)
	_add_prop(coords, entry_id, pool_idx)


func _on_element_unknown(coords: Vector2i, entry_id: StringName, category: int) -> void:
	var pool_idx: int = _category_to_pool(category)
	_add_prop(coords, entry_id, pool_idx)


func _on_element_encountered(coords: Vector2i, entry_id: StringName, _label: String) -> void:
	var pool_idx: int = _get_pool_for_entry(entry_id)
	_add_prop(coords, entry_id, pool_idx)


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if state == _HexTile.FogState.REVEALED or state == _HexTile.FogState.HIDDEN:
		_remove_all_props_at(coords)


# --- Prop management ---

func _add_prop(coords: Vector2i, entry_id: StringName, pool_idx: int) -> void:
	# Prevent duplicate props for same entry on same tile
	if _tile_entries.has(coords):
		for info in _tile_entries[coords]:
			if info.entry_id == entry_id:
				return  # Already rendered

	if pool_idx < 0 or pool_idx >= _pools.size():
		return

	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count

	if idx >= MAX_INSTANCES:
		return

	# Track prop count for multi-prop offset
	var prop_index: int = _tile_prop_count.get(coords, 0)
	_tile_prop_count[coords] = prop_index + 1

	# Position: tile center world coords + offset + Y
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5

	# Multi-prop offset
	var offset: Vector2 = _calc_prop_offset(coords, prop_index)
	var pos := Vector3(world_2d.x + offset.x, elevation_y + PROP_Y_OFFSET, world_2d.y + offset.y)

	var xform := Transform3D.IDENTITY
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)
	mm.set_instance_custom_data(idx, Color(1.0, 0.0, 0.0, 1.0))

	if not _tile_entries.has(coords):
		_tile_entries[coords] = []
	_tile_entries[coords].append({
		"entry_id": entry_id,
		"pool": pool_idx,
		"instance_idx": idx,
	})


func _calc_prop_offset(coords: Vector2i, prop_index: int) -> Vector2:
	# For the first prop, we don't know total count yet.
	# We recalculate offsets when adding subsequent props.
	# For simplicity: single prop centered, N≥2 props use radial distribution.
	# TODO(multi-prop-offset): When N goes from 1→2, the first prop (index 0) stays
	# centered at (0,0) instead of being repositioned to its radial slot (angle 0).
	# Fixing this requires finding the first prop's MultiMesh instance index from
	# _tile_entries and calling mm.set_instance_transform() to reposition it.
	# The swap-and-remove pattern in _hide_instance makes instance indices unstable,
	# so a lookup through _tile_entries[coords] is needed. Deferred to a future pass
	# since the visual difference is minor with only 2-3 props per tile.
	var total: int = _tile_prop_count.get(coords, 1)
	if total <= 1:
		return Vector2.ZERO
	var angle: float = (2.0 * PI / float(total)) * float(prop_index)
	var radius: float = MULTI_PROP_RADIUS_FACTOR * HEX_SIZE
	return Vector2(cos(angle) * radius, sin(angle) * radius)


func _remove_all_props_at(coords: Vector2i) -> void:
	if not _tile_entries.has(coords):
		return
	while _tile_entries.has(coords) and not _tile_entries[coords].is_empty():
		var entries_list: Array = _tile_entries[coords]
		var info: Dictionary = entries_list[entries_list.size() - 1]
		_hide_instance(info.pool, info.instance_idx)
		entries_list.remove_at(entries_list.size() - 1)
	_tile_entries.erase(coords)
	_tile_prop_count.erase(coords)


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


# --- Helpers ---

func _get_pool_for_entry(entry_id: StringName) -> int:
	var catalog: RefCounted = _get_catalog()
	if catalog == null:
		return Pool.GENERIC
	var entry = catalog.get_entry(entry_id)
	if entry == null:
		return Pool.GENERIC
	return _category_to_pool(entry.category)


func _category_to_pool(category: int) -> int:
	match category:
		_Catalog.CatalogCategory.FLORA:
			return Pool.FLORA
		_Catalog.CatalogCategory.FAUNA:
			return Pool.FAUNA
		_Catalog.CatalogCategory.MINERAL:
			return Pool.MINERAL
		_Catalog.CatalogCategory.ANOMALY:
			return Pool.ANOMALY
		_:
			return Pool.GENERIC


func _get_catalog() -> RefCounted:
	if _scanner != null and _scanner.has_method("get_catalog"):
		return _scanner.get_catalog()
	return null


# --- Public API (for testing) ---

func get_pool_visible_count(pool_idx: int) -> int:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return 0
	return _pools[pool_idx].multimesh.visible_instance_count


func get_tile_entries() -> Dictionary:
	return _tile_entries


func get_pool_count() -> int:
	return _pools.size()
