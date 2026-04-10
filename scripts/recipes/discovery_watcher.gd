extends Node

## Owns the player's known-recipes list. Watches discovery Events from
## EventRegistry and grants recipes when their conditions are met.
## Autoload registered AFTER RecipeRegistry AND EventRegistry.
##
## Flow:
##   1. On _ready, mark recipes with NO discovery Event as known from start.
##   2. Listen to EventRegistry.event_fired — process grant_recipe effects.
##   3. Listen to Catalog.entry_cataloged — re-evaluate pending discovery Events.
##   4. check_unlocks(ctx) — manual re-evaluation (called externally).

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _GameEvent = preload("res://scripts/core/event.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _PredicateEvaluator = preload("res://scripts/recipes/predicate_evaluator.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")

signal recipe_unlocked(recipe_id: StringName)

## recipe_id → true. Permanent once granted.
var _known_recipes: Dictionary = {}

## Injectable for testing. Defaults to RecipeRegistry autoload.
var _registry: Node = null

## Injectable for testing. Defaults to EventRegistry autoload.
var _event_registry: Node = null

## Injectable for testing. Catalog instance.
var _catalog: RefCounted = null

## recipe_id → GameEvent. Discovery events that haven't fired yet.
## Built on _ready by scanning all events for grant_recipe effects.
var _discovery_events: Dictionary = {}


func _ready() -> void:
	if _registry == null:
		_registry = _get_autoload(&"RecipeRegistry")
	if _event_registry == null:
		_event_registry = _get_autoload(&"EventRegistry")
	_index_discovery_events()
	if _registry != null:
		_populate_initial_known()
	_connect_event_registry_signal()
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


## Re-evaluate all pending (unfired) discovery events against a context.
## Called when external state changes (catalog, tool equip, etc.).
func check_unlocks(ctx: _WorldContext) -> void:
	if _event_registry == null:
		return
	var to_fire: Array = []
	for recipe_id: StringName in _discovery_events:
		var event: _GameEvent = _discovery_events[recipe_id]
		if not event.can_fire():
			continue
		if _all_conditions_met(event, ctx):
			to_fire.append(event)
	for event: _GameEvent in to_fire:
		_event_registry.try_fire(event)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------


## Scan all events for grant_recipe effects and build the discovery index.
func _index_discovery_events() -> void:
	_discovery_events.clear()
	if _event_registry == null:
		return
	var all_events: Array = _event_registry.get_all_events()
	for event in all_events:
		for eff in event.effects:
			if eff.kind == &"grant_recipe":
				var recipe_id := StringName(eff.params.get("recipe_id", ""))
				if recipe_id != &"":
					_discovery_events[recipe_id] = event


## Mark recipes that have NO discovery event as known from start.
func _populate_initial_known() -> void:
	if _registry == null:
		return
	var all_recipes: Array = _registry.get_all_recipes()
	for recipe in all_recipes:
		if not _discovery_events.has(recipe.id):
			_known_recipes[recipe.id] = true


func _connect_event_registry_signal() -> void:
	if _event_registry == null:
		return
	if not _event_registry.is_connected("event_fired", _on_event_fired):
		_event_registry.connect("event_fired", _on_event_fired)


func _connect_catalog_signal() -> void:
	if _catalog != null and _catalog.has_signal("entry_cataloged"):
		if not _catalog.is_connected("entry_cataloged", _on_entry_cataloged):
			_catalog.connect("entry_cataloged", _on_entry_cataloged)


## When an event fires, process its grant_recipe effects.
func _on_event_fired(_event_id: StringName, event: Resource) -> void:
	for eff in event.effects:
		if eff.kind == &"grant_recipe":
			var recipe_id := StringName(eff.params.get("recipe_id", ""))
			if recipe_id != &"":
				grant_recipe(recipe_id)


## When a catalog entry is cataloged, re-evaluate pending discovery events.
func _on_entry_cataloged(_entry_id: StringName, _category: int) -> void:
	var ctx := _build_current_context()
	check_unlocks(ctx)


## Check if all conditions on an event are met.
func _all_conditions_met(event: _GameEvent, ctx: _WorldContext) -> bool:
	for cond in event.conditions:
		if cond.predicate != null:
			if not _PredicateEvaluator.evaluate(cond.predicate, ctx):
				return false
	return true


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
