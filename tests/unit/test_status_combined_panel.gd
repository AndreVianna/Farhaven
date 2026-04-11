extends GdUnitTestSuite
class_name TestStatusCombinedPanel

## Unit tests for StatusCombinedPanel and its status-side sections (task-082).
## Covers the three new left-side sections (stats, discoveries, nav) plus
## signal-driven updates. Uses mock SurvivalSystem / DayNightCycle / Catalog
## so the panel can be exercised without a full scene tree.
##
## We avoid instantiating the full StatusCombinedPanel here because its right
## side loads the inventory_panel scene which drags in HUD/PropRegistry deps.
## The left-side sections are the entire subject of task-082 and we exercise
## them directly — this matches the pattern used by test_catalog_panel_ui.gd
## where individual UI components are tested in isolation.

const _StatsSection = preload("res://ui/status_stats_section.gd")
const _DiscoveriesSection = preload("res://ui/status_discoveries_section.gd")
const _NavSection = preload("res://ui/status_nav_section.gd")


# --- Mock SurvivalSystem ---

class MockSurvival extends Node:
	signal stat_changed(stat_name: StringName, current: float, max_val: float)
	signal player_died()
	signal player_respawned()

	var hp: float = 100.0
	var hp_max: float = 100.0
	var hunger: float = 80.0
	var hunger_max: float = 100.0
	var thirst: float = 60.0
	var thirst_max: float = 100.0

	func emit_stat(name: StringName, current: float, max_val: float) -> void:
		match name:
			&"hp":
				hp = current
				hp_max = max_val
			&"hunger":
				hunger = current
				hunger_max = max_val
			&"thirst":
				thirst = current
				thirst_max = max_val
		stat_changed.emit(name, current, max_val)


# --- Mock DayNightCycle ---

class MockDayNight extends Node:
	signal day_started()
	signal phase_changed(old_phase: int, new_phase: int)

	var day_count: int = 1
	var is_daytime: bool = true

	func advance_day(to: int) -> void:
		day_count = to
		day_started.emit()


# --- Mock Catalog ---

class MockCatalog extends RefCounted:
	signal entry_cataloged(entry_id: StringName, bucket: int)
	signal entry_encountered(entry_id: StringName, label: String)

	var _cataloged: int = 0
	var _total: int = 10

	func get_discovery_count() -> int:
		return _cataloged

	func get_total_count() -> int:
		return _total

	func catalog(id: StringName) -> void:
		_cataloged += 1
		entry_cataloged.emit(id, 0)

	func encounter(id: StringName, label: String) -> void:
		_cataloged += 1
		entry_encountered.emit(id, label)


# --- Section under test state ---

var _stats: Node = null
var _discoveries: Node = null
var _nav: Node = null
var _survival: MockSurvival = null
var _day_night: MockDayNight = null
var _catalog: MockCatalog = null
var _nav_signal_log: Array[String] = []


func before_test() -> void:
	_survival = MockSurvival.new()
	add_child(_survival)
	_day_night = MockDayNight.new()
	add_child(_day_night)
	_catalog = MockCatalog.new()
	_nav_signal_log = []


func after_test() -> void:
	if _stats != null and is_instance_valid(_stats):
		remove_child(_stats)
		_stats.free()
	_stats = null
	if _discoveries != null and is_instance_valid(_discoveries):
		remove_child(_discoveries)
		_discoveries.free()
	_discoveries = null
	if _nav != null and is_instance_valid(_nav):
		remove_child(_nav)
		_nav.free()
	_nav = null
	if _survival != null and is_instance_valid(_survival):
		remove_child(_survival)
		_survival.free()
	_survival = null
	if _day_night != null and is_instance_valid(_day_night):
		remove_child(_day_night)
		_day_night.free()
	_day_night = null
	_catalog = null


func _make_stats() -> Node:
	var section = _StatsSection.new()
	add_child(section)
	_stats = section
	return section


func _make_discoveries() -> Node:
	var section = _DiscoveriesSection.new()
	add_child(section)
	_discoveries = section
	return section


func _make_nav() -> Node:
	var section = _NavSection.new()
	add_child(section)
	_nav = section
	return section


# === PANEL CLASS: instantiates without error ===

func test_status_combined_panel_class_loads() -> void:
	# Guard: StatusCombinedPanel class parses and is accessible via preload.
	var script: GDScript = preload("res://ui/status_combined_panel.gd")
	assert_object(script).is_not_null()


# === STATS SECTION: structure ===

func test_stats_section_instantiates() -> void:
	var section = _make_stats()
	assert_object(section).is_not_null()
	assert_bool(section is VBoxContainer).is_true()


func test_stats_section_has_hp_bar() -> void:
	var section = _make_stats()
	assert_object(section.get_bar(&"hp")).is_not_null()


func test_stats_section_has_hunger_bar() -> void:
	var section = _make_stats()
	assert_object(section.get_bar(&"hunger")).is_not_null()


func test_stats_section_has_thirst_bar() -> void:
	var section = _make_stats()
	assert_object(section.get_bar(&"thirst")).is_not_null()


func test_stats_section_has_stamina_bar() -> void:
	var section = _make_stats()
	assert_object(section.get_bar(&"stamina")).is_not_null()


func test_stats_section_has_day_label() -> void:
	var section = _make_stats()
	assert_object(section.get_day_label()).is_not_null()


func test_stats_section_has_chapter_label() -> void:
	var section = _make_stats()
	assert_object(section.get_chapter_label()).is_not_null()


func test_stats_section_default_chapter_is_chapter_1() -> void:
	var section = _make_stats()
	assert_str(section.get_chapter_label().text).is_equal("Chapter 1")


func test_stats_section_default_day_is_01() -> void:
	var section = _make_stats()
	assert_str(section.get_day_label().text).is_equal("01")


# === STATS SECTION: injected state ===

func test_stats_section_reads_hp_from_survival_system() -> void:
	var section = _make_stats()
	_survival.hp = 42.0
	_survival.hp_max = 100.0
	section.set_survival_system(_survival)
	var value_label: Label = section.get_value_label(&"hp")
	assert_str(value_label.text).is_equal("42 / 100")


func test_stats_section_reads_hunger_from_survival_system() -> void:
	var section = _make_stats()
	_survival.hunger = 75.0
	section.set_survival_system(_survival)
	assert_str(section.get_value_label(&"hunger").text).is_equal("75 / 100")


func test_stats_section_reads_thirst_from_survival_system() -> void:
	var section = _make_stats()
	_survival.thirst = 25.0
	section.set_survival_system(_survival)
	assert_str(section.get_value_label(&"thirst").text).is_equal("25 / 100")


func test_stats_section_stamina_shows_na_when_missing() -> void:
	# MockSurvival does not expose stamina — the section should render N/A.
	var section = _make_stats()
	section.set_survival_system(_survival)
	assert_str(section.get_value_label(&"stamina").text).is_equal("N/A")


func test_stats_section_reads_day_from_cycle() -> void:
	var section = _make_stats()
	_day_night.day_count = 7
	section.set_day_night_cycle(_day_night)
	assert_str(section.get_day_label().text).is_equal("07")


func test_stats_section_updates_on_stat_changed_signal() -> void:
	var section = _make_stats()
	section.set_survival_system(_survival)
	_survival.emit_stat(&"hp", 25.0, 100.0)
	assert_str(section.get_value_label(&"hp").text).is_equal("25 / 100")
	var bar: ProgressBar = section.get_bar(&"hp")
	assert_float(bar.value).is_equal_approx(25.0, 0.01)


func test_stats_section_updates_hunger_on_signal() -> void:
	var section = _make_stats()
	section.set_survival_system(_survival)
	_survival.emit_stat(&"hunger", 10.0, 100.0)
	assert_str(section.get_value_label(&"hunger").text).is_equal("10 / 100")


func test_stats_section_updates_day_on_day_started_signal() -> void:
	var section = _make_stats()
	section.set_day_night_cycle(_day_night)
	_day_night.advance_day(12)
	assert_str(section.get_day_label().text).is_equal("12")


func test_stats_section_set_chapter_updates_label() -> void:
	var section = _make_stats()
	section.set_chapter("Chapter 2")
	assert_str(section.get_chapter_label().text).is_equal("Chapter 2")


func test_stats_section_disconnects_old_survival_on_reassignment() -> void:
	var section = _make_stats()
	section.set_survival_system(_survival)
	var second := MockSurvival.new()
	add_child(second)
	section.set_survival_system(second)
	# Emitting on the first survival should now be a no-op.
	_survival.emit_stat(&"hp", 1.0, 100.0)
	# Section still shows state from 'second' (100/100 default).
	assert_str(section.get_value_label(&"hp").text).is_equal("100 / 100")
	remove_child(second)
	second.free()


# === DISCOVERIES SECTION ===

func test_discoveries_section_instantiates() -> void:
	var section = _make_discoveries()
	assert_object(section).is_not_null()
	assert_object(section.get_count_label()).is_not_null()


func test_discoveries_section_default_count_is_zero_zero() -> void:
	var section = _make_discoveries()
	assert_str(section.get_count_label().text).is_equal("Cataloged: 0 / 0")


func test_discoveries_section_reads_counts_from_catalog() -> void:
	var section = _make_discoveries()
	_catalog._cataloged = 3
	_catalog._total = 10
	section.set_catalog(_catalog)
	assert_str(section.get_count_label().text).is_equal("Cataloged: 3 / 10")


func test_discoveries_section_updates_on_entry_cataloged_signal() -> void:
	var section = _make_discoveries()
	section.set_catalog(_catalog)
	_catalog.catalog(&"P00001")
	assert_str(section.get_count_label().text).is_equal("Cataloged: 1 / 10")


func test_discoveries_section_updates_on_entry_encountered_signal() -> void:
	var section = _make_discoveries()
	section.set_catalog(_catalog)
	_catalog.encounter(&"P00002", "Hostile")
	assert_str(section.get_count_label().text).is_equal("Cataloged: 1 / 10")


func test_discoveries_section_handles_null_catalog() -> void:
	var section = _make_discoveries()
	section.set_catalog(null)
	assert_str(section.get_count_label().text).is_equal("Cataloged: 0 / 0")


# === NAV SECTION ===

func test_nav_section_instantiates() -> void:
	var section = _make_nav()
	assert_object(section).is_not_null()


func test_nav_section_has_three_buttons() -> void:
	var section = _make_nav()
	assert_int(section.get_buttons().size()).is_equal(3)


func test_nav_section_button_names() -> void:
	var section = _make_nav()
	var names: Array[String] = []
	for btn: Button in section.get_buttons():
		names.append(btn.text)
	assert_bool("Settings" in names).is_true()
	assert_bool("About" in names).is_true()
	assert_bool("Contact" in names).is_true()


func test_nav_section_has_modal() -> void:
	var section = _make_nav()
	assert_object(section.get_modal()).is_not_null()
	assert_bool(section.get_modal() is AcceptDialog).is_true()


func test_nav_section_modal_starts_hidden() -> void:
	var section = _make_nav()
	assert_bool(section.get_modal().visible).is_false()


func test_nav_section_button_press_emits_nav_opened() -> void:
	var section = _make_nav()
	section.nav_opened.connect(func(link_name: String) -> void:
		_nav_signal_log.append(link_name)
	)
	var buttons: Array[Button] = section.get_buttons()
	buttons[0].pressed.emit()
	assert_int(_nav_signal_log.size()).is_equal(1)
	assert_str(_nav_signal_log[0]).is_equal("Settings")


func test_nav_section_button_press_populates_modal_text() -> void:
	var section = _make_nav()
	section.show_modal("About")
	assert_bool("About" in section.get_modal().dialog_text).is_true()
	assert_bool("future update" in section.get_modal().dialog_text).is_true()


func test_nav_section_all_three_buttons_trigger_modal() -> void:
	var section = _make_nav()
	section.nav_opened.connect(func(link_name: String) -> void:
		_nav_signal_log.append(link_name)
	)
	for btn: Button in section.get_buttons():
		btn.pressed.emit()
	assert_int(_nav_signal_log.size()).is_equal(3)
	assert_bool("Settings" in _nav_signal_log).is_true()
	assert_bool("About" in _nav_signal_log).is_true()
	assert_bool("Contact" in _nav_signal_log).is_true()
