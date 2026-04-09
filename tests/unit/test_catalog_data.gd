class_name TestCatalogData
extends GdUnitTestSuite

const _CatalogData = preload("res://scripts/scanner/catalog_data.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")


func test_default_entries_is_empty() -> void:
	var data := _CatalogData.new()
	assert_int(data.entries.size()).is_equal(0)


func test_add_entries() -> void:
	var data := _CatalogData.new()
	var entry := _CatalogEntry.new()
	entry.entry_id = &"fauna_01"
	entry.display_name = "Deer"
	data.entries.append(entry)
	assert_int(data.entries.size()).is_equal(1)
	assert_str(String(data.entries[0].entry_id)).is_equal("fauna_01")


func test_multiple_entries() -> void:
	var data := _CatalogData.new()
	for i in 3:
		var entry := _CatalogEntry.new()
		entry.entry_id = StringName("fauna_%02d" % i)
		data.entries.append(entry)
	assert_int(data.entries.size()).is_equal(3)


func test_data_is_resource() -> void:
	var data := _CatalogData.new()
	assert_bool(data is Resource).is_true()
