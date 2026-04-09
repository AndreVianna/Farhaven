class_name TestDiscoveryWatcher
extends GdUnitTestSuite

## Unit tests for DiscoveryWatcher (task-050).

const _DiscoveryWatcher = preload("res://scripts/recipes/discovery_watcher.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
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
var _catalog: FakeCatalog


func _make_recipe(id: StringName, unlock_preds: Array = []) -> _Recipe:
	var r := _Recipe.new()
	r.id = id
	r.kind = _Recipe.Kind.TRANSFORM
	r.unlock_when = []
	for pred in unlock_preds:
		r.unlock_when.append(pred)
	return r


func _make_predicate(p_kind: StringName, p_params: Dictionary = {}) -> _Predicate:
	var pred := _Predicate.new()
	pred.kind = p_kind
	pred.params = p_params
	return pred


func before_test() -> void:
	_registry = FakeRegistry.new()
	add_child(_registry)
	_catalog = FakeCatalog.new()
	_watcher = _DiscoveryWatcher.new()
	_watcher._registry = _registry
	_watcher._catalog = _catalog


func after_test() -> void:
	if is_instance_valid(_watcher):
		if _watcher.get_parent() != null:
			_watcher.get_parent().remove_child(_watcher)
		_watcher.free()
	if is_instance_valid(_registry):
		_registry.queue_free()


# ---------------------------------------------------------------------------
# Tests: initial known recipes
# ---------------------------------------------------------------------------


func test_recipes_with_empty_unlock_when_are_known_from_start() -> void:
	_registry._recipes.append(_make_recipe(&"basic_craft"))
	_registry._recipes.append(_make_recipe(&"basic_eat"))
	# Manually call _ready-like logic.
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"basic_craft")).is_true()
	assert_bool(_watcher.is_known(&"basic_eat")).is_true()


func test_recipes_with_unlock_when_are_not_known_from_start() -> void:
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	_registry._recipes.append(_make_recipe(&"eat_berry", [pred]))
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"eat_berry")).is_false()


func test_mixed_recipes_initial_state() -> void:
	_registry._recipes.append(_make_recipe(&"basic_craft"))
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	_registry._recipes.append(_make_recipe(&"eat_berry", [pred]))
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"basic_craft")).is_true()
	assert_bool(_watcher.is_known(&"eat_berry")).is_false()


# ---------------------------------------------------------------------------
# Tests: grant_recipe
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
	_watcher._populate_initial_known()
	var known: Array = _watcher.get_known_recipes()
	assert_int(known.size()).is_equal(2)
	assert_bool(known.has(&"a")).is_true()
	assert_bool(known.has(&"b")).is_true()


# ---------------------------------------------------------------------------
# Tests: entry_cataloged triggers unlock check
# ---------------------------------------------------------------------------


func test_entry_cataloged_triggers_unlock() -> void:
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	_registry._recipes.append(_make_recipe(&"eat_berry", [pred]))
	# Wire catalog signal.
	_watcher._connect_catalog_signal()
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"eat_berry")).is_false()

	# Catalog the berry. The _on_entry_cataloged should evaluate and unlock.
	_catalog.catalog_entry(&"berry")

	assert_bool(_watcher.is_known(&"eat_berry")).is_true()


func test_entry_cataloged_does_not_unlock_if_other_pred_fails() -> void:
	var pred1 := _make_predicate(&"cataloged", {"prop": &"berry"})
	var pred2 := _make_predicate(&"has_tool", {"tool": &"knife"})
	_registry._recipes.append(_make_recipe(&"eat_berry_with_knife", [pred1, pred2]))
	_watcher._connect_catalog_signal()
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"eat_berry_with_knife")).is_false()

	# Catalog the berry — but has_tool will fail (no player context).
	_catalog.catalog_entry(&"berry")

	assert_bool(_watcher.is_known(&"eat_berry_with_knife")).is_false()


# ---------------------------------------------------------------------------
# Tests: check_unlocks with context
# ---------------------------------------------------------------------------


func test_check_unlocks_with_catalog_context() -> void:
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	_registry._recipes.append(_make_recipe(&"eat_berry", [pred]))
	_watcher._populate_initial_known()

	assert_bool(_watcher.is_known(&"eat_berry")).is_false()

	# Pre-catalog berry in catalog and pass context with catalog.
	_catalog._cataloged[&"berry"] = true
	var ctx := _WorldContext.new()
	ctx.catalog = _catalog
	_watcher.check_unlocks(ctx)

	assert_bool(_watcher.is_known(&"eat_berry")).is_true()


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
