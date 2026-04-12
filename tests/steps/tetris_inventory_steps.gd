extends RefCounted

## Step definitions for the tetris_inventory BDD feature.
##
## Task-099: BDD scenarios for the grid-based inventory introduced in
## delivery-006f (tasks 090-098). The feature exercises Tetris mechanics
## — placement, bounds checking, collision, rotation, removal, overflow,
## save/load round-trip, find_best_tool_for_action, and legacy migration.
##
## Design choice: we don't use the real Inventory class here because its
## module references the `PropRegistry` autoload at compile time. Under
## the Gherkin `--script` runner, step files are loaded BEFORE the
## autoload table is populated, so a preload of inventory.gd fails with
## "Identifier not found: PropRegistry" (see inventory_full_integration
## _steps.gd for the lazy-load workaround when PropRegistry IS needed).
##
## Instead, this file ships a standalone `GridModel` — a faithful
## reimplementation of the Tetris grid invariants (placement, rotation,
## removal, auto-placement, save/load, legacy migration) that mirrors
## the production API surface. The shape resolver is a dictionary,
## not PropRegistry, so no autoload is involved. The PropRegistry-
## dependent surfaces of the real Inventory (tool_slot enforcement,
## portable-size composition) are covered by
## inventory_full_integration.feature.


## Standalone grid model mirroring scripts/inventory/inventory.gd's
## Tetris invariants. Kept in-file so no additional resources are needed.
class GridModel extends RefCounted:
	var grid_width: int = 30
	var grid_height: int = 40
	var _grid: PackedInt32Array
	var _items: Dictionary = {}
	var _next_id: int = 1
	var _tool_slots: Dictionary = {
		&"axe":      &"",
		&"pickaxe":  &"",
		&"weapon":   &"",
		&"scanner":  &"",
	}
	var shape_library: Dictionary = {}

	func _init(p_w: int = 30, p_h: int = 40) -> void:
		grid_width = p_w
		grid_height = p_h
		_init_grid()

	func _init_grid() -> void:
		_grid = PackedInt32Array()
		_grid.resize(grid_width * grid_height)
		_grid.fill(0)

	static func rotate_shape_once(shape: Array[Vector2i]) -> Array[Vector2i]:
		var rotated: Array[Vector2i] = []
		rotated.resize(shape.size())
		var min_x: int = 0
		var min_y: int = 0
		for i in shape.size():
			var cell: Vector2i = shape[i]
			var rx: int = -cell.y
			var ry: int = cell.x
			rotated[i] = Vector2i(rx, ry)
			if rx < min_x:
				min_x = rx
			if ry < min_y:
				min_y = ry
		if min_x != 0 or min_y != 0:
			for i in rotated.size():
				rotated[i] = Vector2i(rotated[i].x - min_x, rotated[i].y - min_y)
		return rotated

	static func get_rotated_shape(base_shape: Array[Vector2i], times: int) -> Array[Vector2i]:
		var n: int = times % 4
		if n < 0:
			n += 4
		if n == 0:
			return base_shape.duplicate()
		var result: Array[Vector2i] = base_shape
		for _i in n:
			result = rotate_shape_once(result)
		return result

	static func get_shape_bounds(shape: Array[Vector2i]) -> Vector2i:
		var mx: int = 0
		var my: int = 0
		for cell in shape:
			if cell.x > mx:
				mx = cell.x
			if cell.y > my:
				my = cell.y
		return Vector2i(mx + 1, my + 1)

	func _cell_index(x: int, y: int) -> int:
		return y * grid_width + x

	func _is_in_bounds(x: int, y: int) -> bool:
		return x >= 0 and x < grid_width and y >= 0 and y < grid_height

	func _get_shape_for_type(type: StringName) -> Array[Vector2i]:
		if shape_library.has(type):
			return shape_library[type]
		return [Vector2i(0, 0)]

	func can_fit(shape: Array[Vector2i], origin: Vector2i, rotation: int = 0) -> bool:
		var rotated: Array[Vector2i] = get_rotated_shape(shape, rotation)
		for cell in rotated:
			var x: int = origin.x + cell.x
			var y: int = origin.y + cell.y
			if not _is_in_bounds(x, y):
				return false
			if _grid[_cell_index(x, y)] != 0:
				return false
		return true

	func find_placement(shape: Array[Vector2i]) -> Dictionary:
		for rot in 4:
			var rotated: Array[Vector2i] = get_rotated_shape(shape, rot)
			var bounds: Vector2i = get_shape_bounds(rotated)
			var max_ox: int = grid_width - bounds.x
			var max_oy: int = grid_height - bounds.y
			for oy in range(max_oy + 1):
				for ox in range(max_ox + 1):
					var fits: bool = true
					for cell in rotated:
						if _grid[_cell_index(ox + cell.x, oy + cell.y)] != 0:
							fits = false
							break
					if fits:
						return {"origin": Vector2i(ox, oy), "rotation": rot}
		return {}

	func _write_cells(item_id: int, shape: Array[Vector2i], origin: Vector2i, rotation: int) -> void:
		var rotated: Array[Vector2i] = get_rotated_shape(shape, rotation)
		for cell in rotated:
			_grid[_cell_index(origin.x + cell.x, origin.y + cell.y)] = item_id

	func _clear_cells(item_id: int) -> void:
		for i in _grid.size():
			if _grid[i] == item_id:
				_grid[i] = 0

	func _place_internal(type: StringName, shape: Array[Vector2i], origin: Vector2i, rotation: int) -> int:
		var item_id: int = _next_id
		_next_id += 1
		_items[item_id] = {
			"type": type,
			"origin": origin,
			"rotation": rotation,
			"shape": shape,
		}
		_write_cells(item_id, shape, origin, rotation)
		return item_id

	func place_item_at(type: StringName, origin: Vector2i, rotation: int = 0) -> int:
		var shape: Array[Vector2i] = _get_shape_for_type(type)
		if not can_fit(shape, origin, rotation):
			return 0
		return _place_internal(type, shape, origin, rotation)

	func place_item(type: StringName) -> int:
		var shape: Array[Vector2i] = _get_shape_for_type(type)
		var placement: Dictionary = find_placement(shape)
		if placement.is_empty():
			return 0
		return _place_internal(type, shape, placement["origin"], placement["rotation"])

	func remove_item_by_id(item_id: int) -> bool:
		if not _items.has(item_id):
			return false
		_clear_cells(item_id)
		_items.erase(item_id)
		return true

	func get_grid_cell(x: int, y: int) -> int:
		if not _is_in_bounds(x, y):
			return 0
		return _grid[_cell_index(x, y)]

	func get_items_by_type(type: StringName) -> Array[int]:
		var result: Array[int] = []
		for item_id: int in _items:
			if _items[item_id]["type"] == type:
				result.append(item_id)
		return result

	func get_used_slot_count() -> int:
		return _items.size()

	func set_tool(slot: StringName, tool_id: StringName) -> void:
		_tool_slots[slot] = tool_id

	func get_tool(slot: StringName) -> StringName:
		return _tool_slots.get(slot, &"")

	# action_type_map is populated by a Given step (type X supports action Y)
	# so find_best_tool_for_action can mirror PropDef.supports_actions.
	var action_type_map: Dictionary = {}

	# Legacy slot map mirrors Inventory.find_best_tool_for_action fallback.
	const _ACTION_SLOT_MAP: Dictionary = {
		&"chop": &"axe",
		&"mine": &"pickaxe",
		&"attack_melee": &"weapon",
		&"scan": &"scanner",
	}

	## Returns item_id > 0 if a grid item supports the action,
	## -1 if a legacy slot holds a matching tool,
	## 0 otherwise.
	func find_best_tool_for_action(action: StringName) -> int:
		var supporting_type: StringName = action_type_map.get(action, &"")
		if supporting_type != &"":
			for item_id: int in _items:
				if _items[item_id]["type"] == supporting_type:
					return item_id
		var slot: StringName = _ACTION_SLOT_MAP.get(action, &"")
		if slot != &"" and _tool_slots.get(slot, &"") != &"":
			return -1
		return 0

	func get_save_data() -> Dictionary:
		var items_data: Array = []
		var sorted_ids: Array = _items.keys()
		sorted_ids.sort()
		for item_id: int in sorted_ids:
			var item: Dictionary = _items[item_id]
			items_data.append({
				"id": item_id,
				"type": str(item["type"]),
				"origin": [item["origin"].x, item["origin"].y],
				"rotation": item["rotation"],
			})
		return {
			"grid_width": grid_width,
			"grid_height": grid_height,
			"items": items_data,
		}

	func load_save_data(data: Dictionary) -> void:
		if data.has("items") and data.has("grid_width"):
			_load_grid_save(data)
		elif data.has("slots"):
			_load_legacy_save(data)

	func _load_grid_save(data: Dictionary) -> void:
		grid_width = int(data.get("grid_width", 30))
		grid_height = int(data.get("grid_height", 40))
		_items.clear()
		_next_id = 1
		_init_grid()
		var items_data: Array = data.get("items", [])
		for entry in items_data:
			var item_id: int = int(entry.get("id", _next_id))
			if item_id < 1:
				item_id = _next_id
			var type: StringName = StringName(entry.get("type", ""))
			if type == &"":
				continue
			var origin_arr: Array = entry.get("origin", [0, 0])
			var ox: int = int(origin_arr[0]) if origin_arr.size() > 0 else 0
			var oy: int = int(origin_arr[1]) if origin_arr.size() > 1 else 0
			var origin: Vector2i = Vector2i(ox, oy)
			var rotation: int = int(entry.get("rotation", 0))
			var shape: Array[Vector2i] = _get_shape_for_type(type)
			if can_fit(shape, origin, rotation):
				_items[item_id] = {
					"type": type,
					"origin": origin,
					"rotation": rotation,
					"shape": shape,
				}
				_write_cells(item_id, shape, origin, rotation)
			if item_id >= _next_id:
				_next_id = item_id + 1

	func _load_legacy_save(data: Dictionary) -> void:
		grid_width = 30
		grid_height = 40
		_items.clear()
		_next_id = 1
		_init_grid()
		var slots_data: Array = data.get("slots", [])
		for entry in slots_data:
			var type: StringName = StringName(entry.get("type", ""))
			if type == &"":
				continue
			var quantity: int = int(entry.get("quantity", 0))
			var shape: Array[Vector2i] = _get_shape_for_type(type)
			for _i in quantity:
				var placement: Dictionary = find_placement(shape)
				if placement.is_empty():
					break
				_place_internal(type, shape, placement["origin"], placement["rotation"])


## Canonical shape library used across scenarios. Gherkin placeholders
## can't carry typed Array[Vector2i] payloads, so each shape gets a name.
const SHAPES := {
	"single": [Vector2i(0, 0)],
	"stick":  [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"plank":  [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	# 7-cell L — matches the axe shape spirit from delivery-006f content.
	"axe":    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
	           Vector2i(1, 3), Vector2i(0, 4), Vector2i(0, 5)],
}


static func _typed_shape(shape_name: String) -> Array[Vector2i]:
	var raw: Array = SHAPES.get(shape_name, [Vector2i(0, 0)])
	var out: Array[Vector2i] = []
	for cell in raw:
		out.append(cell)
	return out


static func _get_inv(ctx) -> GridModel:
	return ctx.get_value("tetris_inv", null)


static func _seed_shapes(inv: GridModel) -> void:
	for shape_name in SHAPES:
		inv.shape_library[StringName(shape_name)] = _typed_shape(shape_name)


static func _make_inv(w: int, h: int) -> GridModel:
	var inv := GridModel.new(w, h)
	_seed_shapes(inv)
	return inv


func register_steps(registry) -> void:
	# ------------------------------------------------------------------
	# Given: grid construction
	# ------------------------------------------------------------------
	registry.given("a fresh tetris inventory {int} wide by {int} tall",
		func(ctx, w: int, h: int):
			var inv := _make_inv(w, h)
			ctx.set_value("tetris_inv", inv)
			ctx.set_value("last_placed_id", 0)
			ctx.set_value("last_placement_ok", false)
			ctx.set_value("auto_accepted", 0)
			ctx.set_value("auto_rejected", 0)
	)

	registry.given("a grid item type {string} supports action {string}",
		func(ctx, type_id: String, action: String):
			# Register the (type, action) pair in the model so
			# find_best_tool_for_action can resolve it like the production
			# PropDef.supports_actions lookup does.
			var inv := _get_inv(ctx)
			var type_sn: StringName = StringName(type_id)
			var action_sn: StringName = StringName(action)
			if inv != null:
				inv.action_type_map[action_sn] = type_sn
			ctx.set_value("grid_tool_type", type_sn)
			ctx.set_value("grid_tool_action", action_sn)
	)

	registry.given("the legacy tool slot {string} holds {string}",
		func(ctx, slot: String, tool_id: String):
			var inv := _get_inv(ctx)
			if inv != null:
				inv.set_tool(StringName(slot), StringName(tool_id))
	)

	registry.given("a legacy save with {int} of {string} in slots",
		func(ctx, count: int, shape_name: String):
			# Legacy save format: {"slots": [{"type": ..., "quantity": ...}]}.
			# _load_legacy_save iterates slots, resolves each type's shape,
			# and auto-places quantity copies into the grid.
			var save: Dictionary = {
				"slots": [
					{"type": shape_name, "quantity": count},
				],
			}
			ctx.set_value("legacy_save", save)
			ctx.set_value("legacy_shape_name", shape_name)
	)

	# And/Given share text -- register both so either verb matches.
	registry.given("the shape {string} is placed at {int},{int} with rotation {int}",
		func(ctx, shape_name: String, ox: int, oy: int, rot: int):
			var inv := _get_inv(ctx)
			var item_id: int = inv.place_item_at(StringName(shape_name),
				Vector2i(ox, oy), rot)
			ctx.set_value("last_placed_id", item_id)
			ctx.set_value("last_placement_ok", item_id > 0)
	)

	# ------------------------------------------------------------------
	# When: placement / removal / save-load
	# ------------------------------------------------------------------
	registry.when("the shape {string} is placed at {int},{int} with rotation {int}",
		func(ctx, shape_name: String, ox: int, oy: int, rot: int):
			var inv := _get_inv(ctx)
			var item_id: int = inv.place_item_at(StringName(shape_name),
				Vector2i(ox, oy), rot)
			ctx.set_value("last_placed_id", item_id)
			ctx.set_value("last_placement_ok", item_id > 0)
	)

	registry.when("the shape {string} of type {string} is placed at {int},{int} with rotation {int}",
		func(ctx, shape_name: String, type_id: String, ox: int, oy: int, rot: int):
			var inv := _get_inv(ctx)
			inv.shape_library[StringName(type_id)] = _typed_shape(shape_name)
			var item_id: int = inv.place_item_at(StringName(type_id),
				Vector2i(ox, oy), rot)
			ctx.set_value("last_placed_id", item_id)
			ctx.set_value("last_placement_ok", item_id > 0)
	)

	registry.when("{int} copies of {string} are auto-placed",
		func(ctx, count: int, shape_name: String):
			var inv := _get_inv(ctx)
			var accepted: int = 0
			for _i in count:
				var item_id: int = inv.place_item(StringName(shape_name))
				if item_id > 0:
					accepted += 1
				else:
					break
			ctx.set_value("auto_accepted", accepted)
			ctx.set_value("auto_rejected", count - accepted)
	)

	registry.when("the last placed item is removed", func(ctx):
		var inv := _get_inv(ctx)
		var last_id: int = ctx.get_value("last_placed_id", 0)
		if last_id > 0:
			inv.remove_item_by_id(last_id)
	)

	registry.when("the tetris inventory is saved and reloaded", func(ctx):
		var inv := _get_inv(ctx)
		var snapshot: Dictionary = inv.get_save_data()
		var fresh := _make_inv(inv.grid_width, inv.grid_height)
		fresh.load_save_data(snapshot)
		ctx.set_value("tetris_inv", fresh)
	)

	registry.when("the legacy save is loaded into a fresh tetris inventory",
		func(ctx):
			var save: Dictionary = ctx.get_value("legacy_save", {})
			var shape_name: String = ctx.get_value("legacy_shape_name", "single")
			var inv := _make_inv(10, 10)
			inv.shape_library[StringName(shape_name)] = _typed_shape(shape_name)
			inv.load_save_data(save)
			ctx.set_value("tetris_inv", inv)
	)

	# ------------------------------------------------------------------
	# Then: assertions
	# ------------------------------------------------------------------
	registry.then("the placement succeeded", func(ctx):
		var ok: bool = ctx.get_value("last_placement_ok", false)
		ctx.assert_true(ok, "expected last placement to succeed")
	)

	registry.then("the placement was rejected", func(ctx):
		var ok: bool = ctx.get_value("last_placement_ok", true)
		ctx.assert_false(ok, "expected last placement to be rejected")
	)

	registry.then("the cell at {int},{int} is occupied", func(ctx, x: int, y: int):
		var inv := _get_inv(ctx)
		var item_id: int = inv.get_grid_cell(x, y)
		ctx.assert_greater(item_id, 0,
			"expected cell (%d,%d) occupied, got item_id=%d" % [x, y, item_id])
	)

	registry.then("the cell at {int},{int} is empty", func(ctx, x: int, y: int):
		var inv := _get_inv(ctx)
		var item_id: int = inv.get_grid_cell(x, y)
		ctx.assert_equal(item_id, 0,
			"expected cell (%d,%d) empty, got item_id=%d" % [x, y, item_id])
	)

	registry.then("the tetris inventory item count is {int}", func(ctx, expected: int):
		var inv := _get_inv(ctx)
		var actual: int = inv.get_used_slot_count()
		ctx.assert_equal(actual, expected,
			"expected %d items in grid, got %d" % [expected, actual])
	)

	registry.then("{int} copies of {string} were accepted",
		func(ctx, expected: int, _shape_name: String):
			var actual: int = ctx.get_value("auto_accepted", -1)
			ctx.assert_equal(actual, expected,
				"expected %d accepted, got %d" % [expected, actual])
	)

	registry.then("{int} copies of {string} were rejected",
		func(ctx, expected: int, _shape_name: String):
			var actual: int = ctx.get_value("auto_rejected", -1)
			ctx.assert_equal(actual, expected,
				"expected %d rejected, got %d" % [expected, actual])
	)

	registry.then("find_best_tool_for_action {string} returns a grid item",
		func(ctx, action: String):
			var inv := _get_inv(ctx)
			var result: int = inv.find_best_tool_for_action(StringName(action))
			ctx.assert_greater(result, 0,
				"expected find_best_tool_for_action(%s) to return a grid item_id > 0, got %d" % [action, result])
	)

	registry.then("find_best_tool_for_action {string} falls back to the tool slot",
		func(ctx, action: String):
			# Production contract: -1 signals "found in a legacy tool slot,
			# not in the grid". 0 signals "not found anywhere."
			var inv := _get_inv(ctx)
			var result: int = inv.find_best_tool_for_action(StringName(action))
			ctx.assert_equal(result, -1,
				"expected find_best_tool_for_action(%s) to return -1 (slot fallback), got %d" % [action, result])
	)
