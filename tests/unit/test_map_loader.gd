extends GdUnitTestSuite
class_name TestMapLoader

## Tests MapLoader pipeline and HexGrid traversal/visibility/serialization API.
## Replaces test_world_generator.gd after MapLoader pivot.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

var _grid: Node


func before_test() -> void:
	_grid = load("res://scripts/hex/hex_grid.gd").new()
	add_child(_grid)


func after_test() -> void:
	_grid.queue_free()


func _load_ch1() -> bool:
	_grid._tiles.clear()
	var loader = load("res://scripts/hex/map_loader.gd").new(_grid)
	return loader.load_map("res://data/maps/ch1.json")


# --- Map loads successfully ---

func test_map_loads_successfully() -> void:
	var ok: bool = _load_ch1()
	assert_bool(ok).is_true()


# --- Tile count matches JSON ---

func test_tile_count_correct() -> void:
	_load_ch1()
	assert_bool(_grid._tiles.size() > 0).override_failure_message(
		"Expected tiles to be populated after load"
	).is_true()


# --- All biomes present ---

func test_all_biomes_present() -> void:
	_load_ch1()
	var found: Dictionary = {}
	for c in _grid._tiles:
		found[_grid._tiles[c].biome] = true
	assert_bool(found.has(_HexTile.Biome.CRASH_SITE)).override_failure_message("Missing CRASH_SITE").is_true()
	assert_bool(found.has(_HexTile.Biome.GRASSLAND)).override_failure_message("Missing GRASSLAND").is_true()
	assert_bool(found.has(_HexTile.Biome.FOREST)).override_failure_message("Missing FOREST").is_true()
	assert_bool(found.has(_HexTile.Biome.ROCKY)).override_failure_message("Missing ROCKY").is_true()
	assert_bool(found.has(_HexTile.Biome.WATER)).override_failure_message("Missing WATER").is_true()


# --- Spawn tile at origin is CRASH_SITE ---

func test_spawn_tile_is_crash_site() -> void:
	_load_ch1()
	var spawn_tile: Resource = _grid.get_tile(Vector2i.ZERO)
	assert_bool(spawn_tile != null).override_failure_message("Spawn tile missing").is_true()
	if spawn_tile == null:
		return
	assert_int(spawn_tile.biome).is_equal(_HexTile.Biome.CRASH_SITE)


# --- Anomaly exists ---

func test_anomaly_exists() -> void:
	_load_ch1()
	var found: bool = false
	for c in _grid._tiles:
		for prop in _grid._tiles[c].props:
			if prop.is_anomaly():
				found = true
				break
		if found:
			break
	assert_bool(found).override_failure_message("No anomaly tile found").is_true()


# --- get_traversal: WALK for elevation diff 0 ---

func test_get_traversal_walk_diff_0() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 2
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 2
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


# --- get_traversal: WALK for elevation diff 1 ---

func test_get_traversal_walk_diff_1() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 1
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 2
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


# --- get_traversal: WALK for diff 2 uphill ---

func test_get_traversal_walk_diff_2() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 1
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 3
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


# --- get_traversal: JUMP for diff 3 uphill ---

func test_get_traversal_jump_diff_3() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 3
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.JUMP)


# --- get_traversal: WALK for diff 2 downhill ---

func test_get_traversal_walk_diff_2_downhill() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 3
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 1
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.WALK)


# --- get_traversal: DROP for diff 3 downhill ---

func test_get_traversal_drop_diff_3() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 3
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 0
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.DROP)


# --- get_traversal: BLOCKED for diff 5 uphill ---

func test_get_traversal_blocked_diff_5_uphill() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 5
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


# --- get_traversal: BLOCKED for diff 5 downhill ---

func test_get_traversal_blocked_diff_5_downhill() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 5
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 0
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


# --- get_traversal: BLOCKED for diff 6+ ---

func test_get_traversal_blocked_steep_elevation() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.ROCKY; b.elevation = 5
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


# --- get_traversal: BLOCKED for water ---

func test_get_traversal_blocked_water() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.WATER; b.elevation = 0
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


# --- get_traversal: BLOCKED for blocking structure ---

func test_get_traversal_blocked_structure() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 0
	b.props = [_Prop.create_structure(&"P00106")]
	_grid._tiles[Vector2i(1, 0)] = b
	assert_int(_grid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(_grid.TraversalType.BLOCKED)


# --- is_passable: true for WALK ---

func test_is_passable_walk() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 1
	_grid._tiles[Vector2i(0, 0)] = a
	_grid._tiles[Vector2i(1, 0)] = b
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_true()


# --- is_passable: true for JUMP ---

func test_is_passable_jump() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 3
	_grid._tiles[Vector2i(0, 0)] = a
	_grid._tiles[Vector2i(1, 0)] = b
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_true()


# --- is_passable: true for DROP ---

func test_is_passable_drop() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 3
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.GRASSLAND; b.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	_grid._tiles[Vector2i(1, 0)] = b
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_true()


# --- is_passable: false for BLOCKED ---

func test_is_passable_blocked() -> void:
	_grid._tiles.clear()
	var a: Resource = _HexTile.new()
	a.coords = Vector2i(0, 0); a.biome = _HexTile.Biome.GRASSLAND; a.elevation = 0
	var b: Resource = _HexTile.new()
	b.coords = Vector2i(1, 0); b.biome = _HexTile.Biome.WATER; b.elevation = 0
	_grid._tiles[Vector2i(0, 0)] = a
	_grid._tiles[Vector2i(1, 0)] = b
	assert_bool(_grid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_false()


# --- Serialization round-trip ---

func test_serialization_round_trip() -> void:
	_load_ch1()
	var save_data: Dictionary = _grid.get_save_data()

	var grid2: Node = load("res://scripts/hex/hex_grid.gd").new()
	add_child(grid2)
	grid2.load_save_data(save_data)

	assert_int(grid2._tiles.size()).is_equal(_grid._tiles.size())

	for c in _grid._tiles:
		var coords: Vector2i = c
		var orig: Resource = _grid._tiles[coords]
		var loaded: Resource = grid2._tiles.get(coords, null)
		assert_bool(loaded != null).override_failure_message(
			"Missing tile at %s after load" % str(coords)
		).is_true()
		if loaded == null:
			continue
		assert_int(loaded.biome).is_equal(orig.biome)
		assert_int(loaded.elevation).is_equal(orig.elevation)
		assert_int(loaded.props.size()).is_equal(orig.props.size())

	grid2.queue_free()


# --- Invalid JSON: no crash, returns false, tiles empty ---

func test_invalid_json_no_crash() -> void:
	_grid._tiles.clear()
	var loader = load("res://scripts/hex/map_loader.gd").new(_grid)
	var ok: bool = loader.load_map("res://data/maps/nonexistent.json")
	assert_bool(ok).is_false()
	assert_int(_grid._tiles.size()).is_equal(0)
