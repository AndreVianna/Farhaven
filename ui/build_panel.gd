class_name BuildPanel
extends PanelContainer

## Build bottom drawer panel (~45% screen height).
## Opens/closes on BuildButton tap. Renders build recipes with
## ingredient costs. Two states: affordable, unaffordable.
## BUILD tap enters placement mode via BuildingSystem.
## Emits panel_opened for mutual exclusion with other panels.

signal panel_opened()

const BuildEntryUI = preload("res://ui/build_entry_ui.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")

@onready var _close_button: Button = $VBox/Header/CloseButton
@onready var _recipe_list: VBoxContainer = $VBox/ScrollContainer/RecipeList

var _building_system: Node = null
var _inventory = null
var _recipe_registry: Node = null
var _build_entries: Array = []  # Array of BuildEntryUI


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)


# --- Public API ---

func set_building_system(sys: Node) -> void:
	_building_system = sys


func set_inventory(inv) -> void:
	if _inventory != null and _inventory.has_signal("inventory_changed"):
		if _inventory.inventory_changed.is_connected(_on_inventory_changed):
			_inventory.inventory_changed.disconnect(_on_inventory_changed)
	_inventory = inv
	if _inventory != null:
		_inventory.inventory_changed.connect(_on_inventory_changed)


func set_recipe_registry(reg: Node) -> void:
	_recipe_registry = reg


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible and _build_entries.size() > 0:
		return
	visible = true
	_rebuild_recipes()
	_refresh_all()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Internal ---

func _rebuild_recipes() -> void:
	var registry: Node = _get_registry()
	if registry == null:
		return

	var recipes: Array = registry.find_recipes_for_action(&"build")

	# Clear existing entries — remove from tree immediately so stale nodes
	# aren't picked up by find-by-name queries before queue_free completes.
	for entry in _build_entries:
		if is_instance_valid(entry):
			_recipe_list.remove_child(entry)
			entry.queue_free()
	_build_entries.clear()

	# Add entries for each build recipe
	for recipe in recipes:
		_add_build_entry(recipe)


func _add_build_entry(recipe: _Recipe) -> void:
	var entry := BuildEntryUI.new()
	entry.setup(recipe)
	entry.build_requested.connect(_on_build_requested)
	_recipe_list.add_child(entry)
	_build_entries.append(entry)


func _refresh_all() -> void:
	if _inventory == null:
		return
	for entry in _build_entries:
		if is_instance_valid(entry):
			entry.refresh(_inventory)


func _on_build_requested(recipe: _Recipe) -> void:
	if _building_system != null and _building_system.has_method("enter_placement_mode"):
		_building_system.enter_placement_mode(recipe)
	close()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()


func _get_registry() -> Node:
	if _recipe_registry != null:
		return _recipe_registry
	# Fall back to autoload
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("RecipeRegistry")
	return null
