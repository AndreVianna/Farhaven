extends GdUnitTestSuite
class_name TestSshMath

const HexMath = preload("res://scripts/hex/hex_math.gd")

# --- SSH_SIZE constant ---

func test_ssh_size_approximately_0_16() -> void:
	# SSH diameter is ~0.32m, so SSH_SIZE (center-to-vertex) is ~0.16
	assert_float(HexMath.SSH_SIZE).is_equal_approx(0.16, 0.01)

func test_ssh_size_matches_formula() -> void:
	# Same derivation as SUB_HEX_SIZE: (parent_size / cos(30°)) / 5
	var expected: float = (HexMath.SUB_HEX_SIZE / cos(deg_to_rad(30.0))) / 5.0
	assert_float(HexMath.SSH_SIZE).is_equal_approx(expected, 0.0001)

func test_ssh_diameter_approximately_0_32() -> void:
	# The spec says SSH diameter = 0.320m
	assert_float(HexMath.SSH_SIZE * 2.0).is_equal_approx(0.32, 0.01)

# --- ssh_axial_to_world ---

func test_ssh_axial_to_world_origin_returns_zero() -> void:
	var result: Vector2 = HexMath.ssh_axial_to_world(0, 0)
	assert_float(result.x).is_equal_approx(0.0, 0.0001)
	assert_float(result.y).is_equal_approx(0.0, 0.0001)

func test_ssh_axial_to_world_nonzero_is_small_offset() -> void:
	# Any single-step SSH offset should be within SSH diameter
	var result: Vector2 = HexMath.ssh_axial_to_world(1, 0)
	var length: float = result.length()
	assert_bool(length > 0.0).is_true()
	assert_bool(length < HexMath.SSH_SIZE * 2.5).is_true()

# --- Round-trip: ssh_axial_to_world -> world_to_ssh_axial ---

func test_ssh_roundtrip_origin() -> void:
	var world: Vector2 = HexMath.ssh_axial_to_world(0, 0)
	var back: Vector2i = HexMath.world_to_ssh_axial(world)
	assert_bool(back == Vector2i(0, 0)).is_true()

func test_ssh_roundtrip_all_19_positions() -> void:
	var all_sshs: Array[Vector2i] = HexMath.get_all_sshs()
	for ssh in all_sshs:
		var s: Vector2i = ssh
		var world: Vector2 = HexMath.ssh_axial_to_world(s.x, s.y)
		var back: Vector2i = HexMath.world_to_ssh_axial(world)
		assert_bool(back == s).is_true()

func test_ssh_roundtrip_extended_range() -> void:
	# Test positions beyond the valid 19 grid for math correctness
	var test_coords: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(-2, 3), Vector2i(0, -3),
		Vector2i(1, 2), Vector2i(-3, 1),
	]
	for coords in test_coords:
		var c: Vector2i = coords
		var world: Vector2 = HexMath.ssh_axial_to_world(c.x, c.y)
		var back: Vector2i = HexMath.world_to_ssh_axial(world)
		assert_bool(back == c).is_true()

# --- full_position_to_world ---

func test_full_position_to_world_all_zeros_equals_origin_tile() -> void:
	var result: Vector2 = HexMath.full_position_to_world(Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO)
	var expected: Vector2 = HexMath.axial_to_world(Vector2i.ZERO)
	assert_float(result.x).is_equal_approx(expected.x, 0.0001)
	assert_float(result.y).is_equal_approx(expected.y, 0.0001)

func test_full_position_to_world_zero_ssh_equals_prop_world() -> void:
	var tile := Vector2i(3, -2)
	var sub_hex := Vector2i(1, -1)
	var result: Vector2 = HexMath.full_position_to_world(tile, sub_hex, Vector2i.ZERO)
	var expected: Vector2 = HexMath.prop_world_position(tile, sub_hex)
	assert_float(result.x).is_equal_approx(expected.x, 0.0001)
	assert_float(result.y).is_equal_approx(expected.y, 0.0001)

func test_full_position_to_world_nonzero_ssh_within_ssh_size_of_sub_center() -> void:
	var tile := Vector2i(1, 0)
	var sub_hex := Vector2i(0, 1)
	var ssh := Vector2i(1, 0)
	var result: Vector2 = HexMath.full_position_to_world(tile, sub_hex, ssh)
	var sub_center: Vector2 = HexMath.prop_world_position(tile, sub_hex)
	var offset: float = (result - sub_center).length()
	# SSH offset should be within one SSH step (SSH_SIZE * sqrt(3) covers the max single-step distance)
	assert_bool(offset > 0.0).is_true()
	assert_bool(offset < HexMath.SSH_SIZE * 2.5).is_true()

func test_full_position_to_world_equals_sum_of_parts() -> void:
	var tile := Vector2i(2, -1)
	var sub_hex := Vector2i(-1, 1)
	var ssh := Vector2i(1, -1)
	var result: Vector2 = HexMath.full_position_to_world(tile, sub_hex, ssh)
	var expected: Vector2 = HexMath.axial_to_world(tile) + HexMath.sub_axial_to_world(sub_hex) + HexMath.ssh_axial_to_world(ssh.x, ssh.y)
	assert_float(result.x).is_equal_approx(expected.x, 0.0001)
	assert_float(result.y).is_equal_approx(expected.y, 0.0001)

# --- snap_to_ssh ---

func test_snap_to_ssh_returns_valid_sub_hex() -> void:
	var tile := Vector2i(0, 0)
	var world_pos: Vector2 = HexMath.axial_to_world(tile) + Vector2(0.1, 0.1)
	var result: Dictionary = HexMath.snap_to_ssh(world_pos, tile)
	assert_bool(HexMath.is_valid_sub_hex(result["sub_hex"])).is_true()

func test_snap_to_ssh_returns_valid_ssh() -> void:
	var tile := Vector2i(0, 0)
	var world_pos: Vector2 = HexMath.axial_to_world(tile) + Vector2(0.1, 0.1)
	var result: Dictionary = HexMath.snap_to_ssh(world_pos, tile)
	assert_bool(HexMath.is_valid_ssh(result["ssh"])).is_true()

func test_snap_to_ssh_of_ssh_center_returns_same_ssh() -> void:
	var tile := Vector2i(0, 0)
	var sub_hex := Vector2i(1, 0)
	var ssh := Vector2i(0, 1)
	var exact_world: Vector2 = HexMath.full_position_to_world(tile, sub_hex, ssh)
	var result: Dictionary = HexMath.snap_to_ssh(exact_world, tile)
	assert_bool(result["sub_hex"] == sub_hex).is_true()
	assert_bool(result["ssh"] == ssh).is_true()

func test_snap_to_ssh_snapped_world_matches_full_position() -> void:
	var tile := Vector2i(1, -1)
	var sub_hex := Vector2i(0, 1)
	var ssh := Vector2i(-1, 0)
	var exact_world: Vector2 = HexMath.full_position_to_world(tile, sub_hex, ssh)
	var result: Dictionary = HexMath.snap_to_ssh(exact_world, tile)
	var expected_snapped: Vector2 = HexMath.full_position_to_world(tile, result["sub_hex"], result["ssh"])
	assert_float(result["snapped_world"].x).is_equal_approx(expected_snapped.x, 0.0001)
	assert_float(result["snapped_world"].y).is_equal_approx(expected_snapped.y, 0.0001)

func test_snap_to_ssh_origin_tile_center_snaps_to_zero_zero() -> void:
	var tile := Vector2i(0, 0)
	var world_pos: Vector2 = HexMath.axial_to_world(tile)
	var result: Dictionary = HexMath.snap_to_ssh(world_pos, tile)
	assert_bool(result["sub_hex"] == Vector2i.ZERO).is_true()
	assert_bool(result["ssh"] == Vector2i.ZERO).is_true()

# --- Multiple SSH positions within one sub-hex are distinct ---

func test_multiple_ssh_positions_in_same_sub_hex_are_distinct() -> void:
	var tile := Vector2i(0, 0)
	var sub_hex := Vector2i(0, 0)
	var positions: Array[Vector2] = []
	var all_sshs: Array[Vector2i] = HexMath.get_all_sshs()
	for ssh in all_sshs:
		var s: Vector2i = ssh
		var world: Vector2 = HexMath.full_position_to_world(tile, sub_hex, s)
		positions.append(world)
	# All 19 positions should be distinct (no two closer than a tiny epsilon)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: float = (positions[i] - positions[j]).length()
			assert_bool(dist > 0.01).is_true()

# --- SSH positions at sub-hex boundary snap correctly ---

func test_ssh_at_sub_hex_boundary_snaps_correctly() -> void:
	# Place a point exactly at an SSH center near the edge of sub-hex (0,0)
	var tile := Vector2i(0, 0)
	var sub_hex := Vector2i(0, 0)
	var ssh := Vector2i(2, 0)  # ring-2 SSH, near boundary
	var exact_world: Vector2 = HexMath.full_position_to_world(tile, sub_hex, ssh)
	var result: Dictionary = HexMath.snap_to_ssh(exact_world, tile)
	# The snapped position should be very close to the original
	var snap_diff: float = (result["snapped_world"] - exact_world).length()
	assert_bool(snap_diff < 0.001).is_true()

# --- is_valid_ssh ---

func test_is_valid_ssh_center() -> void:
	assert_bool(HexMath.is_valid_ssh(Vector2i(0, 0))).is_true()

func test_is_valid_ssh_ring_1() -> void:
	for d in HexMath.DIRECTIONS:
		var dir: Vector2i = d
		assert_bool(HexMath.is_valid_ssh(dir)).is_true()

func test_is_valid_ssh_ring_2() -> void:
	var ring_2: Array[Vector2i] = HexMath.get_ring(Vector2i.ZERO, 2)
	for pos in ring_2:
		var p: Vector2i = pos
		assert_bool(HexMath.is_valid_ssh(p)).is_true()

func test_is_valid_ssh_radius_3_false() -> void:
	var ring_3: Array[Vector2i] = HexMath.get_ring(Vector2i.ZERO, 3)
	for pos in ring_3:
		var p: Vector2i = pos
		assert_bool(HexMath.is_valid_ssh(p)).is_false()

# --- get_all_sshs ---

func test_get_all_sshs_returns_19() -> void:
	assert_int(HexMath.get_all_sshs().size()).is_equal(19)

func test_get_all_sshs_contains_center() -> void:
	assert_bool(HexMath.get_all_sshs().has(Vector2i.ZERO)).is_true()

func test_get_all_sshs_all_valid() -> void:
	for ssh in HexMath.get_all_sshs():
		var s: Vector2i = ssh
		assert_bool(HexMath.is_valid_ssh(s)).is_true()
