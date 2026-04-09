extends RefCounted

## Step definitions for auto-pickup feature.
## Uses SimpleInventory from common_steps (no autoload dependency).

const _CommonSteps = preload("res://tests/steps/common_steps.gd")


func register_steps(registry) -> void:
	registry.given("a ground item {string} with count {int} on tile {int},{int}", func(ctx, item_type: String, count: int, col: int, row: int):
		var ground_items: Array = ctx.get_value("ground_items", [])
		ground_items.append({
			"tile": Vector2i(col, row),
			"type": StringName(item_type),
			"count": count,
		})
		ctx.set_value("ground_items", ground_items)
	)

	registry.when("the player enters tile {int},{int}", func(ctx, col: int, row: int):
		var ground_items: Array = ctx.get_value("ground_items", [])
		var inv := _CommonSteps.get_or_create_inventory(ctx)

		var remaining: Array = []
		for item in ground_items:
			if item["tile"] == Vector2i(col, row):
				var added: int = inv.add_item(item["type"], item["count"])
				if added < item["count"]:
					remaining.append({
						"tile": item["tile"],
						"type": item["type"],
						"count": item["count"] - added,
					})
			else:
				remaining.append(item)
		ctx.set_value("ground_items", remaining)
		ctx.set_value("player_tile", Vector2i(col, row))
	)

	registry.then("the ground item is removed from tile {int},{int}", func(ctx, col: int, row: int):
		var ground_items: Array = ctx.get_value("ground_items", [])
		for item in ground_items:
			if item["tile"] == Vector2i(col, row):
				ctx.fail("Ground item still present on tile (%d,%d)" % [col, row])
				return
		ctx.assert_true(true)
	)
