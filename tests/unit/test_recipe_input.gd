class_name TestRecipeInput
extends GdUnitTestSuite

const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")


# --- Defaults ---

func test_default_ref_or_tag_is_empty() -> void:
	var inp := _RecipeInput.new()
	assert_str(String(inp.ref_or_tag)).is_empty()


func test_default_count_is_one() -> void:
	var inp := _RecipeInput.new()
	assert_int(inp.count).is_equal(1)


func test_default_source_is_player_inventory() -> void:
	var inp := _RecipeInput.new()
	assert_str(String(inp.source)).is_equal("player_inventory")


func test_default_is_tag_is_false() -> void:
	var inp := _RecipeInput.new()
	assert_bool(inp.is_tag).is_false()


# --- Exact ref input ---

func test_exact_ref_input() -> void:
	var inp := _RecipeInput.new()
	inp.ref_or_tag = &"00010"
	inp.count = 5
	inp.is_tag = false
	assert_str(String(inp.ref_or_tag)).is_equal("00010")
	assert_int(inp.count).is_equal(5)
	assert_bool(inp.is_tag).is_false()


# --- Tag-based input ---

func test_tag_input_with_burnable() -> void:
	var inp := _RecipeInput.new()
	inp.ref_or_tag = &"BURNABLE.log"
	inp.is_tag = true
	assert_str(String(inp.ref_or_tag)).is_equal("BURNABLE.log")
	assert_bool(inp.is_tag).is_true()


# --- Different source locations ---

func test_source_container() -> void:
	var inp := _RecipeInput.new()
	inp.source = &"container"
	assert_str(String(inp.source)).is_equal("container")


func test_source_world_tile() -> void:
	var inp := _RecipeInput.new()
	inp.source = &"world_tile"
	assert_str(String(inp.source)).is_equal("world_tile")


func test_source_world_anywhere() -> void:
	var inp := _RecipeInput.new()
	inp.source = &"world_anywhere"
	assert_str(String(inp.source)).is_equal("world_anywhere")


# --- Edge cases ---

func test_count_zero_is_valid() -> void:
	var inp := _RecipeInput.new()
	inp.count = 0
	assert_int(inp.count).is_equal(0)


func test_input_is_resource() -> void:
	var inp := _RecipeInput.new()
	assert_bool(inp is Resource).is_true()
