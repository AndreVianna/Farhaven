extends RefCounted

## Step definitions for data validation feature.
## Loads all .tres files and checks structural integrity.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")

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
	registry.given("all PropDefs are loaded", func(ctx):
		var defs := _load_all_propdefs()
		ctx.assert_greater(defs.size(), 0, "Expected at least one PropDef")
		ctx.set_value("propdefs", defs)
	)

	registry.given("all Recipes are loaded", func(ctx):
		var recipes := _load_all_recipes()
		ctx.assert_greater(recipes.size(), 0, "Expected at least one Recipe")
		ctx.set_value("recipes", recipes)
	)

	# --- Then: PropDef validations ---
	registry.then("every PropDef has a non-empty id", func(ctx):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			ctx.assert_true(String(def.id).length() > 0,
				"PropDef '%s' has empty id" % def.display_name)
	)

	registry.then("every PropDef has a non-empty display_name", func(ctx):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			ctx.assert_true(def.display_name.length() > 0,
				"PropDef '%s' has empty display_name" % def.id)
	)

	registry.then("all PropDef ids are unique", func(ctx):
		var defs: Array = ctx.get_value("propdefs", [])
		var seen: Dictionary = {}
		for def in defs:
			ctx.assert_false(seen.has(def.id),
				"Duplicate PropDef id: '%s'" % def.id)
			seen[def.id] = true
	)

	registry.then("every PropDef tagged {string} has a catalogable capability", func(ctx, tag: String):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			if def.has_tag(StringName(tag)):
				ctx.assert_not_null(def.catalogable,
					"PropDef '%s' (%s) has tag '%s' but no catalogable cap" % [def.id, def.display_name, tag])
	)

	registry.then("every PropDef with a portable capability has weight greater than {int}", func(ctx, threshold: int):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			if def.portable != null:
				ctx.assert_greater(def.portable.weight, float(threshold),
					"PropDef '%s' (%s) has portable weight <= %d" % [def.id, def.display_name, threshold])
	)

	registry.then("every PropDef tagged {string} with a placeable capability has a non-empty footprint", func(ctx, tag: String):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			if def.has_tag(StringName(tag)) and def.placeable != null:
				ctx.assert_greater(def.placeable.footprint.size(), 0,
					"PropDef '%s' (%s) has STRUCTURE + placeable with empty footprint" % [def.id, def.display_name])
	)

	registry.then("PropDef {string} has a catalogable capability", func(ctx, prop_id: String):
		var defs: Array = ctx.get_value("propdefs", [])
		var found := false
		for def in defs:
			if String(def.id) == prop_id:
				found = true
				ctx.assert_not_null(def.catalogable,
					"PropDef '%s' should have catalogable capability" % prop_id)
				break
		ctx.assert_true(found, "PropDef '%s' not found" % prop_id)
	)

	# --- Then: Recipe validations ---
	registry.then("every Recipe has a non-empty id", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			ctx.assert_true(String(recipe.id).length() > 0,
				"Recipe '%s' has empty id" % recipe.display_name)
	)

	registry.then("every Recipe has a non-empty display_name", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			ctx.assert_true(recipe.display_name.length() > 0,
				"Recipe '%s' has empty display_name" % recipe.id)
	)

	registry.then("all Recipe ids are unique", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		var seen: Dictionary = {}
		for recipe in recipes:
			ctx.assert_false(seen.has(recipe.id),
				"Duplicate Recipe id: '%s'" % recipe.id)
			seen[recipe.id] = true
	)

	registry.then("every Recipe input with numeric ref references a valid PropDef id", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		var defs: Array = ctx.get_value("propdefs", [])
		var def_ids: Dictionary = {}
		for def in defs:
			def_ids[def.id] = true
		for recipe in recipes:
			for input_res in recipe.inputs:
				if not input_res.is_tag:
					# Only validate numeric refs (5-digit IDs), skip placeholder names
					var ref_str := String(input_res.ref_or_tag)
					if ref_str.is_valid_int():
						ctx.assert_true(def_ids.has(input_res.ref_or_tag),
							"Recipe '%s' input references unknown PropDef '%s'" % [recipe.id, input_res.ref_or_tag])
	)

	registry.then("every Recipe output with numeric ref references a valid PropDef id", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		var defs: Array = ctx.get_value("propdefs", [])
		var def_ids: Dictionary = {}
		for def in defs:
			def_ids[def.id] = true
		for recipe in recipes:
			for output_res in recipe.outputs:
				# Only validate numeric refs (5-digit IDs), skip placeholder names
				var ref_str := String(output_res.prop_ref)
				if ref_str.is_valid_int():
					ctx.assert_true(def_ids.has(output_res.prop_ref),
						"Recipe '%s' output references unknown PropDef '%s'" % [recipe.id, output_res.prop_ref])
	)

	registry.then("every Recipe output has prob between {int} and {int}", func(ctx, lo: int, hi: int):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			for output_res in recipe.outputs:
				ctx.assert_greater_or_equal(output_res.prob, float(lo),
					"Recipe '%s' output '%s' has prob < %d" % [recipe.id, output_res.prop_ref, lo])
				ctx.assert_less_or_equal(output_res.prob, float(hi),
					"Recipe '%s' output '%s' has prob > %d" % [recipe.id, output_res.prop_ref, hi])
	)

	registry.then("every Recipe id is a 5-digit numeric string", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			var id_str := String(recipe.id)
			ctx.assert_equal(id_str.length(), 5,
				"Recipe id '%s' is not 5 characters" % id_str)
			ctx.assert_true(id_str.is_valid_int(),
				"Recipe id '%s' is not numeric" % id_str)
	)
