class_name TestMovementCap
extends GdUnitTestSuite

const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")


func test_default_modes_is_empty() -> void:
	var cap := _MovementCap.new()
	assert_bool(cap.modes.is_empty()).is_true()


func test_walk_only_mode() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.WALK): [1.0, 1.5]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.WALK))).is_true()
	var walk_speeds: Array = cap.modes[int(_MovementCap.Mode.WALK)]
	assert_int(walk_speeds.size()).is_equal(2)
	assert_float(walk_speeds[0]).is_equal_approx(1.0, 0.001)
	assert_float(walk_speeds[1]).is_equal_approx(1.5, 0.001)


func test_swim_mode() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.SWIM): [0.8, 1.2]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.SWIM))).is_true()
	var swim_speeds: Array = cap.modes[int(_MovementCap.Mode.SWIM)]
	assert_float(swim_speeds[0]).is_equal_approx(0.8, 0.001)
	assert_float(swim_speeds[1]).is_equal_approx(1.2, 0.001)


func test_fly_mode() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.FLY): [3.0, 5.0]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.FLY))).is_true()
	var fly_speeds: Array = cap.modes[int(_MovementCap.Mode.FLY)]
	assert_float(fly_speeds[0]).is_equal_approx(3.0, 0.001)
	assert_float(fly_speeds[1]).is_equal_approx(5.0, 0.001)


func test_burrow_mode() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.BURROW): [0.5, 0.7]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.BURROW))).is_true()


func test_climb_mode() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.CLIMB): [0.6, 0.8]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.CLIMB))).is_true()


func test_jump_mode_added_to_enum() -> void:
	var cap := _MovementCap.new()
	cap.modes = {int(_MovementCap.Mode.JUMP): [2.0, 3.0]}
	assert_bool(cap.modes.has(int(_MovementCap.Mode.JUMP))).is_true()
	var jump_speeds: Array = cap.modes[int(_MovementCap.Mode.JUMP)]
	assert_float(jump_speeds[0]).is_equal_approx(2.0, 0.001)
	assert_float(jump_speeds[1]).is_equal_approx(3.0, 0.001)


func test_amphibian_walk_and_swim() -> void:
	# Multiple modes coexist: a frog walks AND swims
	var cap := _MovementCap.new()
	cap.modes = {
		int(_MovementCap.Mode.WALK): [1.0, 1.5],
		int(_MovementCap.Mode.SWIM): [0.8, 1.2],
	}
	assert_int(cap.modes.size()).is_equal(2)
	assert_bool(cap.modes.has(int(_MovementCap.Mode.WALK))).is_true()
	assert_bool(cap.modes.has(int(_MovementCap.Mode.SWIM))).is_true()


func test_walk_and_jump_frog() -> void:
	# A frog-like creature with walk and jump
	var cap := _MovementCap.new()
	cap.modes = {
		int(_MovementCap.Mode.WALK): [1.0, 1.5],
		int(_MovementCap.Mode.JUMP): [2.0, 3.0],
	}
	assert_int(cap.modes.size()).is_equal(2)
	assert_bool(cap.modes.has(int(_MovementCap.Mode.WALK))).is_true()
	assert_bool(cap.modes.has(int(_MovementCap.Mode.JUMP))).is_true()


func test_mode_enum_has_jump() -> void:
	# Sanity: JUMP must be the 6th enum value (int 5)
	assert_int(int(_MovementCap.Mode.JUMP)).is_equal(5)
	assert_int(int(_MovementCap.Mode.WALK)).is_equal(0)
	assert_int(int(_MovementCap.Mode.SWIM)).is_equal(1)
	assert_int(int(_MovementCap.Mode.FLY)).is_equal(2)
	assert_int(int(_MovementCap.Mode.BURROW)).is_equal(3)
	assert_int(int(_MovementCap.Mode.CLIMB)).is_equal(4)


func test_cap_is_resource() -> void:
	var cap := _MovementCap.new()
	assert_bool(cap is Resource).is_true()
