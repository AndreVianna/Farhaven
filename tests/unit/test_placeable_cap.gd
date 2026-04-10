class_name TestPlaceableCap
extends GdUnitTestSuite

const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")


func test_cap_is_resource() -> void:
	var cap := _PlaceableCap.new()
	assert_bool(cap is Resource).is_true()


func test_cap_is_marker_only() -> void:
	# PlaceableCap is a pure marker — no fields remain after task-062 cleanup.
	var cap := _PlaceableCap.new()
	assert_bool("footprint" in cap).is_false()
	assert_bool("blocks_movement" in cap).is_false()
	assert_bool("rotation_snap" in cap).is_false()
