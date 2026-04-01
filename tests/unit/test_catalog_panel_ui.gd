extends GdUnitTestSuite
class_name TestCatalogPanelUI

## Unit tests for CatalogEntryUI and CatalogPanel (task-014).
## Follows TDD: written before implementation.

const _CatalogEntryUIPkg = preload("res://ui/catalog_entry_ui.gd")
const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")

var _panel: PanelContainer = null
var _panel_opened_count: int = 0


func _make_entry(id: StringName, name: String, category: int) -> CatalogEntry:
	var e := _CatalogEntry.new()
	e.entry_id = id
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


# --- CatalogEntryUI ---

func test_catalog_entry_ui_minimum_height() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	assert_float(entry_ui.custom_minimum_size.y).is_greater_equal(80.0)
	entry_ui.queue_free()


func test_catalog_entry_ui_setup_name() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"berry_bush", "Berry Bush", 0)
	e.properties = {"edible": true, "toxic": false, "resource_type": &"berries"}
	entry_ui.setup(e)
	assert_str(entry_ui._name_label.text).is_equal("Berry Bush")
	entry_ui.queue_free()


func test_catalog_entry_ui_setup_description() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"berry_bush", "Berry Bush", 0)
	e.description = "A tasty red berry."
	e.properties = {}
	entry_ui.setup(e)
	assert_str(entry_ui._desc_label.text).is_equal("A tasty red berry.")
	entry_ui.queue_free()


func test_catalog_entry_ui_flora_properties_edible() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"berry_bush", "Berry Bush", 0)
	e.properties = {"edible": true, "toxic": false, "resource_type": &"berries"}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.contains("Edible")).is_true()
	entry_ui.queue_free()


func test_catalog_entry_ui_flora_properties_toxic() -> void:
	var entry_ui = _CatalogEntryUIPkg.new()
	add_child(entry_ui)
	var e := _make_entry(&"toxic_berry_bush", "Toxic Berry Bush", 0)
	e.properties = {"edible": true, "toxic": true, "resource_type": &"toxic_berries"}
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
	var e := _make_entry(&"iron_deposit", "Iron Deposit", 2)
	e.properties = {"resource_type": &"ore", "tool_required": &"stone_pickaxe"}
	entry_ui.setup(e)
	assert_bool(entry_ui._props_label.text.to_lower().contains("pickaxe")).is_true()
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
	cat.catalog_entry(&"berry_bush")
	_panel.set_catalog(cat)
	_panel.open()
	assert_bool(_panel._counter_label.text.begins_with("1/")).is_true()


func test_catalog_panel_counter_updates_on_entry_cataloged() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	_panel.set_catalog(cat)
	_panel.open()
	cat.catalog_entry(&"berry_bush")
	assert_bool(_panel._counter_label.text.begins_with("1/")).is_true()


# --- Entries per category ---

func test_catalog_panel_flora_tab_shows_flora_entries() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"berry_bush")
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
