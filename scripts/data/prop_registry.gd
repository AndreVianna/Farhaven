extends Node

## Scans data/props/ and indexes all PropDef .tres files by id.
## Added to project.godot as autoload BEFORE HexGrid.
## All inventory items, tools, and gatherable props are PropDefs —
## there is no separate item registry or hardcoded item config.

const PROPS_PATH := "res://data/props/"

## PropDef id (numeric, e.g. &"00001") → PropDef resource
var _defs: Dictionary = {}

func _ready() -> void:
	_scan_props()

func _scan_props() -> void:
	var dir := DirAccess.open(PROPS_PATH)
	if dir == null:
		push_error("PropRegistry: cannot open %s" % PROPS_PATH)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(PROPS_PATH + file_name)
			if res is PropDef:
				_defs[res.id] = res
		file_name = dir.get_next()

func get_def(type: StringName) -> PropDef:
	return _defs.get(type)

func get_all() -> Array:
	return _defs.values()

func has_def(type: StringName) -> bool:
	return _defs.has(type)

## Resolve a prop to the id of the item it produces when gathered.
## If yield_type is empty, the prop yields itself.
func get_yield_type(type: StringName) -> StringName:
	var def := get_def(type)
	if def and def.yield_type != &"":
		return def.yield_type
	return type

## Get tool speed multiplier for a tool on a prop (1.0 = normal speed).
func get_tool_speed(type: StringName, tool_name: StringName) -> float:
	var def := get_def(type)
	if def and def.tool_speed.has(tool_name):
		return def.tool_speed[tool_name]
	return 1.0
