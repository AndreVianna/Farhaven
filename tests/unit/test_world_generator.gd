extends GdUnitTestSuite
class_name TestWorldGenerator

## Tests WorldGenerator pipeline across multiple seeds.
## Verifies all AC1 criteria per DETAIL.md task-003.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _WorldGenerator = preload("res://scripts/hex/world_generator.gd")

const SEEDS_TO_TEST: int = 10
const BASE_SEED: int = 42

var _grid: Node  # HexGrid autoload instance (isolated copy for testing)


func before_test() -> void:
	# Create a fresh HexGrid node for isolation (not the real autoload)
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)


func after_test() -> void:
	_grid.queue_free()


func _generate(seed_val: int) -> bool:
	_grid._tiles.clear()
	var gen = _WorldGenerator.new(_grid)
	return gen.generate(seed_val)


# --- AC1: Tile count 200-300 across 10 seeds ---

func test_tile_count_200_to_300() -> void:
	for i in range(SEEDS_TO_TEST):
		var seed_val: int = BASE_SEED + i * 100
		var ok: bool = _generate(seed_val)
		assert_bool(ok).override_failure_message("Seed %d: generate() returned false" % seed_val).is_true()
		var count: int = _grid._tiles.size()
		assert_bool(count >= 200 and count <= 300).override_failure_message(
			"Seed %d: tile count %d not in [200,300]" % [seed_val, count]
		).is_true()


# --- AC1: All biomes present ---

func test_all_biomes_present() -> void:
	for i in range(SEEDS_TO_TEST):
		var seed_val: int = BASE_SEED + i * 100
		_generate(seed_val)

		var found: Dictionary = {}
		for c in _grid._tiles:
			found[_grid._tiles[c].biome] = true

		assert_bool(found.has(_HexTile.Biome.CRASH_SITE)).override_failure_message("Seed %d: missing CRASH_SITE" % seed_val).is_true()
		assert_bool(found.has(_HexTile.Biome.GRASSLAND)).override_failure_message("Seed %d: missing GRASSLAND" % seed_val).is_true()
		assert_bool(found.has(_HexTile.Biome.FOREST)).override_failure_message("Seed %d: missing FOREST" % seed_val).is_true()
		assert_bool(found.has(_HexTile.Biome.ROCKY)).override_failure_message("Seed %d: missing ROCKY" % seed_val).is_true()


# --- AC1: Crash Site within 3 hexes of center ---

func test_crash_site_within_3_hexes_of_center() -> void:
	for i in range(SEEDS_TO_TEST):
		var seed_val: int = BASE_SEED + i * 100
		_generate(seed_val)

		var near_center: bool = false
		for c in _grid._tiles:
			var coords: Vector2i = c
			if _grid._tiles[coords].biome == _HexTile.Biome.CRASH_SITE:
				if _HexMath.distance(Vector2i.ZERO, coords) <= 3:
					near_center = true
					break
		assert_bool(near_center).override_failure_message(
			"Seed %d: no CRASH_SITE within 3 hexes of center" % seed_val
		).is_true()


# --- AC1: No cluster > 5 adjacent same-biome ---

func test_no_cluster_larger_than_5() -> void:
	for i in range(SEEDS_TO_TEST):
		var seed_val: int = BASE_SEED + i * 100
		_generate(seed_val)

		var visited: Dictionary = {}
		var cluster_ok: bool = true
		for c in _grid._tiles:
			var start: Vector2i = c
			if visited.has(start):
				continue
			var tile: Resource = _grid._tiles[start]
			if tile.biome == _HexTile.Biome.CRASH_SITE or tile.biome == _HexTile.Biome.WATER:
				visited[start] = true
				continue
			var biome: int = tile.biome
			var cluster_size: int = 0
			var queue: Array[Vector2i] = [start]
			while queue.size() > 0:
				var current: Vector2i = queue.pop_front()
				if visited.has(current):
					continue
				visited[current] = true
				var ct: Resource = _grid._tiles.get(current, null)
				if ct == null or ct.biome != biome:
					continue
				cluster_size += 1
				for n in _HexMath.get_neighbors(current):
					if not visited.has(n) and _grid._tiles.has(n):
						queue.append(n)
			if cluster_size > 5:
				cluster_ok = false
				break

		assert_bool(cluster_ok).override_failure_message("Seed %d: cluster > 5 found" % seed_val).is_true()


# --- AC1: At least 1 anomaly placed and reachable ---

func test_anomaly_placed_and_reachable() -> void:
	for i in range(SEEDS_TO_TEST):
		var seed_val: int = BASE_SEED + i * 100
		_generate(seed_val)

		var anomaly_coord: Vector2i = Vector2i(-9999, -9999)
		var found: bool = false
		for c in _grid._tiles:
			var coords: Vector2i = c
			if _grid._tiles[coords].anomaly != &"":
				anomaly_coord = coords
				found = true
				break
		assert_bool(found).override_failure_message("Seed %d: no anomaly placed" % seed_val).is_true()
		if not found:
			continue

		# BFS reachability from crash site
		var reachable: Dictionary = {}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		reachable[Vector2i.ZERO] = true
		while queue.size() > 0:
			var current: Vector2i = queue.pop_front()
			for n in _HexMath.get_neighbors(current):
				if reachable.has(n) or not _grid._tiles.has(n):
					continue
				if _grid.is_passable(current, n):
					reachable[n] = true
					queue.append(n)

		assert_bool(reachable.has(anomaly_coord)).override_failure_message(
			"Seed %d: anomaly at %s is not reachable" % [seed_val, str(anomaly_coord)]
		).is_true()


# --- is_passable: rejects water ---

func test_is_passable_rejects_water() -> void:
	_generate(BASE_SEED)
	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]
		if tile.biome == _HexTile.Biome.WATER:
			for n in _HexMath.get_neighbors(coords):
				if _grid._tiles.has(n) and _grid._tiles[n].biome != _HexTile.Biome.WATER:
					assert_bool(_grid.is_passable(n, coords)).is_false()
					return
	# No water tile found adjacent to non-water — acceptable for some seeds


# --- is_passable: rejects steep elevation ---

func test_is_passable_rejects_steep_elevation() -> void:
	_grid._tiles.clear()
	var tile_a: Resource = _HexTile.new()
	tile_a.coords = Vector2i(0, 0)
	tile_a.biome = _HexTile.Biome.GRASSLAND
	tile_a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = tile_a

	var tile_b: Resource = _HexTile.new()
	tile_b.coords = Vector2i(1, 0)
	tile_b.biome = _HexTile.Biome.ROCKY
	tile_b.elevation = 3
	_grid._tiles[Vector2i(1, 0)] = tile_b

	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


# --- is_passable: allows Shelter and Torch ---

func test_is_passable_allows_walkable_structures() -> void:
	_grid._tiles.clear()
	var from_tile: Resource = _HexTile.new()
	from_tile.coords = Vector2i(0, 0)
	from_tile.biome = _HexTile.Biome.GRASSLAND
	from_tile.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = from_tile

	for struct_name in [&"shelter", &"torch"]:
		var to_tile: Resource = _HexTile.new()
		to_tile.coords = Vector2i(1, 0)
		to_tile.biome = _HexTile.Biome.GRASSLAND
		to_tile.elevation = 0
		to_tile.structure = struct_name
		_grid._tiles[Vector2i(1, 0)] = to_tile
		assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).override_failure_message(
			"Expected %s to be passable" % struct_name
		).is_true()


# --- is_passable: blocks non-walkable structures ---

func test_is_passable_blocks_other_structures() -> void:
	_grid._tiles.clear()
	var from_tile: Resource = _HexTile.new()
	from_tile.coords = Vector2i(0, 0)
	from_tile.biome = _HexTile.Biome.GRASSLAND
	from_tile.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = from_tile

	var to_tile: Resource = _HexTile.new()
	to_tile.coords = Vector2i(1, 0)
	to_tile.biome = _HexTile.Biome.GRASSLAND
	to_tile.elevation = 0
	to_tile.structure = &"wall"
	_grid._tiles[Vector2i(1, 0)] = to_tile

	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


# --- refresh_visibility: single-source ---

func test_refresh_visibility_single_source() -> void:
	_generate(BASE_SEED)
	# Reset all to HIDDEN
	for c in _grid._tiles:
		_grid._tiles[c].fog_state = _HexTile.FogState.HIDDEN

	var sources: Array[Dictionary] = [{"coords": Vector2i.ZERO, "radius": 2}]
	_grid.refresh_visibility(sources)

	for coords in _HexMath.get_tiles_in_range(Vector2i.ZERO, 2):
		if _grid._tiles.has(coords):
			assert_int(_grid._tiles[coords].fog_state).is_equal(_HexTile.FogState.VISIBLE)


# --- refresh_visibility: multi-source ---

func test_refresh_visibility_multi_source() -> void:
	_generate(BASE_SEED)
	for c in _grid._tiles:
		_grid._tiles[c].fog_state = _HexTile.FogState.HIDDEN

	var second := Vector2i(3, 0)
	var sources: Array[Dictionary] = [
		{"coords": Vector2i.ZERO, "radius": 1},
		{"coords": second, "radius": 1},
	]
	_grid.refresh_visibility(sources)

	for coords in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		if _grid._tiles.has(coords):
			assert_int(_grid._tiles[coords].fog_state).is_equal(_HexTile.FogState.VISIBLE)

	for coords in _HexMath.get_tiles_in_range(second, 1):
		if _grid._tiles.has(coords):
			assert_int(_grid._tiles[coords].fog_state).is_equal(_HexTile.FogState.VISIBLE)


# --- refresh_visibility: demotes VISIBLE to REVEALED on second call ---

func test_refresh_visibility_demotes_visible_to_revealed() -> void:
	# Use manual tiles — no generation needed
	_grid._tiles.clear()
	var center_tile: Resource = _HexTile.new()
	center_tile.coords = Vector2i(0, 0)
	center_tile.biome = _HexTile.Biome.GRASSLAND
	center_tile.elevation = 0
	center_tile.fog_state = _HexTile.FogState.HIDDEN
	_grid._tiles[Vector2i(0, 0)] = center_tile

	# First visibility pass — center becomes VISIBLE
	var sources1: Array[Dictionary] = [{"coords": Vector2i(0, 0), "radius": 0}]
	_grid.refresh_visibility(sources1)
	assert_int(center_tile.fog_state).is_equal(_HexTile.FogState.VISIBLE)

	# Second visibility pass with source far away (coord not in map) — center demotes to REVEALED
	var sources2: Array[Dictionary] = [{"coords": Vector2i(99, 0), "radius": 0}]
	_grid.refresh_visibility(sources2)
	assert_int(center_tile.fog_state).is_equal(_HexTile.FogState.REVEALED)


# --- Serialization round-trip ---

func test_serialization_round_trip() -> void:
	_generate(BASE_SEED)
	var save_data: Dictionary = _grid.get_save_data()

	var grid2: Node = load("res://scripts/hex/hex_grid.gd").new()
	add_child(grid2)
	grid2.load_save_data(save_data)

	assert_int(grid2._tiles.size()).is_equal(_grid._tiles.size())
	assert_int(grid2._seed).is_equal(_grid._seed)

	for c in _grid._tiles:
		var coords: Vector2i = c
		var orig: Resource = _grid._tiles[coords]
		var loaded: Resource = grid2._tiles.get(coords, null)
		assert_bool(loaded != null).override_failure_message("Missing tile at %s after load" % str(coords)).is_true()
		if loaded == null:
			continue
		assert_int(loaded.biome).is_equal(orig.biome)
		assert_int(loaded.elevation).is_equal(orig.elevation)
		assert_int(loaded.fog_state).is_equal(orig.fog_state)
		assert_str(String(loaded.anomaly)).is_equal(String(orig.anomaly))

	grid2.queue_free()


# --- Fog initialized after generation ---

func test_fog_initialized_crash_site_visible() -> void:
	_generate(BASE_SEED)

	for coords in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		if _grid._tiles.has(coords):
			assert_int(_grid._tiles[coords].fog_state).override_failure_message(
				"Tile %s should be VISIBLE after generation" % str(coords)
			).is_equal(_HexTile.FogState.VISIBLE)

	var hidden_count: int = 0
	for c in _grid._tiles:
		if _grid._tiles[c].fog_state == _HexTile.FogState.HIDDEN:
			hidden_count += 1
	assert_bool(hidden_count > 100).is_true()
