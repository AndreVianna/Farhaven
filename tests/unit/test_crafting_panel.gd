extends GdUnitTestSuite
class_name TestCraftingPanel

## Unit tests for CraftingPanel and RecipeEntryUI (task-021).
## Tests panel open/close/toggle, recipe rendering, 3 states,
## ingredient display, craft trigger, signal wiring, and refresh behavior.

const _CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")
const _RecipeEntryUI = preload("res://ui/recipe_entry_ui.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

var _panel: PanelContainer = null
var _inv: RefCounted = null
var _sys: Node = null
var _grid: Node = null
var _panel_opened_count: int = 0


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


# --- Helpers ---

func _place_workbench(coords: Vector2i) -> void:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	var wb: Prop = _Prop.new()
	wb.type = &"workbench"
	wb.category = Prop.Category.STRUCTURE
	wb.sub_hex = Vector2i.ZERO
	wb.blocks_movement = false
	tile.props = [wb]
	_grid.set_tile(coords, tile)


func _place_empty_tile(coords: Vector2i) -> void:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	_grid.set_tile(coords, tile)


func _set_player_tile(coords: Vector2i) -> void:
	var player: Node = _sys.get_parent()
	player.current_tile = coords


func _make_near_workbench() -> void:
	_place_workbench(Vector2i(1, 0))
	_place_empty_tile(Vector2i.ZERO)
	_set_player_tile(Vector2i.ZERO)
	_sys._check_workbench_proximity()


func _discover_recipes() -> void:
	_inv.add_item(&"stone", 1)


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

	_panel = _CraftingPanelScene.instantiate()
	add_child(_panel)
	_panel.set_crafting_system(_sys)
	_panel.set_inventory(_inv)
	_panel_opened_count = 0


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null

	var player: Node = _sys.get_parent()
	player.remove_child(_sys)
	_sys.queue_free()
	remove_child(player)
	player.queue_free()
	remove_child(_grid)
	_grid.queue_free()
	_inv = null


# === PANEL OPEN / CLOSE / TOGGLE ===

func test_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


func test_panel_open_makes_visible() -> void:
	_panel.open()
	assert_bool(_panel.visible).is_true()


func test_panel_close_hides() -> void:
	_panel.open()
	_panel.close()
	assert_bool(_panel.visible).is_false()


func test_panel_toggle_opens_when_hidden() -> void:
	_panel.toggle()
	assert_bool(_panel.visible).is_true()


func test_panel_toggle_closes_when_visible() -> void:
	_panel.open()
	_panel.toggle()
	assert_bool(_panel.visible).is_false()


# === PANEL_OPENED SIGNAL ===

func test_open_emits_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_open_twice_emits_once() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_close_does_not_emit_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.close()
	assert_int(_panel_opened_count).is_equal(0)


# === RECIPE RENDERING ===

func test_pre_discovered_recipes_shown_on_open() -> void:
	_panel.open()
	assert_int(_panel._recipe_list.get_child_count()).is_equal(2)


func test_discovered_recipes_appear_on_open() -> void:
	_discover_recipes()
	_panel.open()
	assert_int(_panel._recipe_list.get_child_count()).is_equal(2)


func test_recipe_entries_are_recipe_entry_ui() -> void:
	_discover_recipes()
	_panel.open()
	for child in _panel._recipe_list.get_children():
		assert_bool(child is _RecipeEntryUI).is_true()


func test_recipe_entry_shows_recipe_name() -> void:
	_discover_recipes()
	_panel.open()
	var found_names: Array[String] = []
	for child in _panel._recipe_list.get_children():
		found_names.append(child._name_label.text)
	assert_bool("Stone Axe" in found_names).is_true()
	assert_bool("Stone Pickaxe" in found_names).is_true()


# === RECIPE ENTRY STATES ===

func test_recipe_unaffordable_when_no_materials() -> void:
	_discover_recipes()
	_panel.open()
	# stone was added for discovery but not enough for axe (need 2 wood + 1 stone)
	var entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.UNAFFORDABLE)


func test_recipe_affordable_with_materials() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 2)  # now have 2 wood + 1 stone (discovery)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.AFFORDABLE)


func test_recipe_already_owned() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 2)
	_inv.set_tool(&"axe", &"stone_axe")
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.ALREADY_OWNED)


# === CRAFT BUTTON STATE ===

func test_craft_button_disabled_when_unaffordable() -> void:
	_discover_recipes()
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_bool(entry._craft_button.disabled).is_true()


func test_craft_button_enabled_when_affordable() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 2)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_bool(entry._craft_button.disabled).is_false()


func test_craft_button_shows_owned_text() -> void:
	_discover_recipes()
	_inv.set_tool(&"axe", &"stone_axe")
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_str(entry._craft_button.text).is_equal("OWNED")


func test_craft_button_shows_craft_text_when_affordable() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 2)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_str(entry._craft_button.text).is_equal("CRAFT")


# === INGREDIENT DISPLAY ===

func test_ingredient_labels_exist() -> void:
	_discover_recipes()
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	# stone_axe needs wood + stone = 2 ingredient labels
	assert_int(entry._ingredients_container.get_child_count()).is_equal(2)


func test_ingredient_shows_owned_slash_needed() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 1)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	var found_wood := false
	for child in entry._ingredients_container.get_children():
		if child is Label and "Wood" in child.text:
			assert_bool("1/2" in child.text).is_true()
			found_wood = true
	assert_bool(found_wood).is_true()


func test_ingredient_green_when_enough() -> void:
	_discover_recipes()
	_inv.add_item(&"wood", 5)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	for child in entry._ingredients_container.get_children():
		if child is Label and "Wood" in child.text:
			var color: Color = child.get_theme_color("font_color")
			assert_float(color.g).is_greater(color.r)
			return
	fail("Wood label not found")


func test_ingredient_red_when_short() -> void:
	_discover_recipes()
	# 0 wood, need 2
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	for child in entry._ingredients_container.get_children():
		if child is Label and "Wood" in child.text:
			var color: Color = child.get_theme_color("font_color")
			assert_float(color.r).is_greater(color.g)
			return
	fail("Wood label not found")


# === CRAFT TRIGGER ===

func test_craft_requested_triggers_crafting_system() -> void:
	_make_near_workbench()
	_discover_recipes()
	_inv.add_item(&"wood", 2)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	entry.craft_requested.emit(&"stone_axe")
	assert_object(_inv.get_tool(&"axe")).is_equal(&"stone_axe")


# === REFRESH ON SIGNALS ===

func test_refresh_on_inventory_changed() -> void:
	_discover_recipes()
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.UNAFFORDABLE)
	# Add enough materials
	_inv.add_item(&"wood", 2)
	# inventory_changed should have triggered refresh
	entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.AFFORDABLE)


func test_refresh_on_craft_completed() -> void:
	_make_near_workbench()
	_discover_recipes()
	_inv.add_item(&"wood", 2)
	_panel.open()
	var entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.AFFORDABLE)
	# Craft it
	_sys.craft(&"stone_axe")
	# Panel should refresh — now owned
	entry = _find_entry(&"stone_axe")
	assert_int(entry.get_state()).is_equal(_RecipeEntryUI.State.ALREADY_OWNED)


func test_pre_discovered_recipes_visible_on_open() -> void:
	_panel.open()
	assert_int(_panel._recipe_list.get_child_count()).is_equal(2)


# === RECIPE ENTRY UI STANDALONE ===

func test_recipe_entry_minimum_height() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	assert_float(entry.custom_minimum_size.y).is_greater_equal(100.0)
	entry.queue_free()


func test_recipe_entry_setup_sets_name() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	entry.setup(&"stone_axe")
	assert_str(entry._name_label.text).is_equal("Stone Axe")
	entry.queue_free()


func test_recipe_entry_get_recipe_name() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	entry.setup(&"stone_pickaxe")
	assert_object(entry.get_recipe_name()).is_equal(&"stone_pickaxe")
	entry.queue_free()


func test_recipe_entry_craft_button_size() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	assert_float(entry._craft_button.custom_minimum_size.x).is_greater_equal(80.0)
	assert_float(entry._craft_button.custom_minimum_size.y).is_greater_equal(48.0)
	entry.queue_free()


func test_recipe_entry_emits_craft_requested() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	entry.setup(&"stone_axe")
	entry.refresh(_inv, _sys)
	_inv.add_item(&"wood", 2)
	_inv.add_item(&"stone", 1)
	entry.refresh(_inv, _sys)
	var fired: Array = []
	entry.craft_requested.connect(func(name: StringName): fired.append(name))
	entry._on_craft_pressed()
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_equal(&"stone_axe")
	entry.queue_free()


func test_recipe_entry_no_emit_when_unaffordable() -> void:
	var entry := _RecipeEntryUI.new()
	add_child(entry)
	entry.setup(&"stone_axe")
	entry.refresh(_inv, _sys)
	var fired: Array = []
	entry.craft_requested.connect(func(name: StringName): fired.append(name))
	entry._on_craft_pressed()
	assert_int(fired.size()).is_equal(0)
	entry.queue_free()


# === HELPER ===

func _find_entry(recipe_name: StringName) :
	for child in _panel._recipe_list.get_children():
		if child is _RecipeEntryUI and child.get_recipe_name() == recipe_name:
			return child
	return null
