class_name TestRecipeRegistry
extends GdUnitTestSuite

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _RecipeRegistry = preload("res://scripts/recipes/recipe_registry.gd")


# --- Helper: build a registry and scan recipes ---

var _registry: Node


func before_test() -> void:
	_registry = _RecipeRegistry.new()
	_registry._scan_recipes()


func after_test() -> void:
	_registry.free()


# --- All 8 canonical recipes load ---

func test_all_canonical_recipes_load() -> void:
	var expected_ids: Array[StringName] = [
		&"eat_berry",
		&"chop_small_tree",
		&"cook_meat",
		&"craft_trap",
		&"trap_fires",
		&"meat_rots",
		&"burn_log_in_fireplace",
		&"eat_toxic_berry",
	]
	for id in expected_ids:
		var recipe = _registry.get_recipe(id)
		assert_that(recipe).is_not_null()


func test_get_all_recipes_returns_eight() -> void:
	var all: Array = _registry.get_all_recipes()
	assert_int(all.size()).is_equal(8)


# --- get_recipe returns correct fields ---

func test_eat_berry_fields() -> void:
	var r = _registry.get_recipe(&"eat_berry")
	assert_that(r).is_not_null()
	assert_int(r.kind).is_equal(_Recipe.Kind.TRANSFORM)
	assert_int(r.inputs.size()).is_equal(1)
	assert_str(String(r.inputs[0].ref_or_tag)).is_equal("00020")
	assert_int(r.inputs[0].count).is_equal(1)
	assert_bool(r.inputs[0].is_tag).is_false()
	assert_int(r.outputs.size()).is_equal(0)
	assert_int(r.effects.size()).is_equal(2)
	assert_str(String(r.effects[0].kind)).is_equal("stat_delta")
	assert_str(String(r.effects[1].kind)).is_equal("sound")
	assert_int(r.actions.size()).is_equal(1)
	assert_str(String(r.actions[0])).is_equal("eat")
	assert_float(r.time).is_equal(0.0)
	assert_int(r.unlock_when.size()).is_equal(1)


func test_chop_small_tree_fields() -> void:
	var r = _registry.get_recipe(&"chop_small_tree")
	assert_that(r).is_not_null()
	assert_int(r.kind).is_equal(_Recipe.Kind.BREAKDOWN)
	assert_int(r.inputs.size()).is_equal(1)
	assert_str(String(r.inputs[0].ref_or_tag)).is_equal("00001")
	assert_str(String(r.inputs[0].source)).is_equal("world_tile")
	assert_int(r.outputs.size()).is_equal(2)
	assert_float(r.outputs[0].prob).is_equal(1.0)
	assert_float(r.outputs[1].prob).is_equal_approx(0.8, 0.0001)
	assert_int(r.conditions.size()).is_equal(1)
	assert_bool(r.conditions[0].must_sustain).is_true()
	assert_float(r.time).is_equal(4.0)
	assert_int(r.unlock_when.size()).is_equal(2)


func test_cook_meat_fields() -> void:
	var r = _registry.get_recipe(&"cook_meat")
	assert_that(r).is_not_null()
	assert_int(r.kind).is_equal(_Recipe.Kind.TRANSFORM)
	assert_int(r.conditions.size()).is_equal(2)
	assert_bool(r.conditions[0].must_sustain).is_true()
	assert_bool(r.conditions[1].must_sustain).is_true()
	assert_float(r.time).is_equal(15.0)


func test_craft_trap_fields() -> void:
	var r = _registry.get_recipe(&"craft_trap")
	assert_that(r).is_not_null()
	assert_int(r.kind).is_equal(_Recipe.Kind.ASSEMBLE)
	assert_int(r.inputs.size()).is_equal(2)
	assert_int(r.outputs.size()).is_equal(1)
	assert_int(r.conditions.size()).is_equal(0)
	assert_int(r.unlock_when.size()).is_equal(0)
	assert_float(r.time).is_equal(3.0)


func test_trap_fires_is_passive() -> void:
	var r = _registry.get_recipe(&"trap_fires")
	assert_that(r).is_not_null()
	assert_int(r.actions.size()).is_equal(0)
	assert_int(r.conditions.size()).is_equal(1)
	assert_bool(r.conditions[0].must_sustain).is_false()
	assert_float(r.time).is_equal(0.0)


func test_meat_rots_is_passive_time_only() -> void:
	var r = _registry.get_recipe(&"meat_rots")
	assert_that(r).is_not_null()
	assert_int(r.actions.size()).is_equal(0)
	assert_int(r.conditions.size()).is_equal(0)
	assert_float(r.time).is_equal(86400.0)


func test_burn_log_uses_tag_input() -> void:
	var r = _registry.get_recipe(&"burn_log_in_fireplace")
	assert_that(r).is_not_null()
	assert_int(r.inputs.size()).is_equal(1)
	assert_bool(r.inputs[0].is_tag).is_true()
	assert_str(String(r.inputs[0].ref_or_tag)).is_equal("BURNABLE.log")
	assert_str(String(r.inputs[0].source)).is_equal("container")


func test_eat_toxic_berry_negative_health() -> void:
	var r = _registry.get_recipe(&"eat_toxic_berry")
	assert_that(r).is_not_null()
	assert_int(r.effects.size()).is_equal(2)
	# Find the health effect
	var health_effect = null
	for e in r.effects:
		if e.params.get("stat", "") == "health":
			health_effect = e
	assert_that(health_effect).is_not_null()
	assert_int(health_effect.params["value"]).is_equal(-25)


# --- Index queries ---

func test_find_recipes_for_input_berry() -> void:
	var results: Array = _registry.find_recipes_for_input(&"00020")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("eat_berry")


func test_find_recipes_for_input_toxic_berry() -> void:
	var results: Array = _registry.find_recipes_for_input(&"00021")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("eat_toxic_berry")


func test_find_recipes_for_input_small_tree() -> void:
	var results: Array = _registry.find_recipes_for_input(&"00001")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("chop_small_tree")


func test_find_recipes_for_input_raw_meat() -> void:
	var results: Array = _registry.find_recipes_for_input(&"00022")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("cook_meat")


func test_find_recipes_for_tag_burnable_log() -> void:
	var results: Array = _registry.find_recipes_for_tag(&"BURNABLE.log")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("burn_log_in_fireplace")


func test_find_recipes_for_action_eat() -> void:
	var results: Array = _registry.find_recipes_for_action(&"eat")
	assert_int(results.size()).is_equal(2)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("eat_berry")).is_true()
	assert_bool(ids.has("eat_toxic_berry")).is_true()


func test_find_recipes_for_action_chop() -> void:
	var results: Array = _registry.find_recipes_for_action(&"chop")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("chop_small_tree")


func test_find_recipes_for_action_assemble() -> void:
	var results: Array = _registry.find_recipes_for_action(&"assemble")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("craft_trap")


func test_find_recipes_for_station_cook() -> void:
	var results: Array = _registry.find_recipes_for_station(&"cook")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("cook_meat")


func test_find_recipes_for_station_fire() -> void:
	var results: Array = _registry.find_recipes_for_station(&"fire")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("burn_log_in_fireplace")


func test_find_recipes_for_nonexistent_input_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_input(&"99999")
	assert_int(results.size()).is_equal(0)


func test_find_recipes_for_nonexistent_action_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_action(&"fly")
	assert_int(results.size()).is_equal(0)


func test_find_recipes_for_nonexistent_station_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_station(&"smelter")
	assert_int(results.size()).is_equal(0)


func test_get_recipe_nonexistent_returns_null() -> void:
	var r = _registry.get_recipe(&"nonexistent_recipe")
	assert_that(r).is_null()
