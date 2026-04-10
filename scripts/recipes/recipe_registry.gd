extends Node

## Scans data/recipes/ and indexes all Recipe .tres files.
## Added to project.godot as autoload AFTER PropRegistry and HexGrid.
## Uses preload because autoloads initialize before class_name registration.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const RECIPES_PATH := "res://data/recipes/"

## Recipe id → Recipe resource
var _by_id: Dictionary = {}

## Input prop ref (StringName) → Array[Recipe]
var _by_input_ref: Dictionary = {}

## Input tag (StringName) → Array[Recipe]
var _by_input_tag: Dictionary = {}

## Player action (StringName) → Array[Recipe]
var _by_action: Dictionary = {}

## Station tag (StringName) → Array[Recipe]
var _by_station_tag: Dictionary = {}


func _ready() -> void:
	_scan_recipes()


func _scan_recipes() -> void:
	var dir := DirAccess.open(RECIPES_PATH)
	if dir == null:
		push_error("RecipeRegistry: cannot open %s" % RECIPES_PATH)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(RECIPES_PATH + file_name)
			if res is _Recipe:
				_register(res)
		file_name = dir.get_next()


func _register(recipe: _Recipe) -> void:
	assert(recipe.id != &"", "RecipeRegistry: recipe loaded with empty id")
	assert(String(recipe.id).begins_with("R"),
		"RecipeRegistry: recipe id '%s' must start with 'R' prefix" % recipe.id)
	_by_id[recipe.id] = recipe
	_index_inputs(recipe)
	_index_actions(recipe)
	_index_station_tags(recipe)


func _index_inputs(recipe: _Recipe) -> void:
	for input in recipe.inputs:
		if input.is_tag():
			var tag_key: StringName = input.get_tag()
			if not _by_input_tag.has(tag_key):
				_by_input_tag[tag_key] = []
			_by_input_tag[tag_key].append(recipe)
		else:
			var ref_key: StringName = StringName(input.ref)
			if not _by_input_ref.has(ref_key):
				_by_input_ref[ref_key] = []
			_by_input_ref[ref_key].append(recipe)


func _index_actions(recipe: _Recipe) -> void:
	for action in recipe.actions:
		if not _by_action.has(action):
			_by_action[action] = []
		_by_action[action].append(recipe)


func _index_station_tags(recipe: _Recipe) -> void:
	for cond in recipe.conditions:
		if cond.predicate and cond.predicate.kind == &"at_station":
			var tag: StringName = cond.predicate.params.get("tag", &"")
			if tag != &"":
				if not _by_station_tag.has(tag):
					_by_station_tag[tag] = []
				_by_station_tag[tag].append(recipe)


## Returns the Recipe with the given id, or null if not found.
func get_recipe(id: StringName) -> _Recipe:
	return _by_id.get(id)


## Returns all loaded recipes.
func get_all_recipes() -> Array:
	return _by_id.values()


## Returns recipes whose inputs consume the given prop ref.
func find_recipes_for_input(prop_ref: StringName) -> Array:
	return _by_input_ref.get(prop_ref, [])


## Returns recipes whose inputs consume any prop matching the given tag.
func find_recipes_for_tag(tag: StringName) -> Array:
	return _by_input_tag.get(tag, [])


## Returns recipes triggered by the given player action.
func find_recipes_for_action(action: StringName) -> Array:
	return _by_action.get(action, [])


## Returns recipes that require a station with the given tag.
func find_recipes_for_station(station_tag: StringName) -> Array:
	return _by_station_tag.get(station_tag, [])
