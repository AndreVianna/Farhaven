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
