extends GdUnitTestSuite
class_name TestSaveManager

const SaveManagerScript = preload("res://scripts/save/save_manager.gd")
const SAVE_PATH: String = "user://save.json"


# --- Helpers ---

func _make_save_manager() -> Node:
	var sm: Node = SaveManagerScript.new()
	add_child(sm)
	return sm


func _cleanup_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _write_save_file(content: String) -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_save_file() -> String:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func before_test() -> void:
	_cleanup_save_file()


func after_test() -> void:
	_cleanup_save_file()


# --- save_game / load_game round-trip ---

func test_save_creates_file() -> void:
	var sm: Node = _make_save_manager()
	var result: bool = sm.save_game()
	assert_bool(result).is_true()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()


func test_save_writes_valid_json() -> void:
	var sm: Node = _make_save_manager()
	sm.save_game()
	var text: String = _read_save_file()
	var parsed: Variant = JSON.parse_string(text)
	assert_object(parsed).is_not_null()


func test_save_load_round_trip_empty() -> void:
	# With no systems reachable, save should produce {} and load should succeed
	var sm: Node = _make_save_manager()
	sm.save_game()
	var loaded: bool = sm.load_game()
	assert_bool(loaded).is_true()


func test_has_save_false_when_no_file() -> void:
	var sm: Node = _make_save_manager()
	assert_bool(sm.has_save()).is_false()


func test_has_save_true_after_save() -> void:
	var sm: Node = _make_save_manager()
	sm.save_game()
	assert_bool(sm.has_save()).is_true()


func test_delete_save_removes_file() -> void:
	var sm: Node = _make_save_manager()
	sm.save_game()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	sm.delete_save()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


# --- Corrupt file handling ---

func test_load_corrupt_file_returns_false() -> void:
	_write_save_file("this is not json {{{")
	var sm: Node = _make_save_manager()
	var result: bool = sm.load_game()
	assert_bool(result).is_false()


func test_load_corrupt_file_deletes_file() -> void:
	_write_save_file("not valid json")
	var sm: Node = _make_save_manager()
	sm.load_game()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


func test_load_json_array_treated_as_corrupt() -> void:
	# A valid JSON array is not a valid save (must be Dictionary)
	_write_save_file("[1, 2, 3]")
	var sm: Node = _make_save_manager()
	var result: bool = sm.load_game()
	assert_bool(result).is_false()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


# --- Missing save file ---

func test_load_missing_file_returns_false() -> void:
	var sm: Node = _make_save_manager()
	var result: bool = sm.load_game()
	assert_bool(result).is_false()


# --- Missing systems at runtime ---

func test_save_with_no_scene_systems_skips_player_children() -> void:
	# Autoloads (HexGrid, DayNightCycle) are present in test env, but player children are not.
	# Verify the save dict does NOT contain player-child keys (inventory, crafting, etc.)
	var sm: Node = _make_save_manager()
	sm.save_game()
	var text: String = _read_save_file()
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).is_true()
	var data: Dictionary = parsed as Dictionary
	assert_bool(data.has("inventory")).is_false()
	assert_bool(data.has("crafting")).is_false()
	assert_bool(data.has("survival")).is_false()
	assert_bool(data.has("journal")).is_false()


# --- Load with extra/missing keys ---

func test_load_with_unknown_keys_does_not_crash() -> void:
	var data: Dictionary = {"unknown_system": {"foo": "bar"}, "another": 42}
	_write_save_file(JSON.stringify(data))
	var sm: Node = _make_save_manager()
	var result: bool = sm.load_game()
	assert_bool(result).is_true()


func test_load_empty_dict_does_not_crash() -> void:
	_write_save_file("{}")
	var sm: Node = _make_save_manager()
	var result: bool = sm.load_game()
	assert_bool(result).is_true()


# --- Dirty flag & timer ---

func test_mark_dirty_sets_flag() -> void:
	var sm: Node = _make_save_manager()
	assert_bool(sm._dirty).is_false()
	sm.mark_dirty()
	assert_bool(sm._dirty).is_true()


func test_save_now_saves_immediately_and_clears_dirty() -> void:
	var sm: Node = _make_save_manager()
	sm.mark_dirty()
	sm.save_now()
	assert_bool(sm._dirty).is_false()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()


func test_timer_saves_when_dirty() -> void:
	var sm: Node = _make_save_manager()
	sm.mark_dirty()
	# Simulate what the timer callback does
	sm._on_save_timer()
	assert_bool(sm._dirty).is_false()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()


func test_timer_skips_save_when_not_dirty() -> void:
	var sm: Node = _make_save_manager()
	# Not dirty — timer should not create a save file
	sm._on_save_timer()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()


func test_save_timer_created_in_ready() -> void:
	var sm: Node = _make_save_manager()
	assert_object(sm._save_timer).is_not_null()
	assert_float(sm._save_timer.wait_time).is_equal(5.0)


# ---------------------------------------------------------------------------
# Aggregate save shape (task-084c gap-fill)
# ---------------------------------------------------------------------------
#
# SaveManager collects data from the nodes listed in _SYSTEM_KEYS, keyed by
# a short string. These tests document which keys participate and verify the
# aggregate format is JSON-parseable round-trip through whatever autoloads
# ARE reachable from the test harness (typically /root/HexGrid and
# /root/DayNightCycle — player-scoped nodes are not present).

func test_system_keys_contract() -> void:
	# Fail-loud if the contract shifts. If this breaks, someone added/removed a
	# system and didn't update either the test or the docs.
	var expected_keys := [
		"hex_grid", "day_night", "player", "camera",
		"crafting", "scanner", "survival",
	]
	var actual_keys: Array = []
	for entry in SaveManagerScript._SYSTEM_KEYS:
		actual_keys.append(entry["key"])
	assert_int(actual_keys.size()).is_equal(expected_keys.size())
	for key in expected_keys:
		assert_bool(actual_keys.has(key)).is_true()


func test_aggregate_save_shape_includes_reachable_autoloads() -> void:
	# /root/HexGrid and /root/DayNightCycle are real autoloads in the test env.
	var sm: Node = _make_save_manager()
	sm.save_game()
	var text: String = _read_save_file()
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).is_true()
	var data: Dictionary = parsed as Dictionary
	# HexGrid is an autoload with get_save_data() — must appear in the dict.
	assert_bool(data.has("hex_grid")).is_true()
	# DayNightCycle is also an autoload with get_save_data().
	assert_bool(data.has("day_night")).is_true()


func test_aggregate_save_hex_grid_section_shape() -> void:
	var sm: Node = _make_save_manager()
	sm.save_game()
	var parsed: Dictionary = JSON.parse_string(_read_save_file())
	# HexGrid.get_save_data() returns {"seed": int, "tiles": Array}
	assert_bool(parsed.has("hex_grid")).is_true()
	var hg_data: Dictionary = parsed["hex_grid"]
	assert_bool(hg_data.has("seed")).is_true()
	assert_bool(hg_data.has("tiles")).is_true()
	assert_bool(hg_data["tiles"] is Array).is_true()


func test_aggregate_save_json_roundtrip_stable() -> void:
	# Save twice back-to-back; the two serialized dicts should have the same
	# top-level key set (contributing autoloads produce deterministic sections
	# when state is unchanged).
	var sm: Node = _make_save_manager()
	sm.save_game()
	var first_text := _read_save_file()
	sm.save_game()
	var second_text := _read_save_file()
	var first_parsed: Dictionary = JSON.parse_string(first_text)
	var second_parsed: Dictionary = JSON.parse_string(second_text)
	assert_int(first_parsed.size()).is_equal(second_parsed.size())
	for key in first_parsed.keys():
		assert_bool(second_parsed.has(key)).is_true()


func test_aggregate_save_is_valid_json_dictionary() -> void:
	# The stored string must parse to a Dictionary. If SaveManager ever started
	# writing an Array or a primitive, load_game would treat it as corrupt.
	var sm: Node = _make_save_manager()
	sm.save_game()
	var parsed: Variant = JSON.parse_string(_read_save_file())
	assert_bool(parsed is Dictionary).is_true()


func test_roundtrip_via_load_does_not_crash_with_autoloads() -> void:
	# Save, then load — distribute_save_data walks _SYSTEM_KEYS and calls
	# load_save_data on whatever nodes are reachable. Must not crash even when
	# only a subset of systems are present.
	var sm: Node = _make_save_manager()
	sm.save_game()
	var ok: bool = sm.load_game()
	assert_bool(ok).is_true()


# ---------------------------------------------------------------------------
# Signal wiring (task-084c gap-fill)
# ---------------------------------------------------------------------------
#
# SaveManager intentionally emits NO signals — it is a passive collector
# driven by mark_dirty() / save_now() / _on_save_timer. Document the
# absence so future work doesn't silently add a signal without a test.

func test_save_manager_has_no_declared_signals() -> void:
	var sm: Node = _make_save_manager()
	var sig_list: Array = sm.get_signal_list()
	# Filter out inherited Node signals — SaveManager's own script declares none.
	var script_signals: Array = []
	var script: Script = sm.get_script() as Script
	if script != null:
		script_signals = script.get_script_signal_list()
	assert_int(script_signals.size()).is_equal(0)
