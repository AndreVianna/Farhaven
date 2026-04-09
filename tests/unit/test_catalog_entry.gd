class_name TestCatalogEntry
extends GdUnitTestSuite

const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")


func test_default_entry_id_is_empty() -> void:
	var entry := _CatalogEntry.new()
	assert_str(String(entry.entry_id)).is_empty()


func test_default_category_is_zero() -> void:
	var entry := _CatalogEntry.new()
	assert_int(entry.category).is_equal(0)


func test_default_display_name_is_empty() -> void:
	var entry := _CatalogEntry.new()
	assert_str(entry.display_name).is_empty()


func test_default_description_is_empty() -> void:
	var entry := _CatalogEntry.new()
	assert_str(entry.description).is_empty()


func test_default_icon_is_null() -> void:
	var entry := _CatalogEntry.new()
	assert_object(entry.icon).is_null()


func test_default_properties_is_empty() -> void:
	var entry := _CatalogEntry.new()
	assert_int(entry.properties.size()).is_equal(0)


func test_configured_fauna_entry() -> void:
	var entry := _CatalogEntry.new()
	entry.entry_id = &"deer_01"
	entry.category = 1  # FAUNA
	entry.display_name = "Forest Deer"
	entry.description = "A gentle woodland creature."
	entry.properties = {"passive": true, "drops": "hide"}
	assert_str(String(entry.entry_id)).is_equal("deer_01")
	assert_int(entry.category).is_equal(1)
	assert_str(entry.display_name).is_equal("Forest Deer")
	assert_bool(entry.properties["passive"]).is_true()


func test_entry_is_resource() -> void:
	var entry := _CatalogEntry.new()
	assert_bool(entry is Resource).is_true()
