extends RefCounted

## Step definitions for recipe lifecycle feature.
## Tests passive recipes, sustain conditions, and trap triggers.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const RECIPES_PATH := "res://data/recipes/"


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
	# --- Given: recipe properties ---
	registry.given("recipe {string} is a passive transform with time {float}", func(ctx, recipe_id: String, time: float):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		ctx.set_value("test_recipe", recipe)
	)

	registry.given("recipe {string} has a must_sustain condition", func(ctx, recipe_id: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		ctx.set_value("test_recipe", recipe)
	)

	registry.given("recipe {string} has a condition with predicate {string}", func(ctx, recipe_id: String, pred_kind: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		ctx.set_value("test_recipe", recipe)
		# Verify the condition exists
		var found := false
		for cond in recipe.conditions:
			if cond.predicate != null and String(cond.predicate.kind) == pred_kind:
				found = true
				break
		ctx.assert_true(found,
			"Recipe '%s' should have condition with predicate '%s'" % [recipe_id, pred_kind])
	)

	# --- Then: recipe assertions ---
	registry.then("recipe {string} has no actions", func(ctx, recipe_id: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe:
			ctx.assert_equal(recipe.actions.size(), 0,
				"Recipe '%s' should have no actions (passive), got %d" % [recipe_id, recipe.actions.size()])
	)

	registry.then("recipe {string} has time greater than {int}", func(ctx, recipe_id: String, threshold: int):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe:
			ctx.assert_greater(recipe.duration, float(threshold),
				"Recipe '%s' should have duration > %d, got %.1f" % [recipe_id, threshold, recipe.duration])
	)

	registry.then("the sustain condition on recipe {string} is for predicate {string}", func(ctx, recipe_id: String, pred_kind: String):
		var recipe := _load_recipe(recipe_id)
		ctx.assert_not_null(recipe, "Recipe '%s' must exist" % recipe_id)
		if recipe == null:
			return
		var found := false
		for cond in recipe.conditions:
			if cond.must_sustain and cond.predicate != null and String(cond.predicate.kind) == pred_kind:
				found = true
				break
		ctx.assert_true(found,
			"Recipe '%s' should have a must_sustain condition for '%s'" % [recipe_id, pred_kind])
	)
