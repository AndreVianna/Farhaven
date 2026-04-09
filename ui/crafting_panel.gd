class_name CraftingPanel
extends PanelContainer

## Crafting bottom drawer panel (~45% screen height).
## Opens/closes on CraftButton tap. Renders discovered recipes with
## ingredient costs. Three states: affordable, unaffordable, already-owned.
## Emits panel_opened for mutual exclusion with other panels.

signal panel_opened()

const RecipeEntryUI = preload("res://ui/recipe_entry_ui.gd")
const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")

@onready var _close_button: Button = $VBox/Header/CloseButton
@onready var _recipe_list: VBoxContainer = $VBox/ScrollContainer/RecipeList

var _crafting_system: Node = null
var _inventory = null
var _recipe_entries: Dictionary = {}  # StringName -> RecipeEntryUI


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)


# --- Public API ---

func set_crafting_system(sys: Node) -> void:
	if _crafting_system != null:
		if _crafting_system.recipe_discovered.is_connected(_on_recipe_discovered):
			_crafting_system.recipe_discovered.disconnect(_on_recipe_discovered)
		if _crafting_system.craft_completed.is_connected(_on_craft_completed):
			_crafting_system.craft_completed.disconnect(_on_craft_completed)
	_crafting_system = sys
	if _crafting_system != null:
		_crafting_system.recipe_discovered.connect(_on_recipe_discovered)
		_crafting_system.craft_completed.connect(_on_craft_completed)


func set_inventory(inv) -> void:
	if _inventory != null and _inventory.has_signal("inventory_changed"):
		if _inventory.inventory_changed.is_connected(_on_inventory_changed):
			_inventory.inventory_changed.disconnect(_on_inventory_changed)
	_inventory = inv
	if _inventory != null:
		_inventory.inventory_changed.connect(_on_inventory_changed)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible and _recipe_entries.size() > 0:
		return
	visible = true
	_rebuild_recipes()
	_refresh_all()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Internal ---

func _rebuild_recipes() -> void:
	if _crafting_system == null:
		return

	var discovered: Array[StringName] = _crafting_system.get_discovered_recipes()

	# Remove entries that are no longer discovered (shouldn't happen, but defensive)
	for name: StringName in _recipe_entries.keys():
		if name not in discovered:
			_recipe_entries[name].queue_free()
			_recipe_entries.erase(name)

	# Add new entries
	for recipe_name: StringName in discovered:
		if not _recipe_entries.has(recipe_name):
			_add_recipe_entry(recipe_name)


func _add_recipe_entry(recipe_name: StringName) -> void:
	var entry := RecipeEntryUI.new()
	entry.setup(recipe_name)
	entry.craft_requested.connect(_on_craft_requested)
	_recipe_list.add_child(entry)
	_recipe_entries[recipe_name] = entry


func _refresh_all() -> void:
	if _inventory == null or _crafting_system == null:
		return
	for name: StringName in _recipe_entries:
		var entry = _recipe_entries[name]
		entry.refresh(_inventory, _crafting_system)


func _on_craft_requested(recipe_name: StringName) -> void:
	if _crafting_system != null:
		_crafting_system.craft(recipe_name)


func _on_recipe_discovered(_recipe_name: StringName) -> void:
	if visible:
		_rebuild_recipes()
		_refresh_all()


func _on_craft_completed(_recipe_name: StringName) -> void:
	if visible:
		_refresh_all()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()
