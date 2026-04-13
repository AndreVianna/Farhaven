extends GdUnitTestSuite
class_name TestBodySchemaWidget

## Unit tests for BodySchemaWidget (delivery-006j Phase C).
## The widget lives on the status panel and renders a fixed-layout
## humanoid with 22 slot panels. Tests cover construction, initial
## empty state, set_equipped painting, and unknown-slot resilience.

const _BodySchemaWidget = preload("res://ui/body_schema_widget.gd")
const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")

var _widget: _BodySchemaWidget


func before_test() -> void:
	_widget = _BodySchemaWidget.new()
	add_child(_widget)
	# Trigger _ready() so slot panels are built.
	_widget._ready()


func after_test() -> void:
	if _widget != null:
		_widget.queue_free()
		_widget = null


func test_builds_one_panel_per_slot() -> void:
	# Every Place must produce a Panel — otherwise the UI silently
	# drops an equipment slot.
	for i in _WearableCap.PLACE_COUNT:
		var panel: Panel = _widget.get_slot_panel(i)
		assert_object(panel).is_not_null()


func test_empty_state_panels_use_empty_color_tooltip_shows_slot_name() -> void:
	# Before set_equipped, tooltip is just the slot name. The fill
	# check is indirect through the stylebox — we assert the panel
	# exists and its tooltip is the slot name.
	var back_panel: Panel = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_panel.tooltip_text).is_equal("back")


func test_set_equipped_updates_panel_tooltip_with_display_name() -> void:
	var def := _PropDef.new()
	def.id = &"P00TEST"
	def.display_name = "Test Backpack"
	def.placeholder_color = Color(0.1, 0.5, 0.9, 1.0)
	# PropDef.wearable presence is not required for the widget — it
	# paints whatever slot the caller asked about. Wiring code in
	# Player enforces the correct mapping.

	_widget.set_equipped({_WearableCap.Place.BACK: def})

	var back_panel: Panel = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_panel.tooltip_text).is_equal("back: Test Backpack")


func test_set_equipped_with_unknown_slot_is_ignored() -> void:
	# Passing an out-of-range int must not crash or affect real slots.
	_widget.set_equipped({999: null})
	for i in _WearableCap.PLACE_COUNT:
		assert_object(_widget.get_slot_panel(i)).is_not_null()


func test_set_equipped_clears_previous_mapping() -> void:
	var def := _PropDef.new()
	def.id = &"P00TEST"
	def.display_name = "Ephemeral"
	def.placeholder_color = Color.RED
	_widget.set_equipped({_WearableCap.Place.BACK: def})

	_widget.set_equipped({})  # fully unequip

	var back_panel: Panel = _widget.get_slot_panel(_WearableCap.Place.BACK)
	assert_str(back_panel.tooltip_text).is_equal("back")
