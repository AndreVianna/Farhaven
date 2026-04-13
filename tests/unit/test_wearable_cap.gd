extends GdUnitTestSuite
class_name TestWearableCap

## Unit tests for WearableCap (delivery-006j).
## The enum grew from 9 slots to 22 with explicit left/right pairs and
## gained two static helpers (place_to_string / string_to_place) that
## callers rely on for save-file stability.

const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")


func test_place_count_matches_enum() -> void:
	# Keep _WearableCap.PLACE_COUNT in sync with the enum body so UI
	# widgets that preallocate slot arrays don't silently skip a slot.
	assert_int(_WearableCap.PLACE_COUNT).is_equal(22)


func test_place_to_string_covers_every_enum_value() -> void:
	# Every declared Place must round-trip to a non-empty string so
	# save files never emit a blank slot key.
	for i in _WearableCap.PLACE_COUNT:
		var s: StringName = _WearableCap.place_to_string(i)
		assert_str(String(s)).is_not_equal("")


func test_string_to_place_round_trip() -> void:
	for i in _WearableCap.PLACE_COUNT:
		var s: StringName = _WearableCap.place_to_string(i)
		var back: int = _WearableCap.string_to_place(s)
		assert_int(back).is_equal(i)


func test_unknown_slot_name_returns_minus_one() -> void:
	# Treated as a hard error signal — callers must NOT fall back to a
	# default slot, which would silently misroute loaded gear.
	assert_int(_WearableCap.string_to_place(&"pocket")).is_equal(-1)
	assert_int(_WearableCap.string_to_place(&"")).is_equal(-1)


func test_default_place_is_back() -> void:
	var cap := _WearableCap.new()
	assert_int(cap.place).is_equal(_WearableCap.Place.BACK)


func test_left_and_right_slots_are_distinct() -> void:
	# L/R pairs must have different enum values so the same PropDef
	# can't collide against itself on both sides.
	var pairs := [
		[&"left_shoulder", &"right_shoulder"],
		[&"left_chest", &"right_chest"],
		[&"left_arm", &"right_arm"],
		[&"left_forearm", &"right_forearm"],
		[&"left_hand", &"right_hand"],
		[&"left_thigh", &"right_thigh"],
		[&"left_leg", &"right_leg"],
		[&"left_foot", &"right_foot"],
	]
	for pair in pairs:
		var l: int = _WearableCap.string_to_place(pair[0])
		var r: int = _WearableCap.string_to_place(pair[1])
		assert_int(l).is_not_equal(r)
		assert_int(l).is_greater_equal(0)
		assert_int(r).is_greater_equal(0)
