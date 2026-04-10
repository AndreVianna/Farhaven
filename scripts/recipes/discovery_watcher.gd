extends Node

## Owns the player's known-recipes list. Listens to global signals
## (Catalog.entry_cataloged, tool equip, grant_recipe effects) and
## grants recipes via events or direct grant_recipe calls.
## Autoload registered AFTER RecipeRegistry.
## NOTE: unlock_when was removed from Recipe in task-056.
## Discovery is now handled by Event system (task-058).

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")

signal recipe_unlocked(recipe_id: StringName)

## recipe_id → true. Permanent once granted.
var _known_recipes: Dictionary = {}

## Injectable for testing. Defaults to RecipeRegistry autoload.
var _registry: Node = null

## Injectable for testing. Catalog instance.
var _catalog: RefCounted = null


func _ready() -> void:
	if _registry == null:
		_registry = _get_autoload(&"RecipeRegistry")
	if _registry != null:
		_populate_initial_known()
	_connect_catalog_signal()


## Returns true if the recipe is in the player's known list.
func is_known(recipe_id: StringName) -> bool:
	return _known_recipes.has(recipe_id)


## Directly grant a recipe (e.g. from grant_recipe effect or event).
func grant_recipe(recipe_id: StringName) -> void:
	if _known_recipes.has(recipe_id):
		return
	_known_recipes[recipe_id] = true
	recipe_unlocked.emit(recipe_id)


## Returns all known recipe ids.
func get_known_recipes() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _known_recipes:
		result.append(key)
	return result


## Save data for persistence.
func get_save_data() -> Dictionary:
	return {"known_recipes": get_known_recipes()}


## Restore known recipes from save data.
func load_save_data(data: Dictionary) -> void:
	_known_recipes.clear()
	var recipes: Array = data.get("known_recipes", [])
	for id in recipes:
		_known_recipes[StringName(id)] = true


## Re-evaluate unlock conditions for all unknown recipes.
## Called when external state changes (catalog, tool equip, etc.).
## NOTE: unlock_when was removed from Recipe (task-056). This now
## only grants recipes that have no unlock conditions (i.e., known from start).
## Task-058 will rewrite discovery via Event system.
func check_unlocks(_ctx: _WorldContext) -> void:
	pass


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------


func _populate_initial_known() -> void:
	if _registry == null:
		return
	# With unlock_when removed (task-056), all recipes are known from start
	# until Event-based discovery is implemented (task-058).
	var all_recipes: Array = _registry.get_all_recipes()
	for recipe in all_recipes:
		_known_recipes[recipe.id] = true


func _connect_catalog_signal() -> void:
	if _catalog != null and _catalog.has_signal("entry_cataloged"):
		if not _catalog.is_connected("entry_cataloged", _on_entry_cataloged):
			_catalog.connect("entry_cataloged", _on_entry_cataloged)
		return
	# Try to find Catalog from the scene tree (it's usually on Player or a singleton).
	# For now, callers set _catalog directly or connect externally.


func _on_entry_cataloged(_entry_id: StringName, _category: int) -> void:
	# NOTE: unlock_when was removed from Recipe (task-056).
	# Event-based discovery (task-058) will replace this logic.
	pass


func _build_current_context() -> _WorldContext:
	var ctx := _WorldContext.new()
	if _catalog != null:
		ctx.catalog = _catalog
	# Auto-fill grid/day_night from autoloads.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		ctx.grid = tree.root.get_node_or_null("HexGrid")
		ctx.day_night = tree.root.get_node_or_null("DayNightCycle")
	return ctx


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
