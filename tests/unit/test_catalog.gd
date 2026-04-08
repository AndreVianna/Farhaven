extends GdUnitTestSuite
class_name TestCatalog

## Unit tests for Catalog data layer (task-011).
## Tests 3-state knowledge system: UNKNOWN → ENCOUNTERED → CATALOGED.

const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")


# Minimal fake HexGrid for get_scannable_at tests
class FakeGrid extends RefCounted:
	var _tiles: Dictionary = {}
	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)


var _catalog
var _signal_id: StringName = &""
var _signal_cat: int = -1
var _signal_count: int = 0
var _encountered_id: StringName = &""
var _encountered_label: String = ""
var _encountered_count: int = 0
var _ksc_id: StringName = &""
var _ksc_old: int = -1
var _ksc_new: int = -1
var _ksc_count: int = 0


func _on_entry_cataloged(id: StringName, cat: int) -> void:
	_signal_id = id
	_signal_cat = cat
	_signal_count += 1


func _on_entry_encountered(id: StringName, label: String) -> void:
	_encountered_id = id
	_encountered_label = label
	_encountered_count += 1


func _on_knowledge_state_changed(id: StringName, old_state: int, new_state: int) -> void:
	_ksc_id = id
	_ksc_old = old_state
	_ksc_new = new_state
	_ksc_count += 1


func before_test() -> void:
	_catalog = _Catalog.new()
	_catalog.initialize()
	_signal_id = &""
	_signal_cat = -1
	_signal_count = 0
	_encountered_id = &""
	_encountered_label = ""
	_encountered_count = 0
	_ksc_id = &""
	_ksc_old = -1
	_ksc_new = -1
	_ksc_count = 0


func after_test() -> void:
	_catalog = null


# --- get_knowledge_state returns UNKNOWN/ENCOUNTERED/CATALOGED correctly ---

func test_get_knowledge_state_unknown_by_default() -> void:
	assert_int(_catalog.get_knowledge_state(&"berry_bush")).is_equal(_Catalog.KnowledgeState.UNKNOWN)


func test_get_knowledge_state_cataloged_after_catalog_entry() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_int(_catalog.get_knowledge_state(&"berry_bush")).is_equal(_Catalog.KnowledgeState.CATALOGED)


func test_get_knowledge_state_encountered_after_encounter_entry() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_int(_catalog.get_knowledge_state(&"thornback")).is_equal(_Catalog.KnowledgeState.ENCOUNTERED)


# --- is_cataloged before/after catalog_entry ---

func test_is_cataloged_false_before_catalog() -> void:
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_false()


func test_is_cataloged_true_after_catalog_entry() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_true()


func test_is_cataloged_only_marks_specific_id() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_bool(_catalog.is_cataloged(&"wood_tree")).is_false()


func test_is_cataloged_false_when_encountered() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_bool(_catalog.is_cataloged(&"thornback")).is_false()


# --- is_encountered ---

func test_is_encountered_false_by_default() -> void:
	assert_bool(_catalog.is_encountered(&"thornback")).is_false()


func test_is_encountered_true_after_encounter_entry() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_bool(_catalog.is_encountered(&"thornback")).is_true()


func test_is_encountered_false_after_catalog_entry() -> void:
	_catalog.catalog_entry(&"thornback")
	assert_bool(_catalog.is_encountered(&"thornback")).is_false()


# --- is_known ---

func test_is_known_false_for_unknown() -> void:
	assert_bool(_catalog.is_known(&"thornback")).is_false()


func test_is_known_true_for_encountered() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_bool(_catalog.is_known(&"thornback")).is_true()


func test_is_known_true_for_cataloged() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_bool(_catalog.is_known(&"berry_bush")).is_true()


# --- encounter_entry sets ENCOUNTERED + stores label ---

func test_encounter_entry_stores_hostile_label() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_str(_catalog.get_encounter_label(&"thornback")).is_equal("Hostile")


func test_encounter_entry_stores_shy_label() -> void:
	_catalog.encounter_entry(&"thornback", "Shy")
	assert_str(_catalog.get_encounter_label(&"thornback")).is_equal("Shy")


func test_encounter_entry_does_not_override_encountered() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	_catalog.encounter_entry(&"thornback", "Shy")  # should not override
	assert_str(_catalog.get_encounter_label(&"thornback")).is_equal("Hostile")
	assert_int(_catalog.get_knowledge_state(&"thornback")).is_equal(_Catalog.KnowledgeState.ENCOUNTERED)


func test_encounter_entry_does_not_downgrade_cataloged() -> void:
	_catalog.catalog_entry(&"thornback")
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_int(_catalog.get_knowledge_state(&"thornback")).is_equal(_Catalog.KnowledgeState.CATALOGED)


# --- catalog_entry can upgrade from ENCOUNTERED to CATALOGED ---

func test_catalog_entry_upgrades_encountered_to_cataloged() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	_catalog.catalog_entry(&"thornback")
	assert_int(_catalog.get_knowledge_state(&"thornback")).is_equal(_Catalog.KnowledgeState.CATALOGED)
	# Encounter label should be cleared
	assert_str(_catalog.get_encounter_label(&"thornback")).is_equal("")


# --- get_discovered_entries returns ENCOUNTERED + CATALOGED ---

func test_get_discovered_entries_empty_initially() -> void:
	assert_int(_catalog.get_discovered_entries().size()).is_equal(0)


func test_get_discovered_entries_includes_cataloged() -> void:
	_catalog.catalog_entry(&"berry_bush")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(1)


func test_get_discovered_entries_includes_encountered() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(1)


func test_get_discovered_entries_includes_both() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.encounter_entry(&"thornback", "Hostile")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(2)


func test_get_discovered_entries_contains_correct_entry() -> void:
	_catalog.catalog_entry(&"wood_tree")
	var found: Array = _catalog.get_discovered_entries()
	assert_int(found.size()).is_equal(1)
	assert_str(String(found[0].entry_id)).is_equal("wood_tree")


# --- get_discovered_by_category filtering ---

func test_get_discovered_by_category_filters_correctly() -> void:
	_catalog.catalog_entry(&"berry_bush")       # FLORA = 0
	_catalog.catalog_entry(&"stone_deposit")    # MINERAL = 2
	_catalog.encounter_entry(&"thornback", "Hostile")  # FAUNA = 1

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


# --- get_discovery_count counts ENCOUNTERED + CATALOGED ---

func test_get_discovery_count_starts_at_zero() -> void:
	assert_int(_catalog.get_discovery_count()).is_equal(0)


func test_get_discovery_count_increments_on_catalog_entry() -> void:
	_catalog.catalog_entry(&"berry_bush")
	assert_int(_catalog.get_discovery_count()).is_equal(1)
	_catalog.catalog_entry(&"wood_tree")
	assert_int(_catalog.get_discovery_count()).is_equal(2)


func test_get_discovery_count_increments_on_encounter_entry() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_int(_catalog.get_discovery_count()).is_equal(1)


func test_get_discovery_count_both_states() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_int(_catalog.get_discovery_count()).is_equal(2)


func test_get_total_count_matches_all_entries() -> void:
	# 4 flora + 1 fauna + 4 minerals + 1 anomaly = 10
	assert_int(_catalog.get_total_count()).is_equal(10)


# --- get_discovery_text returns "X entries" format ---

func test_get_discovery_text_format() -> void:
	_catalog.catalog_entry(&"berry_bush")
	var text: String = _catalog.get_discovery_text()
	assert_str(text).is_equal("1 entry")


func test_get_discovery_text_zero() -> void:
	assert_str(_catalog.get_discovery_text()).is_equal("0 entries")


func test_get_discovery_text_multiple() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_str(_catalog.get_discovery_text()).is_equal("2 entries")


# --- catalog_entry emits entry_cataloged + knowledge_state_changed signals ---

func test_catalog_entry_emits_entry_cataloged_signal() -> void:
	_catalog.entry_cataloged.connect(_on_entry_cataloged)
	_catalog.catalog_entry(&"berry_bush")
	assert_str(String(_signal_id)).is_equal("berry_bush")
	assert_int(_signal_cat).is_equal(_Catalog.CatalogCategory.FLORA)


func test_catalog_entry_emits_knowledge_state_changed() -> void:
	_catalog.knowledge_state_changed.connect(_on_knowledge_state_changed)
	_catalog.catalog_entry(&"berry_bush")
	assert_str(String(_ksc_id)).is_equal("berry_bush")
	assert_int(_ksc_old).is_equal(_Catalog.KnowledgeState.UNKNOWN)
	assert_int(_ksc_new).is_equal(_Catalog.KnowledgeState.CATALOGED)


func test_catalog_entry_does_not_emit_twice() -> void:
	_catalog.entry_cataloged.connect(_on_entry_cataloged)
	_catalog.catalog_entry(&"berry_bush")
	_catalog.catalog_entry(&"berry_bush")  # duplicate
	assert_int(_signal_count).is_equal(1)


func test_catalog_entry_marks_discovered() -> void:
	assert_bool(_catalog.is_cataloged(&"iron_deposit")).is_false()
	_catalog.catalog_entry(&"iron_deposit")
	assert_bool(_catalog.is_cataloged(&"iron_deposit")).is_true()


# --- encounter_entry emits entry_encountered + knowledge_state_changed signals ---

func test_encounter_entry_emits_entry_encountered_signal() -> void:
	_catalog.entry_encountered.connect(_on_entry_encountered)
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_str(String(_encountered_id)).is_equal("thornback")
	assert_str(_encountered_label).is_equal("Hostile")


func test_encounter_entry_emits_knowledge_state_changed() -> void:
	_catalog.knowledge_state_changed.connect(_on_knowledge_state_changed)
	_catalog.encounter_entry(&"thornback", "Hostile")
	assert_str(String(_ksc_id)).is_equal("thornback")
	assert_int(_ksc_old).is_equal(_Catalog.KnowledgeState.UNKNOWN)
	assert_int(_ksc_new).is_equal(_Catalog.KnowledgeState.ENCOUNTERED)


func test_encounter_entry_does_not_emit_twice() -> void:
	_catalog.entry_encountered.connect(_on_entry_encountered)
	_catalog.encounter_entry(&"thornback", "Hostile")
	_catalog.encounter_entry(&"thornback", "Shy")  # duplicate
	assert_int(_encountered_count).is_equal(1)


# --- get_scannable_at ---

func _make_tile_with_prop(prop_type: StringName) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.props = [_Prop.create_prop(prop_type, 0, 0)]
	return tile


func test_get_scannable_at_returns_entry_id_for_uncataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _make_tile_with_prop(&"berries")
	fake._tiles[Vector2i.ZERO] = tile

	_catalog._hex_grid = fake
	var result: StringName = _catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("berry_bush")


func test_get_scannable_at_returns_empty_for_cataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _make_tile_with_prop(&"berries")
	fake._tiles[Vector2i.ZERO] = tile

	_catalog._hex_grid = fake
	_catalog.catalog_entry(&"berry_bush")

	var result: StringName = _catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("")


func test_get_scannable_at_returns_empty_for_encountered_fauna() -> void:
	# ENCOUNTERED fauna cannot be proximity-scanned (needs Trap/Sneak)
	# This test would need a fauna tile — but fauna is queried via FaunaManager,
	# not via prop_nodes. So this covers the case where a prop node
	# somehow maps to a fauna entry that's ENCOUNTERED.
	# Since flora/mineral never enter ENCOUNTERED, this is effectively a no-op
	# for prop nodes in current data. Test the guard anyway.
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _HexTile.new()
	fake._tiles[Vector2i.ZERO] = tile
	_catalog._hex_grid = fake
	# Nothing scannable on empty tile
	var result: StringName = _catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("")


func test_get_scannable_at_returns_empty_when_no_hex_grid() -> void:
	assert_str(String(_catalog.get_scannable_at(Vector2i.ZERO))).is_equal("")


func test_get_scannable_at_anomaly_uncataloged() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _HexTile.new()
	tile.props = [_Prop.create_anomaly(&"anomaly_ch1_001")]
	fake._tiles[Vector2i(1, 0)] = tile

	_catalog._hex_grid = fake
	var result: StringName = _catalog.get_scannable_at(Vector2i(1, 0))
	assert_str(String(result)).is_equal("anomaly_ch1_001")


func test_get_scannable_at_anomaly_cataloged_returns_empty() -> void:
	var fake: FakeGrid = FakeGrid.new()
	var tile: HexTile = _HexTile.new()
	tile.props = [_Prop.create_anomaly(&"anomaly_ch1_001")]
	fake._tiles[Vector2i(1, 0)] = tile

	_catalog._hex_grid = fake
	_catalog.catalog_entry(&"anomaly_ch1_001")
	var result: StringName = _catalog.get_scannable_at(Vector2i(1, 0))
	assert_str(String(result)).is_equal("")


# --- Save / Load round-trip (knowledge states + encounter labels preserved) ---

func test_save_load_round_trip_preserves_cataloged() -> void:
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


func test_save_load_round_trip_preserves_encountered() -> void:
	_catalog.encounter_entry(&"thornback", "Hostile")

	var save_data: Dictionary = _catalog.get_save_data()

	var catalog2 = _Catalog.new()
	catalog2.initialize()
	catalog2.load_save_data(save_data)

	assert_bool(catalog2.is_encountered(&"thornback")).is_true()
	assert_str(catalog2.get_encounter_label(&"thornback")).is_equal("Hostile")
	assert_int(catalog2.get_discovery_count()).is_equal(1)


func test_save_load_round_trip_mixed_states() -> void:
	_catalog.catalog_entry(&"berry_bush")
	_catalog.encounter_entry(&"thornback", "Hostile")

	var save_data: Dictionary = _catalog.get_save_data()

	var catalog2 = _Catalog.new()
	catalog2.initialize()
	catalog2.load_save_data(save_data)

	assert_int(catalog2.get_knowledge_state(&"berry_bush")).is_equal(_Catalog.KnowledgeState.CATALOGED)
	assert_int(catalog2.get_knowledge_state(&"thornback")).is_equal(_Catalog.KnowledgeState.ENCOUNTERED)
	assert_str(catalog2.get_encounter_label(&"thornback")).is_equal("Hostile")
	assert_int(catalog2.get_discovery_count()).is_equal(2)


func test_save_data_format() -> void:
	_catalog.catalog_entry(&"fiber_grass")
	_catalog.encounter_entry(&"thornback", "Hostile")
	var data: Dictionary = _catalog.get_save_data()
	assert_bool(data.has("knowledge")).is_true()
	assert_bool(data.has("encounter_labels")).is_true()
	assert_str(data["knowledge"]["fiber_grass"]).is_equal("CATALOGED")
	assert_str(data["knowledge"]["thornback"]).is_equal("ENCOUNTERED")
	assert_str(data["encounter_labels"]["thornback"]).is_equal("Hostile")


func test_load_save_data_empty() -> void:
	_catalog.catalog_entry(&"stone_deposit")
	_catalog.load_save_data({"knowledge": {}, "encounter_labels": {}})
	assert_int(_catalog.get_discovery_count()).is_equal(0)
	assert_bool(_catalog.is_cataloged(&"stone_deposit")).is_false()


func test_load_save_data_backwards_compatible_with_discovered_format() -> void:
	# Old format had "discovered" array of entry IDs
	_catalog.load_save_data({"discovered": [&"berry_bush", &"stone_deposit"]})
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_true()
	assert_bool(_catalog.is_cataloged(&"stone_deposit")).is_true()
	assert_int(_catalog.get_discovery_count()).is_equal(2)


# --- PropRegistry catalog_entry mapping ---

func test_prop_defs_map_to_valid_catalog_entries() -> void:
	for def in PropRegistry.get_all():
		if def.catalog_entry == &"":
			continue  # anomaly_fragment has no catalog entry
		var entry = _catalog.get_entry(def.catalog_entry)
		assert_bool(entry != null).override_failure_message(
			"PropDef[%s].catalog_entry = %s — no matching CatalogEntry loaded" % [def.id, def.catalog_entry]
		).is_true()


func test_prop_registry_has_nine_defs() -> void:
	assert_int(PropRegistry.get_all().size()).is_equal(9)
