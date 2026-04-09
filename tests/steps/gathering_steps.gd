extends RefCounted

## Step definitions for gathering and discovery feature.
## Uses dictionaries for tiles/props, avoids autoload dependency chain.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")

const RECIPES_PATH := "res://data/recipes/"
const PROPS_PATH := "res://data/props/"

## Knowledge states (from Catalog enum, duplicated to avoid import chain).
const UNKNOWN := 0
const ENCOUNTERED := 1
const CATALOGED := 2


static func _load_recipe(recipe_id: String) -> Resource:
	var dir := DirAccess.open(RECIPES_PATH)
	if dir == null:
		return null
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(RECIPES_PATH + fname)
			if res is _Recipe and String(res.id) == recipe_id:
				return res
		fname = dir.get_next()
	return null


func register_steps(registry) -> void:
	# --- Given: catalog state ---
	registry.given("a catalog with {string} in UNKNOWN state", func(ctx, entry_id: String):
		var knowledge: Dictionary = {}
		knowledge[StringName(entry_id)] = UNKNOWN
		ctx.set_value("knowledge", knowledge)
		ctx.set_value("catalog_entry_id", StringName(entry_id))
	)

	registry.given("catalog entry {string} is cataloged", func(ctx, entry_id: String):
		var knowledge: Dictionary = ctx.get_value("knowledge", {})
		knowledge[StringName(entry_id)] = CATALOGED
		ctx.set_value("knowledge", knowledge)
	)

	# --- Given: recipe tool requirements ---
	registry.given("a recipe {string} that requires tool {string}", func(ctx, recipe_id: String, tool_slot: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		ctx.set_value("test_recipe", recipe)
		ctx.set_value("required_tool_slot", tool_slot)
	)

	# --- Given: prop on tile (as dictionary) ---
	registry.given("a prop {string} on tile {int},{int} with remaining {int}", func(ctx, prop_type: String, col: int, row: int, remaining: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var coords := Vector2i(col, row)
		if not tiles.has(coords):
			tiles[coords] = {
				"coords": coords,
				"biome": 1,
				"elevation": 0,
				"props": [],
			}
		var tile: Dictionary = tiles[coords]
		var props: Array = tile.get("props", [])
		props.append({
			"type": prop_type,
			"remaining": remaining,
			"max_amount": remaining,
		})
		tile["props"] = props
		ctx.set_value("tiles", tiles)
	)

	# --- When: scan prop ---
	registry.when("the player scans prop {string} to completion", func(ctx, entry_id: String):
		var knowledge: Dictionary = ctx.get_value("knowledge", {})
		knowledge[StringName(entry_id)] = CATALOGED
		ctx.set_value("knowledge", knowledge)
	)

	# --- When: tool check ---
	registry.when("the player has no pickaxe equipped", func(ctx):
		ctx.set_value("equipped_pickaxe", false)
	)

	# --- When: gathering ---
	registry.when("the prop is gathered once", func(ctx):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		for coords in tiles:
			var tile: Dictionary = tiles[coords]
			var props: Array = tile.get("props", [])
			for prop in props:
				if prop.get("remaining", 0) > 0:
					prop["remaining"] = prop["remaining"] - 1
					ctx.set_value("gathered_tile", coords)
					return
	)

	# --- Then: catalog assertions ---
	registry.then("catalog entry {string} is CATALOGED", func(ctx, entry_id: String):
		var knowledge: Dictionary = ctx.get_value("knowledge", {})
		var state: int = knowledge.get(StringName(entry_id), UNKNOWN)
		ctx.assert_equal(state, CATALOGED,
			"Expected entry '%s' to be CATALOGED (2), got %d" % [entry_id, state])
	)

	# --- Then: recipe condition check ---
	registry.then("the recipe {string} condition check fails for has_tool", func(ctx, recipe_id: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			return
		var has_tool_condition := false
		for cond in recipe.conditions:
			if cond.predicate != null and cond.predicate.kind == &"has_tool":
				has_tool_condition = true
				break
		ctx.assert_true(has_tool_condition,
			"Recipe '%s' should have a has_tool condition" % recipe_id)
		var equipped: bool = ctx.get_value("equipped_pickaxe", false)
		ctx.assert_false(equipped, "Player should not have pickaxe equipped")
	)

	# --- Then: prop remaining ---
	registry.then("the prop remaining on tile {int},{int} is {int}", func(ctx, col: int, row: int, expected: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist" % [col, row])
		if tile.is_empty():
			return
		var props: Array = tile.get("props", [])
		ctx.assert_greater(props.size(), 0, "Tile must have props")
		if props.size() > 0:
			ctx.assert_equal(props[0].get("remaining", -1), expected,
				"Expected remaining %d, got %d" % [expected, props[0].get("remaining", -1)])
	)
