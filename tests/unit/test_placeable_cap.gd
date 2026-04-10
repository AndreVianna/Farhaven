class_name TestPlaceableCap
extends GdUnitTestSuite

const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")


func test_default_rotation_snap_is_zero() -> void:
	var cap := _PlaceableCap.new()
	assert_int(cap.rotation_snap).is_equal(0)


func test_rotation_snap_60_degrees() -> void:
	var cap := _PlaceableCap.new()
	cap.rotation_snap = 60
	assert_int(cap.rotation_snap).is_equal(60)


func test_cap_is_resource() -> void:
	var cap := _PlaceableCap.new()
	assert_bool(cap is Resource).is_true()


func test_footprint_field_removed() -> void:
	var cap := _PlaceableCap.new()
	assert_bool("footprint" in cap).is_false()


func test_blocks_movement_field_removed() -> void:
	var cap := _PlaceableCap.new()
	assert_bool("blocks_movement" in cap).is_false()
