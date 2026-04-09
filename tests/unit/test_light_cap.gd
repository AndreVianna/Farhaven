class_name TestLightCap
extends GdUnitTestSuite

const _LightCap = preload("res://scripts/data/capabilities/light_cap.gd")


func test_default_radius_is_zero() -> void:
	var cap := _LightCap.new()
	assert_float(cap.radius).is_equal_approx(0.0, 0.001)


func test_default_color_is_warm_orange() -> void:
	var cap := _LightCap.new()
	assert_float(cap.color.r).is_equal_approx(1.0, 0.01)
	assert_float(cap.color.g).is_equal_approx(0.7, 0.01)
	assert_float(cap.color.b).is_equal_approx(0.3, 0.01)
	assert_float(cap.color.a).is_equal_approx(1.0, 0.01)


func test_default_flicker_is_false() -> void:
	var cap := _LightCap.new()
	assert_bool(cap.flicker).is_false()


func test_configured_torch_light() -> void:
	var cap := _LightCap.new()
	cap.radius = 3.0
	cap.color = Color(1.0, 0.5, 0.1)
	cap.flicker = true
	assert_float(cap.radius).is_equal_approx(3.0, 0.001)
	assert_float(cap.color.r).is_equal_approx(1.0, 0.01)
	assert_float(cap.color.g).is_equal_approx(0.5, 0.01)
	assert_bool(cap.flicker).is_true()


func test_zero_radius_means_no_light() -> void:
	var cap := _LightCap.new()
	cap.radius = 0.0
	assert_float(cap.radius).is_equal_approx(0.0, 0.001)


func test_cap_is_resource() -> void:
	var cap := _LightCap.new()
	assert_bool(cap is Resource).is_true()
