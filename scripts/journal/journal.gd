extends Node

## Journal — autoload that tracks unlocked JournalEntry resources.
## Registered in project.godot AFTER EventRegistry so effect handlers can
## call `Journal.add_entry(entry_id)` safely.
##
## Wave 0 scaffolding (delivery-006c): this is a minimal working stub. It
## tracks unlocked ids in a Dictionary, emits a signal on add, and supports
## save/load. A registry-backed lookup and full panel UI land in task-075.

const _JournalEntry = preload("res://scripts/journal/journal_entry.gd")

## Emitted once when a new entry is unlocked. If the entry was already
## unlocked, no signal is emitted.
signal journal_entry_added(entry_id: StringName)

## entry_id → true. Permanent once added (until cleared by load_save_data).
var _unlocked: Dictionary = {}

## Injectable for testing. Defaults to EventRegistry autoload.
var _event_registry: Node = null


func _ready() -> void:
	if _event_registry == null:
		_event_registry = _get_autoload(&"EventRegistry")
	_connect_event_registry_signal()


func _connect_event_registry_signal() -> void:
	if _event_registry == null:
		return
	if not _event_registry.is_connected("event_fired", _on_event_fired):
		_event_registry.connect("event_fired", _on_event_fired)


## When an event fires, process its unlock_journal_entry effects.
## Mirrors DiscoveryWatcher's grant_recipe pattern.
func _on_event_fired(_event_id: StringName, event: Resource) -> void:
	if event == null or not ("effects" in event):
		return
	for eff in event.effects:
		if eff == null:
			continue
		if eff.kind == &"unlock_journal_entry":
			var entry_id := StringName(eff.params.get("entry_id", ""))
			if entry_id != &"":
				add_entry(entry_id)


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null


## Marks an entry as unlocked and emits `journal_entry_added`.
## Returns true if the entry was newly added, false if it was already unlocked
## or the id was empty.
##
## Wave 0 stub: does NOT validate that the entry exists as a .tres file. That
## validation, along with registry-backed metadata lookup, lands in task-075.
func add_entry(entry_id: StringName) -> bool:
	if entry_id == &"":
		return false
	if _unlocked.has(entry_id):
		return false
	_unlocked[entry_id] = true
	journal_entry_added.emit(entry_id)
	return true


## Returns true if the given entry has been unlocked.
func is_unlocked(entry_id: StringName) -> bool:
	return _unlocked.has(entry_id)


## Returns all unlocked entry ids as an Array[StringName].
func get_unlocked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _unlocked:
		result.append(key)
	return result


## Save data for persistence.
func get_save_data() -> Dictionary:
	return {"unlocked_entries": get_unlocked_ids()}


## Restore unlocked entries from save data.
func load_save_data(data: Dictionary) -> void:
	_unlocked.clear()
	var entries: Array = data.get("unlocked_entries", [])
	for id in entries:
		_unlocked[StringName(id)] = true
