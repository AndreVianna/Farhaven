class_name CombinedPanel
extends PanelContainer

## Base class for full-screen combined panels (landscape split layout).
## Left/right halves separated by a centered close button.
## Sub-panels keep their own headers; the combined panel just provides
## the dark overlay, split layout, and close button.

signal panel_opened()

var _left_title: String
var _right_title: String
var _close_button: Button
var _left_container: VBoxContainer
var _right_container: VBoxContainer


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
	add_theme_stylebox_override("panel", style)

	# MarginContainer for padding
	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	# Main HBox: Left | CloseButton | Right
	var hbox := HBoxContainer.new()
	hbox.layout_mode = 2
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	margin.add_child(hbox)

	# Left side container
	_left_container = VBoxContainer.new()
	_left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_container.size_flags_stretch_ratio = 1.0
	hbox.add_child(_left_container)

	_build_left_content(_left_container)

	# Center column: close button at top
	var center_vbox := VBoxContainer.new()
	center_vbox.custom_minimum_size = Vector2(64, 0)
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(center_vbox)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(64, 64)
	_close_button.add_theme_font_size_override("font_size", 28)
	_close_button.pressed.connect(close)
	center_vbox.add_child(_close_button)

	# Right side container
	_right_container = VBoxContainer.new()
	_right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_container.size_flags_stretch_ratio = 1.0
	hbox.add_child(_right_container)

	_build_right_content(_right_container)


# --- Public API ---

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

func _build_left_content(_parent: VBoxContainer) -> void:
	pass


func _build_right_content(_parent: VBoxContainer) -> void:
	pass


func _on_opened() -> void:
	pass


# --- Helpers ---

static func embed_sub_panel(sub_panel: PanelContainer, parent: VBoxContainer) -> void:
	## Embed an existing panel scene into a VBoxContainer half.
	## Forces expand, removes sub-panel background, hides its close button.
	sub_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Remove sub-panel background (combined panel provides the background)
	sub_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	parent.add_child(sub_panel)

	# Force visible — combined panel controls visibility
	sub_panel.visible = true

	# Hide the sub-panel's own close button
	var close_btn: Button = sub_panel.get_node_or_null("VBox/Header/CloseButton")
	if close_btn != null:
		close_btn.visible = false


static func create_placeholder(title: String, subtitle: String) -> VBoxContainer:
	## Create a placeholder section with header and coming-soon text.
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 28)
	vbox.add_child(header)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Placeholder text centered in remaining space
	var placeholder := Label.new()
	placeholder.text = "(%s — Coming Soon)" % subtitle
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placeholder.add_theme_font_size_override("font_size", 20)
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))
	vbox.add_child(placeholder)

	return vbox
