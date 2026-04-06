class_name InventorySlotUI
extends Control

## Single resource/consumable slot in the inventory grid.
## Displays a color-coded icon placeholder and quantity label.
## Emits slot_tapped when a consumable is tapped.

signal slot_tapped(type: StringName)

const SLOT_COLORS: Dictionary = {
	&"wood":           Color(0.55, 0.30, 0.10),
	&"stone":          Color(0.60, 0.60, 0.60),
	&"berries":        Color(0.90, 0.20, 0.30),
	&"toxic_berries":  Color(0.35, 0.75, 0.15),
	&"fiber":          Color(0.75, 0.85, 0.25),
	&"ore":            Color(0.40, 0.50, 0.60),
	&"crystal":        Color(0.40, 0.60, 0.95),
	&"meat":           Color(0.80, 0.25, 0.20),
}

var _type: StringName = &""
var _quantity: int = 0
var _is_consumable: bool = false
var _bg_panel: Panel
var _icon_rect: ColorRect
var _quantity_label: Label
var _highlight_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(110, 110)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	_icon_rect = ColorRect.new()
	_icon_rect.anchor_left = 0.1
	_icon_rect.anchor_top = 0.1
	_icon_rect.anchor_right = 0.9
	_icon_rect.anchor_bottom = 0.9
	_icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_icon_rect)

	_quantity_label = Label.new()
	_quantity_label.anchor_left = 0.0
	_quantity_label.anchor_top = 0.58
	_quantity_label.anchor_right = 0.95
	_quantity_label.anchor_bottom = 1.0
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity_label.add_theme_font_size_override("font_size", 24)
	_quantity_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_quantity_label)

	_apply_empty_style()


func refresh(slot: Dictionary, item_config: Dictionary) -> void:
	_type = slot.get("type", &"")
	_quantity = slot.get("quantity", 0)
	if _type == &"":
		_is_consumable = false
		_apply_empty_style()
		return
	var cfg: Dictionary = item_config.get(_type, {})
	if cfg.is_empty() and ResourceRegistry.has_def(_type):
		var def = ResourceRegistry.get_def(_type)
		cfg = {"category": def.category}
	_is_consumable = cfg.get("category", &"") == &"consumable"
	_apply_occupied_style()


func play_highlight() -> void:
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(_icon_rect, "modulate", Color(2.0, 2.0, 0.5, 1.0), 0.1)
	_highlight_tween.tween_property(_icon_rect, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


func _apply_empty_style() -> void:
	_icon_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_quantity_label.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.38, 0.5)
	_bg_panel.add_theme_stylebox_override("panel", style)


func _apply_occupied_style() -> void:
	_icon_rect.color = SLOT_COLORS.get(_type, Color(0.5, 0.5, 0.5))
	var display_name: String = (_type as String).replace("_", " ").capitalize()
	_quantity_label.text = "%s (%d)" % [display_name, _quantity]
	_quantity_label.visible = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.65, 0.65, 0.70, 0.9)
	_bg_panel.add_theme_stylebox_override("panel", style)


var _last_tap_frame: int = -1

func _gui_input(event: InputEvent) -> void:
	if _type == &"" or not _is_consumable:
		return
	var tapped: bool = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped and Engine.get_process_frames() != _last_tap_frame:
		_last_tap_frame = Engine.get_process_frames()
		play_highlight()
		slot_tapped.emit(_type)
		accept_event()
