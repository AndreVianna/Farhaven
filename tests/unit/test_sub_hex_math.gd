extends GdUnitTestSuite
class_name TestSubHexMath

const HexMath = preload("res://scripts/hex/hex_math.gd")

# --- SUB_HEX_SIZE ---

func test_sub_hex_size_fits_pointy_top_in_hex() -> void:
	var expected: float = (HexMath.HEX_SIZE / cos(deg_to_rad(30.0))) / 5.0
	assert_float(HexMath.SUB_HEX_SIZE).is_equal_approx(expected, 0.0001)

# --- sub_axial_to_world ---

func test_sub_axial_to_world_origin_returns_zero() -> void:
	var result: Vector2 = HexMath.sub_axial_to_world(Vector2i.ZERO)
	assert_float(result.x).is_equal_approx(0.0, 0.0001)
	assert_float(result.y).is_equal_approx(0.0, 0.0001)

# --- round-trip: sub_axial_to_world -> world_to_sub_axial ---

func test_sub_hex_roundtrip_all_19_positions() -> void:
	var all_subs: Array[Vector2i] = HexMath.get_all_sub_hexes()
	for sub in all_subs:
		var s: Vector2i = sub
		var world: Vector2 = HexMath.sub_axial_to_world(s)
		var back: Vector2i = HexMath.world_to_sub_axial(world)
		assert_bool(back == s).is_true()

# --- is_valid_sub_hex ---

func test_is_valid_sub_hex_center() -> void:
	assert_bool(HexMath.is_valid_sub_hex(Vector2i(0, 0))).is_true()

func test_is_valid_sub_hex_ring_1_all_true() -> void:
	for d in HexMath.DIRECTIONS:
		var dir: Vector2i = d
		assert_bool(HexMath.is_valid_sub_hex(dir)).is_true()

func test_is_valid_sub_hex_ring_2_all_true() -> void:
	var ring_2: Array[Vector2i] = HexMath.get_ring(Vector2i.ZERO, 2)
	for pos in ring_2:
		var p: Vector2i = pos
		assert_bool(HexMath.is_valid_sub_hex(p)).is_true()

func test_is_valid_sub_hex_radius_3_false() -> void:
	# All positions at distance 3 from center should be invalid
	var ring_3: Array[Vector2i] = HexMath.get_ring(Vector2i.ZERO, 3)
	for pos in ring_3:
		var p: Vector2i = pos
		assert_bool(HexMath.is_valid_sub_hex(p)).is_false()

# --- get_all_sub_hexes ---

func test_get_all_sub_hexes_returns_19() -> void:
	var subs: Array[Vector2i] = HexMath.get_all_sub_hexes()
	assert_int(subs.size()).is_equal(19)

func test_get_all_sub_hexes_contains_center() -> void:
	var subs: Array[Vector2i] = HexMath.get_all_sub_hexes()
	assert_bool(subs.has(Vector2i.ZERO)).is_true()

func test_get_all_sub_hexes_all_valid() -> void:
	var subs: Array[Vector2i] = HexMath.get_all_sub_hexes()
	for sub in subs:
		var s: Vector2i = sub
		assert_bool(HexMath.is_valid_sub_hex(s)).is_true()

# --- prop_world_position ---

func test_prop_world_position_equals_main_plus_sub() -> void:
	var main_coords := Vector2i(3, -2)
	var sub_coords := Vector2i(1, -1)
	var expected: Vector2 = HexMath.axial_to_world(main_coords) + HexMath.sub_axial_to_world(sub_coords)
	var result: Vector2 = HexMath.prop_world_position(main_coords, sub_coords)
	assert_float(result.x).is_equal_approx(expected.x, 0.0001)
	assert_float(result.y).is_equal_approx(expected.y, 0.0001)

func test_prop_world_position_zero_sub_equals_main() -> void:
	var main_coords := Vector2i(2, 1)
	var main_world: Vector2 = HexMath.axial_to_world(main_coords)
	var result: Vector2 = HexMath.prop_world_position(main_coords, Vector2i.ZERO)
	assert_float(result.x).is_equal_approx(main_world.x, 0.0001)
	assert_float(result.y).is_equal_approx(main_world.y, 0.0001)

# --- Adjacent sub-hex distance ---

func test_adjacent_sub_hexes_have_distance_one() -> void:
	for d in HexMath.DIRECTIONS:
		var dir: Vector2i = d
		assert_int(HexMath.distance(Vector2i.ZERO, dir)).is_equal(1)
