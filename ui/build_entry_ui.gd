class_name BuildEntryUI
extends PanelContainer

## Single build recipe row in the build panel.
## Two states: affordable, unaffordable.
## Ingredient display shows owned/needed with green/red color coding.

signal build_requested(recipe: Resource)

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")

const COLOR_GREEN := Color(0.494, 0.784, 0.525)  # #7EC886 accent_green
const COLOR_RED := Color(0.878, 0.482, 0.482)     # #E07B7B accent_red
const COLOR_TEXT := Color(1.0, 1.0, 1.0)           # text_primary
const COLOR_DIMMED := Color(0.69, 0.72, 0.78)      # #B0B8C8 text_secondary

enum State { AFFORDABLE, UNAFFORDABLE }

var _recipe: _Recipe = null
var _state: int = State.UNAFFORDABLE

var _name_label: Label
var _ingredients_container: HBoxContainer
var _build_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(0, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.24, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Top row: name + build button
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 24)
	top_row.add_child(_name_label)

	_build_button = Button.new()
	_build_button.custom_minimum_size = Vector2(80, 48)
	_build_button.text = "BUILD"
	_build_button.add_theme_font_size_override("font_size", 18)
	_build_button.pressed.connect(_on_build_pressed)
	top_row.add_child(_build_button)

	# Bottom row: ingredients
	_ingredients_container = HBoxContainer.new()
	_ingredients_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_ingredients_container)


func setup(recipe: _Recipe) -> void:
	_recipe = recipe
	# Use recipe display_name, fall back to output PropDef display_name
	var display_name: String = recipe.display_name
	if display_name == "":
		display_name = _get_output_display_name(recipe)
	if display_name == "":
		display_name = String(recipe.id)
	_name_label.text = display_name


func refresh(inventory) -> void:
	if _recipe == null:
		return

	# Determine affordability from recipe inputs
	if _can_afford(inventory):
		_state = State.AFFORDABLE
	else:
		_state = State.UNAFFORDABLE

	# Update visuals
	_update_ingredients(inventory)
	_update_build_button()
	_update_label_style()


func get_recipe() -> _Recipe:
	return _recipe


func get_state() -> int:
	return _state


func _can_afford(inventory) -> bool:
	if _recipe == null:
		return false
	for input in _recipe.inputs:
		if input.source != &"player_inventory" and input.source != &"":
			continue
		if not inventory.has_item(input.ref_or_tag, input.count):
			return false
	return true


func _update_ingredients(inventory) -> void:
	for child in _ingredients_container.get_children():
		child.queue_free()

	if _recipe == null:
		return

	for input in _recipe.inputs:
		if input.source != &"player_inventory" and input.source != &"":
			continue
		var needed: int = input.count
		var owned: int = inventory.get_count(input.ref_or_tag)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)

		var def: _PropDef = PropRegistry.get_def(input.ref_or_tag)
		var display_name: String = def.display_name if def != null and def.display_name != "" else String(input.ref_or_tag)
		lbl.text = "%s: %d/%d" % [display_name, owned, needed]

		if owned >= needed:
			lbl.add_theme_color_override("font_color", COLOR_GREEN)
		else:
			lbl.add_theme_color_override("font_color", COLOR_RED)

		_ingredients_container.add_child(lbl)


func _update_build_button() -> void:
	match _state:
		State.AFFORDABLE:
			_build_button.text = "BUILD"
			_build_button.disabled = false
			_build_button.modulate = Color.WHITE
		State.UNAFFORDABLE:
			_build_button.text = "BUILD"
			_build_button.disabled = true
			_build_button.modulate = Color(1.0, 1.0, 1.0, 0.4)


func _update_label_style() -> void:
	match _state:
		State.AFFORDABLE:
			_name_label.add_theme_color_override("font_color", COLOR_TEXT)
			modulate = Color.WHITE
		State.UNAFFORDABLE:
			_name_label.add_theme_color_override("font_color", COLOR_DIMMED)
			modulate = Color(1.0, 1.0, 1.0, 0.7)


func _on_build_pressed() -> void:
	if _state == State.AFFORDABLE and _recipe != null:
		build_requested.emit(_recipe)


func _get_output_display_name(recipe: _Recipe) -> String:
	for output in recipe.outputs:
		if output.prop_ref != &"":
			var def: _PropDef = PropRegistry.get_def(output.prop_ref)
			if def != null and def.display_name != "":
				return def.display_name
	return ""
