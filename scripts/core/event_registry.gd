extends Node

## Scans data/events/ and indexes all GameEvent .tres files.
## Added to project.godot as autoload AFTER RecipeRegistry, BEFORE DiscoveryWatcher.
## Uses preload because autoloads initialize before class_name registration.

const _GameEvent = preload("res://scripts/core/event.gd")
const EVENTS_PATH := "res://data/events/"

## Emitted after an event fires successfully.
signal event_fired(event_id: StringName, event: Resource)

## Event id → GameEvent resource
var _events: Dictionary = {}


func _ready() -> void:
	_scan_events()


func _scan_events() -> void:
	var dir := DirAccess.open(EVENTS_PATH)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(EVENTS_PATH + fname)
			if res is _GameEvent:
				assert(String(res.id).begins_with("E"),
					"EventRegistry: event id '%s' must start with 'E' prefix" % res.id)
				_events[res.id] = res
		fname = dir.get_next()


## Returns the GameEvent with the given id, or null if not found.
func get_event(id: StringName) -> _GameEvent:
	return _events.get(id, null)


## Returns true if the event exists and has fired at least once.
func is_active(id: StringName) -> bool:
	var event := get_event(id)
	return event != null and event.is_active()


## Try to fire the given event. Returns true if fired (can_fire + incremented).
## Emits event_fired on success.
func try_fire(event: _GameEvent) -> bool:
	if not event.fire():
		return false
	event_fired.emit(event.id, event)
	return true


## Returns all loaded events.
func get_all_events() -> Array:
	return _events.values()


## Returns save data: only events with count > 0, as { id_string: count }.
func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _events:
		if _events[id].count > 0:
			data[String(id)] = _events[id].count
	return data


## Restores event counts from save data.
func load_save_data(data: Dictionary) -> void:
	for id_str: String in data:
		var id := StringName(id_str)
		if _events.has(id):
			_events[id].count = int(data[id_str])
