class_name TestCraftFlash
extends GdUnitTestSuite

const _CraftFlash = preload("res://scripts/hud/craft_flash.gd")


func test_flash_duration_constant() -> void:
	assert_float(_CraftFlash.FLASH_DURATION).is_equal_approx(0.25, 0.001)


func test_flash_color_is_white_with_alpha() -> void:
	var c: Color = _CraftFlash.FLASH_COLOR
	assert_float(c.r).is_equal_approx(1.0, 0.01)
	assert_float(c.g).is_equal_approx(1.0, 0.01)
	assert_float(c.b).is_equal_approx(1.0, 0.01)
	assert_float(c.a).is_equal_approx(0.3, 0.01)


func test_ready_sets_invisible() -> void:
	var flash: Node = auto_free(_CraftFlash.new())
	add_child(flash)
	assert_bool(flash.visible).is_false()


func test_ready_sets_transparent_color() -> void:
	var flash: Node = auto_free(_CraftFlash.new())
	add_child(flash)
	assert_float(flash.color.a).is_equal_approx(0.0, 0.01)


func test_flash_makes_visible() -> void:
	var flash: Node = auto_free(_CraftFlash.new())
	add_child(flash)
	flash.flash()
	assert_bool(flash.visible).is_true()


func test_flash_sets_flash_color() -> void:
	var flash: Node = auto_free(_CraftFlash.new())
	add_child(flash)
	flash.flash()
	assert_float(flash.color.a).is_equal_approx(0.3, 0.01)
