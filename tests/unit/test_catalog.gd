extends GdUnitTestSuite
class_name TestCatalog

## Unit tests for Catalog data layer (task-011).

const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")


# Minimal fake HexGrid for get_scannable_at tests
class FakeGrid extends RefCounted:
	var _tiles: Dictionary = {}
	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)


var _catalog
var _signal_id: StringName = &""
var _signal_cat: int = -1
var _signal_count: int = 0


func _on_entry_cataloged(id: StringName, cat: int) -> void:
	_signal_id = id
	_signal_cat = cat
	_signal_count += 1


func before_test() -> void:
	_catalog = _Catalog.new()
	_catalog.initialize()
	_signal_id = &""
	_signal_cat = -1
	_signal_count = 0


func after_test() -> void:
	_catalog = null


# --- is_cataloged before/after catalog_entry ---

func test_is_cataloged_false_before_catalog() -> void:
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_false()


func test_is_cataloged_true_after_catalog_entry() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_true()


func test_is_cataloged_only_marks_specific_id() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_bool(_catalog.is_cataloged(&"wood_tree")).is_false()


# --- get_discovered_entries ---

func test_get_discovered_entries_empty_initially() -> void:
	assert_int(_catalog.get_discovered_entries().size()).is_equal(0)


func test_get_discovered_entries_after_catalog() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.catalog_entry(&"stone_deposit")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(2)


func test_get_discovered_entries_contains_correct_entry() -> void:
	_catalog.catalog_entry(&"wood_tree")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(1)
	assert_str(String(found[0].entry_id)).is_equal("wood_tree")


# --- get_discovered_by_category ---

func test_get_discovered_by_category_filters_correctly() -> void:
	_catalog.catalog_entry(&"berry_bush")       # FLORA = 0
	_catalog.catalog_entry(&"stone_deposit")    # MINERAL = 2
	_catalog.catalog_entry(&"thornback")        # FAUNA = 1

	var flora: Array = _catalog.get_discovered_by_category(_Catalog.CatalogCategory.FLORA)
	var fauna: Array = _catalog.get_discovered_by_category(_Catalog.CatalogCategory.FAUNA)
	var minerals: Array = _catalog.get_discovered_by_category(_Catalog.CatalogCategory.MINERAL)

	assert_int(flora.size()).is_equal(1)
	assert_int(fauna.size()).is_equal(1)
	assert_int(minerals.size()).is_equal(1)


func test_get_discovered_by_category_empty_when_none() -> void:
	_catalog.catalog_entry(&"berry_bush")
	var fauna: Array = _catalog.get_discovered_by_category(_Catalog.CatalogCategory.FAUNA)
	assert_int(fauna.size()).is_equal(0)


# --- get_discovery_count / get_total_count / get_discovery_text ---

func test_get_discovery_count_starts_at_zero() -> void:
	assert_int(_catalog.get_discovery_count()).is_equal(0)


func test_get_discovery_count_increments_on_catalog_entry() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_int(_catalog.get_discovery_count()).is_equal(1)
	_catalog.catalog_entry(&"wood_tree")
	assert_int(_catalog.get_discovery_count()).is_equal(2)


func test_get_total_count_matches_all_entries() -> void:
	# 4 flora + 1 fauna + 3 minerals + 1 anomaly = 9
	assert_int(_catalog.get_total_count()).is_equal(9)


func test_get_discovery_text_format() -> void:
	_catalog.catalog_entry(&"berry_bush")
	var text: String = _catalog.get_discovery_text()
	assert_str(text).is_equal("1 entry")


func test_get_discovery_text_zero() -> void:
	assert_str(_catalog.get_discovery_text()).is_equal("0 entries")


# --- catalog_entry emits entry_cataloged signal ---

func test_catalog_entry_emits_signal() -> void:
	_catalog.entry_cataloged.connect(_on_entry_cataloged)
	_catalog.catalog_entry(&"berry_bush")
	assert_str(String(_signal_id)).is_equal("berry_bush")
	assert_int(_signal_cat).is_equal(_Catalog.CatalogCategory.FLORA)


func test_catalog_entry_does_not_emit_twice() -> void:
	_catalog.entry_cataloged.connect(_on_entry_cataloged)
	_catalog.catalog_entry(&"berry_bush")
	_catalog.catalog_entry(&"berry_bush")  # duplicate
	assert_int(_signal_count).is_equal(1)


func test_catalog_entry_marks_discovered() -> void:
	assert_bool(_catalog.is_cataloged(&"iron_deposit")).is_false()
	_catalog.catalog_entry(&"iron_deposit")
	assert_bool(_catalog.is_cataloged(&"iron_deposit")).is_true()


# --- get_scannable_at ---

func _make_tile_with_resource(resource_type: StringName) -> HexTile:
	var tile: HexTile = _HexTile.new()
	var node: ResourceNode = _ResourceNode.new()
	node.type = resource_type
	tile.resource_nodes = [node]
	return tile


func test_get_scannable_at_returns_entry_id_for_uncataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _make_tile_with_resource(&"berries")
	fake._tiles[Vector2i.ZERO] = tile

	_catalog._hex_grid = fake
	var result: StringName = _catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("berry_bush")


func test_get_scannable_at_returns_empty_for_cataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _make_tile_with_resource(&"berries")
	fake._tiles[Vector2i.ZERO] = tile

	_catalog._hex_grid = fake
	_catalog.catalog_entry(&"berry_bush")

	var result: StringName = _catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("")


func test_get_scannable_at_returns_empty_when_no_hex_grid() -> void:
	assert_str(String(_catalog.get_scannable_at(Vector2i.ZERO))).is_equal("")


func test_get_scannable_at_anomaly_uncataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _HexTile.new()
	tile.anomaly = &"anomaly_ch1_001"
	fake._tiles[Vector2i(1, 0)] = tile

	_catalog._hex_grid = fake
	var result: StringName = _catalog.get_scannable_at(Vector2i(1, 0))
	assert_str(String(result)).is_equal("anomaly_ch1_001")


func test_get_scannable_at_anomaly_cataloged_returns_empty() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _HexTile.new()
	tile.anomaly = &"anomaly_ch1_001"
	fake._tiles[Vector2i(1, 0)] = tile

	_catalog._hex_grid = fake
	_catalog.catalog_entry(&"anomaly_ch1_001")
	var result: StringName = _catalog.get_scannable_at(Vector2i(1, 0))
	assert_str(String(result)).is_equal("")


# --- Save / Load round-trip ---

func test_save_load_round_trip_preserves_discovered() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.catalog_entry(&"thornback")

	var save_data: Dictionary = _catalog.get_save_data()

	var catalog2 = _Catalog.new()
	catalog2.initialize()
	catalog2.load_save_data(save_data)

	assert_bool(catalog2.is_cataloged(&"berry_bush")).is_true()
	assert_bool(catalog2.is_cataloged(&"thornback")).is_true()
	assert_bool(catalog2.is_cataloged(&"wood_tree")).is_false()
	assert_int(catalog2.get_discovery_count()).is_equal(2)


func test_save_data_format() -> void:
	_catalog.catalog_entry(&"fiber_grass")
	var data: Dictionary = _catalog.get_save_data()
	assert_bool(data.has("discovered")).is_true()
	assert_int(data["discovered"].size()).is_equal(1)
	assert_bool(data["discovered"].has(&"fiber_grass")).is_true()


func test_load_save_data_empty_discovered() -> void:
	_catalog.catalog_entry(&"stone_deposit")
	_catalog.load_save_data({"discovered": []})
	assert_int(_catalog.get_discovery_count()).is_equal(0)
	assert_bool(_catalog.is_cataloged(&"stone_deposit")).is_false()


# --- RESOURCE_TO_ENTRY mapping ---

func test_resource_to_entry_all_seven_map_to_valid_entries() -> void:
	for resource_type in _Catalog.RESOURCE_TO_ENTRY:
		var entry_id: StringName = _Catalog.RESOURCE_TO_ENTRY[resource_type]
		var entry = _catalog.get_entry(entry_id)
		assert_bool(entry != null).override_failure_message(
			"RESOURCE_TO_ENTRY[%s] = %s — no matching CatalogEntry loaded" % [resource_type, entry_id]
		).is_true()


func test_resource_to_entry_has_seven_entries() -> void:
	assert_int(_Catalog.RESOURCE_TO_ENTRY.size()).is_equal(7)
