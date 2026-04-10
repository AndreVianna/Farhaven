class_name TestDiscoveryWatcher
extends GdUnitTestSuite

## Unit tests for DiscoveryWatcher — Event-based recipe discovery (task-058).

const _DiscoveryWatcher = preload("res://scripts/recipes/discovery_watcher.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _GameEvent = preload("res://scripts/core/event.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")


# ---------------------------------------------------------------------------
# Minimal fakes
# ---------------------------------------------------------------------------


class FakeRegistry extends Node:
	var _recipes: Array = []

	func get_all_recipes() -> Array:
		return _recipes

	func get_recipe(id: StringName):
		for r in _recipes:
			if r.id == id:
				return r
		return null


class FakeCatalog extends RefCounted:
	signal entry_cataloged(entry_id: StringName, category: int)
	var _cataloged: Dictionary = {}

	func catalog_entry(entry_id: StringName) -> void:
		_cataloged[entry_id] = true
		entry_cataloged.emit(entry_id, 0)

	func is_cataloged(entry_id: StringName) -> bool:
		return _cataloged.get(entry_id, false)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


var _watcher: Node
var _registry: FakeRegistry
var _event_registry: Node
var _catalog: FakeCatalog


func _make_recipe(id: StringName) -> _Recipe:
	var r := _Recipe.new()
	r.id = id
	return r


func _make_discovery_event(event_id: StringName, recipe_id: StringName, cataloged_props: Array[StringName] = [], has_tools: Array[StringName] = []) -> _GameEvent:
	var event := _GameEvent.new()
	event.id = event_id
	event.max_count = 1
	# Build conditions.
	for prop_id in cataloged_props:
		var pred := _Predicate.new()
		pred.kind = &"cataloged"
		pred.params = {"prop": String(prop_id)}
		var cond := _RecipeCondition.new()
		cond.predicate = pred
		event.conditions.append(cond)
	for tool_id in has_tools:
		var pred := _Predicate.new()
		pred.kind = &"has_tool"
		pred.params = {"tool": String(tool_id)}
		var cond := _RecipeCondition.new()
		cond.predicate = pred
		event.conditions.append(cond)
	# Build grant_recipe effect.
	var eff := _RecipeEffect.new()
	eff.kind = &"grant_recipe"
	eff.params = {"recipe_id": String(recipe_id)}
	event.effects.append(eff)
	return event


func before_test() -> void:
	_registry = FakeRegistry.new()
	add_child(_registry)
	_event_registry = _EventRegistry.new()
	# Prevent EventRegistry from scanning disk — we inject events manually.
	add_child(_event_registry)
	_catalog = FakeCatalog.new()
	_watcher = _DiscoveryWatcher.new()
	_watcher._registry = _registry
	_watcher._event_registry = _event_registry
	_watcher._catalog = _catalog


func after_test() -> void:
	if is_instance_valid(_watcher):
		if _watcher.get_parent() != null:
			_watcher.get_parent().remove_child(_watcher)
		_watcher.free()
	if is_instance_valid(_event_registry):
		if _event_registry.get_parent() != null:
			_event_registry.get_parent().remove_child(_event_registry)
		_event_registry.free()
	if is_instance_valid(_registry):
		_registry.queue_free()


# ---------------------------------------------------------------------------
# Tests: initial known recipes (recipes WITHOUT discovery events)
# ---------------------------------------------------------------------------


func test_recipes_without_discovery_event_are_known_from_start() -> void:
	# Recipes with no corresponding discovery event should be known immediately.
	_registry._recipes.append(_make_recipe(&"R00012"))  # craft_trap — no unlock_when
	_registry._recipes.append(_make_recipe(&"R00016"))  # craft_stone_axe — no unlock_when
	# Manually trigger _ready-like logic.
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"R00012")).is_true()
	assert_bool(_watcher.is_known(&"R00016")).is_true()


func test_recipes_with_discovery_event_are_not_known_from_start() -> void:
	# Recipe 00001 (eat_berry) has a discovery event — should NOT be known.
	_registry._recipes.append(_make_recipe(&"R00001"))
	_registry._recipes.append(_make_recipe(&"R00012"))  # no event
	var event := _make_discovery_event(&"E00001", &"R00001", [&"P00004"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"R00001")).is_false()
	assert_bool(_watcher.is_known(&"R00012")).is_true()


# ---------------------------------------------------------------------------
# Tests: grant_recipe (direct)
# ---------------------------------------------------------------------------


func test_grant_recipe_adds_to_known() -> void:
	assert_bool(_watcher.is_known(&"new_recipe")).is_false()
	_watcher.grant_recipe(&"new_recipe")
	assert_bool(_watcher.is_known(&"new_recipe")).is_true()


func test_grant_recipe_emits_signal() -> void:
	var monitor := monitor_signals(_watcher)
	_watcher.grant_recipe(&"unlocked_recipe")
	await assert_signal(monitor).is_emitted("recipe_unlocked", [&"unlocked_recipe"])


func test_grant_recipe_duplicate_does_not_emit_twice() -> void:
	_watcher.grant_recipe(&"dup_recipe")
	var monitor := monitor_signals(_watcher)
	_watcher.grant_recipe(&"dup_recipe")
	await assert_signal(monitor).is_not_emitted("recipe_unlocked")


# ---------------------------------------------------------------------------
# Tests: event_fired → grant_recipe
# ---------------------------------------------------------------------------


func test_event_fired_grants_recipe() -> void:
	_registry._recipes.append(_make_recipe(&"R00001"))
	var event := _make_discovery_event(&"E00001", &"R00001", [&"P00004"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()

	assert_bool(_watcher.is_known(&"R00001")).is_false()
	# Simulate the event firing.
	_event_registry.try_fire(event)
	assert_bool(_watcher.is_known(&"R00001")).is_true()


func test_event_fired_emits_recipe_unlocked_signal() -> void:
	_registry._recipes.append(_make_recipe(&"R00001"))
	var event := _make_discovery_event(&"E00001", &"R00001", [&"P00004"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()

	var monitor := monitor_signals(_watcher)
	_event_registry.try_fire(event)
	await assert_signal(monitor).is_emitted("recipe_unlocked", [&"R00001"])


# ---------------------------------------------------------------------------
# Tests: catalog entry → check_unlocks → event fires → recipe granted
# ---------------------------------------------------------------------------


func test_catalog_entry_triggers_discovery() -> void:
	_registry._recipes.append(_make_recipe(&"R00001"))
	var event := _make_discovery_event(&"E00001", &"R00001", [&"P00004"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()
	_watcher._connect_catalog_signal()

	assert_bool(_watcher.is_known(&"R00001")).is_false()
	# Catalog the berry bush (00004) — should trigger discovery.
	_catalog.catalog_entry(&"P00004")
	assert_bool(_watcher.is_known(&"R00001")).is_true()


func test_catalog_entry_does_not_trigger_when_conditions_not_met() -> void:
	_registry._recipes.append(_make_recipe(&"R00011"))  # cook_meat
	# cook_meat needs both cataloged(00022) AND cataloged(00101)
	var event := _make_discovery_event(&"E00011", &"R00011", [&"P00022", &"P00101"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()
	_watcher._connect_catalog_signal()

	assert_bool(_watcher.is_known(&"R00011")).is_false()
	# Catalog only meat (00022) — one condition met, but not both.
	_catalog.catalog_entry(&"P00022")
	assert_bool(_watcher.is_known(&"R00011")).is_false()
	# Now catalog campfire (00101) — both conditions met.
	_catalog.catalog_entry(&"P00101")
	assert_bool(_watcher.is_known(&"R00011")).is_true()


func test_one_shot_event_does_not_fire_twice() -> void:
	_registry._recipes.append(_make_recipe(&"R00001"))
	var event := _make_discovery_event(&"E00001", &"R00001", [&"P00004"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()

	# Fire it once.
	_event_registry.try_fire(event)
	assert_bool(_watcher.is_known(&"R00001")).is_true()
	assert_int(event.count).is_equal(1)

	# Try firing again — should be rejected (max_count=1).
	var result: bool = _event_registry.try_fire(event)
	assert_bool(result).is_false()
	assert_int(event.count).is_equal(1)


# ---------------------------------------------------------------------------
# Tests: check_unlocks (manual re-evaluation)
# ---------------------------------------------------------------------------


func test_check_unlocks_fires_events_with_met_conditions() -> void:
	_registry._recipes.append(_make_recipe(&"R00004"))
	var event := _make_discovery_event(&"E00004", &"R00004", [&"P00002"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()

	# Build a context with catalog that has 00002 cataloged.
	var ctx := _WorldContext.new()
	ctx.catalog = _catalog
	_catalog._cataloged[&"P00002"] = true

	assert_bool(_watcher.is_known(&"R00004")).is_false()
	_watcher.check_unlocks(ctx)
	assert_bool(_watcher.is_known(&"R00004")).is_true()


func test_check_unlocks_does_not_fire_when_conditions_unmet() -> void:
	_registry._recipes.append(_make_recipe(&"R00004"))
	var event := _make_discovery_event(&"E00004", &"R00004", [&"P00002"])
	_event_registry._events[event.id] = event
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	_watcher._connect_event_registry_signal()

	var ctx := _WorldContext.new()
	ctx.catalog = _catalog
	# Catalog is empty — condition not met.

	_watcher.check_unlocks(ctx)
	assert_bool(_watcher.is_known(&"R00004")).is_false()


# ---------------------------------------------------------------------------
# Tests: is_known query
# ---------------------------------------------------------------------------


func test_is_known_returns_false_for_unknown() -> void:
	assert_bool(_watcher.is_known(&"unknown_recipe")).is_false()


func test_is_known_returns_true_after_grant() -> void:
	_watcher.grant_recipe(&"test_recipe")
	assert_bool(_watcher.is_known(&"test_recipe")).is_true()


# ---------------------------------------------------------------------------
# Tests: get_known_recipes
# ---------------------------------------------------------------------------


func test_get_known_recipes_returns_all() -> void:
	_registry._recipes.append(_make_recipe(&"a"))
	_registry._recipes.append(_make_recipe(&"b"))
	# No discovery events → both known from start.
	_watcher._index_discovery_events()
	_watcher._populate_initial_known()
	var known: Array = _watcher.get_known_recipes()
	assert_int(known.size()).is_equal(2)
	assert_bool(known.has(&"a")).is_true()
	assert_bool(known.has(&"b")).is_true()


# ---------------------------------------------------------------------------
# Tests: save/load
# ---------------------------------------------------------------------------


func test_save_load_preserves_known_recipes() -> void:
	_watcher.grant_recipe(&"recipe_a")
	_watcher.grant_recipe(&"recipe_b")

	var save_data: Dictionary = _watcher.get_save_data()
	assert_int(save_data["known_recipes"].size()).is_equal(2)

	# Create a fresh watcher and load.
	var watcher2 := _DiscoveryWatcher.new()
	watcher2._registry = _registry
	watcher2._event_registry = _event_registry
	watcher2.load_save_data(save_data)

	assert_bool(watcher2.is_known(&"recipe_a")).is_true()
	assert_bool(watcher2.is_known(&"recipe_b")).is_true()
	assert_bool(watcher2.is_known(&"recipe_c")).is_false()

	watcher2.free()


func test_load_save_data_clears_previous_state() -> void:
	_watcher.grant_recipe(&"old_recipe")
	assert_bool(_watcher.is_known(&"old_recipe")).is_true()

	_watcher.load_save_data({"known_recipes": [&"new_recipe"]})
	assert_bool(_watcher.is_known(&"old_recipe")).is_false()
	assert_bool(_watcher.is_known(&"new_recipe")).is_true()
