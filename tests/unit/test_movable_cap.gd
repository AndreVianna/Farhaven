class_name TestMovableCap
extends GdUnitTestSuite

const _MovableCap = preload("res://scripts/data/capabilities/movable_cap.gd")


func test_default_push_cost_is_one() -> void:
	var cap := _MovableCap.new()
	assert_float(cap.push_cost).is_equal_approx(1.0, 0.001)


func test_custom_push_cost() -> void:
	var cap := _MovableCap.new()
	cap.push_cost = 2.5
	assert_float(cap.push_cost).is_equal_approx(2.5, 0.001)


func test_zero_push_cost_means_free_to_move() -> void:
	var cap := _MovableCap.new()
	cap.push_cost = 0.0
	assert_float(cap.push_cost).is_equal_approx(0.0, 0.001)


func test_cap_is_resource() -> void:
	var cap := _MovableCap.new()
	assert_bool(cap is Resource).is_true()
