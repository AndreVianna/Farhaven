extends Node

## Crafting data layer — child of Player.
## Owns recipe config, discovery tracking, craft validation/execution,
## and workbench proximity detection.

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

signal recipe_discovered(recipe_name: StringName)
signal craft_completed(recipe_name: StringName)
signal craft_failed(recipe_name: StringName, reason: StringName)
signal workbench_proximity_changed(near: bool)

const RECIPE_CONFIG: Dictionary = {
	&"stone_axe": {
		"ingredients": { &"wood": 2, &"stone": 1 },
		"output_type": &"tool",
		"tool_slot": &"axe",
		"discovery_material": &"stone",
		"requires_workbench": false,
		"pre_discovered": true,
	},
	&"stone_pickaxe": {
		"ingredients": { &"wood": 3, &"stone": 2 },
		"output_type": &"tool",
		"tool_slot": &"pickaxe",
		"discovery_material": &"stone",
		"requires_workbench": false,
		"pre_discovered": true,
	},
}

var _discovered_recipes: Array[StringName] = []
var _near_workbench: bool = false

var _inventory: _Inventory
var _grid: Node  # HexGrid autoload or test substitute
var _player: Node  # Parent Player node


func _ready() -> void:
	_player = get_parent()
	if _player:
		_inventory = _player.get_inventory()
	if _grid == null:
		_grid = HexGrid
	_connect_signals()
	_load_pre_discovered()


func _connect_signals() -> void:
	if _inventory:
		_inventory.item_added.connect(_on_item_added)
	if _grid:
		if _grid.has_signal("tile_entered"):
			_grid.tile_entered.connect(_on_tile_entered)
		if _grid.has_signal("tile_exited"):
			_grid.tile_exited.connect(_on_tile_exited)
		if _grid.has_signal("structure_placed"):
			_grid.structure_placed.connect(_on_structure_placed)
		if _grid.has_signal("structure_destroyed"):
			_grid.structure_destroyed.connect(_on_structure_destroyed)


# --- Discovery ---

func _load_pre_discovered() -> void:
	for recipe_name: StringName in RECIPE_CONFIG:
		var recipe: Dictionary = RECIPE_CONFIG[recipe_name]
		if recipe.get("pre_discovered", false) and recipe_name not in _discovered_recipes:
			_discovered_recipes.append(recipe_name)


func _on_item_added(type: StringName, _amount: int) -> void:
	for recipe_name: StringName in RECIPE_CONFIG:
		var recipe: Dictionary = RECIPE_CONFIG[recipe_name]
		if recipe["discovery_material"] == type and recipe_name not in _discovered_recipes:
			_discovered_recipes.append(recipe_name)
			recipe_discovered.emit(recipe_name)


func get_discovered_recipes() -> Array[StringName]:
	return _discovered_recipes.duplicate()


func is_recipe_discovered(recipe_name: StringName) -> bool:
	return recipe_name in _discovered_recipes


# --- Craft ---

func craft(recipe_name: StringName) -> bool:
	if not RECIPE_CONFIG.has(recipe_name):
		craft_failed.emit(recipe_name, &"unknown_recipe")
		return false

	var recipe: Dictionary = RECIPE_CONFIG[recipe_name]

	# 1. Workbench proximity (only for recipes that require it)
	if recipe.get("requires_workbench", true) and not _near_workbench:
		craft_failed.emit(recipe_name, &"no_workbench")
		return false

	# 2. Already owned (tools only)
	if recipe["output_type"] == &"tool":
		var slot: StringName = recipe["tool_slot"]
		if _inventory.get_tool(slot) == recipe_name:
			craft_failed.emit(recipe_name, &"already_owned")
			return false

	# 3. Ingredients
	var ingredients: Dictionary = recipe["ingredients"]
	for material: StringName in ingredients:
		if not _inventory.has_item(material, ingredients[material]):
			craft_failed.emit(recipe_name, &"insufficient_materials")
			return false

	# 4. Consume
	for material: StringName in ingredients:
		_inventory.remove_item(material, ingredients[material])

	# 5. Produce
	if recipe["output_type"] == &"tool":
		_inventory.set_tool(recipe["tool_slot"], recipe_name)

	craft_completed.emit(recipe_name)
	# Apply crafting survival cost
	var survival: Node = _get_survival_system()
	if survival and survival.has_method("apply_activity_cost"):
		survival.apply_activity_cost(&"crafting")
	return true


# --- Survival System Helper ---


func _get_survival_system() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child != self and child.has_method("apply_activity_cost"):
			return child
	return null


# --- Workbench Proximity ---

func is_near_workbench() -> bool:
	return _near_workbench


func _check_workbench_proximity() -> void:
	if _player == null or _grid == null:
		return
	var was_near: bool = _near_workbench
	_near_workbench = _compute_near_workbench(_player.current_tile)
	if _near_workbench != was_near:
		workbench_proximity_changed.emit(_near_workbench)


func _compute_near_workbench(player_tile: Vector2i) -> bool:
	# Check player's own tile
	if _grid.has_structure(player_tile, &"workbench"):
		return true
	# Check 6 neighbors
	var neighbors: Array[Vector2i] = _grid.get_neighbors(player_tile)
	for neighbor: Vector2i in neighbors:
		if _grid.has_structure(neighbor, &"workbench"):
			return true
	return false


func _on_tile_entered(_coords: Vector2i) -> void:
	_check_workbench_proximity()


func _on_tile_exited(_coords: Vector2i) -> void:
	_check_workbench_proximity()


func _on_structure_placed(_coords: Vector2i, _structure_type: StringName) -> void:
	_check_workbench_proximity()


func _on_structure_destroyed(_coords: Vector2i, _structure_type: StringName) -> void:
	_check_workbench_proximity()


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var recipes: Array = []
	for r: StringName in _discovered_recipes:
		recipes.append(String(r))
	return {
		"discovered_recipes": recipes,
	}


func load_save_data(data: Dictionary) -> void:
	_discovered_recipes.clear()
	var recipes: Array = data.get("discovered_recipes", [])
	for r in recipes:
		_discovered_recipes.append(StringName(r))
