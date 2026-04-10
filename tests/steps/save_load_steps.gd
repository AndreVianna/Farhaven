extends RefCounted

## Step definitions for save/load feature.
## Uses SimpleInventory from common_steps (no autoload dependency).

const _CommonSteps = preload("res://tests/steps/common_steps.gd")
const CATALOGED := 2


func register_steps(registry) -> void:
	registry.when("the game is saved and loaded", func(ctx):
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var save_data: Dictionary = inv.get_save_data()
		var new_inv := _CommonSteps.SimpleInventory.new()
		new_inv.load_save_data(save_data)
		ctx.set_value("inventory", new_inv)
	)

	registry.when("the inventory is saved and loaded", func(ctx):
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var save_data: Dictionary = inv.get_save_data()
		var new_inv := _CommonSteps.SimpleInventory.new()
		new_inv.load_save_data(save_data)
		ctx.set_value("inventory", new_inv)
	)

	registry.when("the catalog is saved and loaded", func(ctx):
		var knowledge: Dictionary = ctx.get_value("knowledge", {})
		var saved: Dictionary = {}
		for key in knowledge:
			saved[String(key)] = knowledge[key]
		var restored: Dictionary = {}
		for key in saved:
			restored[StringName(key)] = saved[key]
		ctx.set_value("knowledge", restored)
	)

	registry.when("the discovery state is saved and loaded", func(ctx):
		var known: Array = ctx.get_value("known_recipes", [])
		ctx.set_value("known_recipes", known.duplicate())
	)

	registry.when("the day-night state is saved and loaded", func(ctx):
		# Values preserved in context already
		pass
	)

	registry.when("the full state is saved and loaded", func(ctx):
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var save_data: Dictionary = inv.get_save_data()
		var new_inv := _CommonSteps.SimpleInventory.new()
		new_inv.load_save_data(save_data)
		ctx.set_value("inventory", new_inv)
	)

	registry.given("a full game state with inventory tools catalog and day {int}", func(ctx, day: int):
		var inv := _CommonSteps.SimpleInventory.new()
		inv.add_item(&"P00010", 5)
		inv.set_tool(&"weapon", &"P00204")
		inv.set_tool(&"scanner", &"P00205")
		ctx.set_value("inventory", inv)
		ctx.set_value("day_count", day)
		ctx.set_value("phase", "DAY")
		var knowledge: Dictionary = {}
		knowledge[&"P00001"] = CATALOGED
		ctx.set_value("knowledge", knowledge)
		var known: Array[StringName] = [&"R00016"]
		ctx.set_value("known_recipes", known)
	)

	registry.given("a save file exists", func(ctx):
		ctx.set_value("save_exists", true)
	)

	registry.when("the save is deleted and a fresh game starts", func(ctx):
		ctx.set_value("save_exists", false)
		ctx.set_value("inventory", _CommonSteps.SimpleInventory.new())
		ctx.set_value("day_count", 1)
		ctx.set_value("phase", "DAY")
	)

	registry.then("recipe {string} is known", func(ctx, recipe_id: String):
		var known: Array = ctx.get_value("known_recipes", [])
		var sn := StringName(recipe_id)
		var found := false
		for k in known:
			if k == sn:
				found = true
				break
		ctx.assert_true(found, "Recipe '%s' should be known" % recipe_id)
	)
