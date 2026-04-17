extends GdUnitTestSuite
class_name TestBodySchemaWidget

## Unit tests for BodySchemaWidget (delivery-006j Phase C).
## The widget renders front + back silhouettes with slot overlays drawn
## directly in _draw(). Each slot has an invisible Control that carries
## the tooltip — tests inspect the tooltip state to verify set_equipped
## routes correctly.

const _BodySchemaWidget = preload("res://ui/body_schema_widget.gd")
const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")

var _widget: _BodySchemaWidget


func before_test() -> void:
	_widget = _BodySchemaWidget.new()
	add_child(_widget)
	# Trigger _ready() so slot tooltip Controls are built.
	_widget._ready()


func after_test() -> void:
	if _widget != null:
		_widget.queue_free()
		_widget = null


func test_builds_one_tooltip_area_per_slot() -> void:
	# Every Place must produce a tooltip carrier — otherwise hovering
	# that body region would silently show nothing.
	for i in _WearableCap.PLACE_COUNT:
		var area: Control = _widget.get_slot_panel(i)
		assert_object(area).is_not_null()


func test_empty_state_tooltip_shows_slot_name() -> void:
	var back_area: Control = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_area.tooltip_text).is_equal("back")


func test_set_equipped_updates_tooltip_with_display_name() -> void:
	var def := _PropDef.new()
	def.id = &"P00TEST"
	def.display_name = "Test Backpack"
	# PropDef.wearable presence is not required for the widget — it
	# paints whatever slot the caller asked about. Wiring code in
	# Player enforces the correct mapping.

	_widget.set_equipped({_WearableCap.Place.BACK: def})

	var back_area: Control = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_area.tooltip_text).is_equal("back: Test Backpack")


func test_set_equipped_with_unknown_slot_is_ignored() -> void:
	# Passing an out-of-range int must not crash or affect real slots.
	_widget.set_equipped({999: null})
	for i in _WearableCap.PLACE_COUNT:
		assert_object(_widget.get_slot_panel(i)).is_not_null()


func test_set_equipped_clears_previous_mapping() -> void:
	var def := _PropDef.new()
	def.id = &"P00TEST"
	def.display_name = "Ephemeral"
	_widget.set_equipped({_WearableCap.Place.BACK: def})

	_widget.set_equipped({})  # fully unequip

	var back_area: Control = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_area.tooltip_text).is_equal("back")


func test_widget_minimum_size_fits_both_silhouettes() -> void:
	var expected_w: float = float(_BodySchemaWidget.BODY_W * 2 + _BodySchemaWidget.GAP)
	var expected_h: float = float(_BodySchemaWidget.BODY_H)
	assert_float(_widget.custom_minimum_size.x).is_equal(expected_w)
	assert_float(_widget.custom_minimum_size.y).is_equal(expected_h)
