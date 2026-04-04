extends GdUnitTestSuite

## Unit tests for GroundItemRenderer (task-030).
## Tests MultiMesh pool, signal-driven add/remove, fog awareness, partial pickup.

const _GroundItemRenderer = preload("res://scripts/survival/ground_item_renderer.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal tile_visibility_changed(coords: Vector2i, state: int)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)


class FakeSurvival extends Node:
	var _ground_items: Array[Dictionary] = []
	signal ground_item_dropped(tile: Vector2i, item_type: StringName, count: int)
	signal ground_item_picked_up(tile: Vector2i, item_type: StringName, count: int)

	func get_ground_items_at(tile: Vector2i) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for entry: Dictionary in _ground_items:
			if entry["tile"] == tile:
				result.append(entry)
		return result

	func add_item(tile: Vector2i, item_type: StringName, count: int) -> void:
		_ground_items.append({"tile": tile, "item_type": item_type, "count": count})

	func remove_item(tile: Vector2i, item_type: StringName) -> void:
		for i in range(_ground_items.size() - 1, -1, -1):
			if _ground_items[i]["tile"] == tile and _ground_items[i]["item_type"] == item_type:
				_ground_items.remove_at(i)
				return


# --- Test state ---

var _renderer: Node3D
var _grid: FakeGrid
var _survival: FakeSurvival


func _make_tile(fog: int = _HexTile.FogState.VISIBLE, elev: int = 0) -> HexTile:
	var tile := HexTile.new()
	tile.fog_state = fog
	tile.elevation = elev
	return tile


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_survival = FakeSurvival.new()
	add_child(_survival)

	_renderer = _GroundItemRenderer.new()
	_renderer.name = "GroundItemRenderer"
	_renderer._grid = _grid
	add_child(_renderer)
	_renderer.connect_survival(_survival)


func after_test() -> void:
	if is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	if is_instance_valid(_survival):
		remove_child(_survival)
		_survival.queue_free()
	_renderer = null
	_grid = null
	_survival = null


# ===========================================
# Pool creation tests
# ===========================================

func test_pool_created_with_zero_visible() -> void:
	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_single_multimesh_instance() -> void:
	# Should have exactly one MultiMeshInstance3D child
	var count: int = 0
	for child in _renderer.get_children():
		if child is MultiMeshInstance3D:
			count += 1
	assert_int(count).is_equal(1)


# ===========================================
# Drop / pickup signal tests
# ===========================================

func test_drop_adds_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)

	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_drop_same_tile_twice_only_one_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.add_item(Vector2i(1, 0), &"stone", 3)

	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"stone", 3)

	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_drop_different_tiles_two_markers() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_grid._tiles[Vector2i(2, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.add_item(Vector2i(2, 0), &"stone", 3)

	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(2, 0), &"stone", 3)

	assert_int(_renderer.get_visible_count()).is_equal(2)


func test_full_pickup_removes_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	assert_int(_renderer.get_visible_count()).is_equal(1)

	# Remove all items, then emit pickup
	_survival.remove_item(Vector2i(1, 0), &"berries")
	_survival.ground_item_picked_up.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_partial_pickup_keeps_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.add_item(Vector2i(1, 0), &"stone", 3)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)

	# Remove only berries, stone remains
	_survival.remove_item(Vector2i(1, 0), &"berries")
	_survival.ground_item_picked_up.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(1)


# ===========================================
# Fog awareness tests
# ===========================================

func test_hidden_tile_no_marker_on_drop() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(_HexTile.FogState.HIDDEN)
	_survival.add_item(Vector2i(1, 0), &"berries", 5)

	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_revealed_tile_shows_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(_HexTile.FogState.REVEALED)
	_survival.add_item(Vector2i(1, 0), &"berries", 5)

	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_visibility_hidden_removes_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	assert_int(_renderer.get_visible_count()).is_equal(1)

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.HIDDEN)

	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_visibility_visible_restores_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(_HexTile.FogState.HIDDEN)
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	assert_int(_renderer.get_visible_count()).is_equal(0)

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)

	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_visibility_revealed_restores_marker() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile(_HexTile.FogState.HIDDEN)
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	assert_int(_renderer.get_visible_count()).is_equal(0)

	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.REVEALED)

	assert_int(_renderer.get_visible_count()).is_equal(1)


# ===========================================
# Instance swap-on-remove test
# ===========================================

func test_remove_first_of_two_swaps_correctly() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile()
	_grid._tiles[Vector2i(2, 0)] = _make_tile()
	_survival.add_item(Vector2i(1, 0), &"berries", 5)
	_survival.add_item(Vector2i(2, 0), &"stone", 3)
	_survival.ground_item_dropped.emit(Vector2i(1, 0), &"berries", 5)
	_survival.ground_item_dropped.emit(Vector2i(2, 0), &"stone", 3)
	assert_int(_renderer.get_visible_count()).is_equal(2)

	# Remove first tile's items
	_survival.remove_item(Vector2i(1, 0), &"berries")
	_survival.ground_item_picked_up.emit(Vector2i(1, 0), &"berries", 5)

	assert_int(_renderer.get_visible_count()).is_equal(1)
	# Second tile should still be tracked
	var instances: Dictionary = _renderer.get_tile_instances()
	assert_bool(instances.has(Vector2i(2, 0))).is_true()
	assert_bool(instances.has(Vector2i(1, 0))).is_false()


# ===========================================
# Max instances test
# ===========================================

func test_max_instances_cap() -> void:
	for i in range(12):
		var coords := Vector2i(i, 0)
		_grid._tiles[coords] = _make_tile()
		_survival.add_item(coords, &"berries", 1)
		_survival.ground_item_dropped.emit(coords, &"berries", 1)

	# Capped at MAX_INSTANCES (10)
	assert_int(_renderer.get_visible_count()).is_equal(10)
