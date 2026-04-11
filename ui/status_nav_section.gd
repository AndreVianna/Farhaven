class_name StatusNavSection
extends VBoxContainer

## Navigation links sub-section for the Status combined panel (task-082).
## Renders three buttons (Settings / About / Contact) that open a shared
## "Coming soon" modal. Real systems are out of scope for 006c.

signal nav_opened(link_name: String)

const _LINK_NAMES: Array[String] = ["Settings", "About", "Contact"]

var _buttons: Array[Button] = []
var _modal: AcceptDialog = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	_build_ui()
	_build_modal()


func _build_ui() -> void:
	var header := Label.new()
	header.name = "NavHeader"
	header.text = "MORE"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95, 1.0))
	add_child(header)

	var sep := HSeparator.new()
	add_child(sep)

	for link_name: String in _LINK_NAMES:
		var btn := Button.new()
		btn.name = link_name + "Button"
		btn.text = link_name
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_nav_pressed.bind(link_name))
		add_child(btn)
		_buttons.append(btn)


func _build_modal() -> void:
	_modal = AcceptDialog.new()
	_modal.name = "NavModal"
	_modal.title = "Coming Soon"
	_modal.dialog_text = ""
	_modal.dialog_hide_on_ok = true
	_modal.get_ok_button().custom_minimum_size = Vector2(120, 48)
	_modal.visible = false
	add_child(_modal)


# --- Public API ---

func show_modal(link_name: String) -> void:
	if _modal == null:
		return
	_modal.dialog_text = "%s coming in a future update." % link_name
	_modal.popup_centered()
	nav_opened.emit(link_name)


# --- Accessors for tests ---

func get_buttons() -> Array[Button]:
	return _buttons


func get_modal() -> AcceptDialog:
	return _modal


# --- Handlers ---

func _on_nav_pressed(link_name: String) -> void:
	show_modal(link_name)
