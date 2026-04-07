class_name CombinedPanel
extends PanelContainer

## Base class for full-screen combined panels (landscape split layout).
## Each combined panel has a left side and right side separated by a
## centered close button. Subclasses override _build_left_content()
## and _build_right_content() to populate each half.
##
## Emits panel_opened for mutual exclusion with other combined panels.

signal panel_opened()

var _left_title: String
var _right_title: String
var _close_button: Button


func _init(left_title: String = "", right_title: String = "") -> void:
	_left_title = left_title
	_right_title = right_title


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Full-screen anchors
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark semi-transparent background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)

	# Main HBox: Left | CloseButton | Right
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	# Left side
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	hbox.add_child(left_vbox)

	var left_header := HBoxContainer.new()
	left_header.custom_minimum_size = Vector2(0, 56)
	left_vbox.add_child(left_header)

	var left_label := Label.new()
	left_label.text = _left_title
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_label.add_theme_font_size_override("font_size", 28)
	left_header.add_child(left_label)

	var left_content := Control.new()
	left_content.name = "LeftContent"
	left_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(left_content)

	_build_left_content(left_content)

	# Center close button
	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	center_vbox.custom_minimum_size = Vector2(96, 0)
	hbox.add_child(center_vbox)

	# Top spacer to align close button with headers
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 0)
	center_vbox.add_child(top_spacer)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(96, 96)
	_close_button.add_theme_font_size_override("font_size", 36)
	_close_button.pressed.connect(close)
	center_vbox.add_child(_close_button)

	# Right side
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	hbox.add_child(right_vbox)

	var right_header := HBoxContainer.new()
	right_header.custom_minimum_size = Vector2(0, 56)
	right_vbox.add_child(right_header)

	var right_label := Label.new()
	right_label.text = _right_title
	right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_label.add_theme_font_size_override("font_size", 28)
	right_header.add_child(right_label)

	var right_content := Control.new()
	right_content.name = "RightContent"
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(right_content)

	_build_right_content(right_content)


# --- Public API (same as existing panels) ---

func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	visible = true
	_on_opened()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Virtual methods for subclasses ---

func _build_left_content(_parent: Control) -> void:
	pass


func _build_right_content(_parent: Control) -> void:
	pass


func _on_opened() -> void:
	pass


# --- Helpers for embedding sub-panels ---

static func embed_sub_panel(sub_panel: PanelContainer, parent: Control) -> void:
	## Add an existing panel scene as a child of `parent`, making it fill
	## the parent area. Hides the sub-panel's own close button and forces
	## visibility to true (the combined panel controls visibility).
	sub_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Remove the sub-panel's own background style so only the combined panel bg shows
	sub_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	parent.add_child(sub_panel)

	# Force visible — the combined panel controls visibility, not the sub-panel
	sub_panel.visible = true

	# Hide the sub-panel's close button (it has its own X we don't want)
	var close_btn: Button = sub_panel.get_node_or_null("VBox/Header/CloseButton")
	if close_btn != null:
		close_btn.visible = false


static func create_placeholder(text: String) -> Label:
	## Create a centered placeholder label for sections not yet implemented.
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.8))
	return label
