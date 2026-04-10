extends RefCounted

## Step definitions for Gear hierarchy validation.
## Verifies that PropDef extends Gear and Recipe extends ScriptBase,
## with all expected fields present and no legacy fields.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")

const PROPS_PATH := "res://data/props/"
const RECIPES_PATH := "res://data/recipes/"


static func _load_all_propdefs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(PROPS_PATH)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(PROPS_PATH + fname)
			if res is _PropDef:
				defs.append(res)
		fname = dir.get_next()
	return defs


static func _load_all_recipes() -> Array:
	var recipes: Array = []
	var dir := DirAccess.open(RECIPES_PATH)
	if dir == null:
		return recipes
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(RECIPES_PATH + fname)
			if res is _Recipe:
				recipes.append(res)
		fname = dir.get_next()
	return recipes


func register_steps(registry) -> void:
	# --- Given ---
	registry.given("all PropDef resources are loaded", func(ctx):
		var defs := _load_all_propdefs()
		ctx.assert_greater(defs.size(), 0, "Expected at least one PropDef in data/props/")
		ctx.set_value("propdefs", defs)
	)

	registry.given("all Recipe resources are loaded", func(ctx):
		var recipes := _load_all_recipes()
		ctx.assert_greater(recipes.size(), 0, "Expected at least one Recipe in data/recipes/")
		ctx.set_value("recipes", recipes)
	)

	# --- Then: PropDef / Gear fields ---
	registry.then("every PropDef has id, display_name, short_description, long_description fields", func(ctx):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			# Gear base fields — all must exist (even if empty string for descriptions)
			ctx.assert_true(def is Resource,
				"PropDef must be a Resource")
			# id must be non-empty
			ctx.assert_true(String(def.id).length() > 0,
				"PropDef '%s' has empty id" % def.display_name)
			# display_name must be non-empty
			ctx.assert_true(def.display_name.length() > 0,
				"PropDef '%s' has empty display_name" % def.id)
			# short_description and long_description exist as properties (may be empty)
			ctx.assert_true("short_description" in def,
				"PropDef '%s' missing short_description field" % def.id)
			ctx.assert_true("long_description" in def,
				"PropDef '%s' missing long_description field" % def.id)
	)

	# --- Then: Recipe / ScriptBase fields ---
	registry.then("every Recipe has conditions, effects, actions, duration fields", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			ctx.assert_true("conditions" in recipe,
				"Recipe '%s' missing conditions field" % recipe.id)
			ctx.assert_true("effects" in recipe,
				"Recipe '%s' missing effects field" % recipe.id)
			ctx.assert_true("actions" in recipe,
				"Recipe '%s' missing actions field" % recipe.id)
			ctx.assert_true("duration" in recipe,
				"Recipe '%s' missing duration field" % recipe.id)
	)

	registry.then("no Recipe has a field named {string}", func(ctx, field_name: String):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			ctx.assert_false(field_name in recipe,
				"Recipe '%s' should not have field '%s'" % [recipe.id, field_name])
	)

	registry.then("no Recipe has unlock_when data", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			# unlock_when was removed in task-056; verify it doesn't exist as a property
			ctx.assert_false("unlock_when" in recipe,
				"Recipe '%s' should not have unlock_when (removed in task-056)" % recipe.id)
	)
