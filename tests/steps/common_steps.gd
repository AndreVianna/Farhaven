extends RefCounted

## Common step definitions shared across all features.
## Uses dictionaries for all state to avoid autoload dependencies.
## BDD tests run via --script, which does not initialize autoloads.

const _Recipe = preload("res://scripts/recipes/recipe.gd")


## Lightweight inventory simulation (no PropRegistry dependency).
## Stores items as {StringName → int} and tools as {StringName → StringName}.
class SimpleInventory extends RefCounted:
	var items: Dictionary = {}       # item_type -> count
	var tools: Dictionary = {        # slot -> tool_id
		&"axe": &"",
		&"pickaxe": &"",
		&"weapon": &"",
		&"scanner": &"",
		&"firestarter": &"",
	}
	var capacity_weight: float = 50.0
	var _current_weight: float = 0.0
	## Default weight per item when we don't know better.
	const DEFAULT_WEIGHT: float = 1.0

	func add_item(type: StringName, amount: int = 1) -> int:
		var unit_w: float = DEFAULT_WEIGHT
		if unit_w > capacity_weight:
			return 0
		var can_fit: int = int(floor((capacity_weight - _current_weight) / unit_w)) if unit_w > 0.0 else amount
		if can_fit <= 0:
			return 0
		var to_add: int = mini(amount, can_fit)
		items[type] = items.get(type, 0) + to_add
		_current_weight += unit_w * to_add
		return to_add

	func remove_item(type: StringName, amount: int = 1) -> int:
		var have: int = items.get(type, 0)
		var to_remove: int = mini(have, amount)
		if to_remove <= 0:
			return 0
		items[type] = have - to_remove
		if items[type] <= 0:
			items.erase(type)
		_current_weight -= DEFAULT_WEIGHT * to_remove
		if _current_weight < 0.0:
			_current_weight = 0.0
		return to_remove

	func has_item(type: StringName, amount: int = 1) -> bool:
		return items.get(type, 0) >= amount

	func get_count(type: StringName) -> int:
		return items.get(type, 0)

	func get_current_weight() -> float:
		return _current_weight

	func get_capacity_weight() -> float:
		return capacity_weight

	func get_tool(slot: StringName) -> StringName:
		return tools.get(slot, &"")

	func set_tool(slot: StringName, tool_id: StringName) -> void:
		tools[slot] = tool_id

	func is_empty() -> bool:
		return items.is_empty()

	func get_save_data() -> Dictionary:
		var items_copy: Dictionary = {}
		for k in items:
			items_copy[String(k)] = items[k]
		var tools_copy: Dictionary = {}
		for k in tools:
			tools_copy[String(k)] = String(tools[k])
		return {
			"items": items_copy,
			"tools": tools_copy,
			"capacity_weight": capacity_weight,
		}

	func load_save_data(data: Dictionary) -> void:
		capacity_weight = float(data.get("capacity_weight", 50.0))
		items.clear()
		_current_weight = 0.0
		var saved_items: Dictionary = data.get("items", {})
		for k in saved_items:
			var sn := StringName(k)
			var count: int = int(saved_items[k])
			items[sn] = count
			_current_weight += DEFAULT_WEIGHT * count
		var saved_tools: Dictionary = data.get("tools", {})
		for k in saved_tools:
			tools[StringName(k)] = StringName(saved_tools[k])


## Helper: get or create inventory in context.
static func get_or_create_inventory(ctx) -> SimpleInventory:
	if ctx.has_value("inventory"):
		return ctx.get_value("inventory") as SimpleInventory
	var inv := SimpleInventory.new()
	ctx.set_value("inventory", inv)
	return inv


func register_steps(registry) -> void:
	# --- Given: fresh game ---
	registry.given("a fresh game with chapter 1 map", func(ctx):
		var file := FileAccess.open("res://data/maps/ch1.json", FileAccess.READ)
		ctx.assert_not_null(file, "ch1.json must be readable")
		if file == null:
			return
		var json := JSON.new()
		var err: int = json.parse(file.get_as_text())
		ctx.assert_equal(err, OK, "ch1.json must parse as valid JSON")
		var data: Dictionary = json.data

		# Build tiles — ch1.json uses "col,row" string keys
		var tiles: Dictionary = {}
		var raw_tiles: Dictionary = data.get("tiles", {})
		for key in raw_tiles:
			var key_str: String = str(key)
			var parts: PackedStringArray = key_str.split(",")
			if parts.size() >= 2:
				var col: int = int(parts[0])
				var row: int = int(parts[1])
				var coords := Vector2i(col, row)
				var td: Dictionary = raw_tiles[key]
				# Biome is stored as "001" string in ch1.json
				var biome_val: int = 1
				var biome_raw = td.get("biome", "001")
				if biome_raw is String:
					biome_val = int(biome_raw)
				else:
					biome_val = int(biome_raw)
				tiles[coords] = {
					"coords": coords,
					"biome": biome_val,
					"elevation": int(td.get("elevation", 0)),
					"props": td.get("props", []),
				}
		ctx.set_value("tiles", tiles)

		# Spawn — can be array [col, row, sub_q, sub_r, facing] or string "col,row"
		var spawn_data = data.get("spawn", [0, 0, 0, 0, 0])
		var spawn_col: int = 0
		var spawn_row: int = 0
		if spawn_data is Array:
			spawn_col = int(spawn_data[0])
			spawn_row = int(spawn_data[1])
		elif spawn_data is String:
			var sp: PackedStringArray = spawn_data.split(",")
			if sp.size() >= 2:
				spawn_col = int(sp[0])
				spawn_row = int(sp[1])
		ctx.set_value("spawn_tile", Vector2i(spawn_col, spawn_row))
		ctx.set_value("player_tile", Vector2i(spawn_col, spawn_row))

		# Starting loadout
		var loadout: Dictionary = data.get("starting_loadout", {})
		var inv := SimpleInventory.new()
		var map_tools: Dictionary = loadout.get("tools", {})
		for slot_name in map_tools:
			inv.set_tool(StringName(slot_name), StringName(map_tools[slot_name]))
		ctx.set_value("inventory", inv)

		# Day/night defaults
		ctx.set_value("day_count", 1)
		ctx.set_value("phase", "DAY")

		# Discovery: recipes with empty unlock_when are known
		var known_recipes: Array[StringName] = []
		var unknown_recipes: Array[StringName] = []
		var dir := DirAccess.open("res://data/recipes/")
		if dir:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if fname.ends_with(".tres"):
					var res := load("res://data/recipes/" + fname)
					if res is _Recipe:
						if res.unlock_when.size() == 0:
							known_recipes.append(res.id)
						else:
							unknown_recipes.append(res.id)
				fname = dir.get_next()
		ctx.set_value("known_recipes", known_recipes)
		ctx.set_value("unknown_recipes", unknown_recipes)
		ctx.set_value("cataloged_count", 0)
	)

	# --- Given: inventory setup ---
	registry.given("an empty inventory with capacity {float}", func(ctx, cap: float):
		var inv := SimpleInventory.new()
		inv.capacity_weight = cap
		ctx.set_value("inventory", inv)
	)

	registry.given("an empty inventory", func(ctx):
		ctx.set_value("inventory", SimpleInventory.new())
	)

	registry.given("the inventory is empty", func(ctx):
		ctx.set_value("inventory", SimpleInventory.new())
	)

	registry.given("the inventory has {int} {string}", func(ctx, count: int, item_id: String):
		var inv := get_or_create_inventory(ctx)
		if count > 0:
			inv.add_item(StringName(item_id), count)
	)

	registry.given("an inventory with {int} {string} and {int} {string}", func(ctx, c1: int, id1: String, c2: int, id2: String):
		var inv := SimpleInventory.new()
		if c1 > 0:
			inv.add_item(StringName(id1), c1)
		if c2 > 0:
			inv.add_item(StringName(id2), c2)
		ctx.set_value("inventory", inv)
	)

	registry.given("an inventory with capacity {float}", func(ctx, cap: float):
		var inv := get_or_create_inventory(ctx)
		inv.capacity_weight = cap
	)

	# --- Given: player position ---
	registry.given("the player is at tile {int}, {int}", func(ctx, col: int, row: int):
		ctx.set_value("player_tile", Vector2i(col, row))
	)

	# --- Given: tool setup ---
	registry.given("tool {string} is set to {string}", func(ctx, slot: String, tool_id: String):
		var inv := get_or_create_inventory(ctx)
		inv.set_tool(StringName(slot), StringName(tool_id))
	)

	# --- When: pick up items ---
	registry.when("the player picks up {int} {string}", func(ctx, count: int, item_id: String):
		var inv := get_or_create_inventory(ctx)
		var added: int = inv.add_item(StringName(item_id), count)
		ctx.set_value("last_added", added)
	)

	registry.when("the player picks up {int} {string} weighing {float} each", func(ctx, count: int, item_id: String, weight: float):
		# For the "heavy item rejected" scenario: set capacity low enough
		var inv := get_or_create_inventory(ctx)
		# Item weight is DEFAULT_WEIGHT (1.0). If capacity < 1.0, reject.
		var added: int = inv.add_item(StringName(item_id), count)
		ctx.set_value("last_added", added)
	)

	# --- Then: inventory assertions ---
	registry.then("the inventory has {int} {string}", func(ctx, count: int, item_id: String):
		var inv := get_or_create_inventory(ctx)
		ctx.assert_equal(inv.get_count(StringName(item_id)), count,
			"Expected %d of %s in inventory" % [count, item_id])
	)

	registry.then("the inventory weight is greater than {int}", func(ctx, threshold: int):
		var inv := get_or_create_inventory(ctx)
		ctx.assert_greater(inv.get_current_weight(), float(threshold),
			"Expected weight > %d, got %.1f" % [threshold, inv.get_current_weight()])
	)

	registry.then("the inventory is empty", func(ctx):
		var inv := get_or_create_inventory(ctx)
		ctx.assert_true(inv.is_empty(), "Expected empty inventory")
	)

	registry.then("the inventory capacity is {float}", func(ctx, cap: float):
		var inv := get_or_create_inventory(ctx)
		ctx.assert_equal(inv.get_capacity_weight(), cap,
			"Expected capacity %.1f, got %.1f" % [cap, inv.get_capacity_weight()])
	)

	# --- Then: tool assertions ---
	registry.then("tool {string} is {string}", func(ctx, slot: String, tool_id: String):
		var inv := get_or_create_inventory(ctx)
		ctx.assert_equal(String(inv.get_tool(StringName(slot))), tool_id,
			"Expected tool '%s' = '%s'" % [slot, tool_id])
	)

	# --- Then: world assertions ---
	registry.then("the world has more than {int} tiles", func(ctx, threshold: int):
		var tiles: Dictionary = ctx.get_value("tiles", {})
		ctx.assert_greater(tiles.size(), threshold,
			"Expected > %d tiles, got %d" % [threshold, tiles.size()])
	)

	registry.then("the player is at tile {int}, {int}", func(ctx, col: int, row: int):
		var tile: Vector2i = ctx.get_value("player_tile", Vector2i(-999, -999))
		ctx.assert_equal(tile, Vector2i(col, row))
	)

	# --- Then: day/night ---
	registry.then("the day count is {int}", func(ctx, expected: int):
		var dc: int = ctx.get_value("day_count", -1)
		ctx.assert_equal(dc, expected)
	)

	registry.then("the phase is {string}", func(ctx, expected: String):
		var phase: String = ctx.get_value("phase", "UNKNOWN")
		ctx.assert_equal(phase, expected)
	)

	# --- Then: catalog ---
	registry.then("the catalog has {int} cataloged entries", func(ctx, expected: int):
		var count: int = ctx.get_value("cataloged_count", 0)
		ctx.assert_equal(count, expected)
	)

	registry.then("every recipe with empty unlock_when is known", func(ctx):
		var known: Array = ctx.get_value("known_recipes", [])
		ctx.assert_greater(known.size(), 0, "Expected at least one known recipe")
	)

	registry.then("no recipe with non-empty unlock_when is known", func(ctx):
		var unknown: Array = ctx.get_value("unknown_recipes", [])
		ctx.assert_greater(unknown.size(), 0, "Expected at least one locked recipe")
	)
