class_name TestCatalogableCap
extends GdUnitTestSuite

const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")


func test_default_scan_time_is_one() -> void:
	var cap := _CatalogableCap.new()
	assert_float(cap.scan_time).is_equal_approx(1.0, 0.001)


func test_default_display_tag_is_empty() -> void:
	var cap := _CatalogableCap.new()
	assert_str(String(cap.display_tag)).is_empty()


func test_default_category_is_zero() -> void:
	var cap := _CatalogableCap.new()
	assert_int(cap.category).is_equal(0)


func test_default_display_name_is_empty() -> void:
	var cap := _CatalogableCap.new()
	assert_str(cap.display_name).is_empty()


func test_default_description_is_empty() -> void:
	var cap := _CatalogableCap.new()
	assert_str(cap.description).is_empty()


func test_default_icon_is_null() -> void:
	var cap := _CatalogableCap.new()
	assert_object(cap.icon).is_null()


func test_default_properties_is_empty() -> void:
	var cap := _CatalogableCap.new()
	assert_int(cap.properties.size()).is_equal(0)


func test_configured_flora_entry() -> void:
	var cap := _CatalogableCap.new()
	cap.scan_time = 2.0
	cap.display_tag = &"flora"
	cap.category = 0
	cap.display_name = "Thornwood Tree"
	cap.description = "A hardy tree with thorny bark."
	cap.properties = {"resource_type": "wood"}
	assert_float(cap.scan_time).is_equal_approx(2.0, 0.001)
	assert_str(String(cap.display_tag)).is_equal("flora")
	assert_str(cap.display_name).is_equal("Thornwood Tree")
	assert_str(cap.description).is_equal("A hardy tree with thorny bark.")
	assert_str(cap.properties["resource_type"]).is_equal("wood")


func test_anomaly_category_value() -> void:
	var cap := _CatalogableCap.new()
	cap.category = 3  # ANOMALY
	assert_int(cap.category).is_equal(3)


func test_properties_can_hold_booleans() -> void:
	var cap := _CatalogableCap.new()
	cap.properties = {"edible": false, "toxic": true}
	assert_bool(cap.properties["edible"]).is_false()
	assert_bool(cap.properties["toxic"]).is_true()


func test_cap_is_resource() -> void:
	var cap := _CatalogableCap.new()
	assert_bool(cap is Resource).is_true()
