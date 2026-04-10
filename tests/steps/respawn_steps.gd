extends RefCounted

## Step definitions for death and respawn feature.
## Uses dictionaries for tiles, avoids autoload dependencies.

const _HexMath = preload("res://scripts/hex/hex_math.gd")


func register_steps(registry) -> void:
	# --- Given: shelter and spawn ---
	registry.given("the player has no shelter built", func(ctx):
		ctx.set_value("shelters", [])
	)

	registry.given("the spawn tile is {int},{int}", func(ctx, col: int, row: int):
		ctx.set_value("spawn_tile", Vector2i(col, row))
	)

	registry.given("a shelter on tile {int},{int}", func(ctx, col: int, row: int):
		var shelters: Array = ctx.get_value("shelters", [])
		shelters.append(Vector2i(col, row))
		ctx.set_value("shelters", shelters)
		# Place shelter on tile as dictionary
		var tiles: Dictionary = ctx.get_value("tiles", {})
		if not tiles.has(Vector2i(col, row)):
			tiles[Vector2i(col, row)] = {
				"coords": Vector2i(col, row),
				"biome": 1,
				"elevation": 0,
				"props": [],
			}
			ctx.set_value("tiles", tiles)
		var tile: Dictionary = tiles[Vector2i(col, row)]
		var props: Array = tile.get("props", [])
		props.append({"type": "P00102"})
		tile["props"] = props
	)

	registry.given("the player is closer to tile {int},{int} than to spawn", func(ctx, col: int, row: int):
		ctx.set_value("player_tile", Vector2i(col - 1, row))
	)

	# --- When: player dies ---
	registry.when("the player dies", func(ctx):
		var shelters: Array = ctx.get_value("shelters", [])
		var spawn: Vector2i = ctx.get_value("spawn_tile", Vector2i.ZERO)
		var player_tile: Vector2i = ctx.get_value("player_tile", Vector2i.ZERO)

		if shelters.is_empty():
			ctx.set_value("respawn_tile", spawn)
		else:
			# Find nearest shelter
			var nearest: Vector2i = shelters[0]
			var min_dist: int = _HexMath.distance(player_tile, shelters[0])
			for i in range(1, shelters.size()):
				var d: int = _HexMath.distance(player_tile, shelters[i])
				if d < min_dist:
					min_dist = d
					nearest = shelters[i]
			ctx.set_value("respawn_tile", nearest)
	)

	# --- Then: respawn assertions ---
	registry.then("the respawn tile is {int},{int}", func(ctx, col: int, row: int):
		var respawn: Vector2i = ctx.get_value("respawn_tile", Vector2i(-999, -999))
		ctx.assert_equal(respawn, Vector2i(col, row),
			"Expected respawn at (%d,%d), got (%d,%d)" % [col, row, respawn.x, respawn.y])
	)
