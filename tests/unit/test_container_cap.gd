class_name TestContainerCap
extends GdUnitTestSuite

const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")


func test_default_capacity_size_is_zero() -> void:
	var cap := _ContainerCap.new()
	assert_float(cap.capacity_size).is_equal_approx(0.0, 0.001)


func test_configured_container() -> void:
	var cap := _ContainerCap.new()
	cap.capacity_size = 25.0
	assert_float(cap.capacity_size).is_equal_approx(25.0, 0.001)


func test_cap_is_resource() -> void:
	var cap := _ContainerCap.new()
	assert_bool(cap is Resource).is_true()
