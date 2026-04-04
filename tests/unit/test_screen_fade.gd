extends GdUnitTestSuite
class_name TestScreenFade

## Tests for ScreenFade — fade_out, fade_in, flash, signals — task-029.

const _ScreenFade = preload("res://ui/screen_fade.gd")

var _fade: _ScreenFade


func before_test() -> void:
	_fade = _ScreenFade.new()
	add_child(_fade)


func after_test() -> void:
	remove_child(_fade)
	_fade.queue_free()
	_fade = null


# --- Initialization ---

func test_initial_alpha_is_zero() -> void:
	assert_float(_fade._color_rect.color.a).is_equal_approx(0.0, 0.01)


func test_layer_is_30() -> void:
	assert_int(_fade.layer).is_equal(30)


func test_color_rect_exists() -> void:
	assert_object(_fade._color_rect).is_not_null()


# --- fade_out ---

func test_fade_out_starts_at_alpha_zero() -> void:
	_fade.fade_out(1.0)
	# Right after calling, alpha should be at or near 0
	assert_float(_fade._color_rect.color.a).is_less_equal(0.1)


func test_fade_out_signal_emits() -> void:
	var fired: Array = []
	_fade.fade_out_completed.connect(func() -> void:
		fired.append(true)
	)
	_fade.fade_out(0.05)
	# Wait for tween to finish
	await get_tree().create_timer(0.15).timeout
	assert_int(fired.size()).is_equal(1)


func test_fade_out_reaches_alpha_one() -> void:
	_fade.fade_out(0.05)
	await get_tree().create_timer(0.15).timeout
	assert_float(_fade._color_rect.color.a).is_equal_approx(1.0, 0.01)


# --- fade_in ---

func test_fade_in_starts_at_alpha_one() -> void:
	_fade.fade_in(1.0)
	# Right after calling, alpha should be at or near 1
	assert_float(_fade._color_rect.color.a).is_greater_equal(0.9)


func test_fade_in_signal_emits() -> void:
	var fired: Array = []
	_fade.fade_in_completed.connect(func() -> void:
		fired.append(true)
	)
	_fade.fade_in(0.05)
	await get_tree().create_timer(0.15).timeout
	assert_int(fired.size()).is_equal(1)


func test_fade_in_reaches_alpha_zero() -> void:
	_fade.fade_in(0.05)
	await get_tree().create_timer(0.15).timeout
	assert_float(_fade._color_rect.color.a).is_equal_approx(0.0, 0.01)


# --- flash ---

func test_flash_starts_at_zero_alpha() -> void:
	_fade.flash(Color.RED, 0.1)
	# Should start at 0 alpha
	assert_float(_fade._color_rect.color.a).is_less_equal(0.1)


func test_flash_uses_specified_color() -> void:
	_fade.flash(Color.RED, 0.1)
	assert_float(_fade._color_rect.color.r).is_equal_approx(1.0, 0.01)
	assert_float(_fade._color_rect.color.g).is_equal_approx(0.0, 0.01)
	assert_float(_fade._color_rect.color.b).is_equal_approx(0.0, 0.01)


func test_flash_returns_to_zero_alpha() -> void:
	_fade.flash(Color.RED, 0.05)
	await get_tree().create_timer(0.15).timeout
	assert_float(_fade._color_rect.color.a).is_equal_approx(0.0, 0.01)


# --- Tween replacement ---

func test_new_fade_cancels_previous() -> void:
	_fade.fade_out(10.0)  # Start a very long fade
	_fade.fade_in(0.05)   # Immediately replace with fast fade_in
	await get_tree().create_timer(0.15).timeout
	# Should end at 0, not 1 — fade_in won
	assert_float(_fade._color_rect.color.a).is_equal_approx(0.0, 0.01)
