extends Node

## Crafting data layer — child of Player.
## Owns recipe config, discovery tracking, craft validation/execution,
## and workbench proximity detection.

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
## Uses preload because tests can be parsed before class_name registration completes.
const _PropDef = preload("res://scripts/data/prop_def.gd")

signal recipe_discovered(recipe_name: StringName)
signal craft_completed(recipe_name: StringName)
signal craft_failed(recipe_name: StringName, reason: StringName)
signal station_proximity_changed(near: bool)

## Recipes use numeric PropDef IDs for ingredients, discovery, and output.
## Recipe keys remain semantic for discoverability (e.g. "stone_axe").
## Ingredients reference resource PropDefs (00010 wood, 00013 stone, etc.),
## output_id references the produced tool's PropDef id (00201 axe, 00202 pickaxe).
const RECIPE_CONFIG: Dictionary = {
	&"stone_axe": {
		"ingredients": { &"00010": 2, &"00013": 1 },  # 2 wood + 1 stone
		"output_type": &"tool",
		"output_id": &"00201",  # axe prop
		"tool_slot": &"axe",
		"discovery_material": &"00013",  # stone
		"requires_station": &"",
		"pre_discovered": true,
	},
	&"stone_pickaxe": {
		"ingredients": { &"00010": 3, &"00013": 2 },  # 3 wood + 2 stone
		"output_type": &"tool",
		"output_id": &"00202",  # pickaxe prop
		"tool_slot": &"pickaxe",
		"discovery_material": &"00013",  # stone
		"requires_station": &"",
		"pre_discovered": true,
	},
}

var _discovered_recipes: Array[StringName] = []
var _near_station: bool = false

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

	# 1. Station proximity (only for recipes that require a crafting station)
	var required_station: StringName = recipe.get("requires_station", &"")
	if required_station != &"" and not _is_near_crafting_station(required_station):
		craft_failed.emit(recipe_name, &"no_station")
		return false

	# 2. Already owned (tools only)
	if recipe["output_type"] == &"tool":
		var slot: StringName = recipe["tool_slot"]
		if _inventory.get_tool(slot) == recipe["output_id"]:
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
		_inventory.set_tool(recipe["tool_slot"], recipe["output_id"])

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


# --- Crafting Station Proximity ---

func is_near_station() -> bool:
	return _near_station


func _check_station_proximity() -> void:
	if _player == null or _grid == null:
		return
	var was_near: bool = _near_station
	_near_station = _has_nearby_crafting_station(_player.current_tile)
	if _near_station != was_near:
		station_proximity_changed.emit(_near_station)


## Check if any prop with is_crafting_station=true is on or adjacent to the tile.
func _has_nearby_crafting_station(player_tile: Vector2i) -> bool:
	if _tile_has_crafting_station(player_tile):
		return true
	var neighbors: Array[Vector2i] = _grid.get_neighbors(player_tile)
	for neighbor: Vector2i in neighbors:
		if _tile_has_crafting_station(neighbor):
			return true
	return false


## Check if a specific station type is on or adjacent to the tile.
func _is_near_crafting_station(station_type: StringName) -> bool:
	if _player == null or _grid == null:
		return false
	if _grid.has_structure(_player.current_tile, station_type):
		return true
	var neighbors: Array[Vector2i] = _grid.get_neighbors(_player.current_tile)
	for neighbor: Vector2i in neighbors:
		if _grid.has_structure(neighbor, station_type):
			return true
	return false


## Check if any prop on this tile has is_crafting_station in its PropDef.
func _tile_has_crafting_station(coords: Vector2i) -> bool:
	var tile: Resource = _grid._tiles.get(coords, null)
	if tile == null:
		return false
	for prop in tile.props:
		if PropRegistry.has_def(prop.type):
			var def: _PropDef = PropRegistry.get_def(prop.type)
			if def.is_crafting_station:
				return true
	return false


func _on_tile_entered(_coords: Vector2i) -> void:
	_check_station_proximity()


func _on_tile_exited(_coords: Vector2i) -> void:
	_check_station_proximity()


func _on_structure_placed(_coords: Vector2i, _structure_type: StringName) -> void:
	_check_station_proximity()


func _on_structure_destroyed(_coords: Vector2i, _structure_type: StringName) -> void:
	_check_station_proximity()


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
