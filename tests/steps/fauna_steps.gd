extends RefCounted

## Step definitions for fauna feature.
## Uses dictionaries for tiles/props to avoid autoload dependencies.

const FAUNA_CONFIG := {
	"hp": 20,
	"contact_damage": 10,
	"move_cooldown": 1.0,
	"detection_range": 2,
	"spawn_count_min": 1,
	"spawn_count_max": 3,
	"first_spawn_day": 4,
	"spawn_min_distance": 3,
}


func register_steps(registry) -> void:
	# --- Given: fauna setup ---
	registry.given("valid spawn tiles exist outside light radius", func(ctx):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		for i in range(4, 8):
			tiles[Vector2i(i, 0)] = {
				"coords": Vector2i(i, 0),
				"biome": 1,
				"elevation": 0,
				"props": [],
			}
		ctx.set_value("tiles", tiles)
		ctx.set_value("player_tile", Vector2i(0, 0))
		ctx.set_value("active_lights", [])
	)

	registry.given("a fauna adjacent to the player", func(ctx):
		ctx.set_value("fauna_adjacent", true)
		ctx.set_value("fauna_hp", FAUNA_CONFIG["hp"])
	)

	registry.given("the player is not on a shelter tile", func(ctx):
		ctx.set_value("on_shelter", false)
	)

	registry.given("the player is on a shelter tile", func(ctx):
		ctx.set_value("on_shelter", true)
	)

	registry.given("a fauna at tile {int},{int} with hp {int}", func(ctx, col: int, row: int, hp: int):
		ctx.set_value("fauna_tile", Vector2i(col, row))
		ctx.set_value("fauna_hp", hp)
		var tiles: Dictionary = ctx.get_value("tiles", {})
		if not tiles.has(Vector2i(col, row)):
			tiles[Vector2i(col, row)] = {
				"coords": Vector2i(col, row),
				"biome": 1,
				"elevation": 0,
				"props": [],
			}
			ctx.set_value("tiles", tiles)
	)

	# --- When: night arrives ---
	registry.when("night arrives", func(ctx):
		var day: int = ctx.get_value("day_count", 1)
		if day < FAUNA_CONFIG["first_spawn_day"]:
			ctx.set_value("fauna_count", 0)
		else:
			ctx.set_value("fauna_count", 0)
	)

	registry.when("night arrives and spawn is triggered", func(ctx):
		var day: int = ctx.get_value("day_count", 1)
		if day < FAUNA_CONFIG["first_spawn_day"]:
			ctx.set_value("fauna_count", 0)
		else:
			var count: int = FAUNA_CONFIG["spawn_count_min"] + randi() % (FAUNA_CONFIG["spawn_count_max"] - FAUNA_CONFIG["spawn_count_min"] + 1)
			ctx.set_value("fauna_count", count)
	)

	# --- When: fauna attacks ---
	registry.when("the fauna attacks", func(ctx):
		var on_shelter: bool = ctx.get_value("on_shelter", false)
		var damage: int
		if on_shelter:
			damage = 0
		else:
			damage = FAUNA_CONFIG["contact_damage"]
		ctx.set_value("last_damage", damage)
		var health: float = ctx.get_value("health", 100.0)
		health -= float(damage)
		ctx.set_value("health", health)
	)

	# --- When: fauna dies ---
	registry.when("the fauna dies", func(ctx):
		var fauna_tile: Vector2i = ctx.get_value("fauna_tile", Vector2i.ZERO)
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(fauna_tile, {})
		if not tile.is_empty():
			var props: Array = tile.get("props", [])
			props.append({
				"type": "00107",
				"blocks_movement": false,
				"category": 2,  # ANIMAL
			})
			tile["props"] = props
		ctx.set_value("fauna_count", 0)
	)

	# --- Then: fauna assertions ---
	registry.then("the fauna count is {int}", func(ctx, expected: int):
		var count: int = ctx.get_value("fauna_count", 0)
		ctx.assert_equal(count, expected,
			"Expected %d fauna, got %d" % [expected, count])
	)

	registry.then("the fauna count is between {int} and {int}", func(ctx, lo: int, hi: int):
		var count: int = ctx.get_value("fauna_count", 0)
		ctx.assert_greater_or_equal(count, lo,
			"Expected fauna count >= %d, got %d" % [lo, count])
		ctx.assert_less_or_equal(count, hi,
			"Expected fauna count <= %d, got %d" % [hi, count])
	)

	registry.then("the player takes {int} damage", func(ctx, expected: int):
		var damage: int = ctx.get_value("last_damage", -1)
		ctx.assert_equal(damage, expected,
			"Expected %d damage, got %d" % [expected, damage])
	)

	registry.then("a corpse prop is placed on tile {int},{int}", func(ctx, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist" % [col, row])
		if tile.is_empty():
			return
		var props: Array = tile.get("props", [])
		var found := false
		for prop in props:
			if prop.get("type", "") == "00107":
				found = true
				break
		ctx.assert_true(found,
			"Expected corpse prop on tile (%d,%d)" % [col, row])
	)
