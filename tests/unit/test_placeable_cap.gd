class_name TestPlaceableCap
extends GdUnitTestSuite

const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")


func test_default_footprint_is_empty() -> void:
	var cap := _PlaceableCap.new()
	assert_int(cap.footprint.size()).is_equal(0)


func test_default_blocks_movement_is_false() -> void:
	var cap := _PlaceableCap.new()
	assert_bool(cap.blocks_movement).is_false()


func test_default_rotation_snap_is_zero() -> void:
	var cap := _PlaceableCap.new()
	assert_int(cap.rotation_snap).is_equal(0)


func test_single_cell_footprint() -> void:
	var cap := _PlaceableCap.new()
	cap.footprint = [Vector2i(0, 0)]
	assert_int(cap.footprint.size()).is_equal(1)
	assert_bool(cap.footprint[0] == Vector2i(0, 0)).is_true()


func test_multi_cell_footprint() -> void:
	var cap := _PlaceableCap.new()
	cap.footprint = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	assert_int(cap.footprint.size()).is_equal(3)


func test_blocking_structure() -> void:
	var cap := _PlaceableCap.new()
	cap.blocks_movement = true
	cap.footprint = [Vector2i(0, 0)]
	assert_bool(cap.blocks_movement).is_true()


func test_rotation_snap_60_degrees() -> void:
	var cap := _PlaceableCap.new()
	cap.rotation_snap = 60
	assert_int(cap.rotation_snap).is_equal(60)


func test_cap_is_resource() -> void:
	var cap := _PlaceableCap.new()
	assert_bool(cap is Resource).is_true()
