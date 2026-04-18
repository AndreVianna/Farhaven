class_name ToolSlotUI
extends Control

## Single tool slot in the inventory panel tool row.
## Displays slot label (Axe/Pick/Wpn/Scn) and icon placeholder.
## No tap — tools are auto-used.

## Uses preload because tests can be parsed before class_name registration completes.
const _PropDef = preload("res://scripts/data/prop_def.gd")

## Default tool color when a tool's PropDef is missing.
const DEFAULT_TOOL_COLOR: Color = Color(0.5, 0.5, 0.5)

const SLOT_LABELS: Dictionary = {
	&"axe":     "Axe",
	&"pickaxe": "Pick",
	&"weapon":  "Wpn",
	&"scanner": "Scn",
}

var _bg_panel: Panel
var _slot_label: Label
var _icon_rect: ColorRect


func _init() -> void:
	custom_minimum_size = Vector2(110, 110)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	_slot_label = Label.new()
	_slot_label.anchor_left = 0.0
	_slot_label.anchor_top = 0.0
	_slot_label.anchor_right = 1.0
	_slot_label.anchor_bottom = 0.3
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_slot_label.add_theme_font_size_override("font_size", 22)
	_slot_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_slot_label)

	_icon_rect = ColorRect.new()
	_icon_rect.anchor_left = 0.1
	_icon_rect.anchor_top = 0.25
	_icon_rect.anchor_right = 0.9
	_icon_rect.anchor_bottom = 0.9
	_icon_rect.color = Color(0.10, 0.10, 0.12)
	_icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_icon_rect)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.20, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.50, 0.50, 0.60, 0.8)
	_bg_panel.add_theme_stylebox_override("panel", style)


func setup(slot_name: StringName) -> void:
	_slot_label.text = SLOT_LABELS.get(slot_name, str(slot_name).to_upper().left(3))


func refresh(tool_type: StringName) -> void:
	if tool_type == &"":
		_icon_rect.color = Color(0.10, 0.10, 0.12)
	else:
		# TODO: use prop thumbnail/icon once the icon system lands.
		_icon_rect.color = DEFAULT_TOOL_COLOR
