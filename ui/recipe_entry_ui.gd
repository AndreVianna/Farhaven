class_name RecipeEntryUI
extends PanelContainer

## Single recipe row in the crafting panel.
## Three states: affordable, unaffordable, already-owned.
## Ingredient display shows owned/needed with green/red color coding.

signal craft_requested(recipe_name: StringName)

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")
## Uses preload because tests can be parsed before class_name registration completes.
const _PropDef = preload("res://scripts/data/prop_def.gd")

const COLOR_GREEN := Color(0.494, 0.784, 0.525)  # #7EC886 accent_green
const COLOR_RED := Color(0.878, 0.482, 0.482)     # #E07B7B accent_red
const COLOR_WARM := Color(0.957, 0.635, 0.380)    # #F4A261 accent_warm
const COLOR_TEXT := Color(1.0, 1.0, 1.0)           # text_primary
const COLOR_DIMMED := Color(0.69, 0.72, 0.78)      # #B0B8C8 text_secondary
const COLOR_LABEL := Color(0.533, 0.565, 0.627)    # #8890A0 text_label
const COLOR_OWNED_BG := Color(0.3, 0.4, 0.5, 0.2)

enum State { AFFORDABLE, UNAFFORDABLE, ALREADY_OWNED }

var _recipe_name: StringName = &""
var _state: int = State.UNAFFORDABLE

var _name_label: Label
var _ingredients_container: HBoxContainer
var _craft_button: Button


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

	# Top row: name + craft button
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 24)
	top_row.add_child(_name_label)

	_craft_button = Button.new()
	_craft_button.custom_minimum_size = Vector2(80, 48)
	_craft_button.text = "CRAFT"
	_craft_button.add_theme_font_size_override("font_size", 18)
	_craft_button.pressed.connect(_on_craft_pressed)
	top_row.add_child(_craft_button)

	# Bottom row: ingredients
	_ingredients_container = HBoxContainer.new()
	_ingredients_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_ingredients_container)


func setup(recipe_name: StringName) -> void:
	_recipe_name = recipe_name
	var display_name: String = recipe_name.replace("_", " ").capitalize()
	_name_label.text = display_name


func refresh(inventory, crafting_system) -> void:
	if _recipe_name == &"" or not _CraftingSystem.RECIPE_CONFIG.has(_recipe_name):
		return

	var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[_recipe_name]
	var ingredients: Dictionary = recipe["ingredients"]

	# Determine state
	if recipe["output_type"] == &"tool":
		var slot: StringName = recipe["tool_slot"]
		var output_id: StringName = recipe.get("output_id", &"")
		if output_id != &"" and inventory.get_tool(slot) == output_id:
			_state = State.ALREADY_OWNED
		elif _can_afford(inventory, ingredients):
			_state = State.AFFORDABLE
		else:
			_state = State.UNAFFORDABLE
	else:
		if _can_afford(inventory, ingredients):
			_state = State.AFFORDABLE
		else:
			_state = State.UNAFFORDABLE

	# Update visuals
	_update_ingredients(inventory, ingredients)
	_update_craft_button()
	_update_label_style()


func get_recipe_name() -> StringName:
	return _recipe_name


func get_state() -> int:
	return _state


func _can_afford(inventory, ingredients: Dictionary) -> bool:
	for material: StringName in ingredients:
		if not inventory.has_item(material, ingredients[material]):
			return false
	return true


func _update_ingredients(inventory, ingredients: Dictionary) -> void:
	for child in _ingredients_container.get_children():
		child.queue_free()

	for material: StringName in ingredients:
		var needed: int = ingredients[material]
		var owned: int = inventory.get_count(material)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)

		var def: _PropDef = PropRegistry.get_def(material)
		var display_name: String = def.display_name if def != null and def.display_name != "" else String(material)
		lbl.text = "%s: %d/%d" % [display_name, owned, needed]

		if owned >= needed:
			lbl.add_theme_color_override("font_color", COLOR_GREEN)
		else:
			lbl.add_theme_color_override("font_color", COLOR_RED)

		_ingredients_container.add_child(lbl)


func _update_craft_button() -> void:
	match _state:
		State.AFFORDABLE:
			_craft_button.text = "CRAFT"
			_craft_button.disabled = false
			_craft_button.modulate = Color.WHITE
		State.UNAFFORDABLE:
			_craft_button.text = "CRAFT"
			_craft_button.disabled = true
			_craft_button.modulate = Color(1.0, 1.0, 1.0, 0.4)
		State.ALREADY_OWNED:
			_craft_button.text = "OWNED"
			_craft_button.disabled = true
			_craft_button.modulate = Color(1.0, 1.0, 1.0, 0.4)


func _update_label_style() -> void:
	match _state:
		State.AFFORDABLE:
			_name_label.add_theme_color_override("font_color", COLOR_TEXT)
			modulate = Color.WHITE
		State.UNAFFORDABLE:
			_name_label.add_theme_color_override("font_color", COLOR_DIMMED)
			modulate = Color(1.0, 1.0, 1.0, 0.7)
		State.ALREADY_OWNED:
			_name_label.add_theme_color_override("font_color", COLOR_DIMMED)
			modulate = Color(1.0, 1.0, 1.0, 0.5)


func _on_craft_pressed() -> void:
	if _state == State.AFFORDABLE:
		craft_requested.emit(_recipe_name)
