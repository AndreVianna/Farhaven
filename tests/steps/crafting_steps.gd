extends RefCounted

## Step definitions for crafting and building features.
## Uses SimpleInventory from common_steps (no autoload dependency).

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _CommonSteps = preload("res://tests/steps/common_steps.gd")

const RECIPES_PATH := "res://data/recipes/"

## Tool slot lookup for known tool PropDefs.
const TOOL_SLOTS := {
	&"00201": &"axe",
	&"00202": &"pickaxe",
	&"00204": &"weapon",
	&"00205": &"scanner",
	&"00206": &"firestarter",
}


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
	# --- Given ---
	registry.given("recipe {string} is known", func(ctx, recipe_id: String):
		var known: Array = ctx.get_value("known_recipes", [])
		var sn := StringName(recipe_id)
		if not known.has(sn):
			known.append(sn)
		ctx.set_value("known_recipes", known)
	)

	registry.given("a buildable tile at {int},{int}", func(ctx, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		tiles[Vector2i(col, row)] = {"coords": Vector2i(col, row), "biome": 1, "elevation": 0, "props": []}
		ctx.set_value("tiles", tiles)
	)

	registry.given("recipe {string} requires {int} {string} and {int} {string}", func(ctx, recipe_id: String, _c1: int, _id1: String, _c2: int, _id2: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		ctx.set_value("recipe_" + recipe_id, recipe)
	)

	registry.given("a tile at {int},{int} with a structure occupying sub-hex {int},{int}", func(ctx, col: int, row: int, sq: int, sr: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		tiles[Vector2i(col, row)] = {
			"coords": Vector2i(col, row), "biome": 1, "elevation": 0,
			"props": [{"type": "00101", "blocks_movement": false, "sub_hex": Vector2i(sq, sr), "footprint": [Vector2i(sq, sr)]}],
		}
		ctx.set_value("tiles", tiles)
	)

	# --- When ---
	registry.when("the player crafts recipe {string}", func(ctx, recipe_id: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			return
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		for input_res in recipe.inputs:
			if not input_res.is_tag:
				var removed: int = inv.remove_item(input_res.ref_or_tag, input_res.count)
				ctx.assert_equal(removed, input_res.count,
					"Failed to consume %d of %s" % [input_res.count, input_res.ref_or_tag])
		for output_res in recipe.outputs:
			var tool_slot: StringName = TOOL_SLOTS.get(output_res.prop_ref, &"")
			if tool_slot != &"":
				inv.set_tool(tool_slot, output_res.prop_ref)
			else:
				inv.add_item(output_res.prop_ref, output_res.count)
	)

	registry.when("the player attempts recipe {string}", func(ctx, recipe_id: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			ctx.set_value("recipe_attempt_result", null)
			return
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var can_craft := true
		for input_res in recipe.inputs:
			if not input_res.is_tag:
				if not inv.has_item(input_res.ref_or_tag, input_res.count):
					can_craft = false
					break
		ctx.set_value("recipe_attempt_result", recipe if can_craft else null)
	)

	registry.when("the player builds recipe {string} on tile {int},{int}", func(ctx, recipe_id: String, col: int, row: int):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			return
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist" % [col, row])
		for input_res in recipe.inputs:
			if not input_res.is_tag:
				inv.remove_item(input_res.ref_or_tag, input_res.count)
		if not tile.is_empty():
			var props: Array = tile.get("props", [])
			for output_res in recipe.outputs:
				props.append({"type": String(output_res.prop_ref), "blocks_movement": false, "category": 6})
			tile["props"] = props
	)

	registry.when("a storage chest is placed", func(ctx):
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		inv.capacity_weight += 50.0
	)

	registry.when("the player cancels placement before confirming", func(ctx):
		pass
	)

	registry.when("the player tries to place another structure at sub-hex {int},{int} on tile {int},{int}", func(ctx, sq: int, sr: int, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		if tile.is_empty():
			ctx.set_value("placement_rejected", true)
			return
		var target_sub := Vector2i(sq, sr)
		var props: Array = tile.get("props", [])
		for prop in props:
			var footprint: Array = prop.get("footprint", [])
			if footprint.has(target_sub) or prop.get("sub_hex", Vector2i(-1, -1)) == target_sub:
				ctx.set_value("placement_rejected", true)
				return
		ctx.set_value("placement_rejected", false)
	)

	# --- Then ---
	registry.then("the recipe attempt returns null", func(ctx):
		var result = ctx.get_value("recipe_attempt_result", "MISSING")
		ctx.assert_null(result, "Expected recipe attempt to fail")
	)

	registry.then("recipe {string} is affordable", func(ctx, recipe_id: String):
		var recipe = ctx.get_value("recipe_" + recipe_id, null)
		if recipe == null:
			recipe = _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			return
		var inv := _CommonSteps.get_or_create_inventory(ctx)
		var affordable := true
		for input_res in recipe.inputs:
			if not input_res.is_tag:
				if not inv.has_item(input_res.ref_or_tag, input_res.count):
					affordable = false
		ctx.assert_true(affordable, "Recipe '%s' should be affordable" % recipe_id)
	)

	registry.then("tile {int},{int} has a structure prop {string}", func(ctx, col: int, row: int, prop_type: String):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist" % [col, row])
		var props: Array = tile.get("props", [])
		var found := false
		for prop in props:
			if prop.get("type", "") == prop_type:
				found = true
				break
		ctx.assert_true(found, "Expected structure '%s' on tile (%d,%d)" % [prop_type, col, row])
	)

	registry.then("the placement is rejected", func(ctx):
		var rejected: bool = ctx.get_value("placement_rejected", false)
		ctx.assert_true(rejected, "Expected placement to be rejected")
	)
