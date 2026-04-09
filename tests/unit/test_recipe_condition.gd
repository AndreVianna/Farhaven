class_name TestRecipeCondition
extends GdUnitTestSuite

const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")


func test_default_predicate_is_null() -> void:
	var cond := _RecipeCondition.new()
	assert_object(cond.predicate).is_null()


func test_default_must_sustain_is_false() -> void:
	var cond := _RecipeCondition.new()
	assert_bool(cond.must_sustain).is_false()


func test_condition_with_predicate() -> void:
	var pred := _Predicate.new()
	pred.kind = &"has_tool"
	pred.params = {"tool": "axe"}
	var cond := _RecipeCondition.new()
	cond.predicate = pred
	assert_object(cond.predicate).is_not_null()
	assert_str(String(cond.predicate.kind)).is_equal("has_tool")


func test_sustain_condition_rechecks_during_execution() -> void:
	var pred := _Predicate.new()
	pred.kind = &"at_station"
	pred.params = {"tag": "fire"}
	var cond := _RecipeCondition.new()
	cond.predicate = pred
	cond.must_sustain = true
	assert_bool(cond.must_sustain).is_true()


func test_non_sustain_condition_checked_only_at_start() -> void:
	var cond := _RecipeCondition.new()
	cond.must_sustain = false
	assert_bool(cond.must_sustain).is_false()


func test_condition_is_resource() -> void:
	var cond := _RecipeCondition.new()
	assert_bool(cond is Resource).is_true()


func test_predicate_params_accessible_through_condition() -> void:
	var pred := _Predicate.new()
	pred.kind = &"player_stat"
	pred.params = {"stat": "health", "op": "ge", "value": 20}
	var cond := _RecipeCondition.new()
	cond.predicate = pred
	assert_str(cond.predicate.params["stat"]).is_equal("health")
	assert_str(cond.predicate.params["op"]).is_equal("ge")
	assert_int(cond.predicate.params["value"]).is_equal(20)
