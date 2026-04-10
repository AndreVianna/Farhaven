extends GdUnitTestSuite

## Unit tests for PropRenderer (task-019).
## Tests MultiMesh pool creation and prop instancing via map_generated.
## Pools are now keyed by StringName (prop type id) via PropRegistry.

const _PropRenderer = preload("res://scripts/rendering/prop_renderer.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal prop_depleted(coords: Vector2i, prop_type: StringName)
	signal prop_respawned(coords: Vector2i, prop_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)

	func get_all_tiles() -> Dictionary:
		return _tiles

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_tile_count() -> int:
		return _tiles.size()


# --- Test state ---

var _renderer: Node3D
var _grid: FakeGrid


func _make_tile(prop_type: StringName, remaining: int = 3, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.props = [_Prop.create_prop(prop_type, remaining, 3)]
	return tile


func _make_tile_multi(types: Array) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	var props_arr: Array = []
	for t in types:
		props_arr.append(_Prop.create_prop(t, 3, 3))
	tile.props = props_arr
	return tile


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_renderer = _PropRenderer.new()
	_renderer.name = "PropRenderer"
	_renderer._grid = _grid
	add_child(_renderer)


func after_test() -> void:
	if is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_renderer = null
	_grid = null


# ===========================================
# Pool creation tests
# ===========================================

func test_pools_created_for_all_prop_defs() -> void:
	# PropRegistry should have 9 defs, so 9 pools
	assert_int(_renderer.get_pool_count()).is_equal(PropRegistry.get_all().size())


func test_pools_have_zero_visible_instances_initially() -> void:
	for def in PropRegistry.get_all():
		assert_int(_renderer.get_pool_visible_count(def.id)).is_equal(0)


func test_wood_pool_uses_cylinder_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00010")
	assert_bool(mesh is CylinderMesh).is_true()


func test_stone_pool_uses_box_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00013")
	assert_bool(mesh is BoxMesh).is_true()


func test_berries_pool_uses_sphere_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00020")
	assert_bool(mesh is SphereMesh).is_true()


func test_fiber_pool_uses_box_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00012")
	assert_bool(mesh is BoxMesh).is_true()


func test_ore_pool_mesh_exists() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00014")
	assert_bool(mesh != null).is_true()


func test_crystal_pool_mesh_exists() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"P00015")
	assert_bool(mesh != null).is_true()


# ===========================================
# map_generated instancing tests
# ===========================================

func test_map_generated_populates_tile() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"P00010")

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"P00010")).is_equal(1)


func test_map_generated_populates_all_tiles() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00010")
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"P00013")
	_grid._tiles[Vector2i(2, 0)] = _make_tile(&"P00020")

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"P00010")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"P00013")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"P00020")).is_equal(1)


# ===========================================
# Resource type → pool mapping tests
# ===========================================

func test_wood_maps_to_wood_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00010")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00010")).is_equal(1)


func test_stone_maps_to_stone_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00013")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00013")).is_equal(1)


func test_berries_maps_to_berries_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00020")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00020")).is_equal(1)


func test_fiber_maps_to_fiber_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00012")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00012")).is_equal(1)


func test_ore_maps_to_ore_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00014")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00014")).is_equal(1)


func test_crystal_maps_to_crystal_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00015")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00015")).is_equal(1)


func test_loose_rock_maps_to_loose_rock_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"P00011")
	_grid.map_generated.emit()
	assert_int(_renderer.get_pool_visible_count(&"P00011")).is_equal(1)


# ===========================================
# Multi-prop tile tests
# ===========================================

func test_multi_prop_tile() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile_multi([&"P00010", &"P00020"])

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"P00010")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"P00020")).is_equal(1)
	var entries: Dictionary = _renderer.get_tile_entries()
	assert_int(entries[Vector2i(0, 0)].size()).is_equal(2)


# ===========================================
# Depleted/respawned mesh swap tests
# ===========================================

func test_prop_depleted_marks_entry() -> void:
	var tile: HexTile = _make_tile(&"P00010")
	_grid._tiles[Vector2i(0, 0)] = tile
	_grid.map_generated.emit()

	# Deplete the prop
	tile.props[0].remaining = 0
	_grid.prop_depleted.emit(Vector2i(0, 0), &"P00010")

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries[Vector2i(0, 0)][0].depleted).is_true()


func test_prop_respawned_clears_depleted() -> void:
	var tile: HexTile = _make_tile(&"P00013")
	_grid._tiles[Vector2i(0, 0)] = tile
	_grid.map_generated.emit()

	tile.props[0].remaining = 0
	_grid.prop_depleted.emit(Vector2i(0, 0), &"P00013")

	tile.props[0].remaining = 3
	_grid.prop_respawned.emit(Vector2i(0, 0), &"P00013")

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries[Vector2i(0, 0)][0].depleted).is_false()


func test_depleted_meshes_exist_for_all_pools() -> void:
	for def in PropRegistry.get_all():
		assert_bool(_renderer.get_depleted_mesh(def.id) != null).is_true()


func test_normal_meshes_exist_for_all_pools() -> void:
	for def in PropRegistry.get_all():
		assert_bool(_renderer.get_normal_mesh(def.id) != null).is_true()


# ===========================================
# Positioning tests
# ===========================================

func test_prop_with_offset_creates_entry() -> void:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.props = [_Prop.create_prop(&"P00020", 3, 3, &"", 0.0, 45.0, Vector2i(1, -1))]
	_grid._tiles[Vector2i(0, 0)] = tile

	_grid.map_generated.emit()

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(0, 0))).is_true()
	assert_int(entries[Vector2i(0, 0)].size()).is_equal(1)


func test_unknown_prop_type_not_instanced() -> void:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.props = [_Prop.create_prop(&"unknown_thing", 3, 3)]
	_grid._tiles[Vector2i(0, 0)] = tile

	_grid.map_generated.emit()

	for def in PropRegistry.get_all():
		assert_int(_renderer.get_pool_visible_count(def.id)).is_equal(0)


# ===========================================
# Draw calls estimate
# ===========================================

func test_draw_calls_prop_pools() -> void:
	assert_int(_renderer.get_pool_count()).is_equal(PropRegistry.get_all().size())
