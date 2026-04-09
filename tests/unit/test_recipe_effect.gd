class_name TestRecipeEffect
extends GdUnitTestSuite

const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")


func test_default_kind_is_empty() -> void:
	var effect := _RecipeEffect.new()
	assert_str(String(effect.kind)).is_empty()


func test_default_params_is_empty_dict() -> void:
	var effect := _RecipeEffect.new()
	assert_int(effect.params.size()).is_equal(0)


func test_stat_delta_effect() -> void:
	var effect := _RecipeEffect.new()
	effect.kind = &"stat_delta"
	effect.params = {"stat": "hunger", "value": 5}
	assert_str(String(effect.kind)).is_equal("stat_delta")
	assert_str(effect.params["stat"]).is_equal("hunger")
	assert_int(effect.params["value"]).is_equal(5)


func test_sound_effect() -> void:
	var effect := _RecipeEffect.new()
	effect.kind = &"sound"
	effect.params = {"sound_id": "crunch"}
	assert_str(String(effect.kind)).is_equal("sound")
	assert_str(effect.params["sound_id"]).is_equal("crunch")


func test_emit_light_effect_with_radius_and_duration() -> void:
	var effect := _RecipeEffect.new()
	effect.kind = &"emit_light"
	effect.params = {"radius": 5, "duration": 60}
	assert_int(effect.params["radius"]).is_equal(5)
	assert_int(effect.params["duration"]).is_equal(60)


func test_grant_recipe_effect() -> void:
	var effect := _RecipeEffect.new()
	effect.kind = &"grant_recipe"
	effect.params = {"recipe_id": "craft_torch"}
	assert_str(effect.params["recipe_id"]).is_equal("craft_torch")


func test_params_can_hold_mixed_types() -> void:
	var effect := _RecipeEffect.new()
	effect.kind = &"world_change"
	effect.params = {"flag": "quest_done", "value": true, "weight": 0.5}
	assert_bool(effect.params["value"]).is_true()
	assert_float(effect.params["weight"]).is_equal_approx(0.5, 0.001)


func test_effect_is_resource() -> void:
	var effect := _RecipeEffect.new()
	assert_bool(effect is Resource).is_true()
