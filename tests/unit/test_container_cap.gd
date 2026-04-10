class_name TestContainerCap
extends GdUnitTestSuite

const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")


func test_default_capacity_size_is_zero() -> void:
	var cap := _ContainerCap.new()
	assert_float(cap.capacity_size).is_equal_approx(0.0, 0.001)


func test_default_accepts_filter_is_empty() -> void:
	var cap := _ContainerCap.new()
	assert_int(cap.accepts_filter.size()).is_equal(0)


func test_configured_container() -> void:
	var cap := _ContainerCap.new()
	cap.capacity_size = 25.0
	cap.accepts_filter = [&"BURNABLE.log", &"RESOURCE"]
	assert_float(cap.capacity_size).is_equal_approx(25.0, 0.001)
	assert_int(cap.accepts_filter.size()).is_equal(2)
	assert_bool(cap.accepts_filter.has(&"BURNABLE.log")).is_true()
	assert_bool(cap.accepts_filter.has(&"RESOURCE")).is_true()


func test_filter_does_not_contain_unset_tags() -> void:
	var cap := _ContainerCap.new()
	cap.accepts_filter = [&"WOOD"]
	assert_bool(cap.accepts_filter.has(&"STONE")).is_false()


func test_cap_is_resource() -> void:
	var cap := _ContainerCap.new()
	assert_bool(cap is Resource).is_true()
