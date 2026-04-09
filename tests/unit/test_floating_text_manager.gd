class_name TestFloatingTextManager
extends GdUnitTestSuite

const _FloatingTextManager = preload("res://scripts/hud/floating_text_manager.gd")


func test_rise_pixels_constant() -> void:
	assert_float(_FloatingTextManager.RISE_PIXELS).is_equal_approx(60.0, 0.001)


func test_stack_offset_constant() -> void:
	assert_float(_FloatingTextManager.STACK_OFFSET).is_equal_approx(30.0, 0.001)


func test_active_labels_starts_empty() -> void:
	var mgr := _FloatingTextManager.new()
	assert_int(mgr._active_labels.size()).is_equal(0)
	mgr.free()
