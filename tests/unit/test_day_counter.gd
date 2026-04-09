class_name TestDayCounter
extends GdUnitTestSuite

const _DayCounter = preload("res://scripts/hud/day_counter.gd")


# --- Phase colors ---

func test_phase_colors_has_day() -> void:
	assert_bool(_DayCounter.PHASE_COLORS.has("DAY")).is_true()


func test_phase_colors_has_dusk() -> void:
	assert_bool(_DayCounter.PHASE_COLORS.has("DUSK")).is_true()


func test_phase_colors_has_night() -> void:
	assert_bool(_DayCounter.PHASE_COLORS.has("NIGHT")).is_true()


func test_phase_colors_has_dawn() -> void:
	assert_bool(_DayCounter.PHASE_COLORS.has("DAWN")).is_true()


func test_phase_colors_count() -> void:
	assert_int(_DayCounter.PHASE_COLORS.size()).is_equal(4)


func test_day_color_is_warm_yellow() -> void:
	var c: Color = _DayCounter.PHASE_COLORS["DAY"]
	assert_float(c.r).is_equal_approx(1.0, 0.01)
	assert_float(c.g).is_equal_approx(0.851, 0.01)


func test_night_color_is_soft_purple() -> void:
	var c: Color = _DayCounter.PHASE_COLORS["NIGHT"]
	assert_float(c.r).is_equal_approx(0.608, 0.01)
	assert_float(c.b).is_equal_approx(0.784, 0.01)
