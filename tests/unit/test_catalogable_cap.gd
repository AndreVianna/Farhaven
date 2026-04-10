class_name TestCatalogableCap
extends GdUnitTestSuite

const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")


func test_default_scan_time_is_one() -> void:
	var cap := _CatalogableCap.new()
	assert_float(cap.scan_time).is_equal_approx(1.0, 0.001)


func test_default_show_as_anomaly_is_false() -> void:
	var cap := _CatalogableCap.new()
	assert_bool(cap.show_as_anomaly).is_false()


func test_default_icon_is_null() -> void:
	var cap := _CatalogableCap.new()
	assert_object(cap.icon).is_null()


func test_default_properties_is_empty() -> void:
	var cap := _CatalogableCap.new()
	assert_int(cap.properties.size()).is_equal(0)


func test_configured_plant_entry() -> void:
	var cap := _CatalogableCap.new()
	cap.scan_time = 2.0
	cap.properties = {"resource_type": "wood"}
	assert_float(cap.scan_time).is_equal_approx(2.0, 0.001)
	assert_bool(cap.show_as_anomaly).is_false()
	assert_str(cap.properties["resource_type"]).is_equal("wood")


func test_show_as_anomaly_override() -> void:
	var cap := _CatalogableCap.new()
	cap.show_as_anomaly = true
	assert_bool(cap.show_as_anomaly).is_true()


func test_properties_can_hold_booleans() -> void:
	var cap := _CatalogableCap.new()
	cap.properties = {"edible": false, "toxic": true}
	assert_bool(cap.properties["edible"]).is_false()
	assert_bool(cap.properties["toxic"]).is_true()


func test_cap_is_resource() -> void:
	var cap := _CatalogableCap.new()
	assert_bool(cap is Resource).is_true()
