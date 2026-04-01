extends GdUnitTestSuite
class_name TestPlayerPathfinder

## Tests PlayerPathfinder: valid paths, avoidance of water/elevation/structures,
## empty result for unreachable destinations.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _WorldGenerator = preload("res://scripts/hex/world_generator.gd")
const _PlayerPathfinder = preload("res://scripts/player/player_pathfinder.gd")

var _grid: Node


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)


func after_test() -> void:
	_grid.queue_free()


## Helper: build a small test grid with known tiles.
func _build_small_grid() -> void:
	_grid._tiles.clear()
	# Create a small hex grid: center + ring 1 + ring 2 = 19 tiles.
	for q in range(-2, 3):
		for r in range(-2, 3):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 4:
				continue
			var tile = _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			_grid._tiles[Vector2i(q, r)] = tile


func _build_pathfinder() -> RefCounted:
	var pf = _PlayerPathfinder.new()
	pf._grid = _grid
	pf._build_graph()
	return pf


# --- Valid path tests ---

func test_find_path_to_adjacent_tile() -> void:
	_build_small_grid()
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path.size() >= 2).is_true()
	assert_object(path[0]).is_equal(Vector2i(0, 0))
	assert_object(path[path.size() - 1]).is_equal(Vector2i(1, 0))


func test_find_path_across_grid() -> void:
	_build_small_grid()
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(-2, 0), Vector2i(2, 0))
	assert_bool(path.size() > 0).override_failure_message("Path should not be empty").is_true()
	assert_object(path[0]).is_equal(Vector2i(-2, 0))
	assert_object(path[path.size() - 1]).is_equal(Vector2i(2, 0))
	# Distance is 4, so path should be 5 tiles (including start and end).
	assert_int(path.size()).is_equal(5)


func test_find_path_same_tile_returns_empty() -> void:
	_build_small_grid()
	var pf := _build_pathfinder()
	# AStar2D returns path with single element for same start/end.
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(0, 0))
	# Either empty or single element is acceptable.
	assert_bool(path.size() <= 1).is_true()


# --- Avoidance tests ---

func test_path_avoids_water() -> void:
	_build_small_grid()
	# Make tile (1, 0) water — should be impassable.
	_grid._tiles[Vector2i(1, 0)].biome = _HexTile.Biome.WATER
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_bool(path.size() > 0).override_failure_message("Path should exist around water").is_true()
	# Path should NOT go through water tile.
	assert_bool(path.has(Vector2i(1, 0))).is_false()


func test_path_avoids_steep_elevation() -> void:
	_build_small_grid()
	# Make tile (1, 0) elevation 5 (diff > MAX_ELEVATION_DIFF from 0).
	_grid._tiles[Vector2i(1, 0)].elevation = 5
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0))
	if path.size() > 0:
		assert_bool(path.has(Vector2i(1, 0))).is_false()


func test_path_avoids_blocking_structure() -> void:
	_build_small_grid()
	# Place a blocking structure on (1, 0).
	_grid._tiles[Vector2i(1, 0)].structure = &"wall"
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0))
	if path.size() > 0:
		assert_bool(path.has(Vector2i(1, 0))).is_false()


func test_path_allows_walkable_structure() -> void:
	_build_small_grid()
	# Shelter is walkable per SPEC.
	_grid._tiles[Vector2i(1, 0)].structure = &"shelter"
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path.size() > 0).override_failure_message("Path through shelter should exist").is_true()


func test_unreachable_returns_empty() -> void:
	_build_small_grid()
	# Surround (2, 0) with water to make it unreachable.
	var neighbors: Array[Vector2i] = _HexMath.get_neighbors(Vector2i(2, 0))
	for n in neighbors:
		if _grid._tiles.has(n):
			_grid._tiles[n].biome = _HexTile.Biome.WATER
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_bool(path.is_empty()).override_failure_message("Unreachable tile should return empty path").is_true()


func test_invalid_coords_returns_empty() -> void:
	_build_small_grid()
	var pf := _build_pathfinder()
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(99, 99))
	assert_bool(path.is_empty()).is_true()


# --- Structure update tests ---

func test_structure_placed_updates_graph() -> void:
	_build_small_grid()
	var pf := _build_pathfinder()
	# Initially path goes through (1, 0).
	var path_before: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path_before.size() > 0).is_true()

	# Place blocking structure and update.
	_grid._tiles[Vector2i(1, 0)].structure = &"wall"
	pf._on_structure_placed(Vector2i(1, 0), &"wall")

	var path_after: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path_after.is_empty()).override_failure_message(
		"Path to blocked tile should be empty after structure_placed"
	).is_true()


func test_structure_destroyed_updates_graph() -> void:
	_build_small_grid()
	_grid._tiles[Vector2i(1, 0)].structure = &"wall"
	var pf := _build_pathfinder()

	var path_blocked: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path_blocked.is_empty()).is_true()

	# Destroy structure and update.
	_grid._tiles[Vector2i(1, 0)].structure = &""
	pf._on_structure_destroyed(Vector2i(1, 0), &"wall")

	var path_unblocked: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_bool(path_unblocked.size() > 0).override_failure_message(
		"Path should exist after structure destroyed"
	).is_true()


# --- Full world generation integration ---

func test_pathfinder_with_generated_world() -> void:
	var gen := _WorldGenerator.new(_grid)
	var ok: bool = gen.generate(42)
	assert_bool(ok).is_true()

	var pf := _build_pathfinder()
	# Find a non-water, non-steep tile reachable from crash site.
	var crash_site := Vector2i(0, 0)
	var found_target: Vector2i = crash_site
	for coords: Vector2i in _grid._tiles:
		if coords == crash_site:
			continue
		var tile = _grid._tiles[coords]
		if tile.biome != _HexTile.Biome.WATER:
			var path: Array[Vector2i] = pf.find_path(crash_site, coords)
			if path.size() > 2:
				found_target = coords
				break

	if found_target != crash_site:
		var path: Array[Vector2i] = pf.find_path(crash_site, found_target)
		assert_bool(path.size() >= 2).is_true()
		assert_object(path[0]).is_equal(crash_site)
		assert_object(path[path.size() - 1]).is_equal(found_target)
		# Verify all path tiles are passable transitions.
		for i in range(path.size() - 1):
			assert_bool(_grid.is_passable(path[i], path[i + 1])).override_failure_message(
				"Path step %d->%d should be passable" % [i, i + 1]
			).is_true()
