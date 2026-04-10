class_name TestRecipeOutput
extends GdUnitTestSuite

const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")


# --- Defaults ---

func test_default_prop_ref_is_empty() -> void:
	var out := _RecipeOutput.new()
	assert_str(String(out.prop_ref)).is_empty()


func test_default_count_is_one() -> void:
	var out := _RecipeOutput.new()
	assert_int(out.count).is_equal(1)


func test_default_prob_is_one() -> void:
	var out := _RecipeOutput.new()
	assert_float(out.prob).is_equal_approx(1.0, 0.001)


# --- Configured output ---

func test_output_with_custom_values() -> void:
	var out := _RecipeOutput.new()
	out.prop_ref = &"P00010"
	out.count = 3
	out.prob = 0.75
	assert_str(String(out.prop_ref)).is_equal("P00010")
	assert_int(out.count).is_equal(3)
	assert_float(out.prob).is_equal_approx(0.75, 0.001)


# --- Probability edge cases ---

func test_prob_zero_means_never_produced() -> void:
	var out := _RecipeOutput.new()
	out.prob = 0.0
	assert_float(out.prob).is_equal_approx(0.0, 0.001)


func test_prob_one_means_always_produced() -> void:
	var out := _RecipeOutput.new()
	out.prob = 1.0
	assert_float(out.prob).is_equal_approx(1.0, 0.001)


func test_prob_boundary_half() -> void:
	var out := _RecipeOutput.new()
	out.prob = 0.5
	assert_float(out.prob).is_equal_approx(0.5, 0.001)


# --- Count edge cases ---

func test_count_zero_produces_nothing() -> void:
	var out := _RecipeOutput.new()
	out.count = 0
	assert_int(out.count).is_equal(0)


func test_high_count_output() -> void:
	var out := _RecipeOutput.new()
	out.count = 99
	assert_int(out.count).is_equal(99)


func test_output_is_resource() -> void:
	var out := _RecipeOutput.new()
	assert_bool(out is Resource).is_true()
