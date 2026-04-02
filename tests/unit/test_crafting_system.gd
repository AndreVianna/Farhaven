extends GdUnitTestSuite
class_name TestCraftingSystem

const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")

var _sys: Node
var _inv: RefCounted
var _grid: Node


# --- Mock HexGrid ---

class MockHexGrid extends Node:
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	var _tiles: Dictionary = {}

	func set_tile(coords: Vector2i, tile: Resource) -> void:
		_tiles[coords] = tile

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var dirs: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
		]
		var result: Array[Vector2i] = []
		for d: Vector2i in dirs:
			var n: Vector2i = coords + d
			if _tiles.has(n):
				result.append(n)
		return result


# --- Mock Player ---

class MockPlayer extends Node:
	var current_tile: Vector2i = Vector2i.ZERO
	var inventory: RefCounted

	func _init(inv: RefCounted) -> void:
		inventory = inv

	func get_inventory() -> RefCounted:
		return inventory


# --- Setup / Teardown ---

func before_test() -> void:
	_inv = _Inventory.new()
	_grid = MockHexGrid.new()
	add_child(_grid)

	var player: MockPlayer = MockPlayer.new(_inv)
	add_child(player)

	_sys = _CraftingSystem.new()
	_sys._grid = _grid
	player.add_child(_sys)


func after_test() -> void:
	# _sys is child of player, which is child of this suite
	var player: Node = _sys.get_parent()
	player.remove_child(_sys)
	_sys.queue_free()
	remove_child(player)
	player.queue_free()
	remove_child(_grid)
	_grid.queue_free()
	_inv = null


# --- Helpers ---

func _place_workbench(coords: Vector2i) -> void:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	tile.structure = &"workbench"
	_grid.set_tile(coords, tile)


func _place_empty_tile(coords: Vector2i) -> void:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	tile.structure = &""
	_grid.set_tile(coords, tile)


func _set_player_tile(coords: Vector2i) -> void:
	var player: Node = _sys.get_parent()
	player.current_tile = coords


func _give_materials_for_axe() -> void:
	_inv.add_item(&"wood", 2)
	_inv.add_item(&"stone", 1)


func _give_materials_for_pickaxe() -> void:
	_inv.add_item(&"wood", 3)
	_inv.add_item(&"stone", 2)


# === RECIPE CONFIG ===

func test_recipe_config_has_stone_axe() -> void:
	assert_bool(_CraftingSystem.RECIPE_CONFIG.has(&"stone_axe")).is_true()


func test_recipe_config_has_stone_pickaxe() -> void:
	assert_bool(_CraftingSystem.RECIPE_CONFIG.has(&"stone_pickaxe")).is_true()


func test_stone_axe_ingredients() -> void:
	var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[&"stone_axe"]
	var ingredients: Dictionary = recipe["ingredients"]
	assert_int(ingredients[&"wood"]).is_equal(2)
	assert_int(ingredients[&"stone"]).is_equal(1)


func test_stone_pickaxe_ingredients() -> void:
	var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[&"stone_pickaxe"]
	var ingredients: Dictionary = recipe["ingredients"]
	assert_int(ingredients[&"wood"]).is_equal(3)
	assert_int(ingredients[&"stone"]).is_equal(2)


func test_stone_axe_tool_slot() -> void:
	var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[&"stone_axe"]
	assert_object(recipe["tool_slot"]).is_equal(&"axe")


func test_stone_pickaxe_tool_slot() -> void:
	var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[&"stone_pickaxe"]
	assert_object(recipe["tool_slot"]).is_equal(&"pickaxe")


func test_both_recipes_discovery_material_stone() -> void:
	for name: StringName in [&"stone_axe", &"stone_pickaxe"]:
		var recipe: Dictionary = _CraftingSystem.RECIPE_CONFIG[name]
		assert_object(recipe["discovery_material"]).is_equal(&"stone")


# === DISCOVERY ===

func test_no_recipes_discovered_initially() -> void:
	assert_int(_sys.get_discovered_recipes().size()).is_equal(0)


func test_adding_stone_discovers_both_recipes() -> void:
	_inv.add_item(&"stone", 1)
	var discovered: Array[StringName] = _sys.get_discovered_recipes()
	assert_int(discovered.size()).is_equal(2)
	assert_bool(&"stone_axe" in discovered).is_true()
	assert_bool(&"stone_pickaxe" in discovered).is_true()


func test_adding_wood_discovers_nothing() -> void:
	_inv.add_item(&"wood", 5)
	assert_int(_sys.get_discovered_recipes().size()).is_equal(0)


func test_adding_stone_twice_does_not_duplicate() -> void:
	_inv.add_item(&"stone", 1)
	_inv.add_item(&"stone", 1)
	assert_int(_sys.get_discovered_recipes().size()).is_equal(2)


func test_discovery_emits_signal() -> void:
	var fired: Array = []
	_sys.recipe_discovered.connect(func(name: StringName) -> void:
		fired.append(name)
	)
	_inv.add_item(&"stone", 1)
	assert_int(fired.size()).is_equal(2)
	assert_bool(&"stone_axe" in fired).is_true()
	assert_bool(&"stone_pickaxe" in fired).is_true()


func test_is_recipe_discovered() -> void:
	assert_bool(_sys.is_recipe_discovered(&"stone_axe")).is_false()
	_inv.add_item(&"stone", 1)
	assert_bool(_sys.is_recipe_discovered(&"stone_axe")).is_true()


# === CRAFT — WORKBENCH CHECK ===

func test_craft_fails_without_workbench() -> void:
	_inv.add_item(&"stone", 1)  # discover
	_give_materials_for_axe()
	var result: bool = _sys.craft(&"stone_axe")
	assert_bool(result).is_false()


func test_craft_fail_no_workbench_emits_reason() -> void:
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	var fired: Array = []
	_sys.craft_failed.connect(func(name: StringName, reason: StringName) -> void:
		fired.append({"name": name, "reason": reason})
	)
	_sys.craft(&"stone_axe")
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["reason"]).is_equal(&"no_workbench")


func test_craft_fail_no_workbench_does_not_consume() -> void:
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	_sys.craft(&"stone_axe")
	assert_int(_inv.get_count(&"wood")).is_equal(2)
	assert_int(_inv.get_count(&"stone")).is_equal(2)  # 1 from discover + 1 from helper


# === CRAFT — ALREADY OWNED ===

func test_craft_fails_already_owned() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	_inv.set_tool(&"axe", &"stone_axe")
	var result: bool = _sys.craft(&"stone_axe")
	assert_bool(result).is_false()


func test_craft_already_owned_emits_reason() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	_inv.set_tool(&"axe", &"stone_axe")
	var fired: Array = []
	_sys.craft_failed.connect(func(name: StringName, reason: StringName) -> void:
		fired.append(reason)
	)
	_sys.craft(&"stone_axe")
	assert_object(fired[0]).is_equal(&"already_owned")


func test_craft_already_owned_does_not_consume() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	_inv.set_tool(&"axe", &"stone_axe")
	_sys.craft(&"stone_axe")
	assert_int(_inv.get_count(&"wood")).is_equal(2)


# === CRAFT — INSUFFICIENT MATERIALS ===

func test_craft_fails_insufficient_materials() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)  # discover + 1 stone, but need wood too
	var result: bool = _sys.craft(&"stone_axe")
	assert_bool(result).is_false()


func test_craft_insufficient_emits_reason() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	var fired: Array = []
	_sys.craft_failed.connect(func(name: StringName, reason: StringName) -> void:
		fired.append(reason)
	)
	_sys.craft(&"stone_axe")
	assert_object(fired[0]).is_equal(&"insufficient_materials")


# === CRAFT — SUCCESS ===

func test_craft_stone_axe_succeeds() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)  # discover
	_give_materials_for_axe()
	var result: bool = _sys.craft(&"stone_axe")
	assert_bool(result).is_true()


func test_craft_consumes_ingredients() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)  # triggers discovery (1 stone now)
	_give_materials_for_axe()   # adds 2 wood + 1 stone (total: 2 wood, 2 stone)
	_sys.craft(&"stone_axe")    # consumes 2 wood + 1 stone
	assert_int(_inv.get_count(&"wood")).is_equal(0)
	assert_int(_inv.get_count(&"stone")).is_equal(1)  # 2 - 1 = 1 remaining


func test_craft_sets_tool() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	_sys.craft(&"stone_axe")
	assert_object(_inv.get_tool(&"axe")).is_equal(&"stone_axe")


func test_craft_emits_completed() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 1)
	_give_materials_for_axe()
	var fired: Array = []
	_sys.craft_completed.connect(func(name: StringName) -> void:
		fired.append(name)
	)
	_sys.craft(&"stone_axe")
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_equal(&"stone_axe")


func test_craft_stone_pickaxe_succeeds() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	_inv.add_item(&"stone", 2)  # discover + ingredients
	_inv.add_item(&"wood", 3)
	_sys.craft(&"stone_pickaxe")
	assert_object(_inv.get_tool(&"pickaxe")).is_equal(&"stone_pickaxe")
	assert_int(_inv.get_count(&"wood")).is_equal(0)
	assert_int(_inv.get_count(&"stone")).is_equal(0)


func test_craft_unknown_recipe_fails() -> void:
	var fired: Array = []
	_sys.craft_failed.connect(func(name: StringName, reason: StringName) -> void:
		fired.append(reason)
	)
	_sys.craft(&"nonexistent")
	assert_object(fired[0]).is_equal(&"unknown_recipe")


# === WORKBENCH PROXIMITY ===

func test_not_near_workbench_initially() -> void:
	assert_bool(_sys.is_near_workbench()).is_false()


func test_near_workbench_on_neighbor() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	assert_bool(_sys.is_near_workbench()).is_true()


func test_near_workbench_on_player_tile() -> void:
	_place_workbench(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	assert_bool(_sys.is_near_workbench()).is_true()


func test_not_near_workbench_when_far() -> void:
	_place_workbench(Vector2i(3, 3))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	assert_bool(_sys.is_near_workbench()).is_false()


func test_proximity_changed_signal_fires() -> void:
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()  # ensure starts false
	var fired: Array = []
	_sys.workbench_proximity_changed.connect(func(near: bool) -> void:
		fired.append(near)
	)
	_place_workbench(Vector2i(1, 0))
	_sys._check_workbench_proximity()
	assert_int(fired.size()).is_equal(1)
	assert_bool(fired[0]).is_true()


func test_proximity_changed_fires_false_on_leave() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_place_empty_tile(Vector2i(5, 5))
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()  # near = true
	var fired: Array = []
	_sys.workbench_proximity_changed.connect(func(near: bool) -> void:
		fired.append(near)
	)
	_set_player_tile(Vector2i(5, 5))
	_sys._check_workbench_proximity()
	assert_int(fired.size()).is_equal(1)
	assert_bool(fired[0]).is_false()


func test_proximity_does_not_fire_when_unchanged() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()  # near = true
	var fired: Array = []
	_sys.workbench_proximity_changed.connect(func(near: bool) -> void:
		fired.append(near)
	)
	_sys._check_workbench_proximity()  # still near = true
	assert_int(fired.size()).is_equal(0)


func test_tile_entered_triggers_proximity_check() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_grid.tile_entered.emit(Vector2i.ZERO)
	assert_bool(_sys.is_near_workbench()).is_true()


func test_structure_placed_triggers_proximity_check() -> void:
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	assert_bool(_sys.is_near_workbench()).is_false()
	_place_workbench(Vector2i(1, 0))
	_grid.structure_placed.emit(Vector2i(1, 0), &"workbench")
	assert_bool(_sys.is_near_workbench()).is_true()


func test_structure_destroyed_triggers_proximity_check() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()
	assert_bool(_sys.is_near_workbench()).is_true()
	# Remove the workbench
	var tile: Resource = _grid.get_tile(Vector2i(1, 0))
	tile.structure = &""
	_grid.structure_destroyed.emit(Vector2i(1, 0), &"workbench")
	assert_bool(_sys.is_near_workbench()).is_false()


# === SAVE / LOAD ===

func test_save_empty() -> void:
	var data: Dictionary = _sys.get_save_data()
	assert_int(data["discovered_recipes"].size()).is_equal(0)


func test_save_after_discovery() -> void:
	_inv.add_item(&"stone", 1)
	var data: Dictionary = _sys.get_save_data()
	assert_int(data["discovered_recipes"].size()).is_equal(2)
	assert_bool("stone_axe" in data["discovered_recipes"]).is_true()
	assert_bool("stone_pickaxe" in data["discovered_recipes"]).is_true()


func test_load_restores_discovered() -> void:
	var data: Dictionary = {
		"discovered_recipes": ["stone_axe"],
	}
	_sys.load_save_data(data)
	assert_bool(_sys.is_recipe_discovered(&"stone_axe")).is_true()
	assert_bool(_sys.is_recipe_discovered(&"stone_pickaxe")).is_false()


func test_load_clears_previous() -> void:
	_inv.add_item(&"stone", 1)  # discover both
	assert_int(_sys.get_discovered_recipes().size()).is_equal(2)
	_sys.load_save_data({"discovered_recipes": ["stone_axe"]})
	assert_int(_sys.get_discovered_recipes().size()).is_equal(1)


func test_save_load_roundtrip() -> void:
	_inv.add_item(&"stone", 1)
	var saved: Dictionary = _sys.get_save_data()
	_sys.load_save_data({"discovered_recipes": []})
	assert_int(_sys.get_discovered_recipes().size()).is_equal(0)
	_sys.load_save_data(saved)
	assert_int(_sys.get_discovered_recipes().size()).is_equal(2)
