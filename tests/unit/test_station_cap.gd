class_name TestStationCap
extends GdUnitTestSuite

const _StationCap = preload("res://scripts/data/capabilities/station_cap.gd")


func test_default_station_tags_is_empty() -> void:
	var cap := _StationCap.new()
	assert_int(cap.station_tags.size()).is_equal(0)


func test_single_station_tag() -> void:
	var cap := _StationCap.new()
	cap.station_tags = [&"fire"]
	assert_int(cap.station_tags.size()).is_equal(1)
	assert_bool(cap.station_tags.has(&"fire")).is_true()


func test_multiple_station_tags() -> void:
	var cap := _StationCap.new()
	cap.station_tags = [&"fire", &"cook", &"smelt"]
	assert_int(cap.station_tags.size()).is_equal(3)
	assert_bool(cap.station_tags.has(&"cook")).is_true()
	assert_bool(cap.station_tags.has(&"smelt")).is_true()


func test_station_tag_not_present() -> void:
	var cap := _StationCap.new()
	cap.station_tags = [&"fire"]
	assert_bool(cap.station_tags.has(&"water")).is_false()


func test_cap_is_resource() -> void:
	var cap := _StationCap.new()
	assert_bool(cap is Resource).is_true()
