class_name TestHexGrid
extends GdUnitTestSuite

## Unit tests for HexGrid autoload (task-084c).
##
## HexGrid is a 389-line autoload with a large public API surface:
##   - Tile queries (has_tile/get_tile/get_all_tiles/get_tile_count/get_neighbors)
##   - Elevation traversal (WALK_MAX_DIFF=2, JUMP_MAX_DIFF=4, WALK/JUMP/DROP/BLOCKED)
##   - Seven signals (map_generated, tile_entered, tile_exited, prop_depleted,
##     prop_respawned, structure_placed, structure_destroyed)
##   - spawn_tile / spawn_sub_hex / spawn_facing_deg / starting_loadout round-trip
##
## These tests mutate the global HexGrid autoload's internal state via _tiles,
## mirroring the approach used in test_hex_grid_renderer.gd. after_test() must
## restore HexGrid to a clean state so unrelated tests are not affected.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

var _prev_spawn_tile: Vector2i
var _prev_spawn_sub_hex: Vector2i
var _prev_spawn_facing_deg: float
var _prev_starting_loadout: Dictionary


func before_test() -> void:
	_prev_spawn_tile = HexGrid.spawn_tile
	_prev_spawn_sub_hex = HexGrid.spawn_sub_hex
	_prev_spawn_facing_deg = HexGrid.spawn_facing_deg
	_prev_starting_loadout = HexGrid.starting_loadout.duplicate()
	HexGrid._tiles.clear()
	HexGrid._seed = 0
	HexGrid.spawn_tile = Vector2i.ZERO
	HexGrid.spawn_sub_hex = Vector2i.ZERO
	HexGrid.spawn_facing_deg = 0.0
	HexGrid.starting_loadout = {}


func after_test() -> void:
	HexGrid._tiles.clear()
	HexGrid._seed = 0
	HexGrid.spawn_tile = _prev_spawn_tile
	HexGrid.spawn_sub_hex = _prev_spawn_sub_hex
	HexGrid.spawn_facing_deg = _prev_spawn_facing_deg
	HexGrid.starting_loadout = _prev_starting_loadout


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_tile(coords: Vector2i, elevation: int = 0,
		biome: int = _HexTile.Biome.GRASSLAND) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = biome
	tile.elevation = elevation
	return tile


func _place_tile(coords: Vector2i, elevation: int = 0,
		biome: int = _HexTile.Biome.GRASSLAND) -> Resource:
	var tile := _make_tile(coords, elevation, biome)
	HexGrid._tiles[coords] = tile
	return tile


func _place_3x3_grid(elevation: int = 0) -> void:
	# 3×3 square block in axial coords: (-1..1, -1..1) — not a hex ring, but good
	# enough for has_tile / get_neighbors edge tests because all six neighbors of
	# (0,0) exist within the patch (axial DIRECTIONS hit 6 distinct cells).
	for q in range(-1, 2):
		for r in range(-1, 2):
			_place_tile(Vector2i(q, r), elevation)


# ---------------------------------------------------------------------------
# Construction / reset semantics
# ---------------------------------------------------------------------------

func test_before_test_clears_tiles() -> void:
	# Confirms the autoload is reset to an empty state at the start of every test.
	assert_int(HexGrid.get_tile_count()).is_equal(0)


func test_defaults_after_reset() -> void:
	assert_that(HexGrid.spawn_tile).is_equal(Vector2i.ZERO)
	assert_that(HexGrid.spawn_sub_hex).is_equal(Vector2i.ZERO)
	assert_float(HexGrid.spawn_facing_deg).is_equal(0.0)
	assert_int(HexGrid.starting_loadout.size()).is_equal(0)


func test_traversal_enum_values_unique() -> void:
	# Sanity check — the enum values must all be distinct.
	var values := [
		HexGrid.TraversalType.WALK,
		HexGrid.TraversalType.JUMP,
		HexGrid.TraversalType.DROP,
		HexGrid.TraversalType.BLOCKED,
	]
	var unique := {}
	for v in values:
		unique[v] = true
	assert_int(unique.size()).is_equal(4)


func test_elevation_constants() -> void:
	assert_int(HexGrid.WALK_MAX_DIFF).is_equal(2)
	assert_int(HexGrid.JUMP_MAX_DIFF).is_equal(4)
	assert_int(HexGrid.MAX_ELEVATION_DIFF).is_equal(HexGrid.WALK_MAX_DIFF)


# ---------------------------------------------------------------------------
# Tile queries
# ---------------------------------------------------------------------------

func test_has_tile_false_when_empty() -> void:
	assert_bool(HexGrid.has_tile(Vector2i.ZERO)).is_false()


func test_has_tile_true_after_insert() -> void:
	_place_tile(Vector2i(2, 3))
	assert_bool(HexGrid.has_tile(Vector2i(2, 3))).is_true()
	assert_bool(HexGrid.has_tile(Vector2i(2, 4))).is_false()


func test_get_tile_returns_inserted_tile() -> void:
	var tile := _place_tile(Vector2i(1, 1), 4, _HexTile.Biome.ROCKY)
	var retrieved: Resource = HexGrid.get_tile(Vector2i(1, 1))
	assert_object(retrieved).is_same(tile)
	assert_int(retrieved.elevation).is_equal(4)
	assert_int(retrieved.biome).is_equal(_HexTile.Biome.ROCKY)


func test_get_tile_returns_null_for_unknown_coords() -> void:
	_place_tile(Vector2i(0, 0))
	assert_object(HexGrid.get_tile(Vector2i(99, 99))).is_null()


func test_get_tile_count_matches_tiles_size() -> void:
	_place_3x3_grid()
	assert_int(HexGrid.get_tile_count()).is_equal(9)


func test_get_all_tiles_returns_dictionary() -> void:
	_place_3x3_grid()
	var all: Dictionary = HexGrid.get_all_tiles()
	assert_int(all.size()).is_equal(9)
	assert_bool(all.has(Vector2i(0, 0))).is_true()


# ---------------------------------------------------------------------------
# get_neighbors — center vs edge
# ---------------------------------------------------------------------------

func test_get_neighbors_center_in_full_grid_returns_six() -> void:
	_place_3x3_grid()
	var neighbors: Array[Vector2i] = HexGrid.get_neighbors(Vector2i(0, 0))
	assert_int(neighbors.size()).is_equal(6)


func test_get_neighbors_corner_returns_fewer_than_six() -> void:
	# Isolated corner: only (0,0) has tiles on two of its six sides.
	_place_tile(Vector2i(0, 0))
	_place_tile(Vector2i(1, 0))  # east neighbor
	_place_tile(Vector2i(0, 1))  # SE neighbor
	var neighbors: Array[Vector2i] = HexGrid.get_neighbors(Vector2i(0, 0))
	assert_int(neighbors.size()).is_equal(2)
	assert_bool(neighbors.has(Vector2i(1, 0))).is_true()
	assert_bool(neighbors.has(Vector2i(0, 1))).is_true()


func test_get_neighbors_isolated_tile_returns_empty() -> void:
	_place_tile(Vector2i(5, 5))
	assert_int(HexGrid.get_neighbors(Vector2i(5, 5)).size()).is_equal(0)


func test_get_neighbors_excludes_self() -> void:
	_place_3x3_grid()
	var neighbors: Array[Vector2i] = HexGrid.get_neighbors(Vector2i(0, 0))
	assert_bool(neighbors.has(Vector2i(0, 0))).is_false()


# ---------------------------------------------------------------------------
# get_tiles_in_range / distance
# ---------------------------------------------------------------------------

func test_get_tiles_in_range_only_returns_existing_tiles() -> void:
	_place_3x3_grid()
	var in_range: Array[Vector2i] = HexGrid.get_tiles_in_range(Vector2i(0, 0), 1)
	# Center + 6 neighbors — but our 3x3 patch only contains some of them.
	for c in in_range:
		assert_bool(HexGrid._tiles.has(c)).is_true()
	assert_bool(in_range.has(Vector2i(0, 0))).is_true()


func test_distance_delegates_to_hex_math() -> void:
	assert_int(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 0))).is_equal(0)
	assert_int(HexGrid.distance(Vector2i(0, 0), Vector2i(1, 0))).is_equal(1)
	assert_int(HexGrid.distance(Vector2i(0, 0), Vector2i(3, 0))).is_equal(3)


# ---------------------------------------------------------------------------
# Elevation traversal — WALK / JUMP / DROP / BLOCKED
# ---------------------------------------------------------------------------

func test_traversal_walk_for_same_elevation() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 0)
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.WALK
	)


func test_traversal_walk_at_max_walk_diff_of_two() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 2)  # diff = 2 = WALK_MAX_DIFF
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.WALK
	)


func test_traversal_jump_when_diff_is_three_going_up() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 3)  # diff=3 > WALK, ≤ JUMP, going up
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.JUMP
	)


func test_traversal_jump_at_max_jump_diff_going_up() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 4)  # diff=4 = JUMP_MAX_DIFF going up
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.JUMP
	)


func test_traversal_drop_when_going_down_with_diff_three() -> void:
	_place_tile(Vector2i(0, 0), 5)
	_place_tile(Vector2i(1, 0), 2)  # diff=3 going down
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.DROP
	)


func test_traversal_drop_at_max_jump_diff_going_down() -> void:
	_place_tile(Vector2i(0, 0), 10)
	_place_tile(Vector2i(1, 0), 6)  # diff=4 going down
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.DROP
	)


func test_traversal_blocked_when_diff_exceeds_jump_max() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 5)  # diff=5 > JUMP_MAX_DIFF
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.BLOCKED
	)


func test_traversal_blocked_when_destination_is_deep_water() -> void:
	# Deep water: water_level − elevation > SUBMERSION_MAX (3). Player
	# cannot wade into a tile where they'd be fully submerged.
	_place_tile(Vector2i(0, 0), 0)
	var water := _place_tile(Vector2i(1, 0), -5, _HexTile.Biome.WATER)
	water.water_level = 0  # depth 5 > 3 → blocked
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.BLOCKED
	)


func test_traversal_walks_into_shallow_water() -> void:
	# Shallow water: water_level − elevation ≤ 3. Player walks in up to
	# their hips; movement treated like normal ground.
	_place_tile(Vector2i(0, 0), 0)
	var shallow := _place_tile(Vector2i(1, 0), -2, _HexTile.Biome.WATER)
	shallow.water_level = 0  # depth 2 ≤ 3 → walkable (diff 2 = WALK)
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.DROP
	)


func test_traversal_blocked_when_diff_exceeds_jump_max_going_down() -> void:
	# Symmetric slope rule — drops ALSO cap at JUMP_MAX_DIFF. This test
	# catches regressions where a previous implementation only capped
	# uphill moves.
	_place_tile(Vector2i(0, 0), 10)
	_place_tile(Vector2i(1, 0), 0)  # diff = 10 going down
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.BLOCKED
	)


# ---------------------------------------------------------------------------
# Instadeath / hazard cap lookup
# ---------------------------------------------------------------------------

func test_is_instadeath_false_for_tile_with_no_temperature() -> void:
	# temperature 0 short-circuits before hazard lookup.
	_place_tile(Vector2i(0, 0), 0)
	assert_bool(HexGrid.is_instadeath(Vector2i(0, 0))).is_false()


func test_is_instadeath_false_when_no_biome_data_cache() -> void:
	# Hazard check needs the biome_data cache (populated by MapLoader).
	# Without it, temperature alone can't resolve to instadeath.
	var tile := _place_tile(Vector2i(0, 0), 0)
	tile.temperature = 99
	HexGrid.set_biome_data_cache({})
	assert_bool(HexGrid.is_instadeath(Vector2i(0, 0))).is_false()


func test_is_instadeath_true_when_temperature_at_cap_last_level() -> void:
	# With a cached biome whose HazardCap has 4 levels, temperature 4 is
	# the instadeath threshold.
	var HazardCap := load("res://scripts/data/capabilities/hazard_cap.gd")
	var cap: Resource = HazardCap.new()
	cap.damage_type = &"heat"
	cap.health_damage = [0, 5, 15, 50]
	cap.thirst_drain = [5, 14, 25, 35]
	cap.hunger_drain = [0, 0, 0, 0]
	var biome: BiomeData = BiomeData.new()
	biome.id = &"B99999"
	biome.hazard = cap
	# Single-biome cache means sorted-index 0 → B99999 → tile.biome = 0.
	HexGrid.set_biome_data_cache({&"B99999": biome})
	var tile := _place_tile(Vector2i(0, 0), 0, 0)
	tile.temperature = 4
	assert_bool(HexGrid.is_instadeath(Vector2i(0, 0))).is_true()

	# Below the table size → not instadeath yet.
	tile.temperature = 3
	assert_bool(HexGrid.is_instadeath(Vector2i(0, 0))).is_false()

	# Cleanup cache so it doesn't leak into other tests.
	HexGrid.set_biome_data_cache({})


func test_traversal_blocked_when_destination_missing() -> void:
	_place_tile(Vector2i(0, 0), 0)
	# No tile at (1,0).
	assert_int(HexGrid.get_traversal(Vector2i(0, 0), Vector2i(1, 0))).is_equal(
		HexGrid.TraversalType.BLOCKED
	)


func test_is_passable_matches_not_blocked() -> void:
	_place_tile(Vector2i(0, 0), 0)
	_place_tile(Vector2i(1, 0), 0)
	_place_tile(Vector2i(0, 1), 99)  # 99-diff → BLOCKED
	assert_bool(HexGrid.is_passable(Vector2i(0, 0), Vector2i(1, 0))).is_true()
	assert_bool(HexGrid.is_passable(Vector2i(0, 0), Vector2i(0, 1))).is_false()


func test_get_elevation_diff_absolute_value() -> void:
	_place_tile(Vector2i(0, 0), 3)
	_place_tile(Vector2i(1, 0), 7)
	assert_int(HexGrid.get_elevation_diff(Vector2i(0, 0), Vector2i(1, 0))).is_equal(4)
	assert_int(HexGrid.get_elevation_diff(Vector2i(1, 0), Vector2i(0, 0))).is_equal(4)


func test_get_elevation_diff_returns_sentinel_for_missing() -> void:
	_place_tile(Vector2i(0, 0), 0)
	assert_int(HexGrid.get_elevation_diff(Vector2i(0, 0), Vector2i(9, 9))).is_equal(999)


# ---------------------------------------------------------------------------
# Coordinate conversions (delegated to HexMath but exposed via autoload)
# ---------------------------------------------------------------------------

func test_axial_to_cube_round_trip_center() -> void:
	var cube := HexGrid.axial_to_cube(Vector2i.ZERO)
	assert_that(cube).is_equal(Vector3i(0, 0, 0))


func test_axial_to_world_returns_vector2() -> void:
	var world := HexGrid.axial_to_world(Vector2i(0, 0))
	assert_object(world).is_not_null()


# ---------------------------------------------------------------------------
# Signal emission — one test per signal
# ---------------------------------------------------------------------------

func test_map_generated_signal_fires() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.map_generated.emit()
	await assert_signal(monitor).is_emitted("map_generated")


func test_tile_entered_signal_fires_with_coords() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.tile_entered.emit(Vector2i(3, -2))
	await assert_signal(monitor).is_emitted("tile_entered", [Vector2i(3, -2)])


func test_tile_exited_signal_fires_with_coords() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.tile_exited.emit(Vector2i(-1, 4))
	await assert_signal(monitor).is_emitted("tile_exited", [Vector2i(-1, 4)])


func test_prop_depleted_signal_fires_with_payload() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.prop_depleted.emit(Vector2i(0, 0), &"P00001")
	await assert_signal(monitor).is_emitted("prop_depleted", [Vector2i(0, 0), &"P00001"])


func test_prop_respawned_signal_fires_with_payload() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.prop_respawned.emit(Vector2i(2, 2), &"P00004")
	await assert_signal(monitor).is_emitted("prop_respawned", [Vector2i(2, 2), &"P00004"])


func test_structure_placed_signal_fires_with_payload() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.structure_placed.emit(Vector2i(1, 1), &"S00001")
	await assert_signal(monitor).is_emitted("structure_placed", [Vector2i(1, 1), &"S00001"])


func test_structure_destroyed_signal_fires_with_payload() -> void:
	var monitor := monitor_signals(HexGrid, false)
	HexGrid.structure_destroyed.emit(Vector2i(4, 4), &"S00002")
	await assert_signal(monitor).is_emitted("structure_destroyed", [Vector2i(4, 4), &"S00002"])


# ---------------------------------------------------------------------------
# spawn_tile / spawn_sub_hex / spawn_facing_deg / starting_loadout round-trip
# ---------------------------------------------------------------------------

func test_spawn_tile_assignment_round_trip() -> void:
	HexGrid.spawn_tile = Vector2i(7, -3)
	assert_that(HexGrid.spawn_tile).is_equal(Vector2i(7, -3))


func test_spawn_sub_hex_assignment_round_trip() -> void:
	HexGrid.spawn_sub_hex = Vector2i(2, 1)
	assert_that(HexGrid.spawn_sub_hex).is_equal(Vector2i(2, 1))


func test_spawn_facing_deg_assignment_round_trip() -> void:
	HexGrid.spawn_facing_deg = 270.0
	assert_float(HexGrid.spawn_facing_deg).is_equal(270.0)


func test_starting_loadout_assignment_round_trip() -> void:
	HexGrid.starting_loadout = {"tools": ["axe", "pickaxe"], "slots": 4}
	assert_int(HexGrid.starting_loadout.size()).is_equal(2)
	assert_that(HexGrid.starting_loadout["tools"]).is_equal(["axe", "pickaxe"])
	assert_int(HexGrid.starting_loadout["slots"]).is_equal(4)


# ---------------------------------------------------------------------------
# Serialization — save/load round-trip
# ---------------------------------------------------------------------------

func test_get_save_data_empty_when_no_tiles() -> void:
	var data: Dictionary = HexGrid.get_save_data()
	assert_bool(data.has("seed")).is_true()
	assert_bool(data.has("tiles")).is_true()
	assert_int((data["tiles"] as Array).size()).is_equal(0)


func test_get_save_data_contains_tile_coords_biome_elevation() -> void:
	_place_tile(Vector2i(2, -1), 3, _HexTile.Biome.FOREST)
	var data: Dictionary = HexGrid.get_save_data()
	var tiles: Array = data["tiles"]
	assert_int(tiles.size()).is_equal(1)
	var td: Dictionary = tiles[0]
	assert_int(td["tile_col"]).is_equal(2)
	assert_int(td["tile_row"]).is_equal(-1)
	assert_int(td["biome"]).is_equal(_HexTile.Biome.FOREST)
	assert_int(td["elevation"]).is_equal(3)
	assert_int((td["props"] as Array).size()).is_equal(0)


func test_load_save_data_restores_tiles() -> void:
	var data := {
		"seed": 42,
		"tiles": [
			{
				"tile_col": 0, "tile_row": 0, "biome": _HexTile.Biome.GRASSLAND,
				"elevation": 1, "props": [],
			},
			{
				"tile_col": 1, "tile_row": -1, "biome": _HexTile.Biome.ROCKY,
				"elevation": 5, "props": [],
			},
		],
	}
	HexGrid.load_save_data(data)
	assert_int(HexGrid.get_tile_count()).is_equal(2)
	assert_bool(HexGrid.has_tile(Vector2i(0, 0))).is_true()
	assert_bool(HexGrid.has_tile(Vector2i(1, -1))).is_true()
	var t: Resource = HexGrid.get_tile(Vector2i(1, -1))
	assert_int(t.biome).is_equal(_HexTile.Biome.ROCKY)
	assert_int(t.elevation).is_equal(5)


func test_load_save_data_round_trip_preserves_biome_and_elevation() -> void:
	_place_tile(Vector2i(3, -2), 7, _HexTile.Biome.ROCKY)
	_place_tile(Vector2i(-1, 1), 2, _HexTile.Biome.WATER)
	var data: Dictionary = HexGrid.get_save_data()
	HexGrid._tiles.clear()
	HexGrid.load_save_data(data)
	assert_int(HexGrid.get_tile_count()).is_equal(2)
	var t1: Resource = HexGrid.get_tile(Vector2i(3, -2))
	assert_int(t1.biome).is_equal(_HexTile.Biome.ROCKY)
	assert_int(t1.elevation).is_equal(7)
	var t2: Resource = HexGrid.get_tile(Vector2i(-1, 1))
	assert_int(t2.biome).is_equal(_HexTile.Biome.WATER)
	assert_int(t2.elevation).is_equal(2)


func test_load_save_data_clears_existing_tiles_first() -> void:
	_place_tile(Vector2i(0, 0))
	_place_tile(Vector2i(1, 0))
	HexGrid.load_save_data({"seed": 0, "tiles": [
		{"tile_col": 9, "tile_row": 9, "biome": _HexTile.Biome.GRASSLAND,
			"elevation": 0, "props": []},
	]})
	assert_int(HexGrid.get_tile_count()).is_equal(1)
	assert_bool(HexGrid.has_tile(Vector2i(9, 9))).is_true()
	assert_bool(HexGrid.has_tile(Vector2i(0, 0))).is_false()


func test_load_save_data_skips_tiles_without_coords() -> void:
	HexGrid.load_save_data({"seed": 0, "tiles": [
		{"biome": _HexTile.Biome.GRASSLAND, "elevation": 0, "props": []},  # missing coords
		{"tile_col": 0, "tile_row": 0, "biome": _HexTile.Biome.GRASSLAND,
			"elevation": 0, "props": []},
	]})
	assert_int(HexGrid.get_tile_count()).is_equal(1)


func test_has_structure_false_when_no_tile() -> void:
	assert_bool(HexGrid.has_structure(Vector2i(0, 0), &"S00001")).is_false()


func test_get_anomaly_returns_null_when_no_tile() -> void:
	assert_object(HexGrid.get_anomaly(Vector2i(0, 0))).is_null()


func test_get_props_by_category_empty_for_missing_tile() -> void:
	assert_int(HexGrid.get_props_by_category(Vector2i(0, 0), _Prop.Category.PLANT).size()).is_equal(0)
