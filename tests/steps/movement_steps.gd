extends RefCounted

## Step definitions for movement feature.
## Tests hex grid traversal rules: biome, elevation, and structure blocking.
## Uses plain dictionaries for tiles/props to avoid autoload dependency (PropRegistry).

const TRAVERSAL_NAMES := {0: "WALK", 1: "JUMP", 2: "DROP", 3: "BLOCKED"}
const TRAVERSAL_FROM_NAME := {"WALK": 0, "JUMP": 1, "DROP": 2, "BLOCKED": 3}
const BIOME_FROM_NAME := {
	"CRASH_SITE": 0, "GRASSLAND": 1, "FOREST": 2, "ROCKY": 3, "WATER": 4
}
const BIOME_WATER := 4


## Helper: compute traversal locally (mirrors HexGrid.get_traversal).
static func _compute_traversal(tiles: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var tile_to: Dictionary = tiles.get(to, {})
	if tile_to.is_empty():
		return 3  # BLOCKED
	if tile_to.get("biome", 1) == BIOME_WATER:
		return 3
	var props: Array = tile_to.get("props", [])
	for prop in props:
		# Wall (P00106) blocks movement via collision shape.
		if prop.get("type", "") == "P00106":
			return 3
	var tile_from: Dictionary = tiles.get(from, {})
	if tile_from.is_empty():
		return 3
	var diff: int = abs(int(tile_to.get("elevation", 0)) - int(tile_from.get("elevation", 0)))
	if diff <= 2:
		return 0  # WALK
	if diff <= 4:
		if int(tile_to.get("elevation", 0)) > int(tile_from.get("elevation", 0)):
			return 1  # JUMP
		else:
			return 2  # DROP
	return 3  # BLOCKED


static func _make_tile(col: int, row: int, elev: int, biome: int) -> Dictionary:
	return {"coords": Vector2i(col, row), "elevation": elev, "biome": biome, "props": []}


func register_steps(registry) -> void:
	# --- Given: hex grid setup ---
	registry.given("a hex grid with tiles at {int},{int} and {int},{int} both elevation {int} biome {word}", func(ctx, c1: int, r1: int, c2: int, r2: int, elev: int, biome: String):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var b: int = BIOME_FROM_NAME.get(biome, 1)
		tiles[Vector2i(c1, r1)] = _make_tile(c1, r1, elev, b)
		tiles[Vector2i(c2, r2)] = _make_tile(c2, r2, elev, b)
		ctx.set_value("tiles", tiles)
	)

	registry.given("a hex grid with tile at {int},{int} elevation {int} biome {word}", func(ctx, col: int, row: int, elev: int, biome: String):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var b: int = BIOME_FROM_NAME.get(biome, 1)
		tiles[Vector2i(col, row)] = _make_tile(col, row, elev, b)
		ctx.set_value("tiles", tiles)
	)

	registry.given("a wall prop on tile {int},{int}", func(ctx, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist to place wall" % [col, row])
		if not tile.is_empty():
			var props: Array = tile.get("props", [])
			props.append({"type": "P00106"})
			tile["props"] = props
	)

	registry.given("a campfire prop on tile {int},{int}", func(ctx, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var tile: Dictionary = tiles.get(Vector2i(col, row), {})
		ctx.assert_false(tile.is_empty(), "Tile (%d,%d) must exist to place campfire" % [col, row])
		if not tile.is_empty():
			var props: Array = tile.get("props", [])
			props.append({"type": "P00101"})
			tile["props"] = props
	)

	registry.given("no tile exists at {int},{int}", func(ctx, col: int, row: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		tiles.erase(Vector2i(col, row))
		ctx.set_value("tiles", tiles)
	)

	# --- When: movement ---
	registry.when("the player walks from {int},{int} to {int},{int}", func(ctx, fc: int, fr: int, tc: int, tr: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var result: int = _compute_traversal(tiles, Vector2i(fc, fr), Vector2i(tc, tr))
		ctx.set_value("traversal_result", result)
	)

	registry.when("the player checks traversal from {int},{int} to {int},{int}", func(ctx, fc: int, fr: int, tc: int, tr: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var result: int = _compute_traversal(tiles, Vector2i(fc, fr), Vector2i(tc, tr))
		ctx.set_value("traversal_result", result)
	)

	# --- Then: traversal assertions ---
	registry.then("the traversal result is {word}", func(ctx, expected_name: String):
		var result: int = ctx.get_value("traversal_result", -1)
		var expected: int = TRAVERSAL_FROM_NAME.get(expected_name, -1)
		var result_name: String = TRAVERSAL_NAMES.get(result, "UNKNOWN(%d)" % result)
		ctx.assert_equal(result, expected,
			"Expected traversal %s, got %s" % [expected_name, result_name])
	)

	registry.then("traversal from {int},{int} to {int},{int} is {word}", func(ctx, fc: int, fr: int, tc: int, tr: int, expected_name: String):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		var result: int = _compute_traversal(tiles, Vector2i(fc, fr), Vector2i(tc, tr))
		var expected: int = TRAVERSAL_FROM_NAME.get(expected_name, -1)
		var result_name: String = TRAVERSAL_NAMES.get(result, "UNKNOWN(%d)" % result)
		ctx.assert_equal(result, expected,
			"Expected traversal %s from (%d,%d)->(%d,%d), got %s" % [expected_name, fc, fr, tc, tr, result_name])
	)
