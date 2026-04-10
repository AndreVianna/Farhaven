class_name TestScriptBase
extends GdUnitTestSuite

## Unit tests for ScriptBase class (task-055).

const _ScriptBase = preload("res://scripts/core/script_base.gd")
const _Gear = preload("res://scripts/core/gear.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")


# --- Type hierarchy ---

func test_script_base_extends_gear() -> void:
	var sb := _ScriptBase.new()
	assert_bool(sb is _Gear).is_true()

func test_script_base_extends_resource() -> void:
	var sb := _ScriptBase.new()
	assert_bool(sb is Resource).is_true()


# --- Default values ---

func test_conditions_defaults_to_empty() -> void:
	var sb := _ScriptBase.new()
	assert_int(sb.conditions.size()).is_equal(0)

func test_effects_defaults_to_empty() -> void:
	var sb := _ScriptBase.new()
	assert_int(sb.effects.size()).is_equal(0)

func test_actions_defaults_to_empty() -> void:
	var sb := _ScriptBase.new()
	assert_int(sb.actions.size()).is_equal(0)

func test_duration_defaults_to_zero() -> void:
	var sb := _ScriptBase.new()
	assert_float(sb.duration).is_equal(0.0)


# --- Inherited Gear fields ---

func test_gear_fields_accessible() -> void:
	var sb := _ScriptBase.new()
	sb.id = &"E00001"
	sb.display_name = "Campfire Burn"
	sb.short_description = "Fire consumes fuel."
	sb.long_description = "The campfire burns through its fuel over time."
	assert_str(String(sb.id)).is_equal("E00001")
	assert_str(sb.display_name).is_equal("Campfire Burn")
	assert_str(sb.short_description).is_equal("Fire consumes fuel.")
	assert_str(sb.long_description).is_equal("The campfire burns through its fuel over time.")


# --- Field set and read ---

func test_conditions_array_works() -> void:
	var sb := _ScriptBase.new()
	var cond := _RecipeCondition.new()
	sb.conditions.append(cond)
	assert_int(sb.conditions.size()).is_equal(1)
	assert_bool(sb.conditions[0] is _RecipeCondition).is_true()

func test_effects_array_works() -> void:
	var sb := _ScriptBase.new()
	var effect := _RecipeEffect.new()
	sb.effects.append(effect)
	assert_int(sb.effects.size()).is_equal(1)
	assert_bool(sb.effects[0] is _RecipeEffect).is_true()

func test_actions_array_works() -> void:
	var sb := _ScriptBase.new()
	sb.actions.append(&"chop")
	sb.actions.append(&"gather")
	assert_int(sb.actions.size()).is_equal(2)
	assert_str(String(sb.actions[0])).is_equal("chop")
	assert_str(String(sb.actions[1])).is_equal("gather")

func test_duration_set_and_read() -> void:
	var sb := _ScriptBase.new()
	sb.duration = 5.5
	assert_float(sb.duration).is_equal(5.5)
