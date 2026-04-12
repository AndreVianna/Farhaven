extends GdUnitTestSuite
class_name TestInventorySlotUI

## Unit tests for InventorySlotUI (task-084d).
##
## Covers construction, refresh() with populated and empty slot dictionaries,
## the slot_tapped signal for consumables, quantity label rendering, and
## the empty-vs-occupied visual state.

const _InventorySlotUI = preload("res://ui/inventory_slot_ui.gd")

const ID_WOOD: StringName = &"P00010"      # non-consumable resource
const ID_BERRIES: StringName = &"P00020"   # consumable
const ID_UNKNOWN: StringName = &"P99999"

var _slot: _InventorySlotUI = null
var _tap_count: int = 0
var _last_tapped_type: StringName = &""


func before_test() -> void:
	_slot = _InventorySlotUI.new()
	add_child(_slot)
	_tap_count = 0
	_last_tapped_type = &""


func after_test() -> void:
	if is_instance_valid(_slot):
		_slot.queue_free()
	_slot = null


func _connect_tap() -> void:
	_slot.slot_tapped.connect(func(type: StringName) -> void:
		_tap_count += 1
		_last_tapped_type = type
	)


# --- Construction ---

func test_slot_instantiates_without_error() -> void:
	assert_object(_slot).is_not_null()
	assert_bool(_slot is Control).is_true()


func test_slot_has_minimum_size() -> void:
	assert_float(_slot.custom_minimum_size.x).is_greater_equal(110.0)
	assert_float(_slot.custom_minimum_size.y).is_greater_equal(110.0)


func test_slot_creates_internal_nodes_on_ready() -> void:
	assert_object(_slot._bg_panel).is_not_null()
	assert_object(_slot._icon_rect).is_not_null()
	assert_object(_slot._quantity_label).is_not_null()


func test_default_state_is_empty() -> void:
	# Internal state defaults before any refresh()
	assert_str(String(_slot._type)).is_equal("")
	assert_int(_slot._quantity).is_equal(0)
	assert_bool(_slot._is_consumable).is_false()


func test_default_mouse_filter_is_stop() -> void:
	# Slots must accept _gui_input events to dispatch slot_tapped
	assert_int(_slot.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# --- refresh() with empty slot ---

func test_refresh_empty_dict_shows_no_quantity_label() -> void:
	_slot.refresh({"type": &"", "quantity": 0})
	assert_bool(_slot._quantity_label.visible).is_false()
	assert_str(String(_slot._type)).is_equal("")


func test_refresh_empty_dict_icon_is_transparent() -> void:
	_slot.refresh({"type": &"", "quantity": 0})
	# Empty style sets icon color alpha to 0
	assert_float(_slot._icon_rect.color.a).is_equal(0.0)


# --- refresh() with occupied slot ---

func test_refresh_with_wood_sets_type_and_quantity() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 5})
	assert_str(String(_slot._type)).is_equal(String(ID_WOOD))
	assert_int(_slot._quantity).is_equal(5)


func test_refresh_with_item_shows_quantity_label() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 5})
	assert_bool(_slot._quantity_label.visible).is_true()


func test_refresh_quantity_label_contains_count() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 7})
	assert_bool(_slot._quantity_label.text.contains("7")).is_true()


func test_refresh_with_consumable_sets_is_consumable_true() -> void:
	_slot.refresh({"type": ID_BERRIES, "quantity": 3})
	assert_bool(_slot._is_consumable).is_true()


func test_refresh_with_non_consumable_sets_is_consumable_false() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 3})
	assert_bool(_slot._is_consumable).is_false()


func test_refresh_with_unknown_type_uses_default_color() -> void:
	_slot.refresh({"type": ID_UNKNOWN, "quantity": 1})
	# Unknown type falls through to DEFAULT_SLOT_COLOR in _apply_occupied_style
	assert_bool(_slot._icon_rect.color == _InventorySlotUI.DEFAULT_SLOT_COLOR).is_true()


func test_refresh_from_occupied_to_empty_hides_quantity_label() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 5})
	assert_bool(_slot._quantity_label.visible).is_true()
	_slot.refresh({"type": &"", "quantity": 0})
	assert_bool(_slot._quantity_label.visible).is_false()


# --- play_highlight: tween creation is safe ---

func test_play_highlight_creates_tween_without_crash() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 1})
	_slot.play_highlight()
	# Internal tween should now exist
	assert_object(_slot._highlight_tween).is_not_null()


func test_play_highlight_twice_replaces_previous_tween() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 1})
	_slot.play_highlight()
	_slot.play_highlight()
	# Should not crash; the second call kills the first tween
	assert_object(_slot._highlight_tween).is_not_null()


# --- slot_tapped signal ---

func test_gui_input_mouse_click_on_consumable_emits_signal() -> void:
	_slot.refresh({"type": ID_BERRIES, "quantity": 2})
	_connect_tap()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(1)
	assert_str(String(_last_tapped_type)).is_equal(String(ID_BERRIES))


func test_gui_input_on_non_consumable_does_not_emit() -> void:
	_slot.refresh({"type": ID_WOOD, "quantity": 2})
	_connect_tap()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(0)


func test_gui_input_on_empty_slot_does_not_emit() -> void:
	_slot.refresh({"type": &"", "quantity": 0})
	_connect_tap()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(0)


func test_gui_input_right_click_does_not_emit() -> void:
	_slot.refresh({"type": ID_BERRIES, "quantity": 2})
	_connect_tap()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(0)


func test_gui_input_mouse_release_does_not_emit() -> void:
	_slot.refresh({"type": ID_BERRIES, "quantity": 2})
	_connect_tap()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false  # release
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(0)


func test_gui_input_touch_press_on_consumable_emits_signal() -> void:
	_slot.refresh({"type": ID_BERRIES, "quantity": 2})
	_connect_tap()
	var event := InputEventScreenTouch.new()
	event.pressed = true
	_slot._gui_input(event)
	assert_int(_tap_count).is_equal(1)
