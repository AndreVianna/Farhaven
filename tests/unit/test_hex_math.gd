extends GdUnitTestSuite
class_name TestHexMath

const HexMath = preload("res://scripts/hex/hex_math.gd")

# --- get_neighbors ---

func test_neighbors_count() -> void:
	var neighbors: Array[Vector2i] = HexMath.get_neighbors(Vector2i(0, 0))
	assert_int(neighbors.size()).is_equal(6)

func test_neighbors_all_six_directions() -> void:
	var neighbors: Array[Vector2i] = HexMath.get_neighbors(Vector2i(0, 0))
	assert_bool(neighbors.has(Vector2i(1, 0))).is_true()
	assert_bool(neighbors.has(Vector2i(1, -1))).is_true()
	assert_bool(neighbors.has(Vector2i(0, -1))).is_true()
	assert_bool(neighbors.has(Vector2i(-1, 0))).is_true()
	assert_bool(neighbors.has(Vector2i(-1, 1))).is_true()
	assert_bool(neighbors.has(Vector2i(0, 1))).is_true()

func test_neighbors_offset_coords() -> void:
	var neighbors: Array[Vector2i] = HexMath.get_neighbors(Vector2i(3, -2))
	assert_int(neighbors.size()).is_equal(6)
	assert_bool(neighbors.has(Vector2i(4, -2))).is_true()
	assert_bool(neighbors.has(Vector2i(2, -2))).is_true()
	assert_bool(neighbors.has(Vector2i(3, -3))).is_true()

# --- distance ---

func test_distance_same_tile() -> void:
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(0, 0))).is_equal(0)
	assert_int(HexMath.distance(Vector2i(5, -3), Vector2i(5, -3))).is_equal(0)

func test_distance_adjacent_is_one() -> void:
	for d in HexMath.DIRECTIONS:
		var dir: Vector2i = d
		assert_int(HexMath.distance(Vector2i(0, 0), dir)).is_equal(1)

func test_distance_across_map() -> void:
	# (0,0) to (5,0): 5 steps East
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(5, 0))).is_equal(5)
	# (0,0) to (5,-3): cube diff (5,-2,-3), sum=10, /2=5
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(5, -3))).is_equal(5)
	# (0,0) to (0,4): 4 steps SE
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(0, 4))).is_equal(4)

func test_distance_symmetry() -> void:
	var a := Vector2i(3, -5)
	var b := Vector2i(-2, 4)
	assert_int(HexMath.distance(a, b)).is_equal(HexMath.distance(b, a))

# --- get_ring ---

func test_ring_zero_returns_center() -> void:
	var ring: Array[Vector2i] = HexMath.get_ring(Vector2i(0, 0), 0)
	assert_int(ring.size()).is_equal(1)
	assert_bool(ring.has(Vector2i(0, 0))).is_true()

func test_ring_count_is_six_times_radius() -> void:
	for r in range(1, 5):
		var ring: Array[Vector2i] = HexMath.get_ring(Vector2i(0, 0), r)
		assert_int(ring.size()).is_equal(6 * r)

func test_ring_tiles_have_correct_distance() -> void:
	var center := Vector2i(0, 0)
	for r in range(1, 4):
		var ring: Array[Vector2i] = HexMath.get_ring(center, r)
		for tile in ring:
			var t: Vector2i = tile
			assert_int(HexMath.distance(center, t)).is_equal(r)

func test_ring_radius_one_equals_neighbors() -> void:
	var center := Vector2i(2, -1)
	var ring: Array[Vector2i] = HexMath.get_ring(center, 1)
	var neighbors: Array[Vector2i] = HexMath.get_neighbors(center)
	assert_int(ring.size()).is_equal(6)
	for n in neighbors:
		var nv: Vector2i = n
		assert_bool(ring.has(nv)).is_true()

# --- axial_to_cube ---

func test_axial_to_cube_origin() -> void:
	assert_bool(HexMath.axial_to_cube(Vector2i(0, 0)) == Vector3i(0, 0, 0)).is_true()

func test_axial_to_cube_east() -> void:
	# cube.x=q, cube.y=-q-r, cube.z=r
	assert_bool(HexMath.axial_to_cube(Vector2i(1, 0)) == Vector3i(1, -1, 0)).is_true()

func test_axial_to_cube_se() -> void:
	assert_bool(HexMath.axial_to_cube(Vector2i(0, 1)) == Vector3i(0, -1, 1)).is_true()

func test_axial_to_cube_invariant() -> void:
	# q + r + s == 0 always (cube coordinate constraint)
	for q in range(-3, 4):
		for r in range(-3, 4):
			var cube: Vector3i = HexMath.axial_to_cube(Vector2i(q, r))
			assert_int(cube.x + cube.y + cube.z).is_equal(0)

# --- axial <-> world round-trip ---

func test_world_roundtrip_origin() -> void:
	var world: Vector2 = HexMath.axial_to_world(Vector2i(0, 0))
	var back: Vector2i = HexMath.world_to_axial(world)
	assert_bool(back == Vector2i(0, 0)).is_true()

func test_world_roundtrip_various() -> void:
	var test_coords: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(3, -2), Vector2i(-4, 3), Vector2i(5, -5),
	]
	for coords in test_coords:
		var c: Vector2i = coords
		var world: Vector2 = HexMath.axial_to_world(c)
		var back: Vector2i = HexMath.world_to_axial(world)
		assert_bool(back == c).is_true()

# --- get_tiles_in_range ---

func test_tiles_in_range_count() -> void:
	# Formula: 3*r*(r+1)+1
	for r in range(0, 5):
		var tiles: Array[Vector2i] = HexMath.get_tiles_in_range(Vector2i(0, 0), r)
		var expected: int = 3 * r * (r + 1) + 1
		assert_int(tiles.size()).is_equal(expected)

func test_tiles_in_range_contains_center() -> void:
	var center := Vector2i(2, -3)
	var tiles: Array[Vector2i] = HexMath.get_tiles_in_range(center, 0)
	assert_bool(tiles.has(center)).is_true()

func test_tiles_in_range_all_within_distance() -> void:
	var center := Vector2i(1, 1)
	var radius: int = 2
	var tiles: Array[Vector2i] = HexMath.get_tiles_in_range(center, radius)
	for tile in tiles:
		var t: Vector2i = tile
		assert_bool(HexMath.distance(center, t) <= radius).is_true()
