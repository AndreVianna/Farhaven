class_name TestStatBars
extends GdUnitTestSuite

## Tests for StatBars color logic.
## StatBars._color_for_stat is a pure function that maps stat name + ratio to color.
## We test the logic by instantiating the script and calling the private method.

const _StatBars = preload("res://scripts/hud/stat_bars.gd")


# --- _color_for_stat logic for non-thirst (hp, hunger) ---

func test_hp_above_50_percent_is_green() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.8)
	# Green: (0.2, 0.8, 0.2)
	assert_float(c.g).is_equal_approx(0.8, 0.01)
	assert_float(c.r).is_equal_approx(0.2, 0.01)
	bars.free()


func test_hp_between_25_and_50_percent_is_yellow() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.35)
	# Yellow: (0.9, 0.8, 0.2)
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.8, 0.01)
	bars.free()


func test_hp_below_25_percent_is_red() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.1)
	# Red: (0.9, 0.2, 0.2)
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.2, 0.01)
	bars.free()


func test_hunger_uses_same_colors_as_hp() -> void:
	var bars := _StatBars.new()
	var hp_green: Color = bars._color_for_stat(&"hp", 0.8)
	var hunger_green: Color = bars._color_for_stat(&"hunger", 0.8)
	assert_float(hp_green.r).is_equal_approx(hunger_green.r, 0.001)
	assert_float(hp_green.g).is_equal_approx(hunger_green.g, 0.001)
	bars.free()


# --- _color_for_stat logic for thirst ---

func test_thirst_above_50_percent_is_blue() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"thirst", 0.8)
	# Blue: (0.2, 0.5, 0.9)
	assert_float(c.b).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.5, 0.01)
	bars.free()


func test_thirst_between_25_and_50_percent_is_yellow() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"thirst", 0.35)
	# Yellow: (0.9, 0.8, 0.2)
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	bars.free()


func test_thirst_below_25_percent_is_red() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"thirst", 0.1)
	# Red: (0.9, 0.2, 0.2)
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.2, 0.01)
	bars.free()


# --- Boundary values ---

func test_ratio_exactly_50_for_hp_is_yellow() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.5)
	# 0.5 is NOT > 0.5, so it's yellow
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.8, 0.01)
	bars.free()


func test_ratio_exactly_25_for_hp_is_red() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.25)
	# 0.25 is NOT > 0.25, so it's red
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	assert_float(c.g).is_equal_approx(0.2, 0.01)
	bars.free()


func test_ratio_zero_is_red() -> void:
	var bars := _StatBars.new()
	var c: Color = bars._color_for_stat(&"hp", 0.0)
	assert_float(c.r).is_equal_approx(0.9, 0.01)
	bars.free()
