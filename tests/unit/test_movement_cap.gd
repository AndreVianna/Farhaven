class_name TestMovementCap
extends GdUnitTestSuite

const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")


func test_default_mode_is_walk() -> void:
	var cap := _MovementCap.new()
	assert_int(cap.mode).is_equal(_MovementCap.Mode.WALK)


func test_default_move_cooldown_is_one() -> void:
	var cap := _MovementCap.new()
	assert_float(cap.move_cooldown).is_equal_approx(1.0, 0.001)


func test_default_max_jump_is_one() -> void:
	var cap := _MovementCap.new()
	assert_int(cap.max_jump).is_equal(1)


func test_mode_can_be_swim() -> void:
	var cap := _MovementCap.new()
	cap.mode = _MovementCap.Mode.SWIM
	assert_int(cap.mode).is_equal(_MovementCap.Mode.SWIM)


func test_mode_can_be_fly() -> void:
	var cap := _MovementCap.new()
	cap.mode = _MovementCap.Mode.FLY
	assert_int(cap.mode).is_equal(_MovementCap.Mode.FLY)


func test_mode_can_be_burrow() -> void:
	var cap := _MovementCap.new()
	cap.mode = _MovementCap.Mode.BURROW
	assert_int(cap.mode).is_equal(_MovementCap.Mode.BURROW)


func test_mode_can_be_climb() -> void:
	var cap := _MovementCap.new()
	cap.mode = _MovementCap.Mode.CLIMB
	assert_int(cap.mode).is_equal(_MovementCap.Mode.CLIMB)


func test_custom_move_cooldown() -> void:
	var cap := _MovementCap.new()
	cap.move_cooldown = 0.25
	assert_float(cap.move_cooldown).is_equal_approx(0.25, 0.001)


func test_custom_max_jump() -> void:
	var cap := _MovementCap.new()
	cap.max_jump = 3
	assert_int(cap.max_jump).is_equal(3)


func test_cap_is_resource() -> void:
	var cap := _MovementCap.new()
	assert_bool(cap is Resource).is_true()
