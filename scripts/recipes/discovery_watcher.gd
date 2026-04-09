extends Node

## Owns the player's known-recipes list. Listens to global signals
## (Catalog.entry_cataloged, tool equip, grant_recipe effects) and
## evaluates unlock_when predicates to discover new recipes.
## Autoload registered AFTER RecipeRegistry.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _PredicateEvaluator = preload("res://scripts/recipes/predicate_evaluator.gd")
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


## Re-evaluate unlock_when for all unknown recipes.
## Called when external state changes (catalog, tool equip, etc.).
func check_unlocks(ctx: WorldContext) -> void:
	if _registry == null:
		return
	var all_recipes: Array = _registry.get_all_recipes()
	for recipe in all_recipes:
		if _known_recipes.has(recipe.id):
			continue
		if recipe.unlock_when.is_empty():
			continue
		if _all_unlock_predicates_pass(recipe, ctx):
			grant_recipe(recipe.id)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------


func _populate_initial_known() -> void:
	if _registry == null:
		return
	var all_recipes: Array = _registry.get_all_recipes()
	for recipe in all_recipes:
		if recipe.unlock_when.is_empty():
			_known_recipes[recipe.id] = true


func _connect_catalog_signal() -> void:
	if _catalog != null and _catalog.has_signal("entry_cataloged"):
		if not _catalog.is_connected("entry_cataloged", _on_entry_cataloged):
			_catalog.connect("entry_cataloged", _on_entry_cataloged)
		return
	# Try to find Catalog from the scene tree (it's usually on Player or a singleton).
	# For now, callers set _catalog directly or connect externally.


func _on_entry_cataloged(entry_id: StringName, _category: int) -> void:
	if _registry == null:
		return
	# Build a minimal context for predicate evaluation.
	var ctx := _build_current_context()
	var all_recipes: Array = _registry.get_all_recipes()
	for recipe in all_recipes:
		if _known_recipes.has(recipe.id):
			continue
		if recipe.unlock_when.is_empty():
			continue
		# Quick filter: only check recipes that reference cataloged() predicates
		var has_catalog_pred := false
		for pred in recipe.unlock_when:
			if pred.kind == &"cataloged":
				has_catalog_pred = true
				break
		if not has_catalog_pred:
			continue
		if _all_unlock_predicates_pass(recipe, ctx):
			grant_recipe(recipe.id)


func _all_unlock_predicates_pass(recipe: _Recipe, ctx: WorldContext) -> bool:
	for pred in recipe.unlock_when:
		if not _PredicateEvaluator.evaluate(pred, ctx):
			return false
	return true


func _build_current_context() -> WorldContext:
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
