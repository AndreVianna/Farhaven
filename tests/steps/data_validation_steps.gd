extends RefCounted

## Step definitions for data validation feature.
## Loads all .tres files and checks structural integrity.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _GameEvent = preload("res://scripts/core/event.gd")

const PROPS_PATH := "res://data/props/"
const RECIPES_PATH := "res://data/recipes/"
const EVENTS_PATH := "res://data/events/"


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


static func _load_all_events() -> Array:
	var events: Array = []
	var dir := DirAccess.open(EVENTS_PATH)
	if dir == null:
		return events
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(EVENTS_PATH + fname)
			if res is _GameEvent:
				events.append(res)
		fname = dir.get_next()
	return events


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

	registry.then("every PropDef with a portable capability has size greater than {int}", func(ctx, threshold: int):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			if def.portable != null:
				ctx.assert_greater(def.portable.size, float(threshold),
					"PropDef '%s' (%s) has portable size <= %d" % [def.id, def.display_name, threshold])
	)

	registry.then("every PropDef tagged {string} has a placeable capability", func(ctx, tag: String):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			if def.has_tag(StringName(tag)):
				ctx.assert_not_null(def.placeable,
					"PropDef '%s' (%s) tagged %s must have placeable capability" % [def.id, def.display_name, tag])
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
				if not input_res.is_tag():
					# Only validate prefixed prop refs (P-prefixed IDs), skip placeholder names
					var ref_str := String(input_res.ref)
					if ref_str.begins_with("P"):
						var ref_sn := StringName(ref_str)
						ctx.assert_true(def_ids.has(ref_sn),
							"Recipe '%s' input references unknown PropDef '%s'" % [recipe.id, ref_str])
	)

	registry.then("every Recipe output with numeric ref references a valid PropDef id", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		var defs: Array = ctx.get_value("propdefs", [])
		var def_ids: Dictionary = {}
		for def in defs:
			def_ids[def.id] = true
		for recipe in recipes:
			for output_res in recipe.outputs:
				# Only validate prefixed prop refs (P-prefixed IDs), skip placeholder names
				var ref_str := String(output_res.prop_ref)
				if ref_str.begins_with("P"):
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

	registry.then("every Recipe id starts with R prefix", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			var id_str := String(recipe.id)
			ctx.assert_true(id_str.begins_with("R"),
				"Recipe id '%s' must start with 'R' prefix" % id_str)
	)

	registry.then("no Recipe has an unlock_when property", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			var props := recipe.get_property_list()
			for p in props:
				ctx.assert_true(p["name"] != "unlock_when",
					"Recipe '%s' still has unlock_when property" % recipe.id)
	)

	registry.then("every Recipe has duration via ScriptBase and no legacy time field", func(ctx):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			# duration is inherited from ScriptBase — must exist
			ctx.assert_true("duration" in recipe,
				"Recipe '%s' missing duration field" % recipe.id)
			# legacy "time" field should not exist
			var has_time := false
			for p in recipe.get_property_list():
				if p["name"] == "time":
					has_time = true
					break
			ctx.assert_false(has_time,
				"Recipe '%s' still has legacy 'time' property" % recipe.id)
	)

	registry.then("every PlaceableCap is a pure marker with no extra fields", func(ctx):
		var defs: Array = ctx.get_value("propdefs", [])
		# Properties inherited from Resource/RefCounted are expected; any @export
		# beyond those means PlaceableCap is no longer a pure marker.
		var baseline_props: Array[String] = [
			"resource_local_to_scene", "resource_path", "resource_name",
			"script", "RefCounted", "resource_scene_unique_id",
		]
		for def in defs:
			if def.placeable == null:
				continue
			var cap = def.placeable
			for p in cap.get_property_list():
				var name: String = p["name"]
				# Skip built-in Resource/meta properties
				if name in baseline_props or name.begins_with("_") or name == "":
					continue
				# USAGE_DEFAULT (bit 1) marks @export properties in Godot 4
				if p["usage"] & PROPERTY_USAGE_STORAGE:
					ctx.assert_true(false,
						"PlaceableCap on '%s' has unexpected field '%s' — should be a pure marker" % [def.id, name])
	)

	# --- Given: Events ---
	registry.given("all Events are loaded", func(ctx):
		var events := _load_all_events()
		ctx.assert_greater(events.size(), 0, "Expected at least one Event")
		ctx.set_value("events", events)
	)

	# --- Then: Event validations ---
	registry.then("every Event id starts with E prefix", func(ctx):
		var events: Array = ctx.get_value("events", [])
		for event in events:
			var id_str := String(event.id)
			ctx.assert_true(id_str.begins_with("E"),
				"Event id '%s' must start with 'E' prefix" % id_str)
	)

	registry.then("every Event has max_count greater than or equal to {int}", func(ctx, threshold: int):
		var events: Array = ctx.get_value("events", [])
		for event in events:
			ctx.assert_greater_or_equal(event.max_count, threshold,
				"Event '%s' has max_count %d which is < %d" % [event.id, event.max_count, threshold])
	)
