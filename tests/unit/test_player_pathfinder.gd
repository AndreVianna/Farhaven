class_name TestPlayerPathfinder
extends GdUnitTestSuite

const _PlayerPathfinder = preload("res://scripts/player/player_pathfinder.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")


## Minimal mock grid for pathfinding tests.
class MockGrid extends Node:
	signal map_generated
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	var _tiles: Dictionary = {}
	var _blocked: Dictionary = {}  # coords -> true means impassable

	func add_tile(coords: Vector2i) -> void:
		_tiles[coords] = _HexTile.new()
		_tiles[coords].coords = coords

	func axial_to_world(coords: Vector2i) -> Vector2:
		return _HexMath.axial_to_world(coords)

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		return _HexMath.get_neighbors(coords)

	func is_passable(_from: Vector2i, to: Vector2i) -> bool:
		if not _tiles.has(to):
			return false
		return not _blocked.has(to)


var _grid: MockGrid
var _pathfinder: _PlayerPathfinder


func before_test() -> void:
	_grid = MockGrid.new()
	add_child(_grid)
	_pathfinder = _PlayerPathfinder.new()


func after_test() -> void:
	if is_instance_valid(_grid):
		_grid.queue_free()
	_pathfinder = null


# --- Setup and build ---

func test_find_path_empty_grid_returns_empty() -> void:
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_int(path.size()).is_equal(0)


func test_find_path_single_tile_to_itself() -> void:
	_grid.add_tile(Vector2i(0, 0))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(0, 0))
	assert_int(path.size()).is_equal(1)
	assert_bool(path[0] == Vector2i(0, 0)).is_true()


func test_find_path_adjacent_tiles() -> void:
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_int(path.size()).is_equal(2)
	assert_bool(path[0] == Vector2i(0, 0)).is_true()
	assert_bool(path[1] == Vector2i(1, 0)).is_true()


func test_find_path_through_chain() -> void:
	# Create a chain: (0,0) -> (1,0) -> (2,0)
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_grid.add_tile(Vector2i(2, 0))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(path.size()).is_equal(3)


func test_find_path_blocked_tile_avoids_it() -> void:
	# Three tiles in a line, middle is blocked
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_grid.add_tile(Vector2i(2, 0))
	# Add alternate route
	_grid.add_tile(Vector2i(0, 1))
	_grid.add_tile(Vector2i(1, 1))
	_grid._blocked[Vector2i(1, 0)] = true
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	# Path should exist but not go through (1,0)
	var goes_through_blocked: bool = false
	for coord in path:
		if coord == Vector2i(1, 0):
			goes_through_blocked = true
	assert_bool(goes_through_blocked).is_false()


func test_find_path_no_route_returns_empty() -> void:
	# Two disconnected tiles
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(5, 5))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(5, 5))
	assert_int(path.size()).is_equal(0)


func test_find_path_invalid_coords_returns_empty() -> void:
	_grid.add_tile(Vector2i(0, 0))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	var path: Array[Vector2i] = _pathfinder.find_path(Vector2i(99, 99), Vector2i(0, 0))
	assert_int(path.size()).is_equal(0)


func test_structure_placed_updates_connections() -> void:
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_grid.add_tile(Vector2i(2, 0))
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	# Path should work initially
	var path_before: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(path_before.size()).is_equal(3)
	# Block middle tile and emit structure_placed
	_grid._blocked[Vector2i(1, 0)] = true
	_grid.structure_placed.emit(Vector2i(1, 0), &"wall")
	# Now path through middle should be blocked
	var path_after: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(path_after.size()).is_equal(0)


func test_structure_destroyed_reopens_path() -> void:
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_grid.add_tile(Vector2i(2, 0))
	_grid._blocked[Vector2i(1, 0)] = true
	_pathfinder.setup(_grid)
	_grid.map_generated.emit()
	# Initially blocked
	var path_blocked: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(path_blocked.size()).is_equal(0)
	# Unblock and emit structure_destroyed
	_grid._blocked.erase(Vector2i(1, 0))
	_grid.structure_destroyed.emit(Vector2i(1, 0), &"wall")
	# Now path should work
	var path_open: Array[Vector2i] = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(path_open.size()).is_equal(3)
