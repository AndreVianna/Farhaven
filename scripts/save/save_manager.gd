extends Node

## Autoload singleton — handles save/load for all game systems.
## Mobile-friendly: dirty-flag + 5 s timer, immediate save on critical events,
## hot-resume (pause/unpause) and cold-resume (save/load) support.

const SAVE_PATH: String = "user://save.json"
const SAVE_INTERVAL: float = 5.0

## System registry: key used in save dict → NodePath or callable to locate the node.
## Autoloads are fetched from /root/<Name>.
## Player children are fetched via the scene tree.
## Each system must be a Node in the scene tree with get_save_data()/load_save_data().
## Inventory is saved via Player (RefCounted, not a Node).
## Catalog is saved via ScannerSystem (RefCounted, not a Node).
const _SYSTEM_KEYS: Array[Dictionary] = [
	{"key": "hex_grid", "path": "/root/HexGrid"},
	{"key": "day_night", "path": "/root/DayNightCycle"},
	{"key": "player", "path": "/root/Main/World/Player"},
	{"key": "camera", "path": "/root/Main/World/Camera3D"},
	{"key": "crafting", "path": "/root/Main/World/Player/CraftingSystem"},
	{"key": "scanner", "path": "/root/Main/World/Player/ScannerSystem"},
	{"key": "survival", "path": "/root/Main/World/Player/SurvivalSystem"},
]

var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = SAVE_INTERVAL
	_save_timer.one_shot = false
	_save_timer.autostart = true
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_save_timer)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# App going to background — save immediately and pause
			save_now()
			get_tree().paused = true
		NOTIFICATION_APPLICATION_FOCUS_IN:
			# App coming back — unpause
			get_tree().paused = false
		NOTIFICATION_WM_CLOSE_REQUEST:
			# App being closed — save immediately
			save_now()


# --- Public API ---

func mark_dirty() -> void:
	_dirty = true


func save_now() -> void:
	if save_game():
		_dirty = false


func save_game() -> bool:
	var data: Dictionary = _collect_save_data()
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
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
		push_error("SaveManager: corrupt save file detected — deleting.")
		_delete_save()
		return false
	_distribute_save_data(parsed as Dictionary)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	_delete_save()


# --- Internal ---

func _on_save_timer() -> void:
	if _dirty:
		if save_game():
			_dirty = false


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
