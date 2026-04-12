extends GdUnitTestSuite
class_name TestToolSlotUI

## Unit tests for ToolSlotUI (task-084d).
##
## Covers slot instantiation, setup() label mapping, refresh() with and
## without an equipped tool, and the empty/equipped visual distinction.

const _ToolSlotUI = preload("res://ui/tool_slot_ui.gd")

const ID_AXE: StringName = &"P00201"
const ID_PICKAXE: StringName = &"P00202"
const ID_KNIFE: StringName = &"P00204"
const ID_SCANNER: StringName = &"P00205"

## Default empty color from ToolSlotUI._ready (_icon_rect.color)
const EMPTY_COLOR: Color = Color(0.10, 0.10, 0.12)


func _make_slot() -> _ToolSlotUI:
	var slot := _ToolSlotUI.new()
	add_child(slot)
	return slot


func _free_slot(slot: _ToolSlotUI) -> void:
	if is_instance_valid(slot):
		slot.queue_free()


# --- Construction ---

func test_slot_instantiates_without_error() -> void:
	var slot := _make_slot()
	assert_object(slot).is_not_null()
	assert_bool(slot is Control).is_true()
	_free_slot(slot)


func test_slot_has_minimum_size() -> void:
	var slot := _make_slot()
	assert_float(slot.custom_minimum_size.x).is_greater_equal(110.0)
	assert_float(slot.custom_minimum_size.y).is_greater_equal(110.0)
	_free_slot(slot)


func test_slot_creates_internal_nodes_on_ready() -> void:
	var slot := _make_slot()
	assert_object(slot._bg_panel).is_not_null()
	assert_object(slot._slot_label).is_not_null()
	assert_object(slot._icon_rect).is_not_null()
	_free_slot(slot)


# --- setup(): label mapping ---

func test_setup_axe_label() -> void:
	var slot := _make_slot()
	slot.setup(&"axe")
	assert_str(slot._slot_label.text).is_equal("Axe")
	_free_slot(slot)


func test_setup_pickaxe_label() -> void:
	var slot := _make_slot()
	slot.setup(&"pickaxe")
	assert_str(slot._slot_label.text).is_equal("Pick")
	_free_slot(slot)


func test_setup_weapon_label() -> void:
	var slot := _make_slot()
	slot.setup(&"weapon")
	assert_str(slot._slot_label.text).is_equal("Wpn")
	_free_slot(slot)


func test_setup_scanner_label() -> void:
	var slot := _make_slot()
	slot.setup(&"scanner")
	assert_str(slot._slot_label.text).is_equal("Scn")
	_free_slot(slot)


func test_setup_unknown_slot_uses_fallback_label() -> void:
	var slot := _make_slot()
	slot.setup(&"zap")
	# Fallback path: upper-case, first 3 chars.
	assert_str(slot._slot_label.text).is_equal("ZAP")
	_free_slot(slot)


# --- refresh(): empty vs equipped visual state ---

func test_refresh_empty_string_shows_empty_color() -> void:
	var slot := _make_slot()
	slot.setup(&"axe")
	slot.refresh(&"")
	assert_bool(slot._icon_rect.color == EMPTY_COLOR).is_true()
	_free_slot(slot)


func test_refresh_with_known_tool_changes_color() -> void:
	var slot := _make_slot()
	slot.setup(&"axe")
	slot.refresh(ID_AXE)
	# When an equipped tool is resolvable via PropRegistry, the icon
	# color should differ from the empty default.
	assert_bool(slot._icon_rect.color != EMPTY_COLOR).is_true()
	_free_slot(slot)


func test_refresh_with_unknown_tool_uses_default_tool_color() -> void:
	var slot := _make_slot()
	slot.setup(&"axe")
	slot.refresh(&"P99999")  # not in PropRegistry
	# When the def is missing, the fallback DEFAULT_TOOL_COLOR applies
	assert_bool(slot._icon_rect.color == _ToolSlotUI.DEFAULT_TOOL_COLOR).is_true()
	_free_slot(slot)


func test_refresh_clear_after_equipped_returns_to_empty() -> void:
	var slot := _make_slot()
	slot.setup(&"axe")
	slot.refresh(ID_AXE)
	slot.refresh(&"")
	assert_bool(slot._icon_rect.color == EMPTY_COLOR).is_true()
	_free_slot(slot)


# --- Multi-slot sanity: each slot keeps its own state ---

func test_independent_slots_hold_separate_labels() -> void:
	var axe := _make_slot()
	var pick := _make_slot()
	axe.setup(&"axe")
	pick.setup(&"pickaxe")
	assert_str(axe._slot_label.text).is_equal("Axe")
	assert_str(pick._slot_label.text).is_equal("Pick")
	_free_slot(axe)
	_free_slot(pick)


func test_mouse_filter_is_ignore() -> void:
	# Tools are auto-used — the slot explicitly disables mouse interaction.
	var slot := _make_slot()
	assert_int(slot.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_free_slot(slot)
