class_name TestPortableCap
extends GdUnitTestSuite

const _PortableCap = preload("res://scripts/data/capabilities/portable_cap.gd")


func test_default_weight_is_one() -> void:
	var cap := _PortableCap.new()
	assert_float(cap.weight).is_equal_approx(1.0, 0.001)


func test_custom_weight() -> void:
	var cap := _PortableCap.new()
	cap.weight = 0.15
	assert_float(cap.weight).is_equal_approx(0.15, 0.001)


func test_heavy_item_weight() -> void:
	var cap := _PortableCap.new()
	cap.weight = 5.0
	assert_float(cap.weight).is_equal_approx(5.0, 0.001)


func test_very_light_item() -> void:
	var cap := _PortableCap.new()
	cap.weight = 0.01
	assert_float(cap.weight).is_equal_approx(0.01, 0.001)


func test_cap_is_resource() -> void:
	var cap := _PortableCap.new()
	assert_bool(cap is Resource).is_true()
