extends Node

## Autoload singleton — handles save/load for all game systems.
## task-026: auto-save on day_started, round-trip JSON save/load

const SAVE_PATH: String = "user://save.json"

## System registry: key used in save dict → NodePath or callable to locate the node.
## Autoloads are fetched from /root/<Name>.
## Player children are fetched via the scene tree.
const _SYSTEM_KEYS: Array[Dictionary] = [
	{"key": "hex_grid", "path": "/root/HexGrid"},
	{"key": "day_night", "path": "/root/DayNightCycle"},
	{"key": "player", "path": "/root/Main/Player"},
	{"key": "inventory", "path": "/root/Main/Player/Inventory"},
	{"key": "crafting", "path": "/root/Main/Player/CraftingSystem"},
	{"key": "catalog", "path": "/root/Main/Player/Catalog"},
	{"key": "scanner", "path": "/root/Main/Player/ScannerSystem"},
	{"key": "survival", "path": "/root/Main/Player/SurvivalSystem"},
	{"key": "journal", "path": "/root/Main/Player/JournalSystem"},
]


func _ready() -> void:
	var dnc: Node = get_node_or_null("/root/DayNightCycle")
	if dnc and dnc.has_signal("day_started"):
		dnc.day_started.connect(_on_day_started)


func _on_day_started() -> void:
	save_game()


# --- Public API ---

func save_game() -> bool:
	var data: Dictionary = _collect_save_data()
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing.")
		return false
	file.store_string(json_text)
	file.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_delete_save()
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveManager: corrupt save file detected — deleting.")
		_delete_save()
		return false
	_distribute_save_data(parsed as Dictionary)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	_delete_save()


# --- Internal ---

func _collect_save_data() -> Dictionary:
	var data: Dictionary = {}
	for entry: Dictionary in _SYSTEM_KEYS:
		var key: String = entry["key"]
		var node: Node = get_node_or_null(entry["path"])
		if node == null:
			continue
		if not node.has_method("get_save_data"):
			continue
		data[key] = node.get_save_data()
	return data


func _distribute_save_data(data: Dictionary) -> void:
	for entry: Dictionary in _SYSTEM_KEYS:
		var key: String = entry["key"]
		if not data.has(key):
			continue
		var node: Node = get_node_or_null(entry["path"])
		if node == null:
			continue
		if not node.has_method("load_save_data"):
			continue
		node.load_save_data(data[key])


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
