class_name TestRecipeRegistry
extends GdUnitTestSuite

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _RecipeRegistry = preload("res://scripts/recipes/recipe_registry.gd")


# --- Helper: build a registry and scan recipes ---

var _registry: Node


func before_test() -> void:
	_registry = _RecipeRegistry.new()
	_registry._scan_recipes()


func after_test() -> void:
	_registry.free()


# --- All 8 canonical recipes load ---

func test_all_canonical_recipes_load() -> void:
	var expected_ids: Array[StringName] = [
		&"R00001",  # eat_berry
		&"R00002",  # eat_toxic_berry
		&"R00003",  # chop_small_tree
		&"R00004",  # gather_loose_rocks
		&"R00005",  # gather_tall_grass
		&"R00006",  # gather_berry_bush
		&"R00007",  # gather_boulder
		&"R00008",  # gather_iron_deposit
		&"R00009",  # gather_crystal_cluster
		&"R00010",  # gather_toxic_bush
		&"R00011",  # cook_meat
		&"R00012",  # craft_trap
		&"R00013",  # trap_fires
		&"R00014",  # meat_rots
		&"R00015",  # burn_log_in_fireplace
		&"R00016",  # craft_stone_axe
		&"R00017",  # craft_stone_pickaxe
		&"R00018",  # gather_tree
	]
	for id in expected_ids:
		var recipe = _registry.get_recipe(id)
		assert_that(recipe).is_not_null()


func test_get_all_recipes_returns_twenty_six() -> void:
	var all: Array = _registry.get_all_recipes()
	assert_int(all.size()).is_equal(26)


# --- get_recipe returns correct fields ---

func test_eat_berry_fields() -> void:
	var r = _registry.get_recipe(&"R00001")
	assert_that(r).is_not_null()
	assert_str(r.display_name).is_equal("Eat Berry")
	assert_int(r.inputs.size()).is_equal(1)
	assert_str(r.inputs[0].ref).is_equal("P00020")
	assert_int(r.inputs[0].count).is_equal(1)
	assert_bool(r.inputs[0].is_tag()).is_false()
	assert_bool(r.inputs[0].must_hold).is_true()
	assert_int(r.outputs.size()).is_equal(0)
	assert_int(r.effects.size()).is_equal(2)
	assert_str(String(r.effects[0].kind)).is_equal("stat_delta")
	assert_str(String(r.effects[1].kind)).is_equal("sound")
	assert_int(r.actions.size()).is_equal(1)
	assert_str(String(r.actions[0])).is_equal("eat")
	assert_float(r.duration).is_equal(0.0)


func test_chop_small_tree_fields() -> void:
	var r = _registry.get_recipe(&"R00003")
	assert_that(r).is_not_null()
	assert_int(r.inputs.size()).is_equal(1)
	assert_str(r.inputs[0].ref).is_equal("P00001")
	assert_bool(r.inputs[0].must_hold).is_false()
	assert_int(r.outputs.size()).is_equal(2)
	assert_float(r.outputs[0].prob).is_equal(1.0)
	assert_float(r.outputs[1].prob).is_equal_approx(0.8, 0.0001)
	assert_int(r.conditions.size()).is_equal(1)
	assert_bool(r.conditions[0].must_sustain).is_true()
	assert_float(r.duration).is_equal(4.0)


func test_cook_meat_fields() -> void:
	var r = _registry.get_recipe(&"R00011")
	assert_that(r).is_not_null()
	assert_int(r.conditions.size()).is_equal(2)
	assert_bool(r.conditions[0].must_sustain).is_true()
	assert_bool(r.conditions[1].must_sustain).is_true()
	assert_float(r.duration).is_equal(15.0)


func test_craft_trap_fields() -> void:
	var r = _registry.get_recipe(&"R00012")
	assert_that(r).is_not_null()
	assert_int(r.inputs.size()).is_equal(2)
	assert_int(r.outputs.size()).is_equal(1)
	assert_int(r.conditions.size()).is_equal(0)
	assert_float(r.duration).is_equal(3.0)


func test_trap_fires_is_passive() -> void:
	var r = _registry.get_recipe(&"R00013")
	assert_that(r).is_not_null()
	assert_int(r.actions.size()).is_equal(0)
	assert_int(r.conditions.size()).is_equal(1)
	assert_bool(r.conditions[0].must_sustain).is_false()
	assert_float(r.duration).is_equal(0.0)


func test_meat_rots_is_passive_time_only() -> void:
	var r = _registry.get_recipe(&"R00014")
	assert_that(r).is_not_null()
	assert_int(r.actions.size()).is_equal(0)
	assert_int(r.conditions.size()).is_equal(0)
	assert_float(r.duration).is_equal(86400.0)


func test_burn_log_uses_tag_input() -> void:
	var r = _registry.get_recipe(&"R00015")
	assert_that(r).is_not_null()
	assert_int(r.inputs.size()).is_equal(1)
	assert_bool(r.inputs[0].is_tag()).is_true()
	assert_str(r.inputs[0].ref).is_equal("&BURNABLE.log")
	assert_str(String(r.inputs[0].get_tag())).is_equal("BURNABLE.log")
	assert_bool(r.inputs[0].must_hold).is_false()


func test_eat_toxic_berry_negative_health() -> void:
	var r = _registry.get_recipe(&"R00002")
	assert_that(r).is_not_null()
	assert_int(r.effects.size()).is_equal(2)
	# Find the health effect
	var health_effect = null
	for e in r.effects:
		if e.params.get("stat", "") == "health":
			health_effect = e
	assert_that(health_effect).is_not_null()
	assert_int(health_effect.params["value"]).is_equal(-25)


# --- Index queries ---

func test_find_recipes_for_input_berry() -> void:
	var results: Array = _registry.find_recipes_for_input(&"P00020")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00001")


func test_find_recipes_for_input_toxic_berry() -> void:
	var results: Array = _registry.find_recipes_for_input(&"P00021")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00002")


func test_find_recipes_for_input_small_tree() -> void:
	var results: Array = _registry.find_recipes_for_input(&"P00001")
	assert_int(results.size()).is_equal(2)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("R00003")).is_true()  # chop_small_tree
	assert_bool(ids.has("R00018")).is_true()  # gather_tree


func test_find_recipes_for_input_raw_meat() -> void:
	var results: Array = _registry.find_recipes_for_input(&"P00022")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00011")


func test_find_recipes_for_tag_burnable_log() -> void:
	var results: Array = _registry.find_recipes_for_tag(&"BURNABLE.log")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00015")


func test_find_recipes_for_action_eat() -> void:
	var results: Array = _registry.find_recipes_for_action(&"eat")
	assert_int(results.size()).is_equal(2)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("R00001")).is_true()  # eat_berry
	assert_bool(ids.has("R00002")).is_true()  # eat_toxic_berry


func test_find_recipes_for_action_chop() -> void:
	var results: Array = _registry.find_recipes_for_action(&"chop")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00003")


func test_find_recipes_for_action_assemble() -> void:
	var results: Array = _registry.find_recipes_for_action(&"assemble")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00012")


func test_find_recipes_for_station_cook() -> void:
	var results: Array = _registry.find_recipes_for_station(&"cook")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00011")


func test_find_recipes_for_station_fire() -> void:
	var results: Array = _registry.find_recipes_for_station(&"fire")
	assert_int(results.size()).is_equal(1)
	assert_str(String(results[0].id)).is_equal("R00015")


func test_find_recipes_for_action_gather() -> void:
	var results: Array = _registry.find_recipes_for_action(&"gather")
	assert_int(results.size()).is_equal(8)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("R00018")).is_true()  # gather_tree
	assert_bool(ids.has("R00006")).is_true()  # gather_berry_bush
	assert_bool(ids.has("R00007")).is_true()  # gather_boulder


func test_find_recipes_for_nonexistent_input_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_input(&"P99999")
	assert_int(results.size()).is_equal(0)


func test_find_recipes_for_nonexistent_action_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_action(&"fly")
	assert_int(results.size()).is_equal(0)


func test_find_recipes_for_nonexistent_station_returns_empty() -> void:
	var results: Array = _registry.find_recipes_for_station(&"smelter")
	assert_int(results.size()).is_equal(0)


func test_get_recipe_nonexistent_returns_null() -> void:
	var r = _registry.get_recipe(&"nonexistent_recipe")
	assert_that(r).is_null()


# --- New craft recipes ---

func test_craft_stone_axe_fields() -> void:
	var r = _registry.get_recipe(&"R00016")
	assert_that(r).is_not_null()
	assert_str(r.display_name).is_equal("Craft Stone Axe")
	assert_int(r.inputs.size()).is_equal(2)
	assert_str(r.inputs[0].ref).is_equal("P00010")  # wood
	assert_int(r.inputs[0].count).is_equal(2)
	assert_bool(r.inputs[0].must_hold).is_true()
	assert_str(r.inputs[1].ref).is_equal("P00011")  # rock
	assert_int(r.inputs[1].count).is_equal(1)
	assert_bool(r.inputs[1].must_hold).is_true()
	assert_int(r.outputs.size()).is_equal(1)
	assert_str(String(r.outputs[0].prop_ref)).is_equal("P00201")  # axe
	assert_int(r.effects.size()).is_equal(1)
	assert_str(String(r.effects[0].kind)).is_equal("sound")
	assert_int(r.actions.size()).is_equal(1)
	assert_str(String(r.actions[0])).is_equal("craft")
	assert_float(r.duration).is_equal(3.0)


func test_craft_stone_pickaxe_fields() -> void:
	var r = _registry.get_recipe(&"R00017")
	assert_that(r).is_not_null()
	assert_str(r.display_name).is_equal("Craft Stone Pickaxe")
	assert_int(r.inputs.size()).is_equal(2)
	assert_str(r.inputs[0].ref).is_equal("P00010")  # wood
	assert_int(r.inputs[0].count).is_equal(3)
	assert_bool(r.inputs[0].must_hold).is_true()
	assert_str(r.inputs[1].ref).is_equal("P00011")  # rock
	assert_int(r.inputs[1].count).is_equal(2)
	assert_bool(r.inputs[1].must_hold).is_true()
	assert_int(r.outputs.size()).is_equal(1)
	assert_str(String(r.outputs[0].prop_ref)).is_equal("P00202")  # pickaxe
	assert_int(r.effects.size()).is_equal(1)
	assert_int(r.actions.size()).is_equal(1)
	assert_str(String(r.actions[0])).is_equal("craft")
	assert_float(r.duration).is_equal(3.0)


func test_find_recipes_for_action_craft() -> void:
	var results: Array = _registry.find_recipes_for_action(&"craft")
	assert_int(results.size()).is_equal(2)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("R00016")).is_true()  # craft_stone_axe
	assert_bool(ids.has("R00017")).is_true()  # craft_stone_pickaxe


func test_find_recipes_for_action_build() -> void:
	var results: Array = _registry.find_recipes_for_action(&"build")
	assert_int(results.size()).is_equal(6)
	var ids: Array[String] = []
	for r in results:
		ids.append(String(r.id))
	assert_bool(ids.has("R00019")).is_true()  # build_campfire
	assert_bool(ids.has("R00021")).is_true()  # build_workbench
	assert_bool(ids.has("R00022")).is_true()  # build_storage_chest
	assert_bool(ids.has("R00023")).is_true()  # build_shelter
	assert_bool(ids.has("R00024")).is_true()  # build_wall
	assert_bool(ids.has("R00025")).is_true()  # build_torch


func test_display_name_populated_for_all_recipes() -> void:
	var all: Array = _registry.get_all_recipes()
	for recipe in all:
		assert_str(recipe.display_name).is_not_empty()


# --- Starting loadout ---

func test_starting_loadout_field_exists_on_hex_grid() -> void:
	# HexGrid should expose a starting_loadout Dictionary (set by map_loader).
	assert_that(HexGrid.starting_loadout).is_not_null()
	assert_bool(HexGrid.starting_loadout is Dictionary).is_true()
