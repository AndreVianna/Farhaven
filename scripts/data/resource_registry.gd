extends Node

## Scans data/props/ and indexes all ResourceDef .tres files by id.
## Added to project.godot as autoload BEFORE HexGrid.

const PROPS_PATH := "res://data/props/"

var _defs: Dictionary = {}  # StringName → ResourceDef

func _ready() -> void:
	_scan_props()

func _scan_props() -> void:
	var dir := DirAccess.open(PROPS_PATH)
	if dir == null:
		push_error("ResourceRegistry: cannot open %s" % PROPS_PATH)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(PROPS_PATH + file_name)
			if res is ResourceDef:
				_defs[res.id] = res
		file_name = dir.get_next()

func get_def(type: StringName) -> ResourceDef:
	return _defs.get(type)

func get_all() -> Array:
	return _defs.values()

func has_def(type: StringName) -> bool:
	return _defs.has(type)

## Convenience: get yield type (returns self if no mapping)
func get_yield_type(type: StringName) -> StringName:
	var def := get_def(type)
	if def and def.yield_type != &"":
		return def.yield_type
	return type

## Convenience: get tool speed multiplier for a tool on a prop
func get_tool_speed(type: StringName, tool_name: StringName) -> float:
	var def := get_def(type)
	if def and def.tool_speed.has(tool_name):
		return def.tool_speed[tool_name]
	return 1.0
