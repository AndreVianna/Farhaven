class_name TestRecipeInput
extends GdUnitTestSuite

const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")


# --- Defaults ---

func test_default_ref_is_empty() -> void:
	var inp := _RecipeInput.new()
	assert_str(inp.ref).is_empty()


func test_default_count_is_one() -> void:
	var inp := _RecipeInput.new()
	assert_int(inp.count).is_equal(1)


func test_default_must_hold_is_false() -> void:
	var inp := _RecipeInput.new()
	assert_bool(inp.must_hold).is_false()


func test_default_is_tag_returns_false() -> void:
	var inp := _RecipeInput.new()
	assert_bool(inp.is_tag()).is_false()


# --- Exact ref input ---

func test_exact_ref_input() -> void:
	var inp := _RecipeInput.new()
	inp.ref = "P00010"
	inp.count = 5
	inp.must_hold = true
	assert_str(inp.ref).is_equal("P00010")
	assert_int(inp.count).is_equal(5)
	assert_bool(inp.must_hold).is_true()
	assert_bool(inp.is_tag()).is_false()


# --- Tag-based input ---

func test_tag_input_with_burnable() -> void:
	var inp := _RecipeInput.new()
	inp.ref = "&BURNABLE.log"
	assert_str(inp.ref).is_equal("&BURNABLE.log")
	assert_bool(inp.is_tag()).is_true()
	assert_str(String(inp.get_tag())).is_equal("BURNABLE.log")


func test_tag_input_simple() -> void:
	var inp := _RecipeInput.new()
	inp.ref = "&BURNABLE"
	assert_bool(inp.is_tag()).is_true()
	assert_str(String(inp.get_tag())).is_equal("BURNABLE")


func test_get_tag_returns_empty_for_non_tag() -> void:
	var inp := _RecipeInput.new()
	inp.ref = "P00010"
	assert_str(String(inp.get_tag())).is_empty()


# --- must_hold semantics ---

func test_must_hold_true_means_inventory() -> void:
	var inp := _RecipeInput.new()
	inp.must_hold = true
	assert_bool(inp.must_hold).is_true()


func test_must_hold_false_means_world_vicinity() -> void:
	var inp := _RecipeInput.new()
	inp.must_hold = false
	assert_bool(inp.must_hold).is_false()


# --- Edge cases ---

func test_count_zero_is_valid() -> void:
	var inp := _RecipeInput.new()
	inp.count = 0
	assert_int(inp.count).is_equal(0)


func test_input_is_resource() -> void:
	var inp := _RecipeInput.new()
	assert_bool(inp is Resource).is_true()
