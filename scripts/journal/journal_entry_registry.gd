extends Node

## Scans data/journal/ and indexes all JournalEntry .tres files by id.
## Added to project.godot as autoload AFTER Journal so Journal callers can
## resolve entry metadata (title, body, category) through this registry.
##
## Uses preload because autoloads initialize before class_name registration.
## Mirrors PropRegistry's pattern.
##
## Wave 1 (delivery-006c task-075b): data/journal/ may be empty — that's
## expected. Actual entry .tres files land in delivery-007 content work.

const _JournalEntry = preload("res://scripts/journal/journal_entry.gd")
const JOURNAL_PATH := "res://data/journal/"

## JournalEntry id (prefixed, e.g. &"J00001") → JournalEntry resource
var _defs: Dictionary = {}


func _ready() -> void:
	_scan_entries()


func _scan_entries() -> void:
	var dir := DirAccess.open(JOURNAL_PATH)
	if dir == null:
		# Missing directory is OK in Wave 1 — data/journal/ will be populated
		# in delivery-007. Stay empty, don't push_error.
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(JOURNAL_PATH + file_name)
			if res is _JournalEntry:
				assert(String(res.id).begins_with("J"),
					"JournalEntryRegistry: entry id '%s' must start with 'J' prefix" % res.id)
				_defs[res.id] = res
		file_name = dir.get_next()


## Returns the JournalEntry for the given id, or null if not found.
func get_entry(id: StringName) -> Resource:
	return _defs.get(id)


## Returns true if the given id is registered.
func has_entry(id: StringName) -> bool:
	return _defs.has(id)


## Returns all registered ids as Array[StringName].
func get_all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _defs:
		result.append(key)
	return result


## Returns all registered entries as Array[Resource] (JournalEntry).
func get_all_entries() -> Array:
	return _defs.values()


## Returns entries whose `category` field matches the given category.
func get_entries_by_category(category: StringName) -> Array:
	var result: Array = []
	for entry in _defs.values():
		if entry != null and entry.category == category:
			result.append(entry)
	return result


## Test-only helper: register an entry directly without scanning .tres files.
## Lets unit tests populate the registry with in-memory fixtures.
func register_entry(entry: Resource) -> void:
	if entry == null or not (entry is _JournalEntry):
		return
	_defs[entry.id] = entry


## Test-only helper: clear all registered entries.
func clear() -> void:
	_defs.clear()
