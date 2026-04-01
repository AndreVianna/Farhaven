extends Node3D

## ElementIconRenderer — 5 MultiMeshInstance3D pools for element icons.
## Pools: unknown (question mark), flora, fauna, mineral, anomaly.
## Signal-driven: subscribes to ScannerSystem element_identified/element_unknown/
## entry_cataloged and HexGrid tile_visibility_changed signals.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Constants ---

## Y offset above tile surface for floating icons
const ICON_Y_OFFSET: float = 2.5

## Max instances per MultiMesh pool (Chapter 1: ~50 elements max)
const MAX_INSTANCES: int = 128

## Icon quad half-size (width and height of billboard quad)
const ICON_HALF_SIZE: float = 0.5

## Pool indices matching CatalogCategory + unknown at 0
enum Pool { UNKNOWN, FLORA, FAUNA, MINERAL, ANOMALY }

## Colors per pool
const POOL_COLORS: Dictionary = {
	Pool.UNKNOWN: Color(1.0, 1.0, 0.0, 1.0),   # Yellow question mark
	Pool.FLORA:   Color(0.2, 0.8, 0.2, 1.0),   # Green
	Pool.FAUNA:   Color(0.8, 0.2, 0.2, 1.0),   # Red
	Pool.MINERAL: Color(0.6, 0.6, 0.7, 1.0),   # Gray-blue
	Pool.ANOMALY: Color(0.7, 0.2, 0.9, 1.0),   # Purple
}

# --- State ---

## MultiMeshInstance3D nodes indexed by Pool enum
var _pools: Array = []  # Array of MultiMeshInstance3D

## Tile coords -> Array of {entry_id: StringName, pool: int, instance_idx: int}
var _tile_entries: Dictionary = {}

## entry_id -> pool index mapping for identified entries
var _entry_pool_map: Dictionary = {}

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
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(ICON_HALF_SIZE * 2.0, ICON_HALF_SIZE * 2.0)

	for i in range(5):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.instance_count = MAX_INSTANCES
		mm.visible_instance_count = 0
		mm.mesh = quad_mesh

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Pool_%d" % i

		# Material with billboard + pool color
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/icon_billboard.gdshader")
		mat.set_shader_parameter("icon_color", POOL_COLORS[i])
		mmi.material_override = mat

		add_child(mmi)
		_pools.append(mmi)


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
	if _scanner.has_signal("entry_cataloged"):
		if not _scanner.entry_cataloged.is_connected(_on_entry_cataloged):
			_scanner.entry_cataloged.connect(_on_entry_cataloged)


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
	if pool_idx == Pool.UNKNOWN:
		pool_idx = Pool.FLORA  # fallback
	_entry_pool_map[entry_id] = pool_idx
	_add_icon(coords, entry_id, pool_idx)


func _on_element_unknown(coords: Vector2i) -> void:
	_add_icon(coords, &"__unknown__", Pool.UNKNOWN)


func _on_entry_cataloged(entry_id: StringName, category: int) -> void:
	# Bulk swap: find all unknown icons matching this entry and move to identified pool
	var target_pool: int = _category_to_pool(category)
	_entry_pool_map[entry_id] = target_pool

	# Collect tiles that need swapping (coords only — we rebuild after removing)
	var swap_coords: Array[Vector2i] = []
	for coords in _tile_entries:
		var entries_list: Array = _tile_entries[coords]
		for info in entries_list:
			if info.pool == Pool.UNKNOWN:
				var tile = _grid.get_tile(coords) if _grid != null else null
				if tile != null and _tile_has_entry(tile, entry_id):
					swap_coords.append(coords)
					break  # one match per tile is enough

	# Process swaps: remove unknown, add identified
	for coords in swap_coords:
		# Find and remove the unknown entry for this tile
		if not _tile_entries.has(coords):
			continue
		var entries_list: Array = _tile_entries[coords]
		for i in range(entries_list.size() - 1, -1, -1):
			var info: Dictionary = entries_list[i]
			if info.pool == Pool.UNKNOWN:
				var tile = _grid.get_tile(coords) if _grid != null else null
				if tile != null and _tile_has_entry(tile, entry_id):
					_remove_icon_at(coords, i)
					break  # remove one unknown per tile per cataloged entry

		# Add identified icon
		_add_icon(coords, entry_id, target_pool)


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if state == _HexTile.FogState.REVEALED or state == _HexTile.FogState.HIDDEN:
		_remove_all_icons_at(coords)


# --- Icon management ---

func _add_icon(coords: Vector2i, entry_id: StringName, pool_idx: int) -> void:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return

	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count

	if idx >= MAX_INSTANCES:
		return

	# Position: tile center world coords + Y offset
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5
	var pos := Vector3(world_2d.x, elevation_y + ICON_Y_OFFSET, world_2d.y)

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


func _remove_icon_at(coords: Vector2i, list_index: int) -> void:
	if not _tile_entries.has(coords):
		return
	var entries_list: Array = _tile_entries[coords]
	if list_index < 0 or list_index >= entries_list.size():
		return

	var info: Dictionary = entries_list[list_index]
	var pool_idx: int = info.pool
	var instance_idx: int = info.instance_idx

	_hide_instance(pool_idx, instance_idx)
	entries_list.remove_at(list_index)
	if entries_list.is_empty():
		_tile_entries.erase(coords)


func _remove_all_icons_at(coords: Vector2i) -> void:
	if not _tile_entries.has(coords):
		return
	var entries_list: Array = _tile_entries[coords].duplicate()
	for info in entries_list:
		_hide_instance(info.pool, info.instance_idx)
	_tile_entries.erase(coords)


func _hide_instance(pool_idx: int, instance_idx: int) -> void:
	if pool_idx < 0 or pool_idx >= _pools.size():
		return
	var mmi: MultiMeshInstance3D = _pools[pool_idx]
	var mm: MultiMesh = mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	# Swap-and-pop: move last visible instance into this slot
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
	if _entry_pool_map.has(entry_id):
		return _entry_pool_map[entry_id]
	var catalog: RefCounted = _get_catalog()
	if catalog == null:
		return Pool.UNKNOWN
	var entry = catalog.get_entry(entry_id)
	if entry == null:
		return Pool.UNKNOWN
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
			return Pool.UNKNOWN


func _tile_has_entry(tile: Resource, entry_id: StringName) -> bool:
	for node in tile.resource_nodes:
		var mapped: StringName = _Catalog.RESOURCE_TO_ENTRY.get(node.type, &"")
		if mapped == entry_id:
			return true
	if tile.anomaly == entry_id:
		return true
	return false


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
