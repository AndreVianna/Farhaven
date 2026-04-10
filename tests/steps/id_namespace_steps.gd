extends RefCounted

## Step definitions for ID namespace validation.
## Verifies P/R/E prefix convention and cross-type uniqueness.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
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
	registry.given("all PropDef files are loaded", func(ctx):
		var defs := _load_all_propdefs()
		ctx.assert_greater(defs.size(), 0, "Expected at least one PropDef")
		ctx.set_value("propdefs", defs)
	)

	registry.given("all Recipe files are loaded", func(ctx):
		var recipes := _load_all_recipes()
		ctx.assert_greater(recipes.size(), 0, "Expected at least one Recipe")
		ctx.set_value("recipes", recipes)
	)

	registry.given("all Event files are loaded", func(ctx):
		var events := _load_all_events()
		ctx.assert_greater(events.size(), 0, "Expected at least one Event")
		ctx.set_value("events", events)
	)

	registry.given("all Gear IDs are collected", func(ctx):
		var all_ids: Array[String] = []
		var defs := _load_all_propdefs()
		for def in defs:
			all_ids.append(String(def.id))
		var recipes := _load_all_recipes()
		for recipe in recipes:
			all_ids.append(String(recipe.id))
		var events := _load_all_events()
		for event in events:
			all_ids.append(String(event.id))
		ctx.assert_greater(all_ids.size(), 0, "Expected at least one Gear ID")
		ctx.set_value("all_gear_ids", all_ids)
	)

	# --- Then ---
	registry.then("every prop ID starts with {string}", func(ctx, prefix: String):
		var defs: Array = ctx.get_value("propdefs", [])
		for def in defs:
			var id_str := String(def.id)
			ctx.assert_true(id_str.begins_with(prefix),
				"Prop ID '%s' must start with '%s'" % [id_str, prefix])
	)

	registry.then("every recipe ID starts with {string}", func(ctx, prefix: String):
		var recipes: Array = ctx.get_value("recipes", [])
		for recipe in recipes:
			var id_str := String(recipe.id)
			ctx.assert_true(id_str.begins_with(prefix),
				"Recipe ID '%s' must start with '%s'" % [id_str, prefix])
	)

	registry.then("every event ID starts with {string}", func(ctx, prefix: String):
		var events: Array = ctx.get_value("events", [])
		for event in events:
			var id_str := String(event.id)
			ctx.assert_true(id_str.begins_with(prefix),
				"Event ID '%s' must start with '%s'" % [id_str, prefix])
	)

	registry.then("there are no duplicate IDs", func(ctx):
		var all_ids: Array = ctx.get_value("all_gear_ids", [])
		var seen: Dictionary = {}
		for id_str in all_ids:
			ctx.assert_false(seen.has(id_str),
				"Duplicate Gear ID found: '%s'" % id_str)
			seen[id_str] = true
	)
