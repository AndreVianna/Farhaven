extends GdUnitTestSuite
class_name TestBuildPanel

## Unit tests for BuildPanel and BuildEntryUI (task-035).
## Tests panel open/close/toggle, build recipe rendering, affordability states,
## ingredient display, BUILD trigger, signal wiring, and refresh behavior.

const _BuildPanelScene = preload("res://scenes/ui/build_panel.tscn")
const _BuildEntryUI = preload("res://ui/build_entry_ui.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")

# Numeric PropDef ids used in build recipes
const ID_WOOD: StringName = &"00010"
const ID_STONE: StringName = &"00011"
const ID_FIBER: StringName = &"00012"

var _panel: PanelContainer = null
var _inv: RefCounted = null
var _registry: MockRecipeRegistry = null
var _building_system: MockBuildingSystem = null
var _panel_opened_count: int = 0


# --- Mock RecipeRegistry ---

class MockRecipeRegistry extends Node:
	var _recipes_by_action: Dictionary = {}

	func add_build_recipe(recipe: Resource) -> void:
		if not _recipes_by_action.has(&"build"):
			_recipes_by_action[&"build"] = []
		_recipes_by_action[&"build"].append(recipe)

	func find_recipes_for_action(action: StringName) -> Array:
		return _recipes_by_action.get(action, [])


# --- Mock BuildingSystem ---

class MockBuildingSystem extends Node:
	var last_placement_recipe = null
	var enter_placement_count: int = 0

	func enter_placement_mode(recipe) -> void:
		last_placement_recipe = recipe
		enter_placement_count += 1


# --- Helpers ---

func _make_recipe(id: StringName, display_name: String, inputs_data: Array, output_ref: StringName) -> Resource:
	var recipe := _Recipe.new()
	recipe.id = id
	recipe.display_name = display_name
	recipe.kind = _Recipe.Kind.ASSEMBLE
	recipe.actions = [&"build"]
	recipe.time = 2.0
	var inputs: Array[Resource] = []
	for data in inputs_data:
		var input := _RecipeInput.new()
		input.ref_or_tag = data["ref"]
		input.count = data["count"]
		input.source = &"player_inventory"
		inputs.append(input)
	recipe.inputs = inputs
	var output := _RecipeOutput.new()
	output.prop_ref = output_ref
	output.count = 1
	recipe.outputs = [output]
	return recipe


func _make_standard_recipes() -> void:
	# Campfire: wood 3, fiber 2
	_registry.add_build_recipe(_make_recipe(
		&"00019", "Build Campfire",
		[{"ref": ID_WOOD, "count": 3}, {"ref": ID_FIBER, "count": 2}],
		&"00101"
	))
	# Workbench: wood 5, stone 3
	_registry.add_build_recipe(_make_recipe(
		&"00021", "Build Workbench",
		[{"ref": ID_WOOD, "count": 5}, {"ref": ID_STONE, "count": 3}],
		&"00105"
	))
	# Storage Chest: wood 8, stone 4
	_registry.add_build_recipe(_make_recipe(
		&"00022", "Build Storage Chest",
		[{"ref": ID_WOOD, "count": 8}, {"ref": ID_STONE, "count": 4}],
		&"00104"
	))
	# Shelter: wood 10, stone 5, fiber 3
	_registry.add_build_recipe(_make_recipe(
		&"00023", "Build Shelter",
		[{"ref": ID_WOOD, "count": 10}, {"ref": ID_STONE, "count": 5}, {"ref": ID_FIBER, "count": 3}],
		&"00102"
	))
	# Wall: wood 3
	_registry.add_build_recipe(_make_recipe(
		&"00024", "Build Wall",
		[{"ref": ID_WOOD, "count": 3}],
		&"00106"
	))
	# Torch: wood 2, fiber 1
	_registry.add_build_recipe(_make_recipe(
		&"00025", "Build Torch",
		[{"ref": ID_WOOD, "count": 2}, {"ref": ID_FIBER, "count": 1}],
		&"00103"
	))


# --- Setup / Teardown ---

func before_test() -> void:
	_inv = _Inventory.new()
	_registry = MockRecipeRegistry.new()
	add_child(_registry)
	_building_system = MockBuildingSystem.new()
	add_child(_building_system)

	_panel = _BuildPanelScene.instantiate()
	add_child(_panel)
	_panel.set_recipe_registry(_registry)
	_panel.set_building_system(_building_system)
	_panel.set_inventory(_inv)
	_panel_opened_count = 0


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if is_instance_valid(_building_system):
		remove_child(_building_system)
		_building_system.queue_free()
	if is_instance_valid(_registry):
		remove_child(_registry)
		_registry.queue_free()
	_inv = null


# === PANEL OPEN / CLOSE / TOGGLE ===

func test_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


func test_panel_open_makes_visible() -> void:
	_make_standard_recipes()
	_panel.open()
	assert_bool(_panel.visible).is_true()


func test_panel_close_hides() -> void:
	_make_standard_recipes()
	_panel.open()
	_panel.close()
	assert_bool(_panel.visible).is_false()


func test_panel_toggle_opens_when_hidden() -> void:
	_make_standard_recipes()
	_panel.toggle()
	assert_bool(_panel.visible).is_true()


func test_panel_toggle_closes_when_visible() -> void:
	_make_standard_recipes()
	_panel.open()
	_panel.toggle()
	assert_bool(_panel.visible).is_false()


# === PANEL_OPENED SIGNAL ===

func test_open_emits_panel_opened() -> void:
	_make_standard_recipes()
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_open_twice_emits_once() -> void:
	_make_standard_recipes()
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_close_does_not_emit_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.close()
	assert_int(_panel_opened_count).is_equal(0)


# === BUILD RECIPE RENDERING ===

func test_six_build_recipes_displayed() -> void:
	_make_standard_recipes()
	_panel.open()
	assert_int(_panel._recipe_list.get_child_count()).is_equal(6)


func test_build_entries_are_build_entry_ui() -> void:
	_make_standard_recipes()
	_panel.open()
	for child in _panel._recipe_list.get_children():
		assert_bool(child is _BuildEntryUI).is_true()


func test_recipe_entry_shows_display_name() -> void:
	_make_standard_recipes()
	_panel.open()
	var found_names: Array[String] = []
	for child in _panel._recipe_list.get_children():
		found_names.append(child._name_label.text)
	assert_bool("Build Campfire" in found_names).is_true()
	assert_bool("Build Workbench" in found_names).is_true()
	assert_bool("Build Storage Chest" in found_names).is_true()
	assert_bool("Build Shelter" in found_names).is_true()
	assert_bool("Build Wall" in found_names).is_true()
	assert_bool("Build Torch" in found_names).is_true()


func test_no_recipes_when_registry_empty() -> void:
	# Don't add any recipes
	_panel.open()
	assert_int(_panel._recipe_list.get_child_count()).is_equal(0)


# === AFFORDABILITY STATES ===

func test_recipe_unaffordable_when_no_materials() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.UNAFFORDABLE)


func test_recipe_affordable_with_materials() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 3)  # Wall needs 3 wood
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.AFFORDABLE)


func test_recipe_unaffordable_with_partial_materials() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 2)  # Wall needs 3 wood
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.UNAFFORDABLE)


func test_recipe_affordable_multi_ingredient() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 5)
	_inv.add_item(ID_STONE, 3)
	_panel.open()
	var entry = _find_entry_by_name("Build Workbench")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.AFFORDABLE)


func test_recipe_unaffordable_missing_one_ingredient() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 5)
	# Missing stone
	_panel.open()
	var entry = _find_entry_by_name("Build Workbench")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.UNAFFORDABLE)


# === BUILD BUTTON STATE ===

func test_build_button_disabled_when_unaffordable() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_bool(entry._build_button.disabled).is_true()


func test_build_button_enabled_when_affordable() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 3)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_bool(entry._build_button.disabled).is_false()


func test_build_button_dimmed_when_unaffordable() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_float(entry._build_button.modulate.a).is_less(1.0)


func test_build_button_full_opacity_when_affordable() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 3)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_float(entry._build_button.modulate.a).is_equal(1.0)


# === INGREDIENT DISPLAY ===

func test_ingredient_labels_exist() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Workbench")
	# Workbench needs wood + stone = 2 ingredient labels
	assert_int(entry._ingredients_container.get_child_count()).is_equal(2)


func test_ingredient_labels_three_inputs() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Shelter")
	# Shelter needs wood + stone + fiber = 3 ingredient labels
	assert_int(entry._ingredients_container.get_child_count()).is_equal(3)


func test_ingredient_shows_owned_slash_needed() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 2)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	var found_label := false
	for child in entry._ingredients_container.get_children():
		if child is Label and "2/3" in child.text:
			found_label = true
	assert_bool(found_label).is_true()


func test_ingredient_green_when_enough() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 5)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	for child in entry._ingredients_container.get_children():
		if child is Label:
			var color: Color = child.get_theme_color("font_color")
			# Should be green (more G than R)
			assert_float(color.g).is_greater(color.r)
			return
	fail("Ingredient label not found")


func test_ingredient_red_when_short() -> void:
	_make_standard_recipes()
	# 0 wood, wall needs 3
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	for child in entry._ingredients_container.get_children():
		if child is Label:
			var color: Color = child.get_theme_color("font_color")
			# Should be red (more R than G)
			assert_float(color.r).is_greater(color.g)
			return
	fail("Ingredient label not found")


# === BUILD TRIGGER ===

func test_build_tap_calls_enter_placement_mode() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 3)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	entry._on_build_pressed()
	assert_int(_building_system.enter_placement_count).is_equal(1)
	assert_object(_building_system.last_placement_recipe).is_not_null()
	assert_str(_building_system.last_placement_recipe.display_name).is_equal("Build Wall")


func test_build_tap_closes_panel() -> void:
	_make_standard_recipes()
	_inv.add_item(ID_WOOD, 3)
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	entry._on_build_pressed()
	assert_bool(_panel.visible).is_false()


func test_build_tap_no_action_when_unaffordable() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	entry._on_build_pressed()
	assert_int(_building_system.enter_placement_count).is_equal(0)


# === REFRESH ON INVENTORY_CHANGED ===

func test_refresh_on_inventory_changed() -> void:
	_make_standard_recipes()
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.UNAFFORDABLE)
	# Add enough materials — inventory_changed fires automatically
	_inv.add_item(ID_WOOD, 3)
	# Panel should auto-refresh
	entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.AFFORDABLE)


func test_refresh_updates_ingredient_counts() -> void:
	_make_standard_recipes()
	_panel.open()
	# Initially 0 wood
	var entry = _find_entry_by_name("Build Wall")
	var found_zero := false
	for child in entry._ingredients_container.get_children():
		if child is Label and "0/3" in child.text:
			found_zero = true
	assert_bool(found_zero).is_true()
	# Add 2 wood — inventory_changed triggers refresh
	_inv.add_item(ID_WOOD, 2)
	entry = _find_entry_by_name("Build Wall")
	var found_two := false
	for child in entry._ingredients_container.get_children():
		if child is Label and "2/3" in child.text:
			found_two = true
	assert_bool(found_two).is_true()


func test_no_refresh_when_panel_closed() -> void:
	_make_standard_recipes()
	_panel.open()
	_panel.close()
	# Modify inventory while closed — should not error
	_inv.add_item(ID_WOOD, 3)
	# Re-open and verify it catches up
	_panel.open()
	var entry = _find_entry_by_name("Build Wall")
	assert_int(entry.get_state()).is_equal(_BuildEntryUI.State.AFFORDABLE)


# === BUILD ENTRY UI STANDALONE ===

func test_build_entry_minimum_height() -> void:
	var entry := _BuildEntryUI.new()
	add_child(entry)
	assert_float(entry.custom_minimum_size.y).is_greater_equal(100.0)
	entry.queue_free()


func test_build_entry_setup_sets_name() -> void:
	var recipe := _make_recipe(&"00024", "Build Wall", [{"ref": ID_WOOD, "count": 3}], &"00106")
	var entry := _BuildEntryUI.new()
	add_child(entry)
	entry.setup(recipe)
	assert_str(entry._name_label.text).is_equal("Build Wall")
	entry.queue_free()


func test_build_entry_get_recipe() -> void:
	var recipe := _make_recipe(&"00024", "Build Wall", [{"ref": ID_WOOD, "count": 3}], &"00106")
	var entry := _BuildEntryUI.new()
	add_child(entry)
	entry.setup(recipe)
	assert_object(entry.get_recipe()).is_same(recipe)
	entry.queue_free()


func test_build_entry_button_size() -> void:
	var entry := _BuildEntryUI.new()
	add_child(entry)
	assert_float(entry._build_button.custom_minimum_size.x).is_greater_equal(80.0)
	assert_float(entry._build_button.custom_minimum_size.y).is_greater_equal(48.0)
	entry.queue_free()


func test_build_entry_emits_build_requested() -> void:
	var recipe := _make_recipe(&"00024", "Build Wall", [{"ref": ID_WOOD, "count": 3}], &"00106")
	var entry := _BuildEntryUI.new()
	add_child(entry)
	entry.setup(recipe)
	_inv.add_item(ID_WOOD, 3)
	entry.refresh(_inv)
	var fired: Array = []
	entry.build_requested.connect(func(r): fired.append(r))
	entry._on_build_pressed()
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_same(recipe)
	entry.queue_free()


func test_build_entry_no_emit_when_unaffordable() -> void:
	var recipe := _make_recipe(&"00024", "Build Wall", [{"ref": ID_WOOD, "count": 3}], &"00106")
	var entry := _BuildEntryUI.new()
	add_child(entry)
	entry.setup(recipe)
	entry.refresh(_inv)
	var fired: Array = []
	entry.build_requested.connect(func(r): fired.append(r))
	entry._on_build_pressed()
	assert_int(fired.size()).is_equal(0)
	entry.queue_free()


# === HELPER ===

func _find_entry_by_name(display_name: String):
	for child in _panel._recipe_list.get_children():
		if child is _BuildEntryUI and child._name_label.text == display_name:
			return child
	return null
