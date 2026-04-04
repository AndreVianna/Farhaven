extends GdUnitTestSuite

## Unit tests for ResourceRenderer (task-019).
## Tests MultiMesh pool creation, fog-driven instancing, depleted/respawned mesh swaps.
## Pools are now keyed by StringName (resource type id) via ResourceRegistry.

const _ResourceRenderer = preload("res://scripts/rendering/resource_renderer.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal tile_visibility_changed(coords: Vector2i, state: int)
	signal resource_depleted(coords: Vector2i, resource_type: StringName)
	signal resource_respawned(coords: Vector2i, resource_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)


# --- Test state ---

var _renderer: Node3D
var _grid: FakeGrid


func _make_tile(resource_type: StringName, remaining: int = 3, elev: int = 0, fog: int = _HexTile.FogState.VISIBLE) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.fog_state = fog
	var prop: Prop = _Prop.new()
	prop.type = resource_type
	prop.category = Prop.Category.RESOURCE
	prop.remaining = remaining
	prop.max_amount = 3
	prop.sub_hex = Vector2i.ZERO
	tile.props = [prop]
	return tile


func _make_tile_multi(types: Array, fog: int = _HexTile.FogState.VISIBLE) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.fog_state = fog
	var props_arr: Array = []
	for t in types:
		var prop: Prop = _Prop.new()
		prop.type = t
		prop.category = Prop.Category.RESOURCE
		prop.remaining = 3
		prop.max_amount = 3
		prop.sub_hex = Vector2i.ZERO
		props_arr.append(prop)
	tile.props = props_arr
	return tile


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_renderer = _ResourceRenderer.new()
	_renderer.name = "ResourceRenderer"
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

func test_pools_created_for_all_resource_defs() -> void:
	# ResourceRegistry should have 9 defs, so 9 pools
	assert_int(_renderer.get_pool_count()).is_equal(ResourceRegistry.get_all().size())


func test_pools_have_zero_visible_instances_initially() -> void:
	for def in ResourceRegistry.get_all():
		assert_int(_renderer.get_pool_visible_count(def.id)).is_equal(0)


func test_wood_pool_uses_cylinder_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"wood")
	assert_bool(mesh is CylinderMesh).is_true()


func test_stone_pool_uses_box_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"stone")
	assert_bool(mesh is BoxMesh).is_true()


func test_berries_pool_uses_sphere_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"berries")
	assert_bool(mesh is SphereMesh).is_true()


func test_fiber_pool_uses_box_mesh() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"fiber")
	assert_bool(mesh is BoxMesh).is_true()


func test_ore_pool_mesh_exists() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"ore")
	assert_bool(mesh != null).is_true()


func test_crystal_pool_mesh_exists() -> void:
	var mesh: Mesh = _renderer.get_pool_mesh(&"crystal")
	assert_bool(mesh != null).is_true()


# ===========================================
# Fog-driven instancing tests
# ===========================================

func test_visible_tile_adds_resource_on_visibility_changed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood")

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)


func test_revealed_tile_adds_resource_dimmed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"stone")

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.REVEALED)

	assert_int(_renderer.get_pool_visible_count(&"stone")).is_equal(1)


func test_hidden_tile_removes_resources() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood")
	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.HIDDEN)

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(0)


func test_hidden_tile_not_instanced() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 3, 0, _HexTile.FogState.HIDDEN)

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(0)


func test_map_generated_populates_visible_tiles() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"wood", 3, 0, _HexTile.FogState.VISIBLE)
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"stone", 3, 0, _HexTile.FogState.VISIBLE)
	_grid._tiles[Vector2i(2, 0)] = _make_tile(&"berries", 3, 0, _HexTile.FogState.HIDDEN)

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"stone")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"berries")).is_equal(0)


func test_map_generated_populates_revealed_tiles() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"fiber", 3, 0, _HexTile.FogState.REVEALED)

	_grid.map_generated.emit()

	assert_int(_renderer.get_pool_visible_count(&"fiber")).is_equal(1)


# ===========================================
# Resource type → pool mapping tests
# ===========================================

func test_wood_maps_to_wood_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"wood")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)


func test_stone_maps_to_stone_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"stone")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"stone")).is_equal(1)


func test_berries_maps_to_berries_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"berries")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"berries")).is_equal(1)


func test_fiber_maps_to_fiber_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"fiber")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"fiber")).is_equal(1)


func test_ore_maps_to_ore_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"ore")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"ore")).is_equal(1)


func test_crystal_maps_to_crystal_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"crystal")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"crystal")).is_equal(1)


func test_loose_rock_maps_to_loose_rock_pool() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"loose_rock")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"loose_rock")).is_equal(1)


# ===========================================
# Multi-resource tile tests
# ===========================================

func test_multi_resource_tile() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile_multi([&"wood", &"berries"])

	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(&"berries")).is_equal(1)
	var entries: Dictionary = _renderer.get_tile_entries()
	assert_int(entries[Vector2i(0, 0)].size()).is_equal(2)


# ===========================================
# Depleted/respawned mesh swap tests
# ===========================================

func test_resource_depleted_marks_entry() -> void:
	var tile: HexTile = _make_tile(&"wood")
	_grid._tiles[Vector2i(0, 0)] = tile
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)

	# Deplete the resource
	tile.props[0].remaining = 0
	_grid.resource_depleted.emit(Vector2i(0, 0), &"wood")

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries[Vector2i(0, 0)][0].depleted).is_true()


func test_resource_respawned_clears_depleted() -> void:
	var tile: HexTile = _make_tile(&"stone")
	_grid._tiles[Vector2i(0, 0)] = tile
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)

	tile.props[0].remaining = 0
	_grid.resource_depleted.emit(Vector2i(0, 0), &"stone")

	tile.props[0].remaining = 3
	_grid.resource_respawned.emit(Vector2i(0, 0), &"stone")

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries[Vector2i(0, 0)][0].depleted).is_false()


func test_depleted_meshes_exist_for_all_pools() -> void:
	for def in ResourceRegistry.get_all():
		assert_bool(_renderer.get_depleted_mesh(def.id) != null).is_true()


func test_normal_meshes_exist_for_all_pools() -> void:
	for def in ResourceRegistry.get_all():
		assert_bool(_renderer.get_normal_mesh(def.id) != null).is_true()


# ===========================================
# Positioning tests
# ===========================================

func test_resource_with_offset_creates_entry() -> void:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.fog_state = _HexTile.FogState.VISIBLE
	var prop: Prop = _Prop.new()
	prop.type = &"berries"
	prop.category = Prop.Category.RESOURCE
	prop.remaining = 3
	prop.max_amount = 3
	prop.sub_hex = Vector2i(1, -1)
	prop.rotation_deg = 45.0
	tile.props = [prop]
	_grid._tiles[Vector2i(0, 0)] = tile

	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(0, 0))).is_true()
	assert_int(entries[Vector2i(0, 0)].size()).is_equal(1)


func test_unknown_resource_type_not_instanced() -> void:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.fog_state = _HexTile.FogState.VISIBLE
	var prop: Prop = _Prop.new()
	prop.type = &"unknown_thing"
	prop.category = Prop.Category.RESOURCE
	prop.remaining = 3
	prop.max_amount = 3
	prop.sub_hex = Vector2i.ZERO
	tile.props = [prop]
	_grid._tiles[Vector2i(0, 0)] = tile

	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)

	for def in ResourceRegistry.get_all():
		assert_int(_renderer.get_pool_visible_count(def.id)).is_equal(0)


# ===========================================
# Swap-and-remove instance management tests
# ===========================================

func test_swap_and_remove_preserves_other_instances() -> void:
	# Add resources on two tiles
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"wood")
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood")

	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(2)

	# Remove first tile's resource
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.HIDDEN)

	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)
	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(1, 0))).is_true()
	assert_bool(not entries.has(Vector2i(0, 0))).is_true()


# ===========================================
# Draw calls estimate
# ===========================================

func test_draw_calls_resource_pools() -> void:
	assert_int(_renderer.get_pool_count()).is_equal(ResourceRegistry.get_all().size())


# ===========================================
# Visibility transition tests
# ===========================================

func test_visible_to_revealed_keeps_instances() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"wood")
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.VISIBLE)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)

	# Transition to REVEALED — should keep instance (dimmed)
	_grid._tiles[Vector2i(0, 0)].fog_state = _HexTile.FogState.REVEALED
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.REVEALED)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)


func test_revealed_to_hidden_removes_instances() -> void:
	_grid._tiles[Vector2i(0, 0)] = _make_tile(&"wood", 3, 0, _HexTile.FogState.REVEALED)
	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.REVEALED)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(1)

	_grid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.HIDDEN)
	assert_int(_renderer.get_pool_visible_count(&"wood")).is_equal(0)
