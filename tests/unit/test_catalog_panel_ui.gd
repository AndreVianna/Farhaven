extends GdUnitTestSuite
class_name TestCatalogPanelUI

## Unit tests for CatalogEntryUI and CatalogPanel (task-014).
## Tests 3-state display: ENCOUNTERED entries show minimal info,
## CATALOGED entries show full info.

const _CatalogEntryUIPkg = preload("res://ui/catalog_entry_ui.gd")
const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")

var _panel: PanelContainer = null
var _panel_opened_count: int = 0


func _make_entry(id: StringName, name: String, category: int) -> CatalogableCap:
	var e := _CatalogableCap.new()
	e.display_name = name
	e.description = "Test description."
	e.category = category
	e.properties = {}
	return e


func before_test() -> void:
	_panel = _CatalogPanelScene.instantiate()
	add_child(_panel)
	_panel_opened_count = 0


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


# --- CatalogEntryUI: CATALOGED display ---

func test_catalog_entry_ui_minimum_height() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	assert_float(entry_ui.custom_minimum_size.y).is_greater_equal(80.0)
	entry_ui.queue_free()


func test_catalog_entry_ui_setup_name() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00004", "Berry Bush", 0)
	e.properties = {"edible": true, "toxic": false, "prop_type": &"berries"}
	entry_ui.setup(e)
	assert_str(entry_ui._name_label.text).is_equal("Berry Bush")
	entry_ui.queue_free()


func test_catalog_entry_ui_setup_description() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00004", "Berry Bush", 0)
	e.description = "A tasty red berry."
	e.properties = {}
	entry_ui.setup(e)
	assert_str(entry_ui._desc_label.text).is_equal("A tasty red berry.")
	entry_ui.queue_free()


func test_catalog_entry_ui_flora_properties_edible() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00004", "Berry Bush", 0)
	e.properties = {"edible": true, "toxic": false, "prop_type": &"berries"}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.contains("Edible")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_flora_properties_toxic() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00008", "Toxic Berry Bush", 0)
	e.properties = {"edible": true, "toxic": true, "prop_type": &"toxic_berries"}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.contains("Toxic")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_fauna_hostile_shows_hostile() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"thornback", "Thornback", 1)
	e.properties = {"hostile": true, "damage": 10, "hp": 20}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.contains("Hostile")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_mineral_shows_tool() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00006", "Iron Deposit", 2)
	e.properties = {"prop_type": &"ore", "tool_required": &"stone_pickaxe"}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.to_lower().contains("pickaxe")).is_true()
	entry_ui.queue_free()


# --- CatalogEntryUI: ENCOUNTERED display ---

func test_catalog_entry_ui_encountered_shows_warning_label() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	entry_ui.setup_encountered("Hostile")
	assert_bool(entry_ui._name_label.text.contains("Unidentified Fauna")).is_true()
	assert_bool(entry_ui._name_label.text.contains("Hostile")).is_true()
	assert_bool(entry_ui._name_label.text.contains("⚠️")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_encountered_shy_label() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	entry_ui.setup_encountered("Shy")
	assert_bool(entry_ui._name_label.text.contains("Shy")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_encountered_no_description() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	entry_ui.setup_encountered("Hostile")
	assert_str(entry_ui._desc_label.text).is_equal("")
	assert_str(entry_ui._props_label.text).is_equal("")
	entry_ui.queue_free()


func test_catalog_entry_ui_encountered_flag() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	entry_ui.setup_encountered("Hostile")
	assert_bool(entry_ui.is_encountered()).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_cataloged_not_encountered() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"P00004", "Berry Bush", 0)
	e.properties = {}
	entry_ui.setup(e)
	assert_bool(entry_ui.is_encountered()).is_false()
	entry_ui.queue_free()


# --- CatalogPanel open / close / toggle ---

func test_catalog_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


func test_catalog_panel_open_makes_visible() -> void:
	_panel.open()
	assert_bool(_panel.visible).is_true()


func test_catalog_panel_close_hides() -> void:
	_panel.open()
	_panel.close()
	assert_bool(_panel.visible).is_false()


func test_catalog_panel_toggle_opens_when_hidden() -> void:
	_panel.toggle()
	assert_bool(_panel.visible).is_true()


func test_catalog_panel_toggle_closes_when_visible() -> void:
	_panel.open()
	_panel.toggle()
	assert_bool(_panel.visible).is_false()


# --- panel_opened signal ---

func test_catalog_panel_open_emits_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_catalog_panel_open_twice_emits_once() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_catalog_panel_close_does_not_emit_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.close()
	assert_int(_panel_opened_count).is_equal(0)


# --- Category tabs ---

func test_catalog_panel_has_four_tabs() -> void:
	assert_int(_panel._tabs.get_tab_count()).is_equal(4)


func test_catalog_panel_tab_titles() -> void:
	assert_str(_panel._tabs.get_tab_title(0)).is_equal("Flora")
	assert_str(_panel._tabs.get_tab_title(1)).is_equal("Fauna")
	assert_str(_panel._tabs.get_tab_title(2)).is_equal("Minerals")
	assert_str(_panel._tabs.get_tab_title(3)).is_equal("Anomalies")


# --- Discovery counter ---

func test_catalog_panel_counter_updates_on_open() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00004")
	_panel.set_catalog(cat)
	_panel.open()
	assert_str(_panel._counter_label.text).is_equal("1 entry")


func test_catalog_panel_counter_updates_on_entry_cataloged() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	_panel.set_catalog(cat)
	_panel.open()
	cat.catalog_entry(&"P00004")
	assert_str(_panel._counter_label.text).is_equal("1 entry")


func test_catalog_panel_counter_counts_encountered_plus_cataloged() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00004")
	cat.encounter_entry(&"thornback", "Hostile")
	_panel.set_catalog(cat)
	_panel.open()
	assert_str(_panel._counter_label.text).is_equal("2 entries")


# --- Entries per category ---

func test_catalog_panel_flora_tab_shows_flora_entries() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00004")
	_panel.set_catalog(cat)
	_panel.open()
	assert_int(_panel._flora_list.get_child_count()).is_equal(1)


func test_catalog_panel_wrong_category_not_in_flora() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"thornback")  # FAUNA — should NOT appear in flora tab
	_panel.set_catalog(cat)
	_panel.open()
	assert_int(_panel._flora_list.get_child_count()).is_equal(0)


func test_catalog_panel_encountered_fauna_shows_in_fauna_tab() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.encounter_entry(&"thornback", "Hostile")
	_panel.set_catalog(cat)
	_panel.open()
	assert_int(_panel._fauna_list.get_child_count()).is_equal(1)


func test_catalog_panel_encountered_entry_uses_encountered_display() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.encounter_entry(&"thornback", "Hostile")
	_panel.set_catalog(cat)
	_panel.open()
	# The entry in the fauna list should be an encountered entry
	var child: Node = _panel._fauna_list.get_child(0)
	assert_bool(child is _CatalogEntryUIPkg).is_true()
	if child is _CatalogEntryUIPkg:
		assert_bool(child.is_encountered()).is_true()


func test_catalog_panel_updates_on_entry_encountered() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	_panel.set_catalog(cat)
	_panel.open()
	assert_int(_panel._fauna_list.get_child_count()).is_equal(0)

	cat.encounter_entry(&"thornback", "Hostile")

	assert_int(_panel._fauna_list.get_child_count()).is_equal(1)
	assert_str(_panel._counter_label.text).is_equal("1 entry")
