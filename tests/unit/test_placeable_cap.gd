class_name TestPlaceableCap
extends GdUnitTestSuite

const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")


func test_cap_is_resource() -> void:
	var cap := _PlaceableCap.new()
	assert_bool(cap is Resource).is_true()


func test_footprint_defaults_to_single_hex() -> void:
	var cap := _PlaceableCap.new()
	assert_bool("footprint" in cap).is_true()
	assert_int(cap.footprint.x).is_equal(1)
	assert_int(cap.footprint.y).is_equal(1)


func test_no_legacy_fields() -> void:
	# blocks_movement and rotation_snap were removed in earlier cleanup.
	var cap := _PlaceableCap.new()
	assert_bool("blocks_movement" in cap).is_false()
	assert_bool("rotation_snap" in cap).is_false()
